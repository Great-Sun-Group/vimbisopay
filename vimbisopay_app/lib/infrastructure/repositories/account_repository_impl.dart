import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/error/failures.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/account_repository.dart';
import '../../core/config/api_config.dart';
import '../database/database_helper.dart';
import '../services/security_service.dart';
import '../services/encryption_service.dart';

class AccountRepositoryImpl implements AccountRepository {
  final String baseUrl =
      'https://dev.mycredex.dev';
  
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final SecurityService _securityService = SecurityService();
  late final EncryptionService _encryptionService;

  AccountRepositoryImpl() {
    _encryptionService = EncryptionService(_securityService);
  }

  Map<String, String> get _baseHeaders => {
    'Content-Type': 'application/json',
    'x-client-api-key': ApiConfig.apiKey,
  };

  Map<String, String> _authHeaders(String token) => {
    ..._baseHeaders,
    'Authorization': 'Bearer $token',
  };

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await _databaseHelper.getUser();
      return Right(user);
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  Future<Either<Failure, bool>> saveUser(User user) async {
    try {
      await _databaseHelper.saveUser(user);
      return const Right(true);
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, double>>> getBalances() async {
    try {
      final user = await _databaseHelper.getUser();
      if (user == null) {
        return Left(InfrastructureFailure('Not authenticated'));
      }

      final response = await http.get(
        Uri.parse('$baseUrl/balances'),
        headers: _authHeaders(user.token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Right(Map<String, double>.from(data['balances']));
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get balances';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List>> getLedger({int? startRow, int? numRows}) async {
    try {
      final user = await _databaseHelper.getUser();
      if (user == null) {
        return Left(InfrastructureFailure('Not authenticated'));
      }

      final queryParams = {
        if (startRow != null) 'startRow': startRow.toString(),
        if (numRows != null) 'numRows': numRows.toString(),
      };

      final response = await http.get(
        Uri.parse('$baseUrl/ledger').replace(queryParameters: queryParams),
        headers: _authHeaders(user.token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Right(data['entries'] as List);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get ledger';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Account>> getAccountByHandle(String handle) async {
    try {
      final user = await _databaseHelper.getUser();
      if (user == null) {
        return Left(InfrastructureFailure('Not authenticated'));
      }

      final response = await http.get(
        Uri.parse('$baseUrl/accounts/$handle'),
        headers: _authHeaders(user.token),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Right(Account(
          id: data['id'],
          handle: data['handle'],
          name: data['name'],
          defaultDenom: data['defaultDenom'],
          balances: Map<String, double>.from(data['balances']),
        ));
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Failed to get account';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> onboardMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/onboardMember'),
        headers: _baseHeaders,
        body: json.encode({
          'firstname': firstName,
          'lastname': lastName,
          'phone': phone,
          'defaultDenom': 'CXX',
          'password': password
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const Right(true);
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Failed to onboard member';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    required String password,
  }) async {
    try {
      // Client-side password validation
      if (password.length < 6) {
        return Left(InfrastructureFailure('Password must be at least 6 characters'));
      }

      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: _baseHeaders,
        body: json.encode({
          'phone': phone,
        //  'password': password, // Map password to pin for API
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        
        // Validate response structure
        if (!jsonResponse.containsKey('data') || 
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details')) {
          return Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        
        // Create user object with data from response
        final user = User(
          memberId: actionDetails['memberID'],
          phone: actionDetails['phone'],
          token: actionDetails['token'],
        );
        
        // Return user without saving to database
        return Right(user);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Login failed';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }
}
