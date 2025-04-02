import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/product.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';

/// A service class for handling marketplace product operations.
class MarketplaceProductService {
  final MarketplaceRepository _marketplaceRepository;

  MarketplaceProductService(this._marketplaceRepository);

  /// Loads products from the marketplace repository.
  ///
  /// If [vendorId] and [filterOwnProducts] are provided, products from the specified vendor
  /// will be filtered out from the results.
  Future<void> loadProducts({
    required Function(bool) onLoadingStateChanged,
    required Function(List<Product>) onProductsLoaded,
    required Function(String) onError,
    String? vendorId,
    bool filterOwnProducts = false,
    double? latitude,
    double? longitude,
    String query = 'a', // Default search with "a" to get products
  }) async {
    onLoadingStateChanged(true);

    try {
      final result = await _marketplaceRepository.searchProducts(
        query,
        latitude: latitude,
        longitude: longitude,
      );

      result.fold(
        (failure) {
          onError(failure.message ?? 'Failed to load products');
          onLoadingStateChanged(false);
        },
        (products) {
          // If user is a vendor in browse mode, filter out their own products
          List<Product> filteredProducts = products;
          if (filterOwnProducts && vendorId != null) {
            Logger.data('[MARKETPLACE] Filtering out vendor\'s own products. Vendor ID: $vendorId');
            filteredProducts = products.where((product) => product.vendorId != vendorId).toList();
            Logger.data('[MARKETPLACE] Filtered ${products.length - filteredProducts.length} products');
          }
          
          onProductsLoaded(filteredProducts);
          onLoadingStateChanged(false);
        },
      );
    } catch (e) {
      onError('An unexpected error occurred: $e');
      onLoadingStateChanged(false);
    }
  }

  /// Searches for products in the marketplace.
  ///
  /// If [vendorId] and [filterOwnProducts] are provided, products from the specified vendor
  /// will be filtered out from the results.
  Future<void> searchProducts({
    required String query,
    required Function(bool) onLoadingStateChanged,
    required Function(List<Product>) onProductsLoaded,
    required Function(String) onError,
    String? vendorId,
    bool filterOwnProducts = false,
    double? latitude,
    double? longitude,
  }) async {
    if (query.isEmpty) {
      query = 'a'; // Default search with "a" to get products
    }
    
    await loadProducts(
      onLoadingStateChanged: onLoadingStateChanged,
      onProductsLoaded: onProductsLoaded,
      onError: onError,
      vendorId: vendorId,
      filterOwnProducts: filterOwnProducts,
      latitude: latitude,
      longitude: longitude,
      query: query,
    );
  }
}
