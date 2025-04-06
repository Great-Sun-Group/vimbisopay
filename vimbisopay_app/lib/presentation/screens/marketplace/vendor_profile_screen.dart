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
import 'package:vimbisopay_app/presentation/screens/marketplace/edit_vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/add_edit_sku_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

/// Vendor Profile Screen for the VimbisoPay app.
///
/// This screen displays a vendor's profile information, including business
/// details, contact information, ratings, and products.
class VendorProfileScreen extends StatefulWidget {
  /// The ID of the vendor to display.
  final String vendorId;

  /// Whether the current user is the owner of this vendor profile.
  final bool isOwner;
  
  /// Whether to show a success message when the screen is loaded.
  final bool showSuccessMessage;

  /// Creates a new [VendorProfileScreen] instance.
  const VendorProfileScreen({
    super.key,
    required this.vendorId,
    this.isOwner = false,
    this.showSuccessMessage = false,
  });

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  final DatabaseHelper _databaseHelper = ServiceLocator.databaseHelper;
  final StoreStatusService _storeStatusService = ServiceLocator.storeStatusService;
  bool _isLoading = true;
  bool _isUpdatingStoreStatus = false;
  String _errorMessage = '';
  Vendor? _vendor;
  List<Product> _products = [];
  User? _currentUser;
  String? _profileThumbnailUrl;
  bool _storeOpen = false;

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('VendorProfileScreen initialized');
    _loadVendorData();
    
