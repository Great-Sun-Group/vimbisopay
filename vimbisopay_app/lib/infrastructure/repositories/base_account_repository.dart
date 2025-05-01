import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/network_logger.dart';

/// Base class that provides common utilities for the AccountRepository implementation
abstract class BaseAccountRepository {
  final String baseUrl = ApiConfig.baseUrl;
  
  final DatabaseHelper databaseHelper;
  final PasswordService passwordService;
  final http.Client httpClient;
  
  BaseAccountRepository({
    required this.passwordService,
    required this.databaseHelper,
    required this.httpClient,
  });
  
  Map<String, dynamic> calculateUnsecuredBalances({
    required Map<String, dynamic> baseBalances,
    required List<dynamic> pendingIn,
    required List<dynamic> pendingOut,
    required String defaultDenom,
  }) {
    // Extract base values, defaulting to 0.00 if not present
    final double baseReceivables = double.tryParse(baseBalances['totalReceivables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    final double basePayables = double.tryParse(baseBalances['totalPayables']
                ?.toString()
                .replaceAll(RegExp(r'[^\d.-]'), '') ??
            '0.00') ??
        0.00;

    // Calculate pending amounts
    final double pendingInTotal = pendingIn.fold(0.00, (sum, tx) {
      final amount = double.tryParse(tx['formattedInitialAmount']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.-]'), '') ??
              '0.00') ??
          0.00;
      return sum + amount;
    });

    final double pendingOutTotal = pendingOut.fold(0.00, (sum, tx) {
      final amount = double.tryParse(tx['formattedInitialAmount']
                  ?.toString()
                  .replaceAll(RegExp(r'[^\d.-]'), '') ??
              '0.00') ??
          0.00;
      return sum + amount;
    });

    // Add pending amounts to base values
    final totalReceivables = baseReceivables + pendingInTotal;
    final totalPayables = basePayables + pendingOutTotal;
    final netPayRec = totalReceivables - totalPayables;

    // Format values with denomination
    return {
      'totalReceivables':
          '${totalReceivables.toStringAsFixed(2)} $defaultDenom',
      'totalPayables': '${totalPayables.toStringAsFixed(2)} $defaultDenom',
      'netPayRec': '${netPayRec.toStringAsFixed(2)} $defaultDenom',
    };
  }

  Map<String, String> get baseHeaders => {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
      };

  Map<String, String> authHeaders(String token) => {
        ...baseHeaders,
        'Authorization': 'Bearer $token',
      };

  Future<http.Response> loggedRequest(
    Future<http.Response> Function() request,
    String url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      NetworkLogger.logRequest(
        url: url,
        method: method,
        headers: headers ?? {},
        body: body,
      );

      final response = await request();

      NetworkLogger.logResponse(
        url: url,
        statusCode: response.statusCode,
        body: response.body,
      );

      return response;
    } catch (e) {
      NetworkLogger.logError(url: url, error: e);
      rethrow;
    }
  }

  Map<String, String>? extractTokenInfo(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final data = json.decode(decoded);

      return {
        'version': data['version']?.toString() ?? 'v1',
        'authMethod': data['authMethod']?.toString() ?? 'password',
      };
    } catch (e) {
      Logger.error('Error decoding token', e);
      return null;
    }
  }
  
  /// Abstract method that must be implemented by subclasses
  Future<Either<Failure, User>> login({
    required String phone,
  });
  
  /// Abstract method that must be implemented by subclasses
  Future<Either<Failure, bool>> saveUser(User user);
  
  /// Execute an authenticated request with token refresh capability
  Future<Either<Failure, T>> executeAuthenticatedRequest<T>({
    required Future<Either<Failure, T>> Function(String token) request,
    bool isRetry = false,
  }) async {
    try {
      final user = await databaseHelper.getUser();
      if (user == null) {
        return const Left(InfrastructureFailure('Not authenticated'));
      }

      final result = await request(user.token);

      return result.fold(
        (failure) async {
          if (!isRetry &&
              failure.message?.toLowerCase().contains('token expired') ==
                  true) {
            // No password check needed for v1 login

            // Re-login with phone number only
            final loginResult = await login(
              phone: user.phone,
            );

            return loginResult.fold(
              (loginFailure) => Left(loginFailure),
              (newUser) async {
                Logger.data('[TOKEN_REFRESH] Creating updated user with refreshed token');
                Logger.data('[TOKEN_REFRESH] Original user activateMarket: ${user.activateMarket}');
                Logger.data('[TOKEN_REFRESH] New user activateMarket: ${newUser.activateMarket}');
                
                // Extract vendor status directly from the login response
                bool isVendor = false;
                
                // Get vendor status from the new user
                isVendor = newUser.activateMarket;
                Logger.data('[TOKEN_REFRESH] Using vendor status from login response: $isVendor');
                
                // Use the extracted vendor status or fall back to previous values
                final activateMarket = isVendor || newUser.activateMarket || user.activateMarket;
                Logger.data('[TOKEN_REFRESH] Final activateMarket value: $activateMarket');
                
                final updatedUser = newUser.copyWith(
                  activateMarket: activateMarket, // Set vendor status based on dashboard data
                  storeOpen: user.storeOpen, // Preserve the original storeOpen status
                  latitude: user.latitude, // Preserve the original latitude
                  longitude: user.longitude, // Preserve the original longitude
                );

                Logger.data('[TOKEN_REFRESH] Updated user activateMarket: ${updatedUser.activateMarket}');
                final saveResult = await saveUser(updatedUser);

                return saveResult.fold(
                  (saveFailure) => Left(saveFailure),
                  (_) => executeAuthenticatedRequest<T>(
                    request: request,
                    isRetry: true,
                  ),
                );
              },
            );
          }
          return Left(failure);
        },
        Right.new,
      );
    } catch (e) {
      Logger.error('Error in executeAuthenticatedRequest', e);
      return Left(InfrastructureFailure(e.toString()));
    }
  }
}
