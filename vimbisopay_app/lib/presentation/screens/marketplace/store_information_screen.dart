import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/infrastructure/services/store_status_service.dart';
import 'package:vimbisopay_app/infrastructure/utils/database_checker.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/edit_vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/add_edit_sku_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

/// Store Information Screen for the VimbisoPay app.
///
/// This screen displays a store's information, including business
/// details, contact information, ratings, and products.
class StoreInformationScreen extends StatefulWidget {
  /// The ID of the store to display.
  final String storeId;

  /// Whether the current user is the owner of this store.
  final bool isOwner;
  
  /// Whether to show a success message when the screen is loaded.
  final bool showSuccessMessage;

  /// Creates a new [StoreInformationScreen] instance.
  const StoreInformationScreen({
    super.key,
    required this.storeId,
    this.isOwner = false,
    this.showSuccessMessage = false,
  });

  @override
  State<StoreInformationScreen> createState() => _StoreInformationScreenState();
}

class _StoreInformationScreenState extends State<StoreInformationScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  final DatabaseHelper _databaseHelper = ServiceLocator.databaseHelper;
  final StoreStatusService _storeStatusService = ServiceLocator.storeStatusService;
  
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isUpdatingStoreStatus = false;
  String _errorMessage = '';
  
  Vendor? _vendor;
  List<Product> _products = [];
  User? _currentUser;
  String? _profileThumbnailUrl;
  bool _storeOpen = false;
  String? _personalAccountId;

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('StoreInformationScreen initialized');
    
    // Initially set loading to false until we determine if we need to show the loading indicator
    setState(() {
      _isLoading = false;
    });
    
    // Check database status
    DatabaseChecker.checkDatabaseStatus().then((_) {
      Logger.data('[STORE_INFO] Database status check completed');
    });
    
    // Load cached data first, then fetch fresh data
    _loadCachedData().then((cachedDataFound) {
      // Only show loading indicator if no cached data was found
      if (!cachedDataFound && mounted) {
        setState(() {
          _isLoading = true;
        });
      }
      
      _loadFreshData();
      
      // Proactively request location permission when the screen is initialized
      if (mounted && widget.isOwner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _storeStatusService.requestLocationPermission(context);
        });
      }
      
      // Show success message if needed
      if (widget.showSuccessMessage) {
        // Use post-frame callback to ensure the context is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Store information updated successfully'),
                backgroundColor: AppColors.successGreen,
              ),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    Logger.lifecycle('StoreInformationScreen disposed');
    super.dispose();
  }

  /// Loads cached store data from the database
  /// Returns true if cached data was found, false otherwise
  Future<bool> _loadCachedData() async {
    try {
      Logger.data('[STORE_INFO] Loading cached store data');
      
      // Load current user data
      _currentUser = await _databaseHelper.getUser();
      if (_currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not found';
        });
        return false;
      }
      
      // Get store status from user
      _storeOpen = _currentUser!.storeOpen;
      Logger.data('[STORE_INFO] Store status from cache: ${_storeOpen ? 'Open' : 'Closed'}');
      
      // Find the user's personal account ID
      if (_currentUser?.dashboard != null && _currentUser!.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType PERSONAL
        for (final account in _currentUser!.dashboard!.accounts) {
          if (account.accountType == 'PERSONAL') {
            _personalAccountId = account.accountID;
            Logger.data('[STORE_INFO] Found PERSONAL account: $_personalAccountId (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType PERSONAL found, try to find by name
        if (_personalAccountId == null) {
          for (final account in _currentUser!.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('PERSONAL')) {
              _personalAccountId = account.accountID;
              Logger.data('[STORE_INFO] Found account with PERSONAL in name: $_personalAccountId (${account.accountName})');
              break;
            }
          }
        }
      }
      
      // Load cached store data from database
      // First try with personal account ID if available
      CachedStore? cachedStore;
      if (_personalAccountId != null) {
        Logger.data('[STORE_INFO] Trying to get cached store data with personal account ID: $_personalAccountId');
        cachedStore = await _databaseHelper.getCachedStore(_personalAccountId!);
      }
      
      // If not found with personal account ID, try with widget.storeId
      if (cachedStore == null) {
        Logger.data('[STORE_INFO] No cached store data found with personal account ID, trying with widget.storeId: ${widget.storeId}');
        cachedStore = await _databaseHelper.getCachedStore(widget.storeId);
      }
      
      if (cachedStore != null) {
        Logger.data('[STORE_INFO] Found cached store data with ID: ${cachedStore.storeId}');
        
        final vendor = cachedStore.vendor;
        final products = cachedStore.products;
        final profileImageUrl = cachedStore.profileImageUrl;
        
        setState(() {
          _isLoading = false;
          _vendor = vendor;
          _products = products;
          _profileThumbnailUrl = profileImageUrl;
        });
        return true;
      } else {
        Logger.data('[STORE_INFO] No cached store data found');
        // Keep isLoading true to show loading indicator until fresh data is loaded
        return false;
      }
    } catch (e) {
      Logger.error('[STORE_INFO] Error loading cached data', e);
      // Don't set error message here, as we'll try to load fresh data next
      return false;
    }
  }

  /// Loads fresh store data from the API
  Future<void> _loadFreshData() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
      if (_vendor == null) {
        _isLoading = true; // Only show loading indicator if we don't have cached data
      }
    });

    try {
      Logger.data('[STORE_INFO] Starting to load fresh store data for store ID: ${widget.storeId}');
      
      // Check if user is a vendor
      if (_currentUser == null || !_currentUser!.activateMarket) {
        Logger.error('[STORE_INFO] User is not a vendor or user is null');
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'User is not a vendor';
        });
        return;
      }

      // Check if we have a personal account ID
      if (_personalAccountId == null) {
        Logger.error('[STORE_INFO] No personal account ID found for user: ${_currentUser!.memberId}');
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          _errorMessage = 'No personal account found';
        });
        return;
      }
      
      Logger.data('[STORE_INFO] Using personal account ID: $_personalAccountId to fetch storefront data');
      
      // Use the getStorefront API to get vendor information
      final storefrontResult = await _marketplaceRepository.getStorefront(_personalAccountId!);
      
      return storefrontResult.fold(
        (failure) {
          Logger.error('[STORE_INFO] Failed to get storefront: ${failure.message}');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isRefreshing = false;
              // Only set error message if we don't have cached data
              if (_vendor == null) {
                _errorMessage = 'Failed to get storefront: ${failure.message}';
              }
            });
          }
        },
        (data) async {
          try {
            Logger.data('[STORE_INFO] Successfully received storefront data');
            
            // Log the structure of the data for debugging
            Logger.data('[STORE_INFO] Data structure: ${_getDataStructure(data)}');
            
            // Validate the expected data structure
            if (!data.containsKey('dashboard')) {
              throw Exception('Missing dashboard key in response data');
            }
            if (!data['dashboard'].containsKey('store')) {
              throw Exception('Missing store key in dashboard data');
            }
            if (!data['dashboard'].containsKey('vendor')) {
              throw Exception('Missing vendor key in dashboard data');
            }
            
            // Extract store information
            final store = data['dashboard']['store'];
            final storeId = store['storeID'] as String?;
            final storeName = store['storeName'] as String?;
            final storeDescription = store['storeDescription'] as String?;
            final storeOpen = store['storeOpen'] as bool?;
            
            Logger.data('[STORE_INFO] Extracted store info - ID: $storeId, Name: $storeName');
            
            // Extract profile picture URLs
            Map<String, dynamic>? profilePictureUrls = store['profilePictureUrls'] as Map<String, dynamic>?;
            String? profileImageUrl;
            if (profilePictureUrls != null) {
              Logger.data('[STORE_INFO] Found profile picture URLs: ${profilePictureUrls.keys.join(', ')}');
              
              // Prefer pic600 if available, then pic200, then thumbnail, then original
              if (profilePictureUrls['pic600'] != null) {
                profileImageUrl = profilePictureUrls['pic600'] as String?;
                Logger.data('[STORE_INFO] Using pic600 as profile image URL');
              } else if (profilePictureUrls['pic200'] != null) {
                profileImageUrl = profilePictureUrls['pic200'] as String?;
                Logger.data('[STORE_INFO] Using pic200 as profile image URL');
              } else if (profilePictureUrls['thumbnail'] != null) {
                profileImageUrl = profilePictureUrls['thumbnail'] as String?;
                Logger.data('[STORE_INFO] Using thumbnail as profile image URL');
              } else if (profilePictureUrls['original'] != null) {
                profileImageUrl = profilePictureUrls['original'] as String?;
                Logger.data('[STORE_INFO] Using original as profile image URL');
              }
            } else {
              Logger.data('[STORE_INFO] No profile picture URLs found');
            }
            
            // Extract vendor information
            final vendor = data['dashboard']['vendor'];
            final memberId = vendor['memberID'] as String?;
            final firstname = vendor['firstname'] as String?;
            final lastname = vendor['lastname'] as String?;
            final memberHandle = vendor['memberHandle'] as String?;
            final vendorBio = vendor['vendorBio'] as String?;
            
            Logger.data('[STORE_INFO] Extracted vendor info - Member ID: $memberId, Name: $firstname $lastname');
            
            // Create a Vendor object
            // Always use personal account ID as the store ID if available
            final vendorStoreId = _personalAccountId ?? widget.storeId;
            Logger.data('[STORE_INFO] Using store ID for vendor object: $vendorStoreId');
            
            final vendorObj = Vendor(
              id: vendorStoreId,
              memberId: memberId ?? _currentUser!.memberId,
              businessName: storeName ?? (firstname != null && lastname != null ? '$firstname $lastname' : 'My Business'),
              description: storeDescription ?? vendorBio ?? 'Store profile',
              email: '',
              phone: _currentUser!.phone,
              profileImageUrl: profileImageUrl,
              bannerImageUrl: null,
              rating: 0.0,
              ratingCount: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            // Update store status
            if (storeOpen != null) {
              _storeOpen = storeOpen;
              Logger.data('[STORE_INFO] Updated store status: ${_storeOpen ? 'Open' : 'Closed'}');
            }
            
            // Extract products
            List<Product> vendorProducts = [];
            if (data['dashboard'].containsKey('products') && data['dashboard']['products'] is List) {
              final products = data['dashboard']['products'] as List;
              Logger.data('[STORE_INFO] Found ${products.length} products in response');
              
              vendorProducts = products.map((product) {
                // Extract product details
                final productId = product['productID'] as String?;
                final productName = product['productName'] as String?;
                final productDescription = product['productDescription'] as String?;
                
                // Extract thumbnail URL
                String? thumbnailUrl = product['thumbnailPicUrl'] as String?;
                List<String> imageUrls = [];
                if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
                  imageUrls.add(thumbnailUrl);
                }
                
                // Create a Product object
                return Product(
                  id: productId ?? '',
                  vendorId: vendorObj.id,
                  name: productName ?? 'Unknown Product',
                  description: productDescription ?? 'No description',
                  price: 0, // Default price
                  currency: 'USD', // Default currency
                  imageUrls: imageUrls,
                  category: 'Internal',
                  tags: ['internal', 'physical_asset'],
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
                profileImageUrl: profileImageUrl ?? "",
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
            
            // Update state
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isRefreshing = false;
                _vendor = vendorObj;
                _products = vendorProducts;
                _profileThumbnailUrl = profileImageUrl;
              });
            }
            
            Logger.data('[STORE_INFO] Successfully updated UI with fresh store data');
          } catch (e, stackTrace) {
            Logger.error('[STORE_INFO] Error parsing storefront data', e);
            Logger.error('[STORE_INFO] Stack trace: $stackTrace');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _isRefreshing = false;
                // Only set error message if we don't have cached data
                if (_vendor == null) {
                  _errorMessage = 'Error parsing storefront data: $e';
                }
              });
            }
          }
        },
      );
    } catch (e, stackTrace) {
      Logger.error('[STORE_INFO] Unexpected error in _loadFreshData', e);
      Logger.error('[STORE_INFO] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
          // Only set error message if we don't have cached data
          if (_vendor == null) {
            _errorMessage = 'An unexpected error occurred: $e';
          }
        });
      }
    }
  }
  
  /// Helper method to log the structure of a data object without exposing sensitive data
  String _getDataStructure(dynamic data, {int level = 0}) {
    if (data == null) {
      return 'null';
    }
    
    if (data is Map) {
      final keys = data.keys.map((k) {
        final value = data[k];
        if (value is Map) {
          return '$k: {${_getDataStructure(value, level: level + 1)}}';
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty && _vendor == null
              ? _buildErrorView()
              : _vendor != null
                  ? _buildStoreProfile()
                  : const Center(child: CircularProgressIndicator()), // Fallback if vendor is null
      // Add FloatingActionButton here, only visible if user is the owner AND products list is not empty
      floatingActionButton: (widget.isOwner && _products.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/vendor-sales-tab',
                  arguments: {
                    'vendorId': widget.storeId,
                  },
                );
              },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('New Sale'),
              backgroundColor: AppColors.primary,
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadFreshData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreProfile() {
    // Add null check to prevent exception
    if (_vendor == null) {
      Logger.error('[STORE_INFO] Attempted to build store profile with null vendor');
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading store information...'),
          ],
        ),
      );
    }
    
    final vendor = _vendor!;
    
    return RefreshIndicator(
      onRefresh: () async {
        await _loadFreshData();
      },
      child: CustomScrollView(
        slivers: [
          _buildAppBar(vendor),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isRefreshing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                  _buildBusinessInfo(vendor),
                  const SizedBox(height: 24),
                  _buildAccountsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(Vendor vendor) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner image
            Positioned.fill(
              child: _buildImageFromUrl(
                vendor.bannerImageUrl,
                placeholder: Container(
                  color: AppColors.primary.withOpacity(0.2),
                  child: const Center(
                    child: Icon(
                      Icons.storefront,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            // Gradient overlay for better text visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.transparent,
                      AppColors.black.withOpacity(0.7),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Profile image
            Positioned(
              left: 16,
              bottom: 16,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: ClipOval(
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: _buildProfileImage(vendor),
                    ),
                  ),
                ),
              ),
            ),
            // Business name and rating
            Positioned(
              left: 108,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.businessName,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: AppColors.black45,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.ratingDisplay,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 2,
                              color: AppColors.black45,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
            if (widget.isOwner) ...[
              IconButton(
                icon: const Icon(Icons.inventory_2),
                tooltip: 'Manage Inventory',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InventoryManagementScreen(
                        vendorId: widget.storeId,
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Profile',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditVendorProfileScreen(
                        vendorId: widget.storeId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Store information updated successfully'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    }
                    
                    // Refresh the store data
                    if (mounted) {
                      _loadFreshData();
                    }
                  });
                },
              ),
            ],
      ],
    );
  }

  /// Updates the store status and location.
  Future<void> _updateStoreStatus(bool value) async {
    if (_isUpdatingStoreStatus) return;
    
    setState(() {
      _isUpdatingStoreStatus = true;
    });
    
    try {
      Logger.data('[STORE_INFO] Updating store status to: ${value ? 'Open' : 'Closed'}');
      
      // Get current location if opening the store
      double? latitude;
      double? longitude;
      
      if (value) {
        // First check if location services are enabled
        final servicesEnabled = await _storeStatusService.checkLocationServicesEnabled(context);
        if (!servicesEnabled) {
          Logger.error('[STORE_INFO] Location services are disabled');
          if (mounted) {
            // Ask if the user wants to continue without location
            final continueWithoutLocation = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Location Services Disabled'),
                content: const Text(
                  'Your store will be marked as open, but customers won\'t be able to see your location. '
                  'Would you like to continue without location?'
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Continue Without Location'),
                  ),
                ],
              ),
            ) ?? false;
            
            if (!continueWithoutLocation) {
              Logger.data('[STORE_INFO] User cancelled store status update due to disabled location services');
              setState(() {
                _isUpdatingStoreStatus = false;
              });
              return;
            }
            
            // User chose to continue without location
            Logger.data('[STORE_INFO] User chose to continue without location');
          } else {
            setState(() {
              _isUpdatingStoreStatus = false;
            });
            return;
          }
        } else {
          // Location services are enabled, now check and request permission if needed
          final hasPermission = await _storeStatusService.requestLocationPermission(context);
          if (!hasPermission) {
            Logger.error('[STORE_INFO] Location permission not granted');
            if (mounted) {
              // Ask if the user wants to continue without location
              final continueWithoutLocation = await showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('Location Permission Denied'),
                  content: const Text(
                    'Your store will be marked as open, but customers won\'t be able to see your location. '
                    'Would you like to continue without location?'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Continue Without Location'),
                    ),
                  ],
                ),
              ) ?? false;
              
              if (!continueWithoutLocation) {
                Logger.data('[STORE_INFO] User cancelled store status update due to denied location permission');
                setState(() {
                  _isUpdatingStoreStatus = false;
                });
                return;
              }
              
              // User chose to continue without location
              Logger.data('[STORE_INFO] User chose to continue without location');
            } else {
              setState(() {
                _isUpdatingStoreStatus = false;
              });
              return;
            }
          } else {
            // Permission granted, get current location
            final location = await _storeStatusService.getCurrentLocation();
            if (location != null) {
              (latitude, longitude) = location;
              Logger.data('[STORE_INFO] Got location: ($latitude, $longitude)');
            } else {
              Logger.error('[STORE_INFO] Failed to get location');
              // Ask if the user wants to continue without location
              if (mounted) {
                final continueWithoutLocation = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    title: const Text('Location Not Available'),
                    content: const Text(
                      'We couldn\'t get your current location. Your store will be marked as open, '
                      'but customers won\'t be able to see your location. '
                      'Would you like to continue without location?'
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Continue Without Location'),
                      ),
                    ],
                  ),
                ) ?? false;
                
                if (!continueWithoutLocation) {
                  Logger.data('[STORE_INFO] User cancelled store status update due to location not available');
                  setState(() {
                    _isUpdatingStoreStatus = false;
                  });
                  return;
                }
                
                // User chose to continue without location
                Logger.data('[STORE_INFO] User chose to continue without location');
              } else {
                setState(() {
                  _isUpdatingStoreStatus = false;
                });
                return;
              }
            }
          }
        }
      }
      
      // Update store status
      final (success, errorMessage) = await _storeStatusService.updateStoreStatus(
        storeOpen: value,
        latitude: latitude,
        longitude: longitude,
      );
      
      if (success) {
        Logger.data('[STORE_INFO] Store status updated successfully');
        // Update local state
        if (mounted) {
          setState(() {
            _storeOpen = value;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Store is now ${value ? 'open' : 'closed'}${latitude != null ? ' with location' : ''}'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      } else {
        Logger.error('[STORE_INFO] Failed to update store status: $errorMessage');
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update store status: ${errorMessage ?? 'Unknown error'}',
                style: const TextStyle(color: AppColors.white),
              ),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('[STORE_INFO] Error updating store status', e);
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error updating store status: $e',
              style: const TextStyle(color: AppColors.white),
            ),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStoreStatus = false;
        });
      }
    }
  }

  Widget _buildBusinessInfo(Vendor vendor) {
    return SettingsContainer(
      title: 'About',
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              if (widget.isOwner) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: vendor.isActive
                            ? AppColors.successGreen.withOpacity(0.2)
                            : AppColors.errorRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vendor.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: vendor.isActive ? AppColors.successGreen : AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                      onPressed: () {
                        // TODO: Navigate to store settings
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Store settings coming soon'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Store:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _isUpdatingStoreStatus
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Switch(
                            value: _storeOpen,
                            activeColor: AppColors.successGreen,
                            onChanged: _updateStoreStatus,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      _storeOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: _storeOpen ? AppColors.successGreen : AppColors.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_currentUser?.latitude != null && _currentUser?.longitude != null)
                      Tooltip(
                        message: 'Location: ${_currentUser!.latitude!.toStringAsFixed(4)}, ${_currentUser!.longitude!.toStringAsFixed(4)}',
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAccountsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.isOwner)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditSkuScreen(
                        vendorId: widget.storeId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Product added successfully'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                      
                      // Refresh the store data
                      if (mounted) {
                        _loadFreshData();
                      }
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        _products.isEmpty
            ? _buildEmptyProductsView()
            : _buildProductsGrid(),
      ],
    );
  }

  Widget _buildEmptyProductsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.isOwner
                  ? 'You haven\'t added any products yet'
                  : 'This store hasn\'t added any products yet',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.isOwner) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditSkuScreen(
                        vendorId: widget.storeId,
                      ),
                    ),
                  ).then((_) {
                    if (mounted) {
                      _loadFreshData();
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Product'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return _buildProductCard(product);
      },
    );
  }

  /// Builds the product image widget based on the image URL type.
  Widget _buildProductImage(Product product) {
    if (product.imageUrls.isEmpty) {
      // Show placeholder if no image
      return Container(
        color: AppColors.grey300,
        child: const Center(
          child: Icon(
            Icons.image,
            color: AppColors.grey,
          ),
        ),
      );
    }
    
    final imageUrl = product.imageUrls.first;
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('[STORE_INFO] Error loading local image: $filePath', error);
          return Container(
            color: AppColors.grey300,
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: AppColors.grey,
              ),
            ),
          );
        },
      );
    } else {
      // Show remote image
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: AppColors.grey200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.grey300,
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: AppColors.grey,
            ),
          ),
        ),
      );
    }
  }

  /// Builds the profile image for the vendor, using the profile thumbnail URL if available.
  Widget _buildProfileImage(Vendor vendor) {
    // Use profile thumbnail URL if available
    if (_profileThumbnailUrl != null && _profileThumbnailUrl!.isNotEmpty) {
      Logger.data('[STORE_INFO] Using profile thumbnail URL: $_profileThumbnailUrl');
      return _buildImageFromUrl(
        _profileThumbnailUrl,
        placeholder: Container(
          color: AppColors.primary,
          child: const Center(
            child: Icon(
              Icons.person,
              size: 38,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }
    
    // Otherwise use vendor's profile image URL
    return vendor.profileImageUrl != null
        ? _buildImageFromUrl(
            vendor.profileImageUrl,
            placeholder: Container(
              color: AppColors.primary,
              child: const Center(
                child: Icon(
                  Icons.storefront,
                  size: 38,
                  color: AppColors.white,
                ),
              ),
            ),
          )
        : Container(
            color: AppColors.primary,
            child: const Center(
              child: Icon(
                Icons.storefront,
                size: 38,
                color: AppColors.white,
              ),
            ),
          );
  }

  /// Builds an image widget from a URL, handling both local and remote URLs.
  Widget _buildImageFromUrl(String? imageUrl, {Widget? placeholder}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      Logger.data('[STORE_INFO] Image URL is null or empty, using placeholder');
      return placeholder ?? Container(color: AppColors.grey300);
    }
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      Logger.data('[STORE_INFO] Loading local image: $filePath');
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('[STORE_INFO] Error loading local image: $filePath', error);
          return placeholder ?? Container(color: AppColors.grey300);
        },
      );
    } else {
      // Show remote image
      Logger.data('[STORE_INFO] Loading remote image: $imageUrl');
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder ?? Container(
          color: AppColors.grey200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          Logger.error('[STORE_INFO] Error loading remote image: $url', error);
          return placeholder ?? Container(color: AppColors.grey300);
        },
      );
    }
  }

  Widget _buildProductCard(Product product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to product detail screen
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${product.name}'),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            AspectRatio(
              aspectRatio: 1.0,
              child: _buildProductImage(product),
            ),
            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.formattedPrice,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: Row(
                        children: [
                          Icon(
                            product.isAvailable
                                ? Icons.check_circle
                                : Icons.cancel,
                            size: 16,
                            color: product.isAvailable
                                ? AppColors.successGreen
                                : AppColors.errorRed,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product.isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.isAvailable
                                    ? AppColors.successGreen
                                    : AppColors.errorRed,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