    // Proactively request location permission when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isOwner) {
        _storeStatusService.requestLocationPermission(context);
      }
    });
    
    // Show success message if needed
    if (widget.showSuccessMessage) {
      // Use post-frame callback to ensure the context is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vendor profile created successfully'),
              backgroundColor: AppColors.successGreen,
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    Logger.lifecycle('VendorProfileScreen disposed');
    super.dispose();
  }

  Future<void> _loadVendorData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load current user data
      try {
        _currentUser = await _databaseHelper.getUser();
        if (_currentUser == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'User not found';
          });
          return;
        }
        
        // Get store status from user
        _storeOpen = _currentUser!.storeOpen;
        Logger.data('[VENDOR_PROFILE] Store status: ${_storeOpen ? 'Open' : 'Closed'}');
      } catch (e) {
        Logger.error('[VENDOR_PROFILE] Error loading user data', e);
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user data: $e';
        });
        return;
      }

      // Check if user is a vendor
      if (!_currentUser!.activateMarket) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'User is not a vendor';
        });
        return;
      }

      // Find the user's personal account ID
      String? personalAccountId;
      if (_currentUser?.dashboard != null && _currentUser!.dashboard!.accounts.isNotEmpty) {
        // Try to find an account with accountType PERSONAL
        for (final account in _currentUser!.dashboard!.accounts) {
          if (account.accountType == 'PERSONAL') {
            personalAccountId = account.accountID;
            Logger.data('[VENDOR_PROFILE] Found PERSONAL account: $personalAccountId (${account.accountName})');
            break;
          }
        }
        
        // If no account with accountType PERSONAL found, try to find by name
        if (personalAccountId == null) {
          for (final account in _currentUser!.dashboard!.accounts) {
            if (account.accountName.toUpperCase().contains('PERSONAL')) {
              personalAccountId = account.accountID;
              Logger.data('[VENDOR_PROFILE] Found account with PERSONAL in name: $personalAccountId (${account.accountName})');
              break;
            }
          }
        }
      }
      
      if (personalAccountId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No personal account found';
        });
        return;
      }
      
      // Use the getStorefront API to get vendor information
      final storefrontResult = await _marketplaceRepository.getStorefront(personalAccountId);
      
      return storefrontResult.fold(
        (failure) {
          Logger.error('[VENDOR_PROFILE] Failed to get storefront: ${failure.message}');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to get storefront: ${failure.message}';
          });
        },
        (data) {
          try {
            // Extract store information
            final store = data['dashboard']['store'];
            final storeId = store['storeID'] as String?;
            final storeName = store['storeName'] as String?;
            final storeDescription = store['storeDescription'] as String?;
            final storeOpen = store['storeOpen'] as bool?;
            
            // Extract profile picture URLs
            Map<String, dynamic>? profilePictureUrls = store['profilePictureUrls'] as Map<String, dynamic>?;
            String? profileImageUrl;
            if (profilePictureUrls != null) {
              // Prefer pic600 if available, then pic200, then thumbnail, then original
              if (profilePictureUrls['pic600'] != null) {
                profileImageUrl = profilePictureUrls['pic600'] as String?;
              } else if (profilePictureUrls['pic200'] != null) {
                profileImageUrl = profilePictureUrls['pic200'] as String?;
              } else if (profilePictureUrls['thumbnail'] != null) {
                profileImageUrl = profilePictureUrls['thumbnail'] as String?;
              } else if (profilePictureUrls['original'] != null) {
                profileImageUrl = profilePictureUrls['original'] as String?;
              }
            }
            
            // Extract vendor information
            final vendor = data['dashboard']['vendor'];
            final memberId = vendor['memberID'] as String?;
            final firstname = vendor['firstname'] as String?;
            final lastname = vendor['lastname'] as String?;
            final memberHandle = vendor['memberHandle'] as String?;
            final vendorBio = vendor['vendorBio'] as String?;
            
            // Create a Vendor object
            final vendorObj = Vendor(
              id: storeId ?? widget.vendorId,
              memberId: memberId ?? _currentUser!.memberId,
              businessName: storeName ?? (firstname != null && lastname != null ? '$firstname $lastname' : 'My Business'),
              description: storeDescription ?? vendorBio ?? 'Vendor profile',
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
            }
            
            // Extract products
            List<Product> vendorProducts = [];
            if (data['dashboard']['products'] is List) {
              final products = data['dashboard']['products'] as List;
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
                  isAvailable: true,
                  accountId: productId,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );
              }).toList();
            }
            
            // Update state
            setState(() {
              _isLoading = false;
              _vendor = vendorObj;
              _products = vendorProducts;
              _profileThumbnailUrl = profileImageUrl;
            });
          } catch (e) {
            Logger.error('[VENDOR_PROFILE] Error parsing storefront data', e);
            setState(() {
              _isLoading = false;
              _errorMessage = 'Error parsing storefront data: $e';
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: InlineLoadingAnimation(size: 80))
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildVendorProfile(),
      // Add FloatingActionButton here, only visible if user is the owner AND products list is not empty
      floatingActionButton: (widget.isOwner && _products.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/vendor-sales-tab',
                  arguments: {
                    'vendorId': widget.vendorId,
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
              onPressed: _loadVendorData,
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

  Widget _buildVendorProfile() {
    final vendor = _vendor!;
    
    return CustomScrollView(
      slivers: [
        _buildAppBar(vendor),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBusinessInfo(vendor),
                const SizedBox(height: 24),
                _buildAccountsSection(),
              ],
            ),
          ),
        ),
      ],
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
                        vendorId: widget.vendorId,
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
                        vendorId: widget.vendorId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Vendor profile updated successfully'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                    }
                    
                    // Refresh the vendor data
                    if (mounted) {
                      _loadVendorData();
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
      Logger.data('[VENDOR_PROFILE] Updating store status to: ${value ? 'Open' : 'Closed'}');
      
      // Get current location if opening the store
      double? latitude;
      double? longitude;
      
      if (value) {
        // First check if location services are enabled
        final servicesEnabled = await _storeStatusService.checkLocationServicesEnabled(context);
        if (!servicesEnabled) {
          Logger.error('[VENDOR_PROFILE] Location services are disabled');
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
              Logger.data('[VENDOR_PROFILE] User cancelled store status update due to disabled location services');
              setState(() {
                _isUpdatingStoreStatus = false;
              });
              return;
            }
            
            // User chose to continue without location
            Logger.data('[VENDOR_PROFILE] User chose to continue without location');
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
            Logger.error('[VENDOR_PROFILE] Location permission not granted');
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
                Logger.data('[VENDOR_PROFILE] User cancelled store status update due to denied location permission');
                setState(() {
                  _isUpdatingStoreStatus = false;
                });
                return;
              }
              
              // User chose to continue without location
              Logger.data('[VENDOR_PROFILE] User chose to continue without location');
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
              Logger.data('[VENDOR_PROFILE] Got location: ($latitude, $longitude)');
            } else {
              Logger.error('[VENDOR_PROFILE] Failed to get location');
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
                  Logger.data('[VENDOR_PROFILE] User cancelled store status update due to location not available');
                  setState(() {
                    _isUpdatingStoreStatus = false;
                  });
                  return;
                }
                
                // User chose to continue without location
                Logger.data('[VENDOR_PROFILE] User chose to continue without location');
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
        Logger.data('[VENDOR_PROFILE] Store status updated successfully');
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
        Logger.error('[VENDOR_PROFILE] Failed to update store status: $errorMessage');
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
      Logger.error('[VENDOR_PROFILE] Error updating store status', e);
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
                        // TODO: Navigate to vendor settings
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vendor settings coming soon'),
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
                            child: InlineLoadingAnimation(size: 24),
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
              'Accounts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (widget.isOwner)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Account'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditSkuScreen(
                        vendorId: widget.vendorId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Account added successfully'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                      
                      // Check if the result contains a product
                      if (result.containsKey('product') && result['product'] != null) {
                        final productMap = result['product'] as Map<String, dynamic>;
                        Logger.data('[VENDOR_PROFILE] Retrieved product data from AddEditSkuScreen');
                        
                        try {
                          // Create a new Product object from the data
                          final retrievedProduct = Product(
                            id: productMap['id'],
                            vendorId: productMap['vendorId'],
                            name: productMap['name'],
                            description: productMap['description'],
                            price: productMap['price'],
                            currency: productMap['currency'],
                            imageUrls: List<String>.from(productMap['imageUrls']),
                            isAvailable: productMap['isAvailable'],
                            accountId: productMap['accountId'],
                            createdAt: DateTime.parse(productMap['createdAt']),
                            updatedAt: DateTime.parse(productMap['updatedAt']),
                          );
                          
                          // Check if the product has image URLs
                          if (retrievedProduct.imageUrls.isNotEmpty) {
                            Logger.data('[VENDOR_PROFILE] Retrieved product has image URLs: ${retrievedProduct.imageUrls}');
                            
                            // Update the state with the new product
                            setState(() {
                              // Add the new product to the list
                              _products.add(retrievedProduct);
                            });
                            
                            // No need to reload all vendor data
                            return;
                          }
                        } catch (e) {
                          Logger.error('[VENDOR_PROFILE] Error creating Product from result data', e);
                          // Continue to reload all vendor data
                        }
                      }
                    }
                    
                    // If we didn't get a product or it didn't have image URLs, refresh all data
                    if (mounted) {
                      _loadVendorData();
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        _products.isEmpty
            ? _buildEmptyAccountsView()
            : _buildAccountsGrid(),
      ],
    );
  }

  Widget _buildEmptyAccountsView() {
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
                  ? 'You haven\'t added any accounts yet'
                  : 'This vendor hasn\'t added any accounts yet',
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
                        vendorId: widget.vendorId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Account added successfully'),
                            backgroundColor: AppColors.successGreen,
                          ),
                        );
                      }
                      
                      // Check if the result contains a product
                      if (result.containsKey('product') && result['product'] != null) {
                        final productMap = result['product'] as Map<String, dynamic>;
                        Logger.data('[VENDOR_PROFILE] Retrieved product data from AddEditSkuScreen');
                        
                        try {
                          // Create a new Product object from the data
                          final retrievedProduct = Product(
                            id: productMap['id'],
                            vendorId: productMap['vendorId'],
                            name: productMap['name'],
                            description: productMap['description'],
                            price: productMap['price'],
                            currency: productMap['currency'],
                            imageUrls: List<String>.from(productMap['imageUrls']),
                            isAvailable: productMap['isAvailable'],
                            accountId: productMap['accountId'],
                            createdAt: DateTime.parse(productMap['createdAt']),
                            updatedAt: DateTime.parse(productMap['updatedAt']),
                          );
                          
                          // Check if the product has image URLs
                          if (retrievedProduct.imageUrls.isNotEmpty) {
                            Logger.data('[VENDOR_PROFILE] Retrieved product has image URLs: ${retrievedProduct.imageUrls}');
                            
                            // Update the state with the new product
                            setState(() {
                              // Add the new product to the list
                              _products.add(retrievedProduct);
                            });
                            
                            // No need to reload all vendor data
                            return;
                          }
                        } catch (e) {
                          Logger.error('[VENDOR_PROFILE] Error creating Product from result data', e);
                          // Continue to reload all vendor data
                        }
                      }
                    }
                    
                    // If we didn't get a product or it didn't have image URLs, refresh all data
                    if (mounted) {
                      _loadVendorData();
                    }
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Account'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsGrid() {
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
    if (product.imageUrls.isEmpty || product.imageUrls.first == 'https://example.com/product_placeholder.jpg') {
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
          Logger.error('Error loading local image: $filePath', error);
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
            child: InlineLoadingAnimation(size: 40),
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
      Logger.data('[VENDOR_PROFILE] Using profile thumbnail URL: $_profileThumbnailUrl');
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
      Logger.data('[VENDOR_PROFILE] Image URL is null or empty, using placeholder');
      return placeholder ?? Container(color: AppColors.grey300);
    }
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      Logger.data('[VENDOR_PROFILE] Loading local image: $filePath');
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('[VENDOR_PROFILE] Error loading local image: $filePath', error);
          return placeholder ?? Container(color: AppColors.grey300);
        },
      );
    } else {
      // Show remote image
      Logger.data('[VENDOR_PROFILE] Loading remote image: $imageUrl');
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder ?? Container(
          color: AppColors.grey200,
          child: const Center(child: InlineLoadingAnimation(size: 40)),
        ),
        errorWidget: (context, url, error) {
          Logger.error('[VENDOR_PROFILE] Error loading remote image: $url', error);
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
