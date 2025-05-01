import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/helpers/store_information_helper.dart';

/// Result of loading cached store data
class CachedDataResult {
  final bool cachedDataFound;
  final Vendor? vendor;
  final List<Product> products;
  final String? profileThumbnailUrl;
  final bool storeOpen;
  final String? operationsAccountId;
  final User? currentUser;

  CachedDataResult({
    required this.cachedDataFound,
    this.vendor,
    required this.products,
    this.profileThumbnailUrl,
    required this.storeOpen,
    this.operationsAccountId,
    this.currentUser,
  });
}

/// Result of loading fresh store data
class FreshDataResult {
  final bool success;
  final String errorMessage;
  final Vendor? vendor;
  final List<Product> products;
  final String? profileThumbnailUrl;

  FreshDataResult({
    required this.success,
    required this.errorMessage,
    this.vendor,
    required this.products,
    this.profileThumbnailUrl,
  });
}

/// Service for loading store data
class StoreDataService {
  final MarketplaceRepository _marketplaceRepository;
  final DatabaseHelper _databaseHelper;

  /// Creates a new [StoreDataService] instance
  StoreDataService({
    required MarketplaceRepository marketplaceRepository,
    required DatabaseHelper databaseHelper,
  })  : _marketplaceRepository = marketplaceRepository,
        _databaseHelper = databaseHelper;

