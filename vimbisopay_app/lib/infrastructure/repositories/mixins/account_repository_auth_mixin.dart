import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/core/services/dashboard_service.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

/// Mixin that provides authentication-related methods for AccountRepositoryImpl
mixin AccountRepositoryAuthMixin on BaseAccountRepository {
  
  // loginV2 method removed as we're now using v1 login only

  @override
  Future<Either<Failure, User>> login({
    required String phone,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[LOGIN] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/login';
      final body = {
        'phone': formattedPhone,
      };

      // Phone-only authentication - no password fields

      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: baseHeaders,
        body: body,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details') ||
            !jsonResponse['data'].containsKey('dashboard')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];

        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure(
              'Missing required user fields in response'));
        }

        final dashboardData = jsonResponse['data']['dashboard'];

        // Extract vendor status from dashboard data
        final bool isVendor = dashboardData['member']['activateMarket'] as bool? ?? false;
        Logger.data('[LOGIN] Vendor status from API: $isVendor');
        
        // Extract profile thumbnail URL from dashboard data
        final String? profileThumbnailUrl = dashboardData['member']['profilePictureThumbnail'] as String?;
        Logger.data('[LOGIN] Profile thumbnail URL: $profileThumbnailUrl');
        
        // Parse dashboard data including accountsInternal
        final Map<String, dynamic> dashboardMap = {
          'member': {
            'memberID': actionDetails['memberID'],
            'memberTier': dashboardData['member']['memberTier'],
            'firstname': dashboardData['member']['firstname'],
            'lastname': dashboardData['member']['lastname'],
            'memberHandle': dashboardData['member']['memberHandle'] as String?,
            'defaultDenom': dashboardData['member']['defaultDenom'],
            'profilePictureThumbnail': profileThumbnailUrl,
            'remainingAvailableUSD': (() {
              final rawValue = dashboardData['member']['remainingAvailableUSD'];
              Logger.data('[LOGIN] Raw remainingAvailableUSD from API: $rawValue (type: ${rawValue?.runtimeType})');
              return rawValue;
            })(),
            'creditRating': dashboardData['member']['creditRating'],
          },
          'accounts': dashboardData['accounts']
              .map((accountData) => {
                    'accountID': accountData['accountID'],
                    'accountName': accountData['accountName'],
                    'accountHandle': accountData['accountHandle'],
                    'accountType': accountData['accountType'],
                    'defaultDenom': accountData['defaultDenom'],
                    'isOwnedAccount': accountData['isOwnedAccount'],
                    'balanceData': {
                      'securedNetBalancesByDenom': accountData['balanceData']
                          ['securedNetBalancesByDenom'],
                      'unsecuredBalancesInDefaultDenom':
                          calculateUnsecuredBalances(
                        baseBalances: accountData['balanceData']
                            ['unsecuredBalancesInDefaultDenom'],
                        pendingIn: accountData['pendingInData'] ?? [],
                        pendingOut: accountData['pendingOutData'] ?? [],
                        defaultDenom: accountData['defaultDenom'],
                      ),
                      'netCredexAssetsInDefaultDenom':
                          accountData['balanceData']
                              ['netCredexAssetsInDefaultDenom'],
                    },
                    'pendingInData': {
                      'success': true,
                      'data': accountData['pendingInData'] ?? [],
                      'message': 'Pending offers retrieved',
                    },
                    'pendingOutData': {
                      'success': true,
                      'data': accountData['pendingOutData'] ?? [],
                      'message': 'Pending outgoing offers retrieved',
                    },
                    'sendOffersTo': accountData['sendOffersTo'],
                  })
              .toList(),
        };
        
        // Add accountsInternal if present in the response
        if (dashboardData.containsKey('accountsInternal') && dashboardData['accountsInternal'] != null) {
          Logger.data('[LOGIN] Found accountsInternal in dashboard data');
          dashboardMap['accountsInternal'] = dashboardData['accountsInternal'];
        } else {
          Logger.data('[LOGIN] No accountsInternal found in dashboard data');
        }
        
        final dashboardObj = dashboard.Dashboard.fromMap(dashboardMap);

        // Update the centralized dashboard service with the latest data
        DashboardService.instance.updateDashboard(dashboardObj);
        Logger.data('[LOGIN] Dashboard updated in centralized service');

        // Extract version and authMethod from token
        final tokenInfo = extractTokenInfo(token);
        final version = tokenInfo?['version'] ?? 'v1';
        final authMethod = tokenInfo?['authMethod'] ?? 'password';


        // Get existing user to preserve store status and location
        final existingUser = await databaseHelper.getUser();
        
        // Return full user info
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          version: version,
          authMethod: authMethod,
          dashboard: dashboardObj,
          activateMarket: isVendor, // Set activateMarket based on vendor status
          // Preserve store status and location from existing user if available
          storeOpen: existingUser?.storeOpen ?? false,
          latitude: existingUser?.latitude,
          longitude: existingUser?.longitude,
        );
        
        Logger.data('[LOGIN] Preserved store status: ${user.storeOpen}');
        if (user.latitude != null && user.longitude != null) {
          Logger.data('[LOGIN] Preserved location: (${user.latitude}, ${user.longitude})');
        }

        return Right(user);
      } else {
        final errorMessage =
            json.decode(response.body)['message'] ?? 'Login failed';
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
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[ONBOARD_MEMBER] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/onboardMember';
      final body = {
        'firstname': firstName,
        'lastname': lastName,
        'phone': formattedPhone,
        'defaultDenom': 'USD',
      };

      final response = await loggedRequest(
        () => httpClient.post(
          Uri.parse(url),
          headers: baseHeaders,
          body: json.encode(body),
        ),
        url,
        'POST',
        headers: baseHeaders,
        body: body,
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
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final user = await databaseHelper.getUser();
      return Right(user);
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('Error in login', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  @override
  Future<Either<Failure, bool>> saveUser(User user) async {
    try {
      await databaseHelper.saveUser(user);
      return const Right(true);
    } catch (e) {
      return Left(InfrastructureFailure(e.toString()));
    }
  }
}
