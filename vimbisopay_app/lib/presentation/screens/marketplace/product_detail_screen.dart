import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/product.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/vendor.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

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
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  
  bool _isLoading = true;
  String _errorMessage = '';
  Product? _product;
  Vendor? _vendor;
  List<Product> _relatedProducts = [];
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Load product details
      final productResult = await _marketplaceRepository.getProduct(widget.productId);
      
      await productResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load product';
          });
        },
        (product) async {
          _product = product;
          
          // Load vendor details
          // final vendorResult = await _marketplaceRepository.getVendor(product.vendorId);
          
          // vendorResult.fold(
          //   (failure) {
          //     Logger.error('Failed to load vendor', failure);
          //   },
          //   (vendor) {
          //     _vendor = vendor;
          //   },
          // );
          
          // Load related products (same category)
          final relatedResult = await _marketplaceRepository.getProductsByCategory(product.category);
          
          relatedResult.fold(
            (failure) {
              Logger.error('Failed to load related products', failure);
            },
            (products) {
              // Filter out current product and limit to 10 related products
              _relatedProducts = products
                  .where((p) => p.id != product.id)
                  .take(10)
                  .toList();
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
      margin: const EdgeInsets.all(16),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/vendor-profile',
            arguments: {
              'vendorId': _vendor!.id,
              'isOwner': false,
            },
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Vendor image
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
              // Vendor info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _vendor!.businessName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _vendor!.ratingDisplay,
                      style: TextStyle(
                        color: AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              const Icon(
                Icons.chevron_right,
                color: AppColors.textGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRelatedProducts() {
    if (_relatedProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Related Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              final product = _relatedProducts[index];
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
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
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
                      Text(
                        _product!.formattedPrice,
                        style: const TextStyle(
                          fontSize: 20,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _product!.description,
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Availability
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _product!.isAvailable
                              ? AppColors.success.withOpacity(0.1)
                              : AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _product!.isAvailable
                                  ? Icons.check_circle
                                  : Icons.cancel,
                              size: 16,
                              color: _product!.isAvailable
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _product!.isAvailable
                                  ? 'Available'
                                  : 'Unavailable',
                              style: TextStyle(
                                color: _product!.isAvailable
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
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
