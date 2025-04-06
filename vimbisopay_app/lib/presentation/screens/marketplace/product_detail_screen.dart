import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/product.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/vendor.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/store_information_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';
import 'dart:convert';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final MarketplaceRepository _marketplaceRepository =
      ServiceLocator.marketplaceRepository;

  bool _isLoading = true;
  String _errorMessage = '';
  Product? _product;
  Vendor? _vendor;
  List<Product> _relatedProducts = [];
  int _currentImageIndex = 0;
  bool _isCurrentUserVendor = false; // Track if the current user is a vendor

  // Additional vendor and store information
  String? _vendorFirstName;
  String? _vendorLastName;
  String? _vendorBio;
  bool _storeOpen = false;
  double? _storeLatitude;
  double? _storeLongitude;
  String? _storeName;
  String? _storeDescription;
  String? _storeHandle;

  @override
  void initState() {
    super.initState();
    _checkIfUserIsVendor();
    _loadProductDetails();
  }

  /// Checks if the current user is a vendor.
  Future<void> _checkIfUserIsVendor() async {
    try {
      // Get the current user from the database
      final databaseHelper = ServiceLocator.databaseHelper;
      final user = await databaseHelper.getUser();
      
      if (user != null) {
        // Check if the user is a vendor
        final isVendor = await _marketplaceRepository.isMemberVendor(user.memberId);
        
        if (mounted) {
          setState(() {
            _isCurrentUserVendor = isVendor;
          });
        }
        
        Logger.data('[PRODUCT_DETAIL] Current user is vendor: $_isCurrentUserVendor');
      } else {
        Logger.data('[PRODUCT_DETAIL] No user found, assuming not a vendor');
      }
    } catch (e) {
      Logger.error('[PRODUCT_DETAIL] Error checking if user is vendor', e);
      // Default to false if there's an error
      if (mounted) {
        setState(() {
          _isCurrentUserVendor = false;
        });
      }
    }
  }

  /// Gets the current location if available.
  ///
  /// Returns a tuple of latitude and longitude if successful, null otherwise.
  Future<(double, double)?> _getCurrentLocation() async {
    try {
      final storeStatusService = ServiceLocator.storeStatusService;
      return await storeStatusService.getCurrentLocation();
    } catch (e) {
      Logger.error('[PRODUCT_DETAIL] Error getting current location', e);
      return null;
    }
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Get current location
      final location = await _getCurrentLocation();
      double? latitude;
      double? longitude;

      if (location != null) {
        (latitude, longitude) = location;
        Logger.data(
            '[PRODUCT_DETAIL] Using location for product search: ($latitude, $longitude)');
      } else {
        Logger.data(
            '[PRODUCT_DETAIL] No location available for product search');
      }

      // Load product details
      final productResult =
          await _marketplaceRepository.getProduct(widget.productId);

      await productResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load product';
          });
        },
        (product) async {
          _product = product;

          // Extract store and vendor information directly from the product object
          try {
            Logger.data(
                '[PRODUCT_DETAIL] Extracting store and vendor information from product object');

            // Get vendor from product
            _vendor = product.vendor;
            
            // Get store from product
            if (product.store != null) {
              _storeName = product.store!.name;
              _storeDescription = product.store!.description;
              _storeOpen = product.store!.isOpen;
              _storeLatitude = product.store!.latitude;
              _storeLongitude = product.store!.longitude;
              _storeHandle = product.store!.handle;
              
              Logger.data(
                  '[PRODUCT_DETAIL] Extracted store info - Name: $_storeName, Open: $_storeOpen, Location: ($_storeLatitude, $_storeLongitude)');
            } else {
              // Fallback to storeName if store object is not available
              _storeName = product.storeName;
              Logger.data('[PRODUCT_DETAIL] Using fallback store name: $_storeName');
            }
            
            // Extract vendor information if available
            if (_vendor != null) {
              // Try to extract first name and last name from business name
              final nameParts = _vendor!.businessName.split(' ');
              if (nameParts.length > 1) {
                _vendorFirstName = nameParts.first;
                _vendorLastName = nameParts.skip(1).join(' ');
              } else {
                _vendorFirstName = _vendor!.businessName;
                _vendorLastName = '';
              }
              
              _vendorBio = _vendor!.description;
              
              Logger.data(
                  '[PRODUCT_DETAIL] Extracted vendor info - Name: $_vendorFirstName $_vendorLastName, Bio: $_vendorBio');
            } else if (product.vendorId.isNotEmpty) {
              // Create a basic vendor object if not available but we have vendorId
              _vendor = Vendor(
                id: product.vendorId,
                memberId: product.vendorId,
                businessName: _storeName ?? 'Store',
                description: 'No description available',
                email: '',
                phone: '',
                profileImageUrl: null,
                bannerImageUrl: null,
                rating: 0.0,
                ratingCount: 0,
                isActive: _storeOpen,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              
              Logger.data('[PRODUCT_DETAIL] Created fallback vendor object');
            }

            Logger.data(
                '[PRODUCT_DETAIL] Successfully extracted store and vendor information');
          } catch (e) {
            Logger.error(
                '[PRODUCT_DETAIL] Error extracting store and vendor information',
                e);
          }

          // Load related products using search with the product's name as query and location if available
          final relatedResult = await _marketplaceRepository.searchProducts(
            product.name,
            latitude: latitude,
            longitude: longitude,
          );

          relatedResult.fold(
            (failure) {
              Logger.error(
                  '[PRODUCT_DETAIL] Failed to load related products', failure);
            },
            (products) {
              // Filter out current product and limit to 10 related products
              _relatedProducts =
                  products.where((p) => p.id != product.id).take(10).toList();

              Logger.data(
                  '[PRODUCT_DETAIL] Loaded ${_relatedProducts.length} related products using search');

              // If no related products found, try to get products from the same vendor
              if (_relatedProducts.isEmpty && product.vendorId.isNotEmpty) {
                Logger.data(
                    '[PRODUCT_DETAIL] No related products found, trying to get products from the same vendor');

                // This would ideally use a getProductsByVendor method, but we'll use search as a fallback
                // In a real implementation, you might want to add a specific API for this
                _marketplaceRepository
                    .searchProducts(
                  '',
                  latitude: latitude,
                  longitude: longitude,
                )
                    .then((vendorProductsResult) {
                  vendorProductsResult.fold(
                    (failure) {
                      Logger.error(
                          '[PRODUCT_DETAIL] Failed to load vendor products',
                          failure);
                    },
                    (vendorProducts) {
                      // Filter for products from the same vendor
                      final sameVendorProducts = vendorProducts
                          .where((p) =>
                              p.vendorId == product.vendorId &&
                              p.id != product.id)
                          .take(10)
                          .toList();

                      if (sameVendorProducts.isNotEmpty) {
                        setState(() {
                          _relatedProducts = sameVendorProducts;
                        });
                        Logger.data(
                            '[PRODUCT_DETAIL] Loaded ${sameVendorProducts.length} products from the same vendor');
                      }
                    },
                  );
                });
              }
            },
          );

          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      Logger.error('Error loading product details', e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'An unexpected error occurred';
        });
      }
    }
  }

  // Parse the product response JSON to extract store and vendor information
  void _parseProductResponse(String jsonString) {
    try {
      final Map<String, dynamic> responseData = jsonDecode(jsonString);
      Logger.data('[PRODUCT_DETAIL] Parsing product response JSON');

      if (responseData.containsKey('data') &&
          responseData['data'] is Map<String, dynamic> &&
          responseData['data'].containsKey('dashboard') &&
          responseData['data']['dashboard'] is Map<String, dynamic>) {
        final dashboard =
            responseData['data']['dashboard'] as Map<String, dynamic>;

        // Extract store information
        if (dashboard.containsKey('store') &&
            dashboard['store'] is Map<String, dynamic>) {
          final store = dashboard['store'] as Map<String, dynamic>;

          _storeName = store['storeName'] as String?;
          _storeDescription = store['storeDescription'] as String?;
          _storeHandle = store['storeHandle'] as String?;
          _storeOpen = store['storeOpen'] as bool? ?? false;

          // Extract location if available
          if (store.containsKey('location') &&
              store['location'] is Map<String, dynamic>) {
            final location = store['location'] as Map<String, dynamic>;
            _storeLatitude = location['latitude'] as double?;
            _storeLongitude = location['longitude'] as double?;
          }

          Logger.data(
              '[PRODUCT_DETAIL] Extracted store info - Name: $_storeName, Open: $_storeOpen, Location: ($_storeLatitude, $_storeLongitude)');
        }

        // Extract vendor information
        if (dashboard.containsKey('vendor') &&
            dashboard['vendor'] is Map<String, dynamic>) {
          final vendor = dashboard['vendor'] as Map<String, dynamic>;

          final memberId = vendor['memberID'] as String?;
          _vendorFirstName = vendor['firstname'] as String?;
          _vendorLastName = vendor['lastname'] as String?;
          final memberHandle = vendor['memberHandle'] as String?;
          _vendorBio = vendor['vendorBio'] as String?;
          final vendorProfilePictureUrl =
              vendor['profilePictureUrl'] as String?;

          Logger.data(
              '[PRODUCT_DETAIL] Extracted vendor info - Name: $_vendorFirstName $_vendorLastName, Bio: $_vendorBio');

          // Create a Vendor object with the extracted information
          if (_product != null) {
            _vendor = Vendor(
              id: _product!.vendorId,
              memberId: memberId ?? '',
              businessName: _storeName ?? 'Store',
              description:
                  _storeDescription ?? _vendorBio ?? 'No description available',
              email: '',
              phone: '',
              profileImageUrl: vendorProfilePictureUrl,
              bannerImageUrl: null,
              rating: 0.0,
              ratingCount: 0,
              isActive: _storeOpen,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        }
      }
    } catch (e) {
      Logger.error('[PRODUCT_DETAIL] Error parsing product response JSON', e);
    }
  }

  Widget _buildImageGallery() {
    if (_product == null || _product!.imageUrls.isEmpty) {
      return Container(
        height: 300,
        color: AppColors.textGray.withOpacity(0.3),
        child: Center(
          child: Icon(
            Icons.image,
            size: 64,
            color: AppColors.textGray,
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Image display
        SizedBox(
          height: 300,
          child: PageView.builder(
            itemCount: _product!.imageUrls.length,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Image.network(
                _product!.imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  Logger.error('Error loading product image', error);
                  return Container(
                    color: AppColors.textGray.withOpacity(0.3),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: AppColors.textGray,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Image indicators
        if (_product!.imageUrls.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _product!.imageUrls.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index == _currentImageIndex
                        ? AppColors.primary
                        : AppColors.textGray.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVendorCard() {
    if (_vendor == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          // Store information section
          InkWell(
            onTap: _isCurrentUserVendor ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StoreInformationScreen(
                    storeId: _vendor!.id,
                    isOwner: false,
                  ),
                ),
              );
            } : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Store image
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.textGray.withOpacity(0.3),
                    backgroundImage: _vendor!.profileImageUrl != null
                        ? NetworkImage(_vendor!.profileImageUrl!)
                        : null,
                    child: _vendor!.profileImageUrl == null
                        ? const Icon(Icons.store)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  // Store info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Store',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _storeOpen 
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 8,
                                    color: _storeOpen 
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _storeOpen ? 'Open' : 'Closed',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _storeOpen 
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _vendor!.businessName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon (only for vendors)
                  if (_isCurrentUserVendor)
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textGray,
                    ),
                ],
              ),
            ),
          ),
          // Divider
          const Divider(height: 1),
          // Store and vendor information
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store section
                Row(
                  children: [
                    const Icon(
                      Icons.store,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Store Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_storeDescription != null && _storeDescription!.isNotEmpty)
                  Text(
                    _storeDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (_vendor!.description.isNotEmpty)
                  Text(
                    _vendor!.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (_storeHandle != null && _storeHandle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Store Handle: $_storeHandle',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (_storeLatitude != null && _storeLongitude != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Location: ${_storeLatitude!.toStringAsFixed(4)}, ${_storeLongitude!.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),

                // Vendor section
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Vendor Information',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_vendorFirstName != null && _vendorLastName != null)
                  Text(
                    'Name: $_vendorFirstName $_vendorLastName',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  'Member ID: ${_vendor!.memberId}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_vendorBio != null && _vendorBio!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Bio: $_vendorBio',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                if (_isCurrentUserVendor) // Only show the button for vendors
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoreInformationScreen(
                              storeId: _vendor!.id,
                              isOwner: false,
                            ),
                          ),
                        );
                      },
                      child: const Text('View Store'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts() {
    if (_relatedProducts.isEmpty) return const SizedBox.shrink();

    // Filter products by same store if possible
    List<Product> sameStoreProducts = [];
    List<Product> otherProducts = [];

    if (_product != null && _vendor != null) {
      // Find products from the same store
      sameStoreProducts = _relatedProducts
          .where((p) => p.vendorId == _product!.vendorId)
          .toList();

      // Find products from different stores
      otherProducts = _relatedProducts
          .where((p) => p.vendorId != _product!.vendorId)
          .toList();
    } else {
      // If we don't have vendor info, just use all related products
      otherProducts = _relatedProducts;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Products from the same store
        if (sameStoreProducts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'More from ${_vendor?.businessName ?? 'this store'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildProductsList(sameStoreProducts),
          const SizedBox(height: 16),
        ],

        // Products from other stores
        if (otherProducts.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Similar Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildProductsList(otherProducts),
        ],
      ],
    );
  }

  Widget _buildProductsList(List<Product> products) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return SizedBox(
            width: 140,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/product-detail',
                    arguments: {
                      'productId': product.id,
                    },
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    AspectRatio(
                      aspectRatio: 1,
                      child: product.imageUrls.isNotEmpty
                          ? Image.network(
                              product.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: AppColors.textGray.withOpacity(0.3),
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: AppColors.textGray,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: AppColors.textGray.withOpacity(0.3),
                              child: Icon(
                                Icons.image,
                                color: AppColors.textGray,
                              ),
                            ),
                    ),
                    // Product info
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.formattedPrice,
                            style: const TextStyle(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: InlineLoadingAnimation(size: 80),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadProductDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_product == null) {
      return const Scaffold(
        body: Center(
          child: Text('Product not found'),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildImageGallery(),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _product!.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _product!.description,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                // Vendor card
                _buildVendorCard(),
                // Related products
                _buildRelatedProducts(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
