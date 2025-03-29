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
import 'package:vimbisopay_app/presentation/screens/marketplace/edit_vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/add_edit_sku_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

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
  bool _isLoading = true;
  String _errorMessage = '';
  Vendor? _vendor;
  List<Product> _products = [];
  User? _currentUser;
  String? _profileThumbnailUrl;

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('VendorProfileScreen initialized');
    _loadVendorData();
    
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
        if (_currentUser != null && _currentUser!.dashboard != null) {
          _profileThumbnailUrl = _currentUser!.dashboard!.member.profilePictureThumbnail;
          Logger.data('[VENDOR_PROFILE] User profile thumbnail URL: $_profileThumbnailUrl');
          
          // Additional logging to help debug profile image issues
          if (_profileThumbnailUrl == null || _profileThumbnailUrl!.isEmpty) {
            Logger.data('[VENDOR_PROFILE] Profile thumbnail URL is null or empty');
          } else {
            Logger.data('[VENDOR_PROFILE] Profile thumbnail URL is available: $_profileThumbnailUrl');
          }
        } else {
          Logger.data('[VENDOR_PROFILE] User or dashboard is null, cannot get profile thumbnail');
        }
      } catch (e) {
        Logger.error('[VENDOR_PROFILE] Error loading user data', e);
        // Continue even if user data loading fails
      }

      // Load vendor data
      final vendorResult = await _marketplaceRepository.getVendor(widget.vendorId);
      
      vendorResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load vendor data';
          });
        },
        (vendor) async {
          List<Product> allProducts = [];
          
          // Load vendor's products from marketplace repository
          final productsResult = await _marketplaceRepository.getProductsByVendor(vendor.id);
          
          productsResult.fold(
            (failure) {
              Logger.error('Failed to load vendor products', failure);
              // Continue with empty products list
            },
            (products) {
              allProducts.addAll(products);
            },
          );
          
          // Load internal accounts of type PRODUCTION from user's dashboard
          if (_currentUser != null && 
              _currentUser!.dashboard != null && 
              widget.isOwner) {
            
            final dashboard = _currentUser!.dashboard!;
            final productionAccounts = dashboard.accountsInternal
                .where((account) => account.accountType == 'PHYSICAL_ASSET')
                .toList();
            
            Logger.data('[VENDOR_PROFILE] Found ${productionAccounts.length} PRODUCTION accounts');
            
            // Convert internal accounts to Product objects
            final internalProducts = productionAccounts.map((account) {
              // Create image URLs list with profile picture thumbnail if available
              List<String> imageUrls = [];
              if (account.profilePictureThumbnail != null && account.profilePictureThumbnail!.isNotEmpty) {
                Logger.data('[VENDOR_PROFILE] Adding profile picture thumbnail to product: ${account.profilePictureThumbnail}');
                imageUrls.add(account.profilePictureThumbnail!);
              } else {
                Logger.data('[VENDOR_PROFILE] No profile picture thumbnail available for account: ${account.accountID}');
              }
              
              // Create a Product from the internal account
              return Product(
                id: account.accountID,
                vendorId: vendor.id,
                name: account.accountName,
                description: 'Internal production account',
                price: 0, // Default price, would need to be updated from account balance
                currency: 'CXX', // Default currency
                imageUrls: imageUrls, // Include profile picture thumbnail if available
                category: 'Internal',
                tags: ['internal', 'production'],
                isAvailable: true,
                accountId: account.accountID,
                createdAt: DateTime.now(), // We don't have creation date
                updatedAt: DateTime.now(), // We don't have update date
              );
            }).toList();
            
            // Add internal products to the list
            allProducts.addAll(internalProducts);
          }
          
          setState(() {
            _isLoading = false;
            _vendor = vendor;
            _products = allProducts;
          });
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
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? _buildErrorView()
              : _buildVendorProfile(),
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
                icon: const Icon(Icons.point_of_sale),
                tooltip: 'New Sale',
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/vendor-sales-tab',
                    arguments: {
                      'vendorId': widget.vendorId,
                    },
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
                            category: productMap['category'],
                            tags: List<String>.from(productMap['tags']),
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
                            category: productMap['category'],
                            tags: List<String>.from(productMap['tags']),
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
          child: const Center(child: CircularProgressIndicator()),
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
