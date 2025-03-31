import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/product.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/location_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

class SearchResultsScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;
  final String? vendorId;
  final bool filterOwnProducts;

  const SearchResultsScreen({
    super.key,
    this.initialQuery,
    this.initialCategory,
    this.vendorId,
    this.filterOwnProducts = false,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  final LocationService _locationService = ServiceLocator.locationService;
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  String _errorMessage = '';
  List<Product> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  double? _latitude;
  double? _longitude;
  
  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    _selectedCategory = widget.initialCategory;
    _getCurrentLocation().then((_) {
      _loadProducts();
    });
  }
  
  /// Gets the current location if available.
  Future<void> _getCurrentLocation() async {
    try {
      Logger.data('[SEARCH_RESULTS] Getting current location');
      
      // Check if permission is already granted
      bool hasPermission = await _locationService.checkLocationPermission();
      if (!hasPermission) {
        Logger.data('[SEARCH_RESULTS] Location permission not granted');
        return;
      }
      
      final position = await _locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
        });
        Logger.data('[SEARCH_RESULTS] Got location: (${position.latitude}, ${position.longitude})');
      } else {
        Logger.error('[SEARCH_RESULTS] Failed to get location');
      }
    } catch (e) {
      Logger.error('[SEARCH_RESULTS] Error getting current location', e);
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // If we have a selected category, use getProductsByCategory
      // Otherwise use searchProducts with location data if available
      final result = _selectedCategory != null
          ? await _marketplaceRepository.getProductsByCategory(_selectedCategory!)
          : await _marketplaceRepository.searchProducts(
              _searchController.text,
              latitude: _latitude,
              longitude: _longitude,
            );

      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load products';
          });
        },
        (products) {
          // Filter out vendor's own products if needed
          List<Product> filteredProducts = products;
          if (widget.filterOwnProducts && widget.vendorId != null) {
            Logger.data('[SEARCH_RESULTS] Filtering out vendor\'s own products. Vendor ID: ${widget.vendorId}');
            filteredProducts = products.where((product) => product.vendorId != widget.vendorId).toList();
            Logger.data('[SEARCH_RESULTS] Filtered ${products.length - filteredProducts.length} products');
          }
          
          // Extract unique categories
          final categories = filteredProducts
              .map((p) => p.category)
              .toSet()
              .toList()
            ..sort();

          setState(() {
            _isLoading = false;
            _products = filteredProducts;
            _categories = categories;
          });
        },
      );
    } catch (e) {
      Logger.error('[SEARCH_RESULTS] Error loading products', e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred';
      });
    }
  }

  void _selectCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
    _loadProducts();
  }

  void _onSearch(String query) {
    setState(() {
      _selectedCategory = null; // Clear category when searching
    });
    _loadProducts();
  }

  Widget _buildProductCard(Product product) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
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
                                ? AppColors.success
                                : AppColors.error,
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
                                    ? AppColors.success
                                    : AppColors.error,
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

  Widget _buildProductImage(Product product) {
    if (product.imageUrls.isEmpty) {
      return Container(
        color: AppColors.textGray.withOpacity(0.3),
        child: Center(
          child: Icon(
            Icons.image,
            color: AppColors.textGray,
          ),
        ),
      );
    }

    return Image.network(
      product.imageUrls.first,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        Logger.error('Error loading product image', error);
        return Container(
          color: AppColors.textGray.withOpacity(0.3),
          child: Center(
            child: Icon(
              Icons.image_not_supported,
              color: AppColors.textGray,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Results'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search products...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onSubmitted: _onSearch,
              ),
            ),
            
            // Category filter
            if (_categories.isNotEmpty)
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: const Text('All'),
                        selected: _selectedCategory == null,
                        onSelected: (selected) {
                          if (selected) {
                            _selectCategory(null);
                          }
                        },
                      ),
                    ),
                    ..._categories.map((category) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _selectedCategory == category,
                          onSelected: (selected) {
                            if (selected) {
                              _selectCategory(category);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            
            // Loading indicator or error message
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              Expanded(
                child: Center(
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
                        onPressed: _loadProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            // Product grid
            else if (_products.isNotEmpty)
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16.0),
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
                ),
              )
            // Empty state
            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Try a different search or category',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textSecondary,
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