  /// Loads cached store data from the database
  Future<CachedDataResult> loadCachedData(String storeId) async {
    try {
      Logger.data('[STORE_INFO] Loading cached store data');
      
      // Load current user data
      final currentUser = await _databaseHelper.getUser();
      if (currentUser == null) {
        Logger.error('[STORE_INFO] User not found');
        return CachedDataResult(
          cachedDataFound: false,
          products: [],
          storeOpen: false,
        );
      }
      
      // Get store status from user
      final storeOpen = currentUser.storeOpen;
      Logger.data('[STORE_INFO] Store status from cache: ${storeOpen ? 'Open' : 'Closed'}');
      
      // Find the user's personal account ID
      String? operationsAccountId;
      if (currentUser.dashboard != null && currentUser.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType OPERATIONS
        for (final account in currentUser.dashboard!.accounts) {
          if (account.accountType == 'OPERATIONS') {
            operationsAccountId = account.accountID;
            Logger.data('[STORE_INFO] Found OPERATIONS account: $operationsAccountId (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType OPERATIONS found, try to find by name
        if (operationsAccountId == null) {
          for (final account in currentUser.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('OPERATIONS')) {
              operationsAccountId = account.accountID;
              Logger.data('[STORE_INFO] Found account with OPERATIONS in name: $operationsAccountId (${account.accountName})');
              break;
            }
          }
        }
      }
      
      // Load cached store data from database
      // First try with personal account ID if available
      CachedStore? cachedStore;
      if (operationsAccountId != null) {
        Logger.data('[STORE_INFO] Trying to get cached store data with personal account ID: $operationsAccountId');
        cachedStore = await _databaseHelper.getCachedStore(operationsAccountId);
      }
      
      // If not found with personal account ID, try with storeId
      if (cachedStore == null) {
        Logger.data('[STORE_INFO] No cached store data found with personal account ID, trying with storeId: $storeId');
        cachedStore = await _databaseHelper.getCachedStore(storeId);
      }
      
      if (cachedStore != null) {
        Logger.data('[STORE_INFO] Found cached store data with ID: ${cachedStore.storeId}');
        
        final vendor = cachedStore.vendor;
        final products = cachedStore.products;
        final profileImageUrl = cachedStore.profileImageUrl;
        
        return CachedDataResult(
          cachedDataFound: true,
          vendor: vendor,
          products: products,
          profileThumbnailUrl: profileImageUrl,
          storeOpen: storeOpen,
          operationsAccountId: operationsAccountId,
          currentUser: currentUser,
        );
      } else {
        Logger.data('[STORE_INFO] No cached store data found');
        return CachedDataResult(
          cachedDataFound: false,
          products: [],
          storeOpen: storeOpen,
          operationsAccountId: operationsAccountId,
          currentUser: currentUser,
        );
      }
    } catch (e) {
      Logger.error('[STORE_INFO] Error loading cached data', e);
      return CachedDataResult(
        cachedDataFound: false,
        products: [],
        storeOpen: false,
      );
    }
  }

  /// Loads fresh store data from the API
  Future<FreshDataResult> loadFreshData(
    String storeId,
    String? operationsAccountId,
    User? currentUser,
  ) async {
    try {
      Logger.data('[STORE_INFO] Starting to load fresh store data for store ID: $storeId');
      
      // Check if user is a vendor
      if (currentUser == null || !currentUser.activateMarket) {
        Logger.error('[STORE_INFO] User is not a vendor or user is null');
        return FreshDataResult(
          success: false,
          errorMessage: 'User is not a vendor',
          products: [],
        );
      }

      // Check if we have a personal account ID
      if (operationsAccountId == null) {
        Logger.error('[STORE_INFO] No personal account ID found for user: ${currentUser.memberId}');
        return FreshDataResult(
          success: false,
          errorMessage: 'No personal account found',
          products: [],
        );
      }
      
      Logger.data('[STORE_INFO] Using personal account ID: $operationsAccountId to fetch storefront data');
      
      // Use the getAccountDashboard API to get vendor information
      final dashboardResult = await _marketplaceRepository.getAccountDashboard(operationsAccountId);
      
      return await dashboardResult.fold(
        (failure) {
          Logger.error('[STORE_INFO] Failed to get storefront: ${failure.message}');
          return FreshDataResult(
            success: false,
            errorMessage: 'Failed to get storefront: ${failure.message}',
            products: [],
          );
        },
        (data) async {
          try {
            Logger.data('[STORE_INFO] Successfully received storefront data');
            
            // Log the structure of the data for debugging
            Logger.data('[STORE_INFO] Data structure: ${StoreInformationHelper.getDataStructure(data)}');
            
            // Validate the expected data structure
            if (!data.containsKey('dashboard')) {
              throw Exception('Missing dashboard key in response data');
            }
            
            // Extract account information
            final dashboard = data['dashboard'];
            final accountId = dashboard['accountID'] as String?;
            final accountName = dashboard['accountName'] as String?;
            final accountHandle = dashboard['accountHandle'] as String?;
            final accountType = dashboard['accountType'] as String?;
            final defaultDenom = dashboard['defaultDenom'] as String?;
            final isOwnedAccount = dashboard['isOwnedAccount'] as bool?;
            
            Logger.data('[STORE_INFO] Extracted account info - ID: $accountId, Name: $accountName, Type: $accountType');
            
            // Extract sender information
            Map<String, dynamic>? sendOffersTo;
            if (dashboard.containsKey('sendOffersTo') && dashboard['sendOffersTo'] is Map<String, dynamic>) {
              sendOffersTo = dashboard['sendOffersTo'] as Map<String, dynamic>;
            }
            
            final memberId = sendOffersTo?['memberID'] as String?;
            final firstname = sendOffersTo?['firstname'] as String?;
            final lastname = sendOffersTo?['lastname'] as String?;
            
            Logger.data('[STORE_INFO] Extracted sender info - Member ID: $memberId, Name: $firstname $lastname');
            
            // Create a Vendor object
            // Always use personal account ID as the store ID if available
            final vendorStoreId = operationsAccountId ?? storeId;
            Logger.data('[STORE_INFO] Using store ID for vendor object: $vendorStoreId');
            
            final vendorObj = Vendor(
              id: vendorStoreId,
              memberId: memberId ?? currentUser.memberId,
              businessName: accountName ?? (firstname != null && lastname != null ? '$firstname $lastname' : 'My Business'),
              description: 'Store profile for $accountName', // No description in the new API response
              email: '',
              phone: currentUser.phone,
              profileImageUrl: null, // No profile image in the new API response
              bannerImageUrl: null,
              rating: 0.0,
              ratingCount: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            // Extract products
            List<Product> vendorProducts = [];
            if (dashboard.containsKey('products') && dashboard['products'] is List) {
              final products = dashboard['products'] as List;
              Logger.data('[STORE_INFO] Found ${products.length} products in response');
              
              vendorProducts = products.map<Product>((product) {
                // Extract product details
                final productId = product['accountID'] as String?;
                final productName = product['accountName'] as String?;
                final productType = product['accountType'] as String?;
                final productBalance = product['accountBalanceUSD'] as num?;
                final profilePictureThumbnail = product['profilePictureThumbnail'] as String?;
                
                // Create image URLs list with profile picture thumbnail if available
                final List<String> imageUrls = [];
                if (profilePictureThumbnail != null && profilePictureThumbnail.isNotEmpty) {
                  Logger.data('[STORE_INFO] Adding profile picture thumbnail to product: $profilePictureThumbnail');
                  imageUrls.add(profilePictureThumbnail);
                } else {
                  Logger.data('[STORE_INFO] No profile picture thumbnail available for product: $productId');
                }
                
                // Create a Product object
                return Product(
                  id: productId ?? '',
                  vendorId: vendorObj.id,
                  name: productName ?? 'Unknown Product',
                  description: '',
                  price: productBalance != null ? (productBalance * 100).toInt() : 0, // Convert from dollars to cents
                  currency: 'USD', // Default currency
                  imageUrls: imageUrls, // Use the profile picture thumbnail as the product image
                  isAvailable: true,
                  accountId: productId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }).toList();
              
              Logger.data('[STORE_INFO] Created ${vendorProducts.length} Product objects');
            } else {
              Logger.data('[STORE_INFO] No products found in response or invalid format');
            }
            
            // Cache the store data in the database
            Logger.data('[STORE_INFO] Attempting to cache store data in database with ID: ${vendorObj.id}');
            try {
              await _databaseHelper.cacheStoreData(
                storeId: vendorObj.id,
                vendor: vendorObj,
                products: vendorProducts,
                profileImageUrl: '',  // No profile image in the new API response
              );
              Logger.data('[STORE_INFO] Successfully cached store data in database with ID: ${vendorObj.id}');
              
              // Verify the data was cached by retrieving it
              final cachedStore = await _databaseHelper.getCachedStore(vendorObj.id);
              if (cachedStore != null) {
                Logger.data('[STORE_INFO] Verified cached data can be retrieved with ID: ${cachedStore.storeId}');
              } else {
                Logger.error('[STORE_INFO] Failed to verify cached data - could not retrieve it');
              }
            } catch (cacheError) {
              Logger.error('[STORE_INFO] Error caching store data', cacheError);
              // Continue even if caching fails, as we still have the data in memory
            }
            
            return FreshDataResult(
              success: true,
              errorMessage: '',
              vendor: vendorObj,
              products: vendorProducts,
              profileThumbnailUrl: '',
            );
          } catch (e, stackTrace) {
            Logger.error('[STORE_INFO] Error parsing storefront data', e);
            Logger.error('[STORE_INFO] Stack trace: $stackTrace');
            return FreshDataResult(
              success: false,
              errorMessage: 'Error parsing storefront data: $e',
              products: [],
            );
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[STORE_INFO] Unexpected error in loadFreshData', e);
      Logger.error('[STORE_INFO] Stack trace: $stackTrace');
      return FreshDataResult(
        success: false,
        errorMessage: 'An unexpected error occurred: $e',
        products: [],
      );
    }
  }
}
