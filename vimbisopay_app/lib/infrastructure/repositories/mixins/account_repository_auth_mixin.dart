import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' as dashboard;
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/error_translator.dart';
import 'package:vimbisopay_app/core/utils/phone_formatter.dart';
import 'package:vimbisopay_app/infrastructure/repositories/base_account_repository.dart';

/// Mixin that provides authentication-related methods for AccountRepositoryImpl
mixin AccountRepositoryAuthMixin on BaseAccountRepository {
  
  @override
  Future<Either<Failure, User>> loginV2({
    required String phone,
    String? password,
    String? passwordHash,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[LOGIN_V2] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/v2/login';
      final body = {
        'phone': formattedPhone,
      };

      // For v2 login, we send phone and hashed password
      if (password != null) {
        // Hash the password before sending
        final hash = await passwordService.hashPassword(password);
        body['password'] = hash;
        // Store the hash for later use
        passwordHash = hash;
      } else if (passwordHash != null) {
        // For token refresh, use the stored hash
        body['password'] = passwordHash;
      }

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

      final jsonResponse = json.decode(response.body);

      // Check for PASSWORD_REQUIRED error
      if (jsonResponse['data']?['action']?['details']?['code'] == 'PASSWORD_REQUIRED') {
        return Left(AuthFailure(
          message: jsonResponse['message'] ?? 'Password is required for this account',
          code: 'PASSWORD_REQUIRED',
        ));
      }

      if (response.statusCode == 200) {
        if (!jsonResponse.containsKey('data') ||
            !jsonResponse['data'].containsKey('action') ||
            !jsonResponse['data']['action'].containsKey('details') ||
            !jsonResponse['data'].containsKey('dashboard')) {
          return const Left(InfrastructureFailure('Invalid response format'));
        }

        final actionDetails = jsonResponse['data']['action']['details'];
        final dashboardData = jsonResponse['data']['dashboard'];

        final memberId = actionDetails['memberID']?.toString();
        final userPhone = actionDetails['phone']?.toString();
        final token = actionDetails['token']?.toString();
        final version = actionDetails['version']?.toString();
        final authMethod = actionDetails['authMethod']?.toString();
        final otpVerified = actionDetails['otpVerified'] as bool? ?? false;

        if (memberId == null || userPhone == null || token == null) {
          return const Left(InfrastructureFailure(
              'Missing required user fields in response'));
        }

        // Check if this is a phone-only v2 login
        if (version == 'v2' && authMethod == 'phone_only') {
          // Create user with minimal info for password setup flow
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          otpVerified: otpVerified,
          version: version,
          authMethod: authMethod,
          passwordHash: passwordHash,
          passwordChanged: password != null ? DateTime.now() : null,
        );
        
        // Save user with password info to database
        await databaseHelper.saveUser(user);
        
        return Right(user);
        }

        // Otherwise process as normal login with dashboard
        // Extract vendor status from dashboard data
        final bool isVendor = dashboardData['member']['activateMarket'] as bool? ?? false;
        Logger.data('[LOGIN_V2] Vendor status from API: $isVendor');
        
        // Parse dashboard data including accountsInternal
        final Map<String, dynamic> dashboardMap = {
          'member': {
            'memberID': actionDetails['memberID'],
            'memberTier': dashboardData['member']['memberTier'],
            'firstname': dashboardData['member']['firstname'],
            'lastname': dashboardData['member']['lastname'],
            'memberHandle': dashboardData['member']['memberHandle'] as String?,
            'defaultDenom': dashboardData['member']['defaultDenom'],
            'profilePictureThumbnail': dashboardData['member']['profilePictureThumbnail'] as String?,
            // Extract remainingAvailableUSD with explicit logging
            'remainingAvailableUSD': (() {
              final rawValue = dashboardData['member']['remainingAvailableUSD'];
              Logger.data('[LOGIN_V2] Raw remainingAvailableUSD from API: $rawValue (type: ${rawValue?.runtimeType})');
              return rawValue;
            })(),
            'creditRating': dashboardData['member']['creditRating'],
          },
          'accounts': dashboardData['accounts']
              .map((accountData) => {
                    'accountID': accountData['accountID'],
                    'accountName': accountData['accountName'],
                    'accountHandle': accountData['accountHandle'],
                    'defaultDenom': accountData['defaultDenom'],
                    'isOwnedAccount': accountData['isOwnedAccount'],
                    'accountType': accountData['accountType'], // Include accountType field
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
          Logger.data('[LOGIN_V2] Found accountsInternal in dashboard data');
          dashboardMap['accountsInternal'] = dashboardData['accountsInternal'];
        } else {
          Logger.data('[LOGIN_V2] No accountsInternal found in dashboard data');
        }
        
        final dashboardObj = dashboard.Dashboard.fromMap(dashboardMap);

        // Get existing user to preserve store status and location
        final existingUser = await databaseHelper.getUser();
        
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          otpVerified: otpVerified,
          version: version,
          authMethod: authMethod,
          passwordHash: passwordHash,
          passwordChanged: password != null ? DateTime.now() : null,
          dashboard: dashboardObj,
          activateMarket: isVendor, // Set activateMarket based on vendor status
          // Preserve store status and location from existing user if available
          storeOpen: existingUser?.storeOpen ?? false,
          latitude: existingUser?.latitude,
          longitude: existingUser?.longitude,
        );

        // Save user with password info to database
        await databaseHelper.saveUser(user);
        
        Logger.data('[LOGIN_V2] Preserved store status: ${user.storeOpen}');
        if (user.latitude != null && user.longitude != null) {
          Logger.data('[LOGIN_V2] Preserved location: (${user.latitude}, ${user.longitude})');
        }

        return Right(user);
      } else {
        final errorMessage = json.decode(response.body)['message'] ?? 'Login failed';
        return Left(InfrastructureFailure(errorMessage));
      }
    } catch (e) {
      final userFriendlyMessage = ErrorTranslator.translateError(e);
      Logger.error('Error in loginV2', e);
      return Left(InfrastructureFailure(userFriendlyMessage));
    }
  }

  @override
  Future<Either<Failure, User>> login({
    required String phone,
    String? password,
    String? passwordHash,
  }) async {
    try {
      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[LOGIN] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/login';
      final body = {
        'phone': formattedPhone,
      };

      // For phone-only authentication, we don't send any password fields
      if (passwordHash != null) {
        // Only include password fields for token refresh
        body['password_hash'] = passwordHash;
      }

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

        // Extract version and authMethod from token
        final tokenInfo = extractTokenInfo(token);
        final version = tokenInfo?['version'] ?? 'v1';
        final authMethod = tokenInfo?['authMethod'] ?? 'password';

        // For v1 phone-only auth, return minimal user info
        if (version == 'v1' && authMethod == 'phone_only') {
          final user = User(
            memberId: memberId,
            phone: userPhone,
            token: token,
            otpVerified: false,
            version: version,
            authMethod: authMethod,
          );
          return Right(user);
        }

        // Get existing user to preserve store status and location
        final existingUser = await databaseHelper.getUser();
        
        // Otherwise return full user info
        final user = User(
          memberId: memberId,
          phone: userPhone,
          token: token,
          passwordHash: body['password_hash'],
          passwordChanged: DateTime.now(),
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
    required String password,
  }) async {
    try {
      // Hash password before sending to server
      final hash = await passwordService.hashPassword(password);

      // Format phone number before sending
      final formattedPhone = PhoneNumberFormatter.sanitizePhoneNumber(phone);
      Logger.data('[ONBOARD_MEMBER] Formatted phone number: $formattedPhone');

      final url = '$baseUrl/onboardMember';
      final body = {
        'firstname': firstName,
        'lastname': lastName,
        'phone': formattedPhone,
        'defaultDenom': 'USD',
        'password': hash,
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
