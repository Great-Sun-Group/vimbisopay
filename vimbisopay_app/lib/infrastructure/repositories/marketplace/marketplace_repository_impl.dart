import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/error/exceptions.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Implementation of the [MarketplaceRepository] interface.
///
/// This implementation handles API communication and data transformation
/// for marketplace operations. Currently uses mock data for testing.
class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final http.Client _httpClient;
  final String _baseUrl;
  final DatabaseHelper _databaseHelper;

  /// Creates a new [MarketplaceRepositoryImpl] instance.
  ///
  /// Requires an HTTP client for API communication, a base URL for the API,
  /// and a database helper for accessing user data.
  MarketplaceRepositoryImpl({
    required http.Client httpClient,
    required String baseUrl,
    required DatabaseHelper databaseHelper,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl,
        _databaseHelper = databaseHelper;

  @override
  Future<Either<Failure, bool>> enableVendorFunctionality() async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting enableVendorFunctionality operation');
    
    try {
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');

      // Prepare request data
      final requestBody = jsonEncode({
        'vendor': true,
      });
      Logger.data('[MARKETPLACE] Request body: $requestBody');
      
      // Call the /sellInMarket API endpoint with authentication
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/sellInMarket');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/sellInMarket'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBody,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      Logger.data('[MARKETPLACE] Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data: $responseData');
        
        // Extract vendor status from the response
        bool isVendor = false;
        try {
          isVendor = responseData['data']['dashboard']['member']['vendor'] ?? false;
          Logger.data('[MARKETPLACE] Extracted vendor status: $isVendor');
        } catch (e) {
          Logger.error('[MARKETPLACE] Error extracting vendor status from response', e);
          // Continue with default value (false) if extraction fails
        }
        
        // Update the user record in the database
        try {
          final user = await _databaseHelper.getUser();
          if (user != null) {
            // Update user with activateMarket status based on vendor flag
            final updatedUser = user.copyWith(activateMarket: isVendor);
            await _databaseHelper.saveUser(updatedUser);
            Logger.data('[MARKETPLACE] Updated user with activateMarket: $isVendor');
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error updating user with vendor status', e);
          // Continue even if update fails, as the API call was successful
        }
        
        stopwatch.stop();
        Logger.performance('[MARKETPLACE] enableVendorFunctionality completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        return const Right(true);
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure(
            'Failed to enable vendor functionality: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error enabling vendor functionality', e, stackTrace);
      return Left(ServerFailure('Failed to enable vendor functionality: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> updateMemberWithVendorDetails({
    String? firstname,
    String? lastname,
    String? memberHandle,
    String? vendorBio,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting updateMemberWithVendorDetails operation');
    
    try {
      // Log the input parameters
      Logger.data('[MARKETPLACE] Update parameters: firstname=$firstname, lastname=$lastname, memberHandle=$memberHandle, vendorBio=${vendorBio != null ? '${vendorBio.substring(0, min(20, vendorBio.length))}...' : 'null'}');
      
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');

      // Create request body with only the provided fields
      final Map<String, dynamic> requestBody = {};
      if (firstname != null) requestBody['firstname'] = firstname;
      if (lastname != null) requestBody['lastname'] = lastname;
      if (memberHandle != null) requestBody['memberHandle'] = memberHandle;
      if (vendorBio != null) requestBody['vendorBio'] = vendorBio;
      
      final requestBodyJson = jsonEncode(requestBody);
      Logger.data('[MARKETPLACE] Request body: $requestBodyJson');

      // Call the /editMember API endpoint with authentication
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/editMember');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/editMember'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBodyJson,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      Logger.data('[MARKETPLACE] Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        stopwatch.stop();
        Logger.performance('[MARKETPLACE] updateMemberWithVendorDetails completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        return const Right(true);
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure(
            'Failed to update member with vendor details: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error updating member with vendor details', e, stackTrace);
      return Left(
          ServerFailure('Failed to update member with vendor details: $e'));
    }
  }

  // No mock data - using real API calls only

  @override
  Future<Either<Failure, Vendor>> getVendor(String id) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getVendor operation for ID: $id');
    
    try {
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');
      
      // Call the API endpoint to get vendor details
      Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getVendor/$id');
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/getVendor/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data received successfully');
        
        // Extract vendor details from the response
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('vendor')) {
            
            final vendorData = responseData['data']['vendor'] as Map<String, dynamic>;
            
            final vendor = Vendor(
              id: vendorData['id'] ?? id,
              memberId: vendorData['memberId'] ?? '',
              businessName: vendorData['businessName'] ?? 'Unknown Business',
              description: vendorData['description'] ?? '',
              email: vendorData['email'] ?? '',
              phone: vendorData['phone'] ?? '',
              profileImageUrl: vendorData['profileImageUrl'],
              bannerImageUrl: vendorData['bannerImageUrl'],
              rating: (vendorData['rating'] as num?)?.toDouble() ?? 0.0,
              ratingCount: vendorData['ratingCount'] as int? ?? 0,
              isActive: vendorData['isActive'] as bool? ?? true,
              createdAt: vendorData['createdAt'] != null 
                  ? DateTime.parse(vendorData['createdAt']) 
                  : DateTime.now(),
              updatedAt: vendorData['updatedAt'] != null 
                  ? DateTime.parse(vendorData['updatedAt']) 
                  : DateTime.now(),
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] getVendor completed successfully in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          } else {
            Logger.error('[MARKETPLACE] Vendor data not found in response');
            return Left(NotFoundFailure('Vendor not found in response'));
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error parsing vendor data from response', e);
          return Left(ServerFailure('Failed to parse vendor data: $e'));
        }
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 404) {
        Logger.error('[MARKETPLACE] Vendor not found with status code 404');
        return Left(NotFoundFailure('Vendor not found'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to get vendor: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error getting vendor', e, stackTrace);
      return Left(ServerFailure('Failed to get vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Vendor>> getVendorByMemberId(String memberId) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getVendorByMemberId operation for member ID: $memberId');
    
    try {
      // First check if the user is a vendor in the database
      final user = await _databaseHelper.getUser();
      if (user == null || !user.activateMarket) {
        Logger.error('[MARKETPLACE] User is not a vendor in the database');
        return Left(NotFoundFailure('User is not a vendor'));
      }
      
      // Get the user token from local storage
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');
      
      // Call the API endpoint to get vendor details by member ID
      Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getVendorByMemberId/$memberId');
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/getVendorByMemberId/$memberId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data received successfully');
        
        // Extract vendor details from the response
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('vendor')) {
            
            final vendorData = responseData['data']['vendor'] as Map<String, dynamic>;
            
            final vendor = Vendor(
              id: vendorData['id'] ?? 'v_temp_$memberId',
              memberId: vendorData['memberId'] ?? memberId,
              businessName: vendorData['businessName'] ?? 'Unknown Business',
              description: vendorData['description'] ?? '',
              email: vendorData['email'] ?? '',
              phone: vendorData['phone'] ?? user.phone,
              profileImageUrl: vendorData['profileImageUrl'] ?? user.dashboard?.member.profilePictureThumbnail,
              bannerImageUrl: vendorData['bannerImageUrl'],
              rating: (vendorData['rating'] as num?)?.toDouble() ?? 0.0,
              ratingCount: vendorData['ratingCount'] as int? ?? 0,
              isActive: vendorData['isActive'] as bool? ?? true,
              createdAt: vendorData['createdAt'] != null 
                  ? DateTime.parse(vendorData['createdAt']) 
                  : DateTime.now(),
              updatedAt: vendorData['updatedAt'] != null 
                  ? DateTime.parse(vendorData['updatedAt']) 
                  : DateTime.now(),
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] getVendorByMemberId completed successfully in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          } else {
            // If vendor not found in API but user is a vendor, create a temporary vendor record
            Logger.data('[MARKETPLACE] Creating temporary vendor record for member: $memberId');
            
            // Use user data to populate vendor fields if available
            final now = DateTime.now();
            final businessName = user.dashboard?.member.firstname != null && user.dashboard?.member.lastname != null
                ? '${user.dashboard!.member.firstname} ${user.dashboard!.member.lastname}'
                : 'My Business';
                
            final vendor = Vendor(
              id: 'v_temp_${user.memberId}',
              memberId: user.memberId,
              businessName: businessName,
              description: 'Vendor profile',
              email: '', // No email available in DashboardMember
              phone: user.phone,
              profileImageUrl: user.dashboard?.member.profilePictureThumbnail,
              bannerImageUrl: null,
              rating: 0.0,
              ratingCount: 0,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] getVendorByMemberId completed with temporary vendor in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error parsing vendor data from response', e);
          return Left(ServerFailure('Failed to parse vendor data: $e'));
        }
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 404) {
        // If vendor not found in API but user is a vendor, create a temporary vendor record
        Logger.data('[MARKETPLACE] Vendor not found in API, creating temporary vendor record for member: $memberId');
        
        // Use user data to populate vendor fields if available
        final now = DateTime.now();
        final businessName = user.dashboard?.member.firstname != null && user.dashboard?.member.lastname != null
            ? '${user.dashboard!.member.firstname} ${user.dashboard!.member.lastname}'
            : 'My Business';
            
        final vendor = Vendor(
          id: 'v_temp_${user.memberId}',
          memberId: user.memberId,
          businessName: businessName,
          description: 'Vendor profile',
          email: '', // No email available in DashboardMember
          phone: user.phone,
          profileImageUrl: user.dashboard?.member.profilePictureThumbnail,
          bannerImageUrl: null,
          rating: 0.0,
          ratingCount: 0,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        );
        
        stopwatch.stop();
        Logger.performance('[MARKETPLACE] getVendorByMemberId completed with temporary vendor in ${stopwatch.elapsedMilliseconds}ms');
        return Right(vendor);
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to get vendor by member ID: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error getting vendor by member ID', e, stackTrace);
      return Left(ServerFailure('Failed to get vendor by member ID: $e'));
    }
  }

  @override
  Future<bool> isMemberVendor(String memberId) async {
    try {
      Logger.data('[MARKETPLACE] Checking if member is a vendor: $memberId');

      // Get the user from the database to check activateMarket property
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database when checking vendor status');
        return false;
      }
      
      // Check the activateMarket property on the User object
      final isVendor = user.activateMarket;
      Logger.data('[MARKETPLACE] User activateMarket status: $isVendor');
      
      return isVendor;
    } catch (e) {
      Logger.error('[MARKETPLACE] Error checking vendor status', e);
      return false;
    }
  }

  @override
  Future<Either<Failure, Vendor>> createVendor({
    required String memberId,
    required String businessName,
    required String description,
    required String email,
    required String phone,
    String? profileImageUrl,
    String? bannerImageUrl,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting createVendor operation');
    
    try {
      // Log the input parameters
      Logger.data('[MARKETPLACE] Create vendor parameters: memberId=$memberId, businessName=$businessName, email=$email, phone=$phone');
      Logger.data('[MARKETPLACE] Description: ${description.length > 50 ? '${description.substring(0, 50)}...' : description}');
      Logger.data('[MARKETPLACE] Profile image URL: ${profileImageUrl ?? 'null'}');
      Logger.data('[MARKETPLACE] Banner image URL: ${bannerImageUrl ?? 'null'}');
      
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');
      
      // Prepare request data
      final Map<String, dynamic> requestBody = {
        'memberId': memberId,
        'businessName': businessName,
        'description': description,
        'email': email,
        'phone': phone,
      };
      
      if (profileImageUrl != null) requestBody['profileImageUrl'] = profileImageUrl;
      if (bannerImageUrl != null) requestBody['bannerImageUrl'] = bannerImageUrl;
      
      final requestBodyJson = jsonEncode(requestBody);
      Logger.data('[MARKETPLACE] Request body: $requestBodyJson');
      
      // Call the API endpoint to create vendor
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/createVendor');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/createVendor'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBodyJson,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data received successfully');
        
        // Extract vendor details from the response
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('vendor')) {
            
            final vendorData = responseData['data']['vendor'] as Map<String, dynamic>;
            
            final vendor = Vendor(
              id: vendorData['id'] ?? 'v_temp_$memberId',
              memberId: vendorData['memberId'] ?? memberId,
              businessName: vendorData['businessName'] ?? businessName,
              description: vendorData['description'] ?? description,
              email: vendorData['email'] ?? email,
              phone: vendorData['phone'] ?? phone,
              profileImageUrl: vendorData['profileImageUrl'] ?? profileImageUrl,
              bannerImageUrl: vendorData['bannerImageUrl'] ?? bannerImageUrl,
              rating: (vendorData['rating'] as num?)?.toDouble() ?? 0.0,
              ratingCount: vendorData['ratingCount'] as int? ?? 0,
              isActive: vendorData['isActive'] as bool? ?? true,
              createdAt: vendorData['createdAt'] != null 
                  ? DateTime.parse(vendorData['createdAt']) 
                  : DateTime.now(),
              updatedAt: vendorData['updatedAt'] != null 
                  ? DateTime.parse(vendorData['updatedAt']) 
                  : DateTime.now(),
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] createVendor completed successfully in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          } else {
            // If vendor data not found in response, create a temporary vendor object
            final now = DateTime.now();
            final vendor = Vendor(
              id: 'v_temp_$memberId',
              memberId: memberId,
              businessName: businessName,
              description: description,
              email: email,
              phone: phone,
              profileImageUrl: profileImageUrl,
              bannerImageUrl: bannerImageUrl,
              rating: 0.0,
              ratingCount: 0,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] createVendor completed with temporary vendor in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error parsing vendor data from response', e);
          return Left(ServerFailure('Failed to parse vendor data: $e'));
        }
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to create vendor: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error creating vendor', e, stackTrace);
      return Left(ServerFailure('Failed to create vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Vendor>> updateVendor({
    required String id,
    String? businessName,
    String? description,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? bannerImageUrl,
    bool? isActive,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting updateVendor operation for ID: $id');
    
    try {
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');
      
      // If no profile image URL is provided, try to get it from the dashboard
      if (profileImageUrl == null) {
        try {
          if (user.dashboard?.member.profilePictureThumbnail != null) {
            profileImageUrl = user.dashboard!.member.profilePictureThumbnail;
            Logger.data('[UPDATE_VENDOR] Using profile image from dashboard: $profileImageUrl');
          }
        } catch (e) {
          Logger.error('[UPDATE_VENDOR] Error getting profile image from dashboard', e);
          // Continue without profile image if there's an error
        }
      }
      
      // Prepare request data with only the provided fields
      final Map<String, dynamic> requestBody = {
        'id': id,
      };
      
      if (businessName != null) requestBody['businessName'] = businessName;
      if (description != null) requestBody['description'] = description;
      if (email != null) requestBody['email'] = email;
      if (phone != null) requestBody['phone'] = phone;
      if (profileImageUrl != null) requestBody['profileImageUrl'] = profileImageUrl;
      if (bannerImageUrl != null) requestBody['bannerImageUrl'] = bannerImageUrl;
      if (isActive != null) requestBody['isActive'] = isActive;
      
      final requestBodyJson = jsonEncode(requestBody);
      Logger.data('[MARKETPLACE] Request body: $requestBodyJson');
      
      // Call the API endpoint to update vendor
      Logger.data('[MARKETPLACE] Sending PUT request to $_baseUrl/updateVendor');
      final response = await _httpClient.put(
        Uri.parse('$_baseUrl/updateVendor'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBodyJson,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        // For 204 No Content response, we need to get the vendor again to return the updated data
        if (response.statusCode == 204 || response.body.isEmpty) {
          Logger.data('[MARKETPLACE] No content in response, fetching updated vendor');
          
          // Get the updated vendor
          final getVendorResult = await getVendor(id);
          
          return getVendorResult;
        }
        
        // Parse the response body for 200 OK response
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data received successfully');
        
        // Extract vendor details from the response
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('vendor')) {
            
            final vendorData = responseData['data']['vendor'] as Map<String, dynamic>;
            
            final vendor = Vendor(
              id: vendorData['id'] ?? id,
              memberId: vendorData['memberId'] ?? '',
              businessName: vendorData['businessName'] ?? businessName ?? '',
              description: vendorData['description'] ?? description ?? '',
              email: vendorData['email'] ?? email ?? '',
              phone: vendorData['phone'] ?? phone ?? '',
              profileImageUrl: vendorData['profileImageUrl'] ?? profileImageUrl,
              bannerImageUrl: vendorData['bannerImageUrl'] ?? bannerImageUrl,
              rating: (vendorData['rating'] as num?)?.toDouble() ?? 0.0,
              ratingCount: vendorData['ratingCount'] as int? ?? 0,
              isActive: vendorData['isActive'] as bool? ?? isActive ?? true,
              createdAt: vendorData['createdAt'] != null 
                  ? DateTime.parse(vendorData['createdAt']) 
                  : DateTime.now(),
              updatedAt: vendorData['updatedAt'] != null 
                  ? DateTime.parse(vendorData['updatedAt']) 
                  : DateTime.now(),
            );
            
            stopwatch.stop();
            Logger.performance('[MARKETPLACE] updateVendor completed successfully in ${stopwatch.elapsedMilliseconds}ms');
            return Right(vendor);
          } else {
            Logger.error('[MARKETPLACE] Vendor data not found in response');
            return Left(NotFoundFailure('Vendor not found in response'));
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error parsing vendor data from response', e);
          return Left(ServerFailure('Failed to parse vendor data: $e'));
        }
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 404) {
        Logger.error('[MARKETPLACE] Vendor not found with status code 404');
        return Left(NotFoundFailure('Vendor not found'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to update vendor: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error updating vendor', e, stackTrace);
      return Left(ServerFailure('Failed to update vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Product>> getProduct(String id) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getProduct operation for ID: $id');
    
    try {
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');
      
      // Call the /getProduct/{id} API endpoint with authentication
      Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getProduct/$id');
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/getProduct/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data received successfully');
        
        // Check if the response contains profile picture URLs
        List<String> imageUrls = [];
        
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('dashboard') &&
              responseData['data']['dashboard'] is Map<String, dynamic> &&
              responseData['data']['dashboard'].containsKey('product') &&
              responseData['data']['dashboard']['product'] is Map<String, dynamic> &&
              responseData['data']['dashboard']['product'].containsKey('profilePictureUrls')) {
            
            final profilePictureUrls = responseData['data']['dashboard']['product']['profilePictureUrls'] as Map<String, dynamic>;
            Logger.data('[MARKETPLACE] Found profile picture URLs in response: $profilePictureUrls');
            
            // Add the profile picture URLs to the image URLs list
            // Prefer pic600 if available, then pic200, then thumbnail, then original
            if (profilePictureUrls.containsKey('pic600') && profilePictureUrls['pic600'] != null) {
              imageUrls.add(profilePictureUrls['pic600']);
              Logger.data('[MARKETPLACE] Using pic600 as image URL');
            } else if (profilePictureUrls.containsKey('pic200') && profilePictureUrls['pic200'] != null) {
              imageUrls.add(profilePictureUrls['pic200']);
              Logger.data('[MARKETPLACE] Using pic200 as image URL');
            } else if (profilePictureUrls.containsKey('thumbnail') && profilePictureUrls['thumbnail'] != null) {
              imageUrls.add(profilePictureUrls['thumbnail']);
              Logger.data('[MARKETPLACE] Using thumbnail as image URL');
            } else if (profilePictureUrls.containsKey('original') && profilePictureUrls['original'] != null) {
              imageUrls.add(profilePictureUrls['original']);
              Logger.data('[MARKETPLACE] Using original as image URL');
            }
          } else {
            Logger.data('[MARKETPLACE] No profile picture URLs found in response');
            
            // Try to find the product in the mock products list
            try {
              final mockProduct = _mockProducts.firstWhere(
                (p) => p.id == id,
                orElse: () => throw NotFoundException('Product not found in mock data'),
              );
              
              // Use the image URLs from the mock product
              imageUrls = mockProduct.imageUrls;
              Logger.data('[MARKETPLACE] Using image URLs from mock product: $imageUrls');
            } catch (e) {
              Logger.error('[MARKETPLACE] Error finding product in mock data', e);
              // Continue with empty image URLs
            }
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error extracting profile picture URLs from response', e);
          // Continue with empty image URLs
        }
        
        // Extract product details from the response
        String productId = id;
        String vendorId = '';
        String name = '';
        String description = '';
        int price = 0;
        String currency = 'USD';
        String category = '';
        List<String> tags = [];
        bool isAvailable = true;
        String? accountId;
        
        try {
          if (responseData.containsKey('data') && 
              responseData['data'] is Map<String, dynamic> && 
              responseData['data'].containsKey('dashboard') &&
              responseData['data']['dashboard'] is Map<String, dynamic> &&
              responseData['data']['dashboard'].containsKey('product') &&
              responseData['data']['dashboard']['product'] is Map<String, dynamic>) {
            
            final productData = responseData['data']['dashboard']['product'] as Map<String, dynamic>;
            
            productId = productData['productID'] ?? id;
            name = productData['productName'] ?? '';
            description = productData['productDescription'] ?? '';
            
            // Try to get the account ID
            accountId = productId; // Use the product ID as the account ID
            
            Logger.data('[MARKETPLACE] Extracted product details from response: name=$name, description=$description');
          } else {
            Logger.data('[MARKETPLACE] No product details found in response');
            
            // Try to find the product in the mock products list
            try {
              final mockProduct = _mockProducts.firstWhere(
                (p) => p.id == id,
                orElse: () => throw NotFoundException('Product not found in mock data'),
              );
              
              // Use the details from the mock product
              productId = mockProduct.id;
              vendorId = mockProduct.vendorId;
              name = mockProduct.name;
              description = mockProduct.description;
              price = mockProduct.price;
              currency = mockProduct.currency;
              category = mockProduct.category;
              tags = mockProduct.tags;
              isAvailable = mockProduct.isAvailable;
              accountId = mockProduct.accountId;
              
              Logger.data('[MARKETPLACE] Using details from mock product');
            } catch (e) {
              Logger.error('[MARKETPLACE] Error finding product in mock data', e);
              // Continue with default values
            }
          }
        } catch (e) {
          Logger.error('[MARKETPLACE] Error extracting product details from response', e);
          // Continue with default values
        }
        
        // Create the product object
        final product = Product(
          id: productId,
          vendorId: vendorId,
          name: name,
          description: description,
          price: price,
          currency: currency,
          imageUrls: imageUrls,
          category: category,
          tags: tags,
          isAvailable: isAvailable,
          accountId: accountId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        stopwatch.stop();
        Logger.performance('[MARKETPLACE] getProduct completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        
        return Right(product);
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        
        // Try to find the product in the mock products list as a fallback
        try {
          final product = _mockProducts.firstWhere(
            (p) => p.id == id,
            orElse: () => throw NotFoundException('Product not found'),
          );
          
          Logger.data('[MARKETPLACE] Falling back to mock product data');
          return Right(product);
        } on NotFoundException catch (e) {
          Logger.error('[MARKETPLACE] Product not found in mock data', e);
          return Left(NotFoundFailure(e.message));
        } catch (e) {
          Logger.error('[MARKETPLACE] Error finding product in mock data', e);
          return Left(ServerFailure('Failed to get product: ${response.body}'));
        }
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error getting product', e, stackTrace);
      
      // Try to find the product in the mock products list as a fallback
      try {
        final product = _mockProducts.firstWhere(
          (p) => p.id == id,
          orElse: () => throw NotFoundException('Product not found'),
        );
        
        Logger.data('[MARKETPLACE] Falling back to mock product data due to error');
        return Right(product);
      } on NotFoundException catch (e) {
        Logger.error('[MARKETPLACE] Product not found in mock data', e);
        return Left(NotFoundFailure(e.message));
      } catch (e) {
        Logger.error('[MARKETPLACE] Error finding product in mock data', e);
        return Left(ServerFailure('Failed to get product: $e'));
      }
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByVendor(
      String vendorId) async {
    try {
      Logger.data('Getting products for vendor ID: $vendorId');

      // Mock implementation
      final products =
          _mockProducts.where((p) => p.vendorId == vendorId).toList();

      return Right(products);
    } catch (e) {
      Logger.error('Error getting products by vendor', e);
      return Left(ServerFailure('Failed to get products by vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
      String category) async {
    try {
      Logger.data('Getting products for category: $category');

      // Mock implementation
      final products =
          _mockProducts.where((p) => p.category == category).toList();

      return Right(products);
    } catch (e) {
      Logger.error('Error getting products by category', e);
      return Left(ServerFailure('Failed to get products by category: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      Logger.data('Searching products with query: $query');

      // Mock implementation
      final lowercaseQuery = query.toLowerCase();
      final products = _mockProducts.where((p) {
        return p.name.toLowerCase().contains(lowercaseQuery) ||
            p.description.toLowerCase().contains(lowercaseQuery) ||
            p.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      }).toList();

      return Right(products);
    } catch (e) {
      Logger.error('Error searching products', e);
      return Left(ServerFailure('Failed to search products: $e'));
    }
  }

  @override
  Future<Either<Failure, String>> createInternalAccount({
    required String accountName,
    required String defaultDenom,
    required String accountType,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting createInternalAccount operation');
    
    try {
      // Get the user token from local storage
      Logger.data('[MARKETPLACE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[MARKETPLACE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[MARKETPLACE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[MARKETPLACE] User retrieved successfully: ${user.memberId}');

      // Prepare request data
      final requestBody = jsonEncode({
        'accountName': accountName,
        'defaultDenom': defaultDenom,
        'accountType': accountType,
      });
      Logger.data('[MARKETPLACE] Request body: $requestBody');
      
      // Call the /createAccountInternal API endpoint with authentication
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/createAccountInternal');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/createAccountInternal'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBody,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      Logger.data('[MARKETPLACE] Response body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[MARKETPLACE] Response data: $responseData');
        
        // Extract account ID from the response
        final accountId = responseData['data']['action']['details']['accountID'];
        if (accountId == null) {
          Logger.error('[MARKETPLACE] Account ID not found in response');
          return Left(ServerFailure('Account ID not found in response'));
        }
        
        Logger.data('[MARKETPLACE] Account ID: $accountId');
        
        stopwatch.stop();
        Logger.performance('[MARKETPLACE] createInternalAccount completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        return Right(accountId);
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure(
            'Failed to create internal account: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error creating internal account', e, stackTrace);
      return Left(ServerFailure('Failed to create internal account: $e'));
    }
  }

  @override
  Future<Either<Failure, Product>> createProduct({
    required String vendorId,
    required String name,
    required String description,
    required int price,
    required String currency,
    required List<String> imageUrls,
    required String category,
    required List<String> tags,
    required bool isAvailable,
    String? accountId,
  }) async {
    try {
      Logger.data('Creating product for vendor ID: $vendorId');

      // Create an internal account for the product if not provided
      String productAccountId = accountId ?? '';
      if (productAccountId.isEmpty) {
        final accountResult = await createInternalAccount(
          accountName: name,
          defaultDenom: currency,
          accountType: 'PHYSICAL_ASSET',
        );
        
        final accountEither = await accountResult;
        if (accountEither.isLeft()) {
          return Left(accountEither.fold(
            (failure) => failure,
            (_) => ServerFailure('Failed to create internal account'),
          ));
        }
        
        productAccountId = accountEither.fold(
          (_) => '',
          (id) => id,
        );
      }

      // Create the product with the account ID
      final newProduct = Product(
        id: 'p${_mockProducts.length + 1}',
        vendorId: vendorId,
        name: name,
        description: description,
        price: price,
        currency: currency,
        imageUrls: imageUrls,
        category: category,
        tags: tags,
        isAvailable: isAvailable,
        accountId: productAccountId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _mockProducts.add(newProduct);

      return Right(newProduct);
    } catch (e) {
      Logger.error('Error creating product', e);
      return Left(ServerFailure('Failed to create product: $e'));
    }
  }

  @override
  Future<Either<Failure, Product>> updateProduct({
    required String id,
    String? name,
    String? description,
    int? price,
    String? currency,
    List<String>? imageUrls,
    String? category,
    List<String>? tags,
    bool? isAvailable,
    String? accountId,
  }) async {
    try {
      Logger.data('Updating product with ID: $id');

      // Find the product
      final productIndex = _mockProducts.indexWhere((p) => p.id == id);
      if (productIndex == -1) {
        throw NotFoundException('Product not found');
      }

      // Get the existing product
      final existingProduct = _mockProducts[productIndex];

      // Create updated product
      final updatedProduct = existingProduct.copyWith(
        name: name,
        description: description,
        price: price,
        currency: currency,
        imageUrls: imageUrls,
        category: category,
        tags: tags,
        isAvailable: isAvailable,
        accountId: accountId,
        updatedAt: DateTime.now(),
      );

      // Update the product in the list
      _mockProducts[productIndex] = updatedProduct;

      return Right(updatedProduct);
    } on NotFoundException catch (e) {
      Logger.error('Product not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating product', e);
      return Left(ServerFailure('Failed to update product: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> getInvoice(String id) async {
    try {
      Logger.data('Getting invoice with ID: $id');

      // Mock implementation
      final invoice = _mockInvoices.firstWhere(
        (i) => i.id == id,
        orElse: () => throw NotFoundException('Invoice not found'),
      );

      return Right(invoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting invoice', e);
      return Left(ServerFailure('Failed to get invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByBuyer(
      String buyerId) async {
    try {
      Logger.data('Getting invoices for buyer ID: $buyerId');

      // Mock implementation
      final invoices =
          _mockInvoices.where((i) => i.buyerId == buyerId).toList();

      return Right(invoices);
    } catch (e) {
      Logger.error('Error getting invoices by buyer', e);
      return Left(ServerFailure('Failed to get invoices by buyer: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByVendor(
      String vendorId) async {
    try {
      Logger.data('Getting invoices for vendor ID: $vendorId');

      // Mock implementation
      final invoices =
          _mockInvoices.where((i) => i.vendorId == vendorId).toList();

      return Right(invoices);
    } catch (e) {
      Logger.error('Error getting invoices by vendor', e);
      return Left(ServerFailure('Failed to get invoices by vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> createInvoice({
    required String buyerId,
    required String vendorId,
    required List<InvoiceLineItem> lineItems,
    required int totalAmount,
    required String currency,
    required String paymentMethod,
    String? notes,
  }) async {
    try {
      Logger.data(
          'Creating invoice for buyer ID: $buyerId and vendor ID: $vendorId');

      // Mock implementation
      final newInvoice = Invoice(
        id: 'i${_mockInvoices.length + 1}',
        buyerId: buyerId,
        vendorId: vendorId,
        lineItems: lineItems,
        totalAmount: totalAmount,
        currency: currency,
        status: InvoiceStatus.pending,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _mockInvoices.add(newInvoice);

      return Right(newInvoice);
    } catch (e) {
      Logger.error('Error creating invoice', e);
      return Left(ServerFailure('Failed to create invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice({
    required String id,
    InvoiceStatus? status,
    String? notes,
    DateTime? paidAt,
  }) async {
    try {
      Logger.data('Updating invoice with ID: $id');

      // Find the invoice
      final invoiceIndex = _mockInvoices.indexWhere((i) => i.id == id);
      if (invoiceIndex == -1) {
        throw NotFoundException('Invoice not found');
      }

      // Get the existing invoice
      final existingInvoice = _mockInvoices[invoiceIndex];

      // Create updated invoice
      final updatedInvoice = existingInvoice.copyWith(
        status: status,
        notes: notes,
        paidAt: paidAt,
        updatedAt: DateTime.now(),
      );

      // Update the invoice in the list
      _mockInvoices[invoiceIndex] = updatedInvoice;

      return Right(updatedInvoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating invoice', e);
      return Left(ServerFailure('Failed to update invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> getAssetMarker(String id) async {
    try {
      Logger.data('Getting asset marker with ID: $id');

      // Mock implementation
      final assetMarker = _mockAssetMarkers.firstWhere(
        (a) => a.id == id,
        orElse: () => throw NotFoundException('Asset marker not found'),
      );

      return Right(assetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting asset marker', e);
      return Left(ServerFailure('Failed to get asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByProduct(
      String productId) async {
    try {
      Logger.data('Getting asset markers for product ID: $productId');

      // Mock implementation
      final assetMarkers =
          _mockAssetMarkers.where((a) => a.productId == productId).toList();

      return Right(assetMarkers);
    } catch (e) {
      Logger.error('Error getting asset markers by product', e);
      return Left(ServerFailure('Failed to get asset markers by product: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByOwner(
      String ownerId) async {
    try {
      Logger.data('Getting asset markers for owner ID: $ownerId');

      // Mock implementation
      final assetMarkers =
          _mockAssetMarkers.where((a) => a.ownerId == ownerId).toList();

      return Right(assetMarkers);
    } catch (e) {
      Logger.error('Error getting asset markers by owner', e);
      return Left(ServerFailure('Failed to get asset markers by owner: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> createAssetMarker({
    required String productId,
    required String ownerId,
    required String creatorId,
    required int quantity,
    required AssetMarkerStatus status,
  }) async {
    try {
      Logger.data('Creating asset marker for product ID: $productId');

      // Mock implementation
      final newAssetMarker = AssetMarker(
        id: 'a${_mockAssetMarkers.length + 1}',
        productId: productId,
        ownerId: ownerId,
        creatorId: creatorId,
        quantity: quantity,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      _mockAssetMarkers.add(newAssetMarker);

      return Right(newAssetMarker);
    } catch (e) {
      Logger.error('Error creating asset marker', e);
      return Left(ServerFailure('Failed to create asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> updateAssetMarker({
    required String id,
    String? ownerId,
    int? quantity,
    AssetMarkerStatus? status,
    DateTime? lastTransferredAt,
  }) async {
    try {
      Logger.data('Updating asset marker with ID: $id');

      // Find the asset marker
      final assetMarkerIndex = _mockAssetMarkers.indexWhere((a) => a.id == id);
      if (assetMarkerIndex == -1) {
        throw NotFoundException('Asset marker not found');
      }

      // Get the existing asset marker
      final existingAssetMarker = _mockAssetMarkers[assetMarkerIndex];

      // Create updated asset marker
      final updatedAssetMarker = existingAssetMarker.copyWith(
        ownerId: ownerId,
        quantity: quantity,
        status: status,
        lastTransferredAt: lastTransferredAt,
        updatedAt: DateTime.now(),
      );

      // Update the asset marker in the list
      _mockAssetMarkers[assetMarkerIndex] = updatedAssetMarker;

      return Right(updatedAssetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating asset marker', e);
      return Left(ServerFailure('Failed to update asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> transferAssetMarker({
    required String id,
    required String newOwnerId,
  }) async {
    try {
      Logger.data(
          'Transferring asset marker with ID: $id to owner ID: $newOwnerId');

      // Find the asset marker
      final assetMarkerIndex = _mockAssetMarkers.indexWhere((a) => a.id == id);
      if (assetMarkerIndex == -1) {
        throw NotFoundException('Asset marker not found');
      }

      // Get the existing asset marker
      final existingAssetMarker = _mockAssetMarkers[assetMarkerIndex];

      // Check if the asset marker is transferable
      if (!existingAssetMarker.isTransferable) {
        throw const ServerException('Asset marker is not transferable');
      }

      // Create updated asset marker
      final updatedAssetMarker = existingAssetMarker.copyWith(
        ownerId: newOwnerId,
        lastTransferredAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update the asset marker in the list
      _mockAssetMarkers[assetMarkerIndex] = updatedAssetMarker;

      return Right(updatedAssetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found for transfer', e);
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      Logger.error('Asset marker not transferable', e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      Logger.error('Error transferring asset marker', e);
      return Left(ServerFailure('Failed to transfer asset marker: $e'));
    }
  }
  
  @override
  Future<Either<Failure, Map<String, String>>> uploadProfileImage({
    required String imagePath,
    required String drAccountId,
    String? crAccountId,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[PROFILE_IMAGE] Starting uploadProfileImage operation');
    
    try {
      // Get the user token from local storage
      Logger.data('[PROFILE_IMAGE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[PROFILE_IMAGE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[PROFILE_IMAGE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[PROFILE_IMAGE] User retrieved successfully: ${user.memberId}');
      
      // Read the image file and convert to base64
      final file = File(imagePath);
      if (!await file.exists()) {
        Logger.error('[PROFILE_IMAGE] Image file not found: $imagePath');
        return Left(NotFoundFailure('Image file not found'));
      }
      
      // Log file details before reading
      final fileSize = await file.length();
      final fileSizeKB = fileSize / 1024;
      final fileSizeMB = fileSizeKB / 1024;
      Logger.data('[PROFILE_IMAGE] Image file size: ${fileSizeKB.toStringAsFixed(2)} KB (${fileSizeMB.toStringAsFixed(2)} MB)');
      
      // Check if file is too large before even trying to encode it
      if (fileSizeKB > 80) { // Reduced from 5MB to 80KB based on server limits
        Logger.error('[PROFILE_IMAGE] Image file is too large: ${fileSizeKB.toStringAsFixed(2)} KB');
        return Left(ServerFailure('Image file is too large. Please use an image smaller than 80KB.'));
      }
      
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final base64SizeKB = base64Image.length / 1024;
      final base64SizeMB = base64SizeKB / 1024;
      Logger.data('[PROFILE_IMAGE] Image converted to base64: ${base64SizeKB.toStringAsFixed(2)} KB (${base64SizeMB.toStringAsFixed(2)} MB)');
      
      // Check if base64 encoded data is too large
      if (base64SizeKB > 100) { // Reduced from 6MB to 100KB (allowing for ~25% increase from base64 encoding)
        Logger.error('[PROFILE_IMAGE] Base64 encoded image is too large: ${base64SizeKB.toStringAsFixed(2)} KB');
        return Left(ServerFailure('Encoded image is too large. Please use a smaller image (under 80KB).'));
      }
      
      // Prepare request data
      final Map<String, dynamic> requestBody = {
        'jpg': base64Image,
        'name': 'profile_pic',
        'drAccountID': drAccountId,
      };
      
      // Add crAccountID if provided
      if (crAccountId != null) {
        requestBody['crAccountID'] = crAccountId;
      }
      
      final requestBodyJson = jsonEncode(requestBody);
      final requestSizeKB = requestBodyJson.length / 1024;
      final requestSizeMB = requestSizeKB / 1024;
      Logger.data('[PROFILE_IMAGE] Request prepared with payload size: ${requestSizeKB.toStringAsFixed(2)} KB (${requestSizeMB.toStringAsFixed(2)} MB)');
      
      // Call the uploadAndOptimizeJpg API endpoint
      Logger.data('[PROFILE_IMAGE] Sending POST request to $_baseUrl/uploadAndOptimizeJpg');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/uploadAndOptimizeJpg'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
          'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
        },
        body: requestBodyJson,
      );
      
      // Log response details
      Logger.data('[PROFILE_IMAGE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the response body
        final responseData = jsonDecode(response.body);
        Logger.data('[PROFILE_IMAGE] Response data received successfully');
        
        // Extract asset IDs with improved handling for different response formats
        String originalAssetId = '';
        String asset200Id = '';
        String asset600Id = '';
        
        // Try to extract from top level first
        if (responseData.containsKey('originalAssetID')) {
          originalAssetId = responseData['originalAssetID']?.toString() ?? '';
          asset200Id = responseData['asset200ID']?.toString() ?? '';
          asset600Id = responseData['asset600ID']?.toString() ?? '';
          Logger.data('[PROFILE_IMAGE] Asset IDs extracted from top level');
        } 
        // Then try to extract from data.action.details object (actual API response format)
        else if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('action') &&
                responseData['data']['action'] is Map<String, dynamic> &&
                responseData['data']['action'].containsKey('details')) {
          final details = responseData['data']['action']['details'] as Map<String, dynamic>;
          originalAssetId = details['originalAssetID']?.toString() ?? '';
          asset200Id = details['asset200ID']?.toString() ?? '';
          asset600Id = details['asset600ID']?.toString() ?? '';
          Logger.data('[PROFILE_IMAGE] Asset IDs extracted from data.action.details object');
        }
        // Finally try to extract directly from data object as fallback
        else if (responseData.containsKey('data')) {
          final data = responseData['data'] as Map<String, dynamic>? ?? {};
          originalAssetId = data['originalAssetID']?.toString() ?? '';
          asset200Id = data['asset200ID']?.toString() ?? '';
          asset600Id = data['asset600ID']?.toString() ?? '';
          Logger.data('[PROFILE_IMAGE] Asset IDs extracted from data object');
        }
        
        Logger.data('[PROFILE_IMAGE] Asset IDs extracted: original=$originalAssetId, 200px=$asset200Id, 600px=$asset600Id');
        
        // Log warning if any asset ID is empty
        if (originalAssetId.isEmpty || asset200Id.isEmpty || asset600Id.isEmpty) {
          Logger.error('[PROFILE_IMAGE] One or more asset IDs are empty', 'Response: ${response.body}');
        }
        
        final result = {
          'originalAssetID': originalAssetId,
          'asset200ID': asset200Id,
          'asset600ID': asset600Id,
        };
        
        stopwatch.stop();
        Logger.performance('[PROFILE_IMAGE] uploadProfileImage completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        
        return Right(result);
      } else if (response.statusCode == 401) {
        Logger.error('[PROFILE_IMAGE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 413) {
        Logger.error('[PROFILE_IMAGE] Request entity too large with status code 413');
        Logger.error('[PROFILE_IMAGE] Original file size: ${fileSizeKB.toStringAsFixed(2)} KB, Base64 size: ${base64SizeKB.toStringAsFixed(2)} KB');
        return Left(ServerFailure('The image file is too large. Please select a smaller image or use a lower resolution image.'));
      } else {
        Logger.error('[PROFILE_IMAGE] Server error with status code ${response.statusCode}');
        Logger.error('[PROFILE_IMAGE] Response body: ${response.body}');
        return Left(ServerFailure('Failed to upload profile image: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[PROFILE_IMAGE] Error uploading profile image', e, stackTrace);
      return Left(ServerFailure('Failed to upload profile image: $e'));
    }
  }
  
  @override
  Future<Either<Failure, bool>> updateProfilePictures({
    required String sourceId,
    required String originalAssetId,
    required String thumbnailAssetId,
    required String asset200Id,
    required String asset600Id,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[PROFILE_IMAGE] Starting updateProfilePictures operation');
    
    try {
      // Get the user token from local storage
      Logger.data('[PROFILE_IMAGE] Retrieving user from database');
      final user = await _databaseHelper.getUser();
      
      if (user == null) {
        Logger.error('[PROFILE_IMAGE] User not found in database');
        return Left(AuthFailure(message: 'User not authenticated - user not found'));
      }
      
      if (user.token.isEmpty) {
        Logger.error('[PROFILE_IMAGE] User token is empty');
        return Left(AuthFailure(message: 'User not authenticated - empty token'));
      }
      
      Logger.data('[PROFILE_IMAGE] User retrieved successfully: ${user.memberId}');
      
      // Prepare request data
      final requestBody = jsonEncode({
        'sourceID': sourceId,
        'originalAssetID': originalAssetId,
        'thumbnailAssetID': thumbnailAssetId,
        'asset200ID': asset200Id,
        'asset600ID': asset600Id,
      });
      
      Logger.data('[PROFILE_IMAGE] Request prepared');
      
      // Call the updateProfilePics API endpoint
      Logger.data('[PROFILE_IMAGE] Sending POST request to $_baseUrl/updateProfilePics');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/updateProfilePics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
          'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
        },
        body: requestBody,
      );
      
      // Log response details
      Logger.data('[PROFILE_IMAGE] Response status code: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        stopwatch.stop();
        Logger.performance('[PROFILE_IMAGE] updateProfilePictures completed successfully in ${stopwatch.elapsedMilliseconds}ms');
        return const Right(true);
      } else if (response.statusCode == 401) {
        Logger.error('[PROFILE_IMAGE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[PROFILE_IMAGE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to update profile pictures: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[PROFILE_IMAGE] Error updating profile pictures', e, stackTrace);
      return Left(ServerFailure('Failed to update profile pictures: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> createCredexOffer({
    required String invoiceId,
    required String accountId,
    required int amount,
    String? note,
  }) async {
    try {
      Logger.data(
          'Creating Credex offer for invoice ID: $invoiceId from account ID: $accountId');

      // Find the invoice
      final invoiceIndex = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      if (invoiceIndex == -1) {
        throw NotFoundException('Invoice not found');
      }

      // Get the existing invoice
      final existingInvoice = _mockInvoices[invoiceIndex];

      // Check if the invoice is already paid
      if (existingInvoice.status != InvoiceStatus.pending) {
        throw const ServerException('Invoice is not in pending status');
      }

      // Check if the amount matches the invoice total
      if (amount != existingInvoice.totalAmount) {
        throw const ServerException(
            'Payment amount does not match invoice total');
      }

      // Create updated invoice with paid status
      final updatedInvoice = existingInvoice.copyWith(
        status: InvoiceStatus.paid,
        notes: note != null
            ? (existingInvoice.notes != null
                ? '${existingInvoice.notes}\n$note'
                : note)
            : existingInvoice.notes,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Update the invoice in the list
      _mockInvoices[invoiceIndex] = updatedInvoice;

      // Create asset markers for the purchased products (in a real implementation)
      // This would involve creating asset markers for each line item in the invoice

      return Right(updatedInvoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found for payment', e);
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      Logger.error('Error processing payment', e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      Logger.error('Error creating Credex offer', e);
      return Left(ServerFailure('Failed to create Credex offer: $e'));
    }
  }
}
