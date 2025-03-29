import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';

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
  final AccountRepository _accountRepository;

  /// Creates a new [MarketplaceRepositoryImpl] instance.
  ///
  /// Requires an HTTP client for API communication, a base URL for the API,
  /// a database helper for accessing user data, and an account repository for token refresh.
  MarketplaceRepositoryImpl({
    required http.Client httpClient,
    required String baseUrl,
    required DatabaseHelper databaseHelper,
    required AccountRepository accountRepository,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl,
        _databaseHelper = databaseHelper,
        _accountRepository = accountRepository;
        
  /// Helper method to generate authentication headers with a token.
  Map<String, String> _authHeaders(String token) => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  };

  /// Helper method to log API requests and responses.
  Future<http.Response> _loggedRequest(
    Future<http.Response> Function() request,
    String url,
    String method, {
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      Logger.data('[MARKETPLACE] Request: $method $url');
      if (headers != null) {
        final redactedHeaders = Map<String, String>.from(headers);
        if (redactedHeaders.containsKey('Authorization')) {
          redactedHeaders['Authorization'] = 'Bearer [REDACTED]';
        }
        Logger.data('[MARKETPLACE] Headers: $redactedHeaders');
      }
      if (body != null) {
        Logger.data('[MARKETPLACE] Body: $body');
      }

      final response = await request();

      Logger.data('[MARKETPLACE] Response status: ${response.statusCode}');
      Logger.data('[MARKETPLACE] Response body: ${response.body}');

      return response;
    } catch (e) {
      Logger.error('[MARKETPLACE] Request error: $e');
      rethrow;
    }
  }

  /// Executes an authenticated request with automatic token refresh on 401 errors.
  ///
  /// This method handles token expiration by automatically refreshing the token
  /// and retrying the request when a 401 error with "token expired" message is received.
  Future<Either<Failure, T>> _executeAuthenticatedRequest<T>({
    required Future<Either<Failure, T>> Function(String token) request,
    bool isRetry = false,
  }) async {
    try {
      final user = await _databaseHelper.getUser();
      if (user == null) {
        return const Left(AuthFailure(message: 'User not authenticated'));
      }

      final result = await request(user.token);

      return result.fold(
        (failure) async {
          if (!isRetry &&
              failure.message?.toLowerCase().contains('token expired') == true) {
            Logger.data('[MARKETPLACE] Token expired, attempting to refresh');
            
            if (user.passwordHash == null) {
              Logger.error('[MARKETPLACE] No stored password hash for token refresh');
              return const Left(InfrastructureFailure(
                  'Authentication failed: No stored password hash'));
            }

            // Use the injected AccountRepository to refresh the token
            final loginResult = await _accountRepository.loginV2(
              phone: user.phone,
              passwordHash: user.passwordHash,
            );

            return loginResult.fold(
              (loginFailure) {
                Logger.error('[MARKETPLACE] Token refresh failed: ${loginFailure.message}');
                return Left(loginFailure);
              },
              (newUser) async {
                Logger.data('[MARKETPLACE] Token refreshed successfully, retrying request');
                // Retry the original request with the new token
                return _executeAuthenticatedRequest<T>(
                  request: request,
                  isRetry: true,
                );
              },
            );
          }
          return Left(failure);
        },
        Right.new,
      );
    } catch (e) {
      Logger.error('[MARKETPLACE] Error in _executeAuthenticatedRequest: $e');
      return Left(InfrastructureFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> enableVendorFunctionality() async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting enableVendorFunctionality operation');
    
    return _executeAuthenticatedRequest<bool>(
      request: (token) async {
        // Prepare request data
        final requestBody = jsonEncode({
          'vendor': true,
        });
        Logger.data('[MARKETPLACE] Request body: $requestBody');
        
        // Call the /sellInMarket API endpoint with authentication
        Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/sellInMarket');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/sellInMarket'),
            headers: _authHeaders(token),
            body: requestBody,
          ),
          '$_baseUrl/sellInMarket',
          'POST',
          headers: _authHeaders(token),
          body: requestBody,
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Parse the response body
          final responseData = jsonDecode(response.body);
          
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
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure(
              'Failed to enable vendor functionality: ${response.body}'));
        }
      },
    );
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
    
    // Log the input parameters
    Logger.data('[MARKETPLACE] Update parameters: firstname=$firstname, lastname=$lastname, memberHandle=$memberHandle, vendorBio=${vendorBio != null ? '${vendorBio.substring(0, min(20, vendorBio.length))}...' : 'null'}');
    
    return _executeAuthenticatedRequest<bool>(
      request: (token) async {
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
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/editMember'),
            headers: _authHeaders(token),
            body: requestBodyJson,
          ),
          '$_baseUrl/editMember',
          'POST',
          headers: _authHeaders(token),
          body: requestBodyJson,
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          stopwatch.stop();
          Logger.performance('[MARKETPLACE] updateMemberWithVendorDetails completed successfully in ${stopwatch.elapsedMilliseconds}ms');
          return const Right(true);
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure(
              'Failed to update member with vendor details: ${response.body}'));
        }
      },
    );
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
    
    // Log the input parameters
    Logger.data('[MARKETPLACE] Create vendor parameters: memberId=$memberId, businessName=$businessName, email=$email, phone=$phone');
    Logger.data('[MARKETPLACE] Description: ${description.length > 50 ? '${description.substring(0, 50)}...' : description}');
    Logger.data('[MARKETPLACE] Profile image URL: ${profileImageUrl ?? 'null'}');
    Logger.data('[MARKETPLACE] Banner image URL: ${bannerImageUrl ?? 'null'}');
    
    return _executeAuthenticatedRequest<Vendor>(
      request: (token) async {
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
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/createVendor'),
            headers: _authHeaders(token),
            body: requestBodyJson,
          ),
          '$_baseUrl/createVendor',
          'POST',
          headers: _authHeaders(token),
          body: requestBodyJson,
        );
        
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
                id: vendorData['id'] ?? memberId,
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
                id: memberId,
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
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to create vendor: ${response.body}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Product>> getProduct(String id) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getProduct operation for ID: $id');
    
    return _executeAuthenticatedRequest<Product>(
      request: (token) async {
        // Call the /getProduct/{id} API endpoint with authentication
        Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getProduct/$id');
        final response = await _loggedRequest(
          () => _httpClient.get(
            Uri.parse('$_baseUrl/getProduct/$id'),
            headers: _authHeaders(token),
          ),
          '$_baseUrl/getProduct/$id',
          'GET',
          headers: _authHeaders(token),
        );
        
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
        } else if (response.statusCode == 404) {
          Logger.error('[MARKETPLACE] Product not found with status code 404');
          return Left(NotFoundFailure('Product not found'));
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to get product: ${response.body}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
      String category) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getProductsByCategory operation for category: $category');
    
    return _executeAuthenticatedRequest<List<Product>>(
      request: (token) async {
        // Call the API endpoint to get products by category
        Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getProductsByCategory/$category');
        final response = await _loggedRequest(
          () => _httpClient.get(
            Uri.parse('$_baseUrl/getProductsByCategory/$category'),
            headers: _authHeaders(token),
          ),
          '$_baseUrl/getProductsByCategory/$category',
          'GET',
          headers: _authHeaders(token),
        );
        
        if (response.statusCode == 200) {
          // Parse the response body
          final responseData = jsonDecode(response.body);
          Logger.data('[MARKETPLACE] Response data received successfully');
          
          // Extract products from the response
          try {
            if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('products') &&
                responseData['data']['products'] is List) {
              
              final productsData = responseData['data']['products'] as List;
              final products = productsData.map((productData) {
                return Product(
                  id: productData['id'] ?? '',
                  vendorId: productData['vendorId'] ?? '',
                  name: productData['name'] ?? '',
                  description: productData['description'] ?? '',
                  price: (productData['price'] as num?)?.toInt() ?? 0,
                  currency: productData['currency'] ?? 'USD',
                  imageUrls: (productData['imageUrls'] as List?)?.map((url) => url.toString()).toList() ?? [],
                  category: productData['category'] ?? category,
                  tags: (productData['tags'] as List?)?.map((tag) => tag.toString()).toList() ?? [],
                  isAvailable: productData['isAvailable'] as bool? ?? true,
                  accountId: productData['accountId'],
                  createdAt: productData['createdAt'] != null 
                      ? DateTime.parse(productData['createdAt']) 
                      : DateTime.now(),
                  updatedAt: productData['updatedAt'] != null 
                      ? DateTime.parse(productData['updatedAt']) 
                      : DateTime.now(),
                );
              }).toList();
              
              stopwatch.stop();
              Logger.performance('[MARKETPLACE] getProductsByCategory completed successfully in ${stopwatch.elapsedMilliseconds}ms');
              return Right(products);
            } else {
              // If no products found, return empty list
              Logger.data('[MARKETPLACE] No products found for category: $category');
              return const Right([]);
            }
          } catch (e) {
            Logger.error('[MARKETPLACE] Error parsing products data from response', e);
            return Left(ServerFailure('Failed to parse products data: $e'));
          }
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to get products by category: ${response.body}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting searchProducts operation for query: $query');
    
    return _executeAuthenticatedRequest<List<Product>>(
      request: (token) async {
        // Prepare request data
        final requestBody = jsonEncode({
          'query': query,
        });
        
        // Call the API endpoint to search products
        Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/searchProducts');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/searchProducts'),
            headers: _authHeaders(token),
            body: requestBody,
          ),
          '$_baseUrl/searchProducts',
          'POST',
          headers: _authHeaders(token),
          body: requestBody,
        );
        
        if (response.statusCode == 200) {
          // Parse the response body
          final responseData = jsonDecode(response.body);
          Logger.data('[MARKETPLACE] Response data received successfully');
          
          // Extract products from the response
          try {
            if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('products') &&
                responseData['data']['products'] is List) {
              
              final productsData = responseData['data']['products'] as List;
              final products = productsData.map((productData) {
                return Product(
                  id: productData['id'] ?? '',
                  vendorId: productData['vendorId'] ?? '',
                  name: productData['name'] ?? '',
                  description: productData['description'] ?? '',
                  price: (productData['price'] as num?)?.toInt() ?? 0,
                  currency: productData['currency'] ?? 'USD',
                  imageUrls: (productData['imageUrls'] as List?)?.map((url) => url.toString()).toList() ?? [],
                  category: productData['category'] ?? '',
                  tags: (productData['tags'] as List?)?.map((tag) => tag.toString()).toList() ?? [],
                  isAvailable: productData['isAvailable'] as bool? ?? true,
                  accountId: productData['accountId'],
                  createdAt: productData['createdAt'] != null 
                      ? DateTime.parse(productData['createdAt']) 
                      : DateTime.now(),
                  updatedAt: productData['updatedAt'] != null 
                      ? DateTime.parse(productData['updatedAt']) 
                      : DateTime.now(),
                );
              }).toList();
              
              stopwatch.stop();
              Logger.performance('[MARKETPLACE] searchProducts completed successfully in ${stopwatch.elapsedMilliseconds}ms');
              return Right(products);
            } else {
              // If no products found, return empty list
              Logger.data('[MARKETPLACE] No products found for query: $query');
              return const Right([]);
            }
          } catch (e) {
            Logger.error('[MARKETPLACE] Error parsing products data from response', e);
            return Left(ServerFailure('Failed to parse products data: $e'));
          }
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to search products: ${response.body}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, String>> createInternalAccount({
    required String accountName,
    required String defaultDenom,
    required String accountType,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting createInternalAccount operation');
    
    return _executeAuthenticatedRequest<String>(
      request: (token) async {
        // Prepare request data
        final requestBody = jsonEncode({
          'accountName': accountName,
          'defaultDenom': defaultDenom,
          'accountType': accountType,
        });
        Logger.data('[MARKETPLACE] Request body: $requestBody');
        
        // Call the /createAccountInternal API endpoint with authentication
        Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/createAccountInternal');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/createAccountInternal'),
            headers: _authHeaders(token),
            body: requestBody,
          ),
          '$_baseUrl/createAccountInternal',
          'POST',
          headers: _authHeaders(token),
          body: requestBody,
        );
        
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
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure(
              'Failed to create internal account: ${response.body}'));
        }
      },
    );
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
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting createProduct operation');
    
    // Create an internal account for the product if not provided
    String productAccountId = accountId ?? '';
    if (productAccountId.isEmpty) {
      Logger.data('[MARKETPLACE] No account ID provided, creating internal account');
      final accountResult = await createInternalAccount(
        accountName: name,
        defaultDenom: currency,
        accountType: 'PHYSICAL_ASSET',
      );
      
      if (accountResult.isLeft()) {
        return Left(accountResult.fold(
          (failure) => failure,
          (_) => ServerFailure('Failed to create internal account'),
        ));
      }
      
      productAccountId = accountResult.fold(
        (_) => '',
        (id) => id,
      );
      Logger.data('[MARKETPLACE] Created internal account with ID: $productAccountId');
    }
    
    final finalProductAccountId = productAccountId; // Create a final copy for the closure
    
    return _executeAuthenticatedRequest<Product>(
      request: (token) async {
        // Prepare request data
        final Map<String, dynamic> requestBody = {
          'vendorId': vendorId,
          'name': name,
          'description': description,
          'price': price,
          'currency': currency,
          'imageUrls': imageUrls,
          'category': category,
          'tags': tags,
          'isAvailable': isAvailable,
          'accountId': finalProductAccountId,
        };
        
        final requestBodyJson = jsonEncode(requestBody);
        Logger.data('[MARKETPLACE] Request body: $requestBodyJson');
        
        // Call the API endpoint to create product
        Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/createProduct');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/createProduct'),
            headers: _authHeaders(token),
            body: requestBodyJson,
          ),
          '$_baseUrl/createProduct',
          'POST',
          headers: _authHeaders(token),
          body: requestBodyJson,
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          // Parse the response body
          final responseData = jsonDecode(response.body);
          Logger.data('[MARKETPLACE] Response data received successfully');
          
          // Extract product details from the response
          try {
            if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('product')) {
              
              final productData = responseData['data']['product'] as Map<String, dynamic>;
              
              final product = Product(
                id: productData['id'] ?? '',
                vendorId: productData['vendorId'] ?? vendorId,
                name: productData['name'] ?? name,
                description: productData['description'] ?? description,
                price: (productData['price'] as num?)?.toInt() ?? price,
                currency: productData['currency'] ?? currency,
                imageUrls: (productData['imageUrls'] as List?)?.map((url) => url.toString()).toList() ?? imageUrls,
                category: productData['category'] ?? category,
                tags: (productData['tags'] as List?)?.map((tag) => tag.toString()).toList() ?? tags,
                isAvailable: productData['isAvailable'] as bool? ?? isAvailable,
                accountId: productData['accountId'] ?? finalProductAccountId,
                createdAt: productData['createdAt'] != null 
                    ? DateTime.parse(productData['createdAt']) 
                    : DateTime.now(),
                updatedAt: productData['updatedAt'] != null 
                    ? DateTime.parse(productData['updatedAt']) 
                    : DateTime.now(),
              );
              
              stopwatch.stop();
              Logger.performance('[MARKETPLACE] createProduct completed successfully in ${stopwatch.elapsedMilliseconds}ms');
              return Right(product);
            } else {
              // If product data not found in response, create a temporary product object
              final now = DateTime.now();
              final product = Product(
                id: 'p_temp_${DateTime.now().millisecondsSinceEpoch}',
                vendorId: vendorId,
                name: name,
                description: description,
                price: price,
                currency: currency,
                imageUrls: imageUrls,
                category: category,
                tags: tags,
                isAvailable: isAvailable,
                accountId: finalProductAccountId,
                createdAt: now,
                updatedAt: now,
              );
              
              stopwatch.stop();
              Logger.performance('[MARKETPLACE] createProduct completed with temporary product in ${stopwatch.elapsedMilliseconds}ms');
              return Right(product);
            }
          } catch (e) {
            Logger.error('[MARKETPLACE] Error parsing product data from response', e);
            return Left(ServerFailure('Failed to parse product data: $e'));
          }
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to create product: ${response.body}'));
        }
      },
    );
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
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting updateProduct operation for ID: $id');
    
    return _executeAuthenticatedRequest<Product>(
      request: (token) async {
        // Prepare request data with only the provided fields
        final Map<String, dynamic> requestBody = {
          'id': id,
        };
        
        if (name != null) requestBody['name'] = name;
        if (description != null) requestBody['description'] = description;
        if (price != null) requestBody['price'] = price;
        if (currency != null) requestBody['currency'] = currency;
        if (imageUrls != null) requestBody['imageUrls'] = imageUrls;
        if (category != null) requestBody['category'] = category;
        if (tags != null) requestBody['tags'] = tags;
        if (isAvailable != null) requestBody['isAvailable'] = isAvailable;
        if (accountId != null) requestBody['accountId'] = accountId;
        
        final requestBodyJson = jsonEncode(requestBody);
        Logger.data('[MARKETPLACE] Request body: $requestBodyJson');
        
        // Call the API endpoint to update product
        Logger.data('[MARKETPLACE] Sending PUT request to $_baseUrl/updateProduct');
        final response = await _loggedRequest(
          () => _httpClient.put(
            Uri.parse('$_baseUrl/updateProduct'),
            headers: _authHeaders(token),
            body: requestBodyJson,
          ),
          '$_baseUrl/updateProduct',
          'PUT',
          headers: _authHeaders(token),
          body: requestBodyJson,
        );
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          // For 204 No Content response, we need to get the product again to return the updated data
          if (response.statusCode == 204 || response.body.isEmpty) {
            Logger.data('[MARKETPLACE] No content in response, fetching updated product');
            
            // Get the updated product
            final getProductResult = await getProduct(id);
            
            return getProductResult;
          }
          
          // Parse the response body for 200 OK response
          final responseData = jsonDecode(response.body);
          Logger.data('[MARKETPLACE] Response data received successfully');
          
          // Extract product details from the response
          try {
            if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('product')) {
              
              final productData = responseData['data']['product'] as Map<String, dynamic>;
              
              final product = Product(
                id: productData['id'] ?? id,
                vendorId: productData['vendorId'] ?? '',
                name: productData['name'] ?? name ?? '',
                description: productData['description'] ?? description ?? '',
                price: (productData['price'] as num?)?.toInt() ?? price ?? 0,
                currency: productData['currency'] ?? currency ?? 'USD',
                imageUrls: (productData['imageUrls'] as List?)?.map((url) => url.toString()).toList() ?? imageUrls ?? [],
                category: productData['category'] ?? category ?? '',
                tags: (productData['tags'] as List?)?.map((tag) => tag.toString()).toList() ?? tags ?? [],
                isAvailable: productData['isAvailable'] as bool? ?? isAvailable ?? true,
                accountId: productData['accountId'] ?? accountId,
                createdAt: productData['createdAt'] != null 
                    ? DateTime.parse(productData['createdAt']) 
                    : DateTime.now(),
                updatedAt: productData['updatedAt'] != null 
                    ? DateTime.parse(productData['updatedAt']) 
                    : DateTime.now(),
              );
              
              stopwatch.stop();
              Logger.performance('[MARKETPLACE] updateProduct completed successfully in ${stopwatch.elapsedMilliseconds}ms');
              return Right(product);
            } else {
              Logger.error('[MARKETPLACE] Product data not found in response');
              return Left(NotFoundFailure('Product not found in response'));
            }
          } catch (e) {
            Logger.error('[MARKETPLACE] Error parsing product data from response', e);
            return Left(ServerFailure('Failed to parse product data: $e'));
          }
        } else if (response.statusCode == 404) {
          Logger.error('[MARKETPLACE] Product not found with status code 404');
          return Left(NotFoundFailure('Product not found'));
        } else {
          Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to update product: ${response.body}'));
        }
      },
    );
  }

  @override
  Future<Either<Failure, Invoice>> getInvoice(String id) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getInvoice called with ID: $id');
    return Left(ServerFailure('API not yet implemented'));
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByBuyer(String buyerId) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getInvoicesByBuyer called with buyer ID: $buyerId');
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByVendor(String vendorId) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getInvoicesByVendor called with vendor ID: $vendorId');
    return const Right([]);
  }

  @override
  Future<Either<Failure, Invoice>> createInvoice({
    required String vendorId,
    required List<InvoiceLineItem> lineItems,
    required int totalAmount,
    required String currency,
    required String paymentMethod,
    String? notes,
  }) async {
    final stopwatch = Stopwatch()..start();
    final correlationId = 'inv_api_${DateTime.now().millisecondsSinceEpoch}';
    Logger.data('[INVOICE_API] [$correlationId] Starting createInvoice operation');
    
    // Log detailed input parameters
    Logger.data('[INVOICE_API] [$correlationId] Input parameters:');
    Logger.data('[INVOICE_API] [$correlationId] - vendorId: $vendorId');
    Logger.data('[INVOICE_API] [$correlationId] - lineItems count: ${lineItems.length}');
    Logger.data('[INVOICE_API] [$correlationId] - totalAmount: $totalAmount (${totalAmount / 100} in dollars)');
    Logger.data('[INVOICE_API] [$correlationId] - currency: $currency');
    Logger.data('[INVOICE_API] [$correlationId] - paymentMethod: $paymentMethod');
    Logger.data('[INVOICE_API] [$correlationId] - notes: ${notes != null ? '${notes.length} characters' : 'null'}');
    
    // Log line items details
    for (var i = 0; i < lineItems.length; i++) {
      final item = lineItems[i];
      Logger.data('[INVOICE_API] [$correlationId] Line item #${i + 1}: productId=${item.productId}, name=${item.productName}, quantity=${item.quantity}, unitPrice=${item.unitPrice}, totalPrice=${item.totalPrice}');
    }
    
    // First, we need to get the user to find the personal account ID
    // This needs to be done outside the _executeAuthenticatedRequest because we need the account ID
    // before making the API call
    Logger.data('[INVOICE_API] [$correlationId] Retrieving user from database');
    final userRetrievalStart = DateTime.now();
    final user = await _databaseHelper.getUser();
    final userRetrievalDuration = DateTime.now().difference(userRetrievalStart).inMilliseconds;
    Logger.data('[INVOICE_API] [$correlationId] User retrieval took $userRetrievalDuration ms');
    
    if (user == null) {
      Logger.error('[INVOICE_API] [$correlationId] User not found in database');
      return Left(AuthFailure(message: 'User not authenticated - user not found'));
    }
    
    // Get payment account ID from the user's personal account
    String paymentAccountId = '';
    
    // Check if user has a dashboard with accounts
    if (user.dashboard != null && user.dashboard!.accounts.isNotEmpty) {
      Logger.data('[INVOICE_API] [$correlationId] User has ${user.dashboard!.accounts.length} accounts');
      
      // Try to find an account with accountType PERSONAL
      for (final account in user.dashboard!.accounts) {
        if (account.accountType == 'PERSONAL') {
          paymentAccountId = account.accountID;
          Logger.data('[INVOICE_API] [$correlationId] Found PERSONAL account: $paymentAccountId (${account.accountName})');
          break;
        }
      }
      
      // If no account with accountType PERSONAL found, try to find by name
      if (paymentAccountId.isEmpty) {
        for (final account in user.dashboard!.accounts) {
          if (account.accountName.toUpperCase().contains('PERSONAL')) {
            paymentAccountId = account.accountID;
            Logger.data('[INVOICE_API] [$correlationId] Found account with PERSONAL in name: $paymentAccountId (${account.accountName})');
            break;
          }
        }
      }
    }
    
    // Check if a valid payment account ID was found
    if (paymentAccountId.isEmpty) {
      Logger.error('[INVOICE_API] [$correlationId] No personal account found for invoice generation');
      return Left(ValidationFailure('Personal account required for invoice generation. Please set up a personal account first.'));
    }
    
    Logger.data('[INVOICE_API] [$correlationId] Using payment account ID: $paymentAccountId');
    
    // Now that we have the payment account ID, we can proceed with the authenticated request
    return _executeAuthenticatedRequest<Invoice>(
      request: (token) async {
        // Prepare the items array for the API request
        Logger.data('[INVOICE_API] [$correlationId] Converting line items to API format');
        final items = lineItems.map((item) => {
          'accountID': item.productId,
          'amount': item.totalPrice / 100, // Convert from cents to dollars
        }).toList();
        
        // Log currency conversion
        Logger.data('[INVOICE_API] [$correlationId] Currency conversion: $totalAmount cents -> ${totalAmount / 100} dollars');
        
        // Prepare request data with the correct format (InvoiceData with capital 'I')
        final requestData = {
          'paymentAccountID': paymentAccountId,
          'InvoiceData': {
            'items': items,
            'total': totalAmount / 100, // Convert from cents to dollars
            'denomination': currency,
            'notes': notes,
          },
        };
        
        final requestBody = jsonEncode(requestData);
        Logger.data('[INVOICE_API] [$correlationId] Request body prepared: ${requestBody.length} characters');
        
        // Call the /generateInvoice API endpoint with authentication
        Logger.data('[INVOICE_API] [$correlationId] Sending POST request to $_baseUrl/generateInvoice');
        final apiCallStart = DateTime.now();
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/generateInvoice'),
            headers: _authHeaders(token),
            body: requestBody,
          ),
          '$_baseUrl/generateInvoice',
          'POST',
          headers: _authHeaders(token),
          body: requestBody,
        );
        final apiCallDuration = DateTime.now().difference(apiCallStart).inMilliseconds;
        
        // Log response details
        Logger.data('[INVOICE_API] [$correlationId] API call completed in $apiCallDuration ms');
        Logger.data('[INVOICE_API] [$correlationId] Response content length: ${response.contentLength ?? 'unknown'} bytes');
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          Logger.data('[INVOICE_API] [$correlationId] Response successful (${response.statusCode})');
          
          // Parse the response body
          final responseBodyStart = DateTime.now();
          final responseData = jsonDecode(response.body);
          final responseBodyDuration = DateTime.now().difference(responseBodyStart).inMilliseconds;
          Logger.data('[INVOICE_API] [$correlationId] Response body parsing took $responseBodyDuration ms');
          
          // Log response structure
          Logger.data('[INVOICE_API] [$correlationId] Response structure: ${_getResponseStructure(responseData)}');
          
          // Extract invoice details from the response according to the specified format
          String invoiceId = '';
          String invoiceQrLink = '';
          DateTime createdAt = DateTime.now();
          int extractedTotalAmount = totalAmount; // Default to the input total amount
          String extractedDenomination = currency; // Default to the input currency
          
          try {
            Logger.data('[INVOICE_API] [$correlationId] Starting response data extraction');
            
            if (responseData.containsKey('data') && 
                responseData['data'] is Map<String, dynamic> && 
                responseData['data'].containsKey('action') &&
                responseData['data']['action'] is Map<String, dynamic>) {
              
              Logger.data('[INVOICE_API] [$correlationId] Found data.action structure in response');
              final action = responseData['data']['action'] as Map<String, dynamic>;
              
              // Extract timestamp
              if (action.containsKey('timestamp') && action['timestamp'] is String) {
                createdAt = DateTime.parse(action['timestamp']);
                Logger.data('[INVOICE_API] [$correlationId] Extracted timestamp: ${action['timestamp']}');
              } else {
                Logger.data('[INVOICE_API] [$correlationId] No timestamp found in response, using current time');
              }
              
              // Extract details
              if (action.containsKey('details') && action['details'] is Map<String, dynamic>) {
                Logger.data('[INVOICE_API] [$correlationId] Found details object in response');
                final details = action['details'] as Map<String, dynamic>;
                
                // Log all available fields in details for debugging
                Logger.data('[INVOICE_API] [$correlationId] Available fields in details: ${details.keys.join(', ')}');
                
                // Extract invoice ID
                if (details.containsKey('invoiceID')) {
                  invoiceId = details['invoiceID']?.toString() ?? '';
                  Logger.data('[INVOICE_API] [$correlationId] Extracted invoice ID: $invoiceId');
                } else {
                  Logger.error('[INVOICE_API] [$correlationId] No invoiceID field found in details');
                }
                
                // Extract invoice QR link
                if (details.containsKey('invoiceQRLink')) {
                  invoiceQrLink = details['invoiceQRLink']?.toString() ?? '';
                  Logger.data('[INVOICE_API] [$correlationId] Extracted invoice QR link: $invoiceQrLink');
                } else {
                  Logger.data('[INVOICE_API] [$correlationId] No invoiceQRLink field found in details');
                }
                
                // Extract total amount
                if (details.containsKey('totalAmount') && details['totalAmount'] is num) {
                  // Convert from dollars to cents (API returns dollars, we store cents)
                  final rawAmount = details['totalAmount'] as num;
                  extractedTotalAmount = (rawAmount * 100).round();
                  Logger.data('[INVOICE_API] [$correlationId] Extracted total amount: $rawAmount dollars -> $extractedTotalAmount cents');
                } else {
                  Logger.data('[INVOICE_API] [$correlationId] No totalAmount field found in details, using input amount: $totalAmount cents');
                }
                
                // Extract denomination (currency)
                if (details.containsKey('denomination')) {
                  extractedDenomination = details['denomination']?.toString() ?? currency;
                  Logger.data('[INVOICE_API] [$correlationId] Extracted denomination: $extractedDenomination');
                } else {
                  Logger.data('[INVOICE_API] [$correlationId] No denomination field found in details, using input currency: $currency');
                }
              } else {
                Logger.error('[INVOICE_API] [$correlationId] No details object found in action');
              }
            } else {
              Logger.error('[INVOICE_API] [$correlationId] Response does not contain expected data.action structure');
              Logger.error('[INVOICE_API] [$correlationId] Response top-level keys: ${responseData.keys.join(', ')}');
            }
            
            // Validate extracted data
            if (invoiceId.isEmpty) {
              Logger.error('[INVOICE_API] [$correlationId] Failed to extract invoice ID from response');
              return Left(ServerFailure('Failed to extract invoice ID from response'));
            }
            
            Logger.data('[INVOICE_API] [$correlationId] Data extraction completed successfully');
            
          } catch (e, stackTrace) {
            Logger.error('[INVOICE_API] [$correlationId] Error extracting invoice details from response', e, stackTrace);
            Logger.error('[INVOICE_API] [$correlationId] Error type: ${e.runtimeType}');
            Logger.error('[INVOICE_API] [$correlationId] Response body: ${response.body}');
            return Left(ServerFailure('Failed to parse invoice response: $e'));
          }
          
          // Create an Invoice object from the response data
          Logger.data('[INVOICE_API] [$correlationId] Creating Invoice object with extracted data');
          final invoice = Invoice(
            id: invoiceId,
            vendorId: vendorId,
            lineItems: lineItems,
            totalAmount: extractedTotalAmount,
            currency: extractedDenomination,
            status: InvoiceStatus.pending,
            paymentMethod: paymentMethod,
            notes: notes,
            createdAt: createdAt,
            updatedAt: createdAt,
            paidAt: null,
            invoiceQrLink: invoiceQrLink,
          );
          
          stopwatch.stop();
          Logger.performance('[INVOICE_API] [$correlationId] createInvoice completed successfully in ${stopwatch.elapsedMilliseconds}ms');
          
          // Return the invoice with the QR link as an additional property
          return Right(invoice);
        } else if (response.statusCode == 400) {
          Logger.error('[INVOICE_API] [$correlationId] Invalid input data with status code 400');
          Logger.error('[INVOICE_API] [$correlationId] Response body: ${response.body}');
          
          // Try to parse error details
          try {
            final errorData = jsonDecode(response.body);
            if (errorData.containsKey('error') && errorData['error'] is String) {
              Logger.error('[INVOICE_API] [$correlationId] Error message: ${errorData['error']}');
            }
          } catch (e) {
            Logger.error('[INVOICE_API] [$correlationId] Could not parse error response', e);
          }
          
          return Left(ValidationFailure('Invalid input data: ${response.body}'));
        } else {
          Logger.error('[INVOICE_API] [$correlationId] Server error with status code ${response.statusCode}');
          Logger.error('[INVOICE_API] [$correlationId] Response body: ${response.body}');
          return Left(ServerFailure('Failed to create invoice: ${response.body}'));
        }
      },
    ).catchError((e, stackTrace) {
      stopwatch.stop();
      Logger.error('[INVOICE_API] [$correlationId] Unhandled exception during invoice creation', e, stackTrace);
      Logger.error('[INVOICE_API] [$correlationId] Exception type: ${e.runtimeType}');
      Logger.error('[INVOICE_API] [$correlationId] Exception message: $e');
      return Left(ServerFailure('Failed to create invoice: $e'));
    });
  }
  
  /// Helper method to log the structure of a response without exposing sensitive data
  String _getResponseStructure(dynamic data, {int level = 0}) {
    if (data == null) {
      return 'null';
    }
    
    if (data is Map) {
      final keys = data.keys.map((k) {
        final value = data[k];
        if (value is Map) {
          return '$k: {${_getResponseStructure(value, level: level + 1)}}';
        } else if (value is List) {
          return '$k: [${value.length} items]';
        } else {
          return '$k: ${value.runtimeType}';
        }
      }).join(', ');
      return keys;
    } else if (data is List) {
      return '[${data.length} items]';
    } else {
      return data.runtimeType.toString();
    }
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice({
    required String id,
    InvoiceStatus? status,
    String? notes,
    DateTime? paidAt,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] updateInvoice called with ID: $id');
    return Left(ServerFailure('API not yet implemented'));
  }

  @override
  Future<Either<Failure, AssetMarker>> getAssetMarker(String id) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getAssetMarker called with ID: $id');
    return Left(ServerFailure('API not yet implemented'));
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByProduct(String productId) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getAssetMarkersByProduct called with product ID: $productId');
    return const Right([]);
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByOwner(String ownerId) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] getAssetMarkersByOwner called with owner ID: $ownerId');
    return const Right([]);
  }

  @override
  Future<Either<Failure, AssetMarker>> createAssetMarker({
    required String productId,
    required String ownerId,
    required String creatorId,
    required int quantity,
    required AssetMarkerStatus status,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] createAssetMarker called');
    return Left(ServerFailure('API not yet implemented'));
  }

  @override
  Future<Either<Failure, AssetMarker>> updateAssetMarker({
    required String id,
    String? ownerId,
    int? quantity,
    AssetMarkerStatus? status,
    DateTime? lastTransferredAt,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] updateAssetMarker called with ID: $id');
    return Left(ServerFailure('API not yet implemented'));
  }

  @override
  Future<Either<Failure, AssetMarker>> transferAssetMarker({
    required String id,
    required String newOwnerId,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] transferAssetMarker called with ID: $id to owner ID: $newOwnerId');
    return Left(ServerFailure('API not yet implemented'));
  }
  
  @override
  Future<Either<Failure, Map<String, String>>> uploadProfileImage({
    required String imagePath,
    required String drAccountId,
    String? crAccountId,
  }) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[PROFILE_IMAGE] Starting uploadProfileImage operation');
    
    // First, we need to read and process the image file before making the API call
    // This needs to be done outside the _executeAuthenticatedRequest
    
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
    
    // Now we can proceed with the authenticated request
    return _executeAuthenticatedRequest<Map<String, String>>(
      request: (token) async {
        // Call the uploadAndOptimizeJpg API endpoint
        Logger.data('[PROFILE_IMAGE] Sending POST request to $_baseUrl/uploadAndOptimizeJpg');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/uploadAndOptimizeJpg'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
            },
            body: requestBodyJson,
          ),
          '$_baseUrl/uploadAndOptimizeJpg',
          'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
          },
          body: requestBodyJson,
        );
        
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
        } else if (response.statusCode == 413) {
          Logger.error('[PROFILE_IMAGE] Request entity too large with status code 413');
          Logger.error('[PROFILE_IMAGE] Original file size: ${fileSizeKB.toStringAsFixed(2)} KB, Base64 size: ${base64SizeKB.toStringAsFixed(2)} KB');
          return Left(ServerFailure('The image file is too large. Please select a smaller image or use a lower resolution image.'));
        } else {
          Logger.error('[PROFILE_IMAGE] Server error with status code ${response.statusCode}');
          Logger.error('[PROFILE_IMAGE] Response body: ${response.body}');
          return Left(ServerFailure('Failed to upload profile image: ${response.body}'));
        }
      },
    ).catchError((e, stackTrace) {
      stopwatch.stop();
      Logger.error('[PROFILE_IMAGE] Error uploading profile image', e, stackTrace);
      return Left(ServerFailure('Failed to upload profile image: $e'));
    });
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
    
    // Prepare request data
    final requestBody = jsonEncode({
      'sourceID': sourceId,
      'originalAssetID': originalAssetId,
      'thumbnailAssetID': thumbnailAssetId,
      'asset200ID': asset200Id,
      'asset600ID': asset600Id,
    });
    
    Logger.data('[PROFILE_IMAGE] Request prepared');
    
    return _executeAuthenticatedRequest<bool>(
      request: (token) async {
        // Call the updateProfilePics API endpoint
        Logger.data('[PROFILE_IMAGE] Sending POST request to $_baseUrl/updateProfilePics');
        final response = await _loggedRequest(
          () => _httpClient.post(
            Uri.parse('$_baseUrl/updateProfilePics'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
              'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
            },
            body: requestBody,
          ),
          '$_baseUrl/updateProfilePics',
          'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'x-client-api-key': 'gfnsrtj543dGJFDGjffDhjdyKGjugDg436vBNb', // TODO: Get from config
          },
          body: requestBody,
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          stopwatch.stop();
          Logger.performance('[PROFILE_IMAGE] updateProfilePictures completed successfully in ${stopwatch.elapsedMilliseconds}ms');
          return const Right(true);
        } else {
          Logger.error('[PROFILE_IMAGE] Server error with status code ${response.statusCode}');
          return Left(ServerFailure('Failed to update profile pictures: ${response.body}'));
        }
      },
    ).catchError((e, stackTrace) {
      stopwatch.stop();
      Logger.error('[PROFILE_IMAGE] Error updating profile pictures', e, stackTrace);
      return Left(ServerFailure('Failed to update profile pictures: $e'));
    });
  }

  @override
  Future<Either<Failure, Invoice>> createCredexOffer({
    required String invoiceId,
    required String accountId,
    required int amount,
    String? note,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] createCredexOffer called with invoice ID: $invoiceId, account ID: $accountId, amount: $amount');
    return Left(ServerFailure('API not yet implemented'));
  }
}
