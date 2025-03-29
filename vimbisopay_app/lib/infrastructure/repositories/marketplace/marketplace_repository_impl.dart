import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
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
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 404) {
        Logger.error('[MARKETPLACE] Product not found with status code 404');
        return Left(NotFoundFailure('Product not found'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to get product: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error getting product', e, stackTrace);
      return Left(ServerFailure('Failed to get product: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(
      String category) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting getProductsByCategory operation for category: $category');
    
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
      
      // Call the API endpoint to get products by category
      Logger.data('[MARKETPLACE] Sending GET request to $_baseUrl/getProductsByCategory/$category');
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/getProductsByCategory/$category'),
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
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to get products by category: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error getting products by category', e, stackTrace);
      return Left(ServerFailure('Failed to get products by category: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting searchProducts operation for query: $query');
    
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
        'query': query,
      });
      
      // Call the API endpoint to search products
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/searchProducts');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/searchProducts'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBody,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
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
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to search products: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error searching products', e, stackTrace);
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
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting createProduct operation');
    
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
      
      // Create an internal account for the product if not provided
      String productAccountId = accountId ?? '';
      if (productAccountId.isEmpty) {
        Logger.data('[MARKETPLACE] No account ID provided, creating internal account');
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
        Logger.data('[MARKETPLACE] Created internal account with ID: $productAccountId');
      }
      
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
        'accountId': productAccountId,
      };
      
      final requestBodyJson = jsonEncode(requestBody);
      Logger.data('[MARKETPLACE] Request body: $requestBodyJson');
      
      // Call the API endpoint to create product
      Logger.data('[MARKETPLACE] Sending POST request to $_baseUrl/createProduct');
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/createProduct'),
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
              accountId: productData['accountId'] ?? productAccountId,
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
              accountId: productAccountId,
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
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to create product: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error creating product', e, stackTrace);
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
    final stopwatch = Stopwatch()..start();
    Logger.data('[MARKETPLACE] Starting updateProduct operation for ID: $id');
    
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
      final response = await _httpClient.put(
        Uri.parse('$_baseUrl/updateProduct'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user.token}',
        },
        body: requestBodyJson,
      );
      
      // Log response details
      Logger.data('[MARKETPLACE] Response status code: ${response.statusCode}');
      
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
      } else if (response.statusCode == 401) {
        Logger.error('[MARKETPLACE] Authentication failed with status code 401');
        return Left(AuthFailure(message: 'Authentication failed'));
      } else if (response.statusCode == 404) {
        Logger.error('[MARKETPLACE] Product not found with status code 404');
        return Left(NotFoundFailure('Product not found'));
      } else {
        Logger.error('[MARKETPLACE] Server error with status code ${response.statusCode}');
        return Left(ServerFailure('Failed to update product: ${response.body}'));
      }
    } catch (e, stackTrace) {
      stopwatch.stop();
      Logger.error('[MARKETPLACE] Error updating product', e, stackTrace);
      return Left(ServerFailure('Failed to update product: $e'));
    }
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
    required String buyerId,
    required String vendorId,
    required List<InvoiceLineItem> lineItems,
    required int totalAmount,
    required String currency,
    required String paymentMethod,
    String? notes,
  }) async {
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] createInvoice called');
    return Left(ServerFailure('API not yet implemented'));
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
    // Empty implementation - API not yet available
    Logger.data('[MARKETPLACE] createCredexOffer called with invoice ID: $invoiceId, account ID: $accountId, amount: $amount');
    return Left(ServerFailure('API not yet implemented'));
  }
}
