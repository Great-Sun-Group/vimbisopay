import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:vimbisopay_app/core/error/exceptions.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';

/// Implementation of the [MarketplaceRepository] interface.
///
/// This implementation handles API communication and data transformation
/// for marketplace operations. Currently uses mock data for testing.
class MarketplaceRepositoryImpl implements MarketplaceRepository {
  final http.Client _httpClient;
  final String _baseUrl;

  /// Creates a new [MarketplaceRepositoryImpl] instance.
  ///
  /// Requires an HTTP client for API communication and a base URL for the API.
  MarketplaceRepositoryImpl({
    required http.Client httpClient,
    required String baseUrl,
  })  : _httpClient = httpClient,
        _baseUrl = baseUrl;

  /// Mock vendors for testing.
  final List<Vendor> _mockVendors = [
    Vendor(
      id: 'v1',
      memberId: 'm1',
      businessName: 'Tech Gadgets',
      description: 'The latest tech gadgets at affordable prices.',
      email: 'contact@techgadgets.com',
      phone: '+1234567890',
      profileImageUrl: 'https://example.com/vendor1.jpg',
      bannerImageUrl: 'https://example.com/banner1.jpg',
      rating: 4.5,
      ratingCount: 42,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Vendor(
      id: 'v2',
      memberId: 'm2',
      businessName: 'Handmade Crafts',
      description: 'Unique handmade crafts for your home.',
      email: 'info@handmadecrafts.com',
      phone: '+1987654321',
      profileImageUrl: 'https://example.com/vendor2.jpg',
      bannerImageUrl: 'https://example.com/banner2.jpg',
      rating: 4.8,
      ratingCount: 36,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  /// Mock products for testing.
  final List<Product> _mockProducts = [
    Product(
      id: 'p1',
      vendorId: 'v1',
      name: 'Wireless Earbuds',
      description: 'High-quality wireless earbuds with noise cancellation.',
      price: 9999, // $99.99
      currency: 'USD',
      imageUrls: [
        'https://example.com/earbuds1.jpg',
        'https://example.com/earbuds2.jpg',
      ],
      category: 'Electronics',
      tags: ['audio', 'wireless', 'earbuds'],
      isAvailable: true,
      inventory: 50,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Product(
      id: 'p2',
      vendorId: 'v1',
      name: 'Smart Watch',
      description: 'Feature-packed smart watch with health tracking.',
      price: 14999, // $149.99
      currency: 'USD',
      imageUrls: [
        'https://example.com/watch1.jpg',
        'https://example.com/watch2.jpg',
      ],
      category: 'Electronics',
      tags: ['wearable', 'smart watch', 'fitness'],
      isAvailable: true,
      inventory: 25,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Product(
      id: 'p3',
      vendorId: 'v2',
      name: 'Handmade Vase',
      description: 'Beautiful handmade ceramic vase for your home.',
      price: 3999, // $39.99
      currency: 'USD',
      imageUrls: [
        'https://example.com/vase1.jpg',
        'https://example.com/vase2.jpg',
      ],
      category: 'Home Decor',
      tags: ['handmade', 'ceramic', 'vase'],
      isAvailable: true,
      inventory: 10,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  /// Mock invoices for testing.
  final List<Invoice> _mockInvoices = [
    Invoice(
      id: 'i1',
      buyerId: 'm3',
      vendorId: 'v1',
      lineItems: [
        InvoiceLineItem(
          productId: 'p1',
          productName: 'Wireless Earbuds',
          quantity: 1,
          unitPrice: 9999,
          totalPrice: 9999,
        ),
      ],
      totalAmount: 9999,
      currency: 'USD',
      status: InvoiceStatus.paid,
      paymentMethod: 'credex',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      paidAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Invoice(
      id: 'i2',
      buyerId: 'm4',
      vendorId: 'v2',
      lineItems: [
        InvoiceLineItem(
          productId: 'p3',
          productName: 'Handmade Vase',
          quantity: 2,
          unitPrice: 3999,
          totalPrice: 7998,
        ),
      ],
      totalAmount: 7998,
      currency: 'USD',
      status: InvoiceStatus.pending,
      paymentMethod: 'credex',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];

  /// Mock asset markers for testing.
  final List<AssetMarker> _mockAssetMarkers = [
    AssetMarker(
      id: 'a1',
      productId: 'p1',
      ownerId: 'm3',
      creatorId: 'v1',
      quantity: 1,
      status: AssetMarkerStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
      lastTransferredAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    AssetMarker(
      id: 'a2',
      productId: 'p3',
      ownerId: 'v2',
      creatorId: 'v2',
      quantity: 10,
      status: AssetMarkerStatus.active,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
  ];

  @override
  Future<Either<Failure, Vendor>> getVendor(String id) async {
    try {
      Logger.data('Getting vendor with ID: $id');
      
      // Mock implementation
      final vendor = _mockVendors.firstWhere(
        (v) => v.id == id,
        orElse: () => throw NotFoundException('Vendor not found'),
      );
      
      return Right(vendor);
    } on NotFoundException catch (e) {
      Logger.error('Vendor not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting vendor', e);
      return Left(ServerFailure('Failed to get vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Vendor>> getVendorByMemberId(String memberId) async {
    try {
      Logger.data('Getting vendor by member ID: $memberId');
      
      // Mock implementation
      final vendor = _mockVendors.firstWhere(
        (v) => v.memberId == memberId,
        orElse: () => throw NotFoundException('Vendor not found for member'),
      );
      
      return Right(vendor);
    } on NotFoundException catch (e) {
      Logger.error('Vendor not found for member', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting vendor by member ID', e);
      return Left(ServerFailure('Failed to get vendor by member ID: $e'));
    }
  }
  
  @override
  Future<bool> isMemberVendor(String memberId) async {
    try {
      Logger.data('Checking if member is a vendor: $memberId');
      
      // Mock implementation
      final vendor = _mockVendors.firstWhere(
        (v) => v.memberId == memberId,
        orElse: () => throw NotFoundException('Vendor not found for member'),
      );
      
      // If we found a vendor, the member is a vendor
      return true;
    } catch (e) {
      // If we get here, the member is not a vendor
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
    try {
      Logger.data('Creating vendor for member ID: $memberId');
      
      // Mock implementation
      final newVendor = Vendor(
        id: 'v${_mockVendors.length + 1}',
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
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _mockVendors.add(newVendor);
      
      return Right(newVendor);
    } catch (e) {
      Logger.error('Error creating vendor', e);
      return Left(ServerFailure('Failed to create vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Vendor>> updateVendor({
    required String id,
    String? businessName,
    String? description,
    String? email,
    String? phone,
    String? profileImageUrl,
    String? bannerImageUrl,
    bool? isActive,
  }) async {
    try {
      Logger.data('Updating vendor with ID: $id');
      
      // Find the vendor
      final vendorIndex = _mockVendors.indexWhere((v) => v.id == id);
      if (vendorIndex == -1) {
        throw NotFoundException('Vendor not found');
      }
      
      // Get the existing vendor
      final existingVendor = _mockVendors[vendorIndex];
      
      // Create updated vendor
      final updatedVendor = existingVendor.copyWith(
        businessName: businessName,
        description: description,
        email: email,
        phone: phone,
        profileImageUrl: profileImageUrl,
        bannerImageUrl: bannerImageUrl,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      
      // Update the vendor in the list
      _mockVendors[vendorIndex] = updatedVendor;
      
      return Right(updatedVendor);
    } on NotFoundException catch (e) {
      Logger.error('Vendor not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating vendor', e);
      return Left(ServerFailure('Failed to update vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, Product>> getProduct(String id) async {
    try {
      Logger.data('Getting product with ID: $id');
      
      // Mock implementation
      final product = _mockProducts.firstWhere(
        (p) => p.id == id,
        orElse: () => throw NotFoundException('Product not found'),
      );
      
      return Right(product);
    } on NotFoundException catch (e) {
      Logger.error('Product not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting product', e);
      return Left(ServerFailure('Failed to get product: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByVendor(String vendorId) async {
    try {
      Logger.data('Getting products for vendor ID: $vendorId');
      
      // Mock implementation
      final products = _mockProducts.where((p) => p.vendorId == vendorId).toList();
      
      return Right(products);
    } catch (e) {
      Logger.error('Error getting products by vendor', e);
      return Left(ServerFailure('Failed to get products by vendor: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> getProductsByCategory(String category) async {
    try {
      Logger.data('Getting products for category: $category');
      
      // Mock implementation
      final products = _mockProducts.where((p) => p.category == category).toList();
      
      return Right(products);
    } catch (e) {
      Logger.error('Error getting products by category', e);
      return Left(ServerFailure('Failed to get products by category: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Product>>> searchProducts(String query) async {
    try {
      Logger.data('Searching products with query: $query');
      
      // Mock implementation
      final lowercaseQuery = query.toLowerCase();
      final products = _mockProducts.where((p) {
        return p.name.toLowerCase().contains(lowercaseQuery) ||
            p.description.toLowerCase().contains(lowercaseQuery) ||
            p.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
      }).toList();
      
      return Right(products);
    } catch (e) {
      Logger.error('Error searching products', e);
      return Left(ServerFailure('Failed to search products: $e'));
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
    int? inventory,
  }) async {
    try {
      Logger.data('Creating product for vendor ID: $vendorId');
      
      // Mock implementation
      final newProduct = Product(
        id: 'p${_mockProducts.length + 1}',
        vendorId: vendorId,
        name: name,
        description: description,
        price: price,
        currency: currency,
        imageUrls: imageUrls,
        category: category,
        tags: tags,
        isAvailable: isAvailable,
        inventory: inventory,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _mockProducts.add(newProduct);
      
      return Right(newProduct);
    } catch (e) {
      Logger.error('Error creating product', e);
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
    int? inventory,
  }) async {
    try {
      Logger.data('Updating product with ID: $id');
      
      // Find the product
      final productIndex = _mockProducts.indexWhere((p) => p.id == id);
      if (productIndex == -1) {
        throw NotFoundException('Product not found');
      }
      
      // Get the existing product
      final existingProduct = _mockProducts[productIndex];
      
      // Create updated product
      final updatedProduct = existingProduct.copyWith(
        name: name,
        description: description,
        price: price,
        currency: currency,
        imageUrls: imageUrls,
        category: category,
        tags: tags,
        isAvailable: isAvailable,
        inventory: inventory,
        updatedAt: DateTime.now(),
      );
      
      // Update the product in the list
      _mockProducts[productIndex] = updatedProduct;
      
      return Right(updatedProduct);
    } on NotFoundException catch (e) {
      Logger.error('Product not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating product', e);
      return Left(ServerFailure('Failed to update product: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> getInvoice(String id) async {
    try {
      Logger.data('Getting invoice with ID: $id');
      
      // Mock implementation
      final invoice = _mockInvoices.firstWhere(
        (i) => i.id == id,
        orElse: () => throw NotFoundException('Invoice not found'),
      );
      
      return Right(invoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting invoice', e);
      return Left(ServerFailure('Failed to get invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByBuyer(String buyerId) async {
    try {
      Logger.data('Getting invoices for buyer ID: $buyerId');
      
      // Mock implementation
      final invoices = _mockInvoices.where((i) => i.buyerId == buyerId).toList();
      
      return Right(invoices);
    } catch (e) {
      Logger.error('Error getting invoices by buyer', e);
      return Left(ServerFailure('Failed to get invoices by buyer: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoicesByVendor(String vendorId) async {
    try {
      Logger.data('Getting invoices for vendor ID: $vendorId');
      
      // Mock implementation
      final invoices = _mockInvoices.where((i) => i.vendorId == vendorId).toList();
      
      return Right(invoices);
    } catch (e) {
      Logger.error('Error getting invoices by vendor', e);
      return Left(ServerFailure('Failed to get invoices by vendor: $e'));
    }
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
    try {
      Logger.data('Creating invoice for buyer ID: $buyerId and vendor ID: $vendorId');
      
      // Mock implementation
      final newInvoice = Invoice(
        id: 'i${_mockInvoices.length + 1}',
        buyerId: buyerId,
        vendorId: vendorId,
        lineItems: lineItems,
        totalAmount: totalAmount,
        currency: currency,
        status: InvoiceStatus.pending,
        paymentMethod: paymentMethod,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _mockInvoices.add(newInvoice);
      
      return Right(newInvoice);
    } catch (e) {
      Logger.error('Error creating invoice', e);
      return Left(ServerFailure('Failed to create invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice({
    required String id,
    InvoiceStatus? status,
    String? notes,
    DateTime? paidAt,
  }) async {
    try {
      Logger.data('Updating invoice with ID: $id');
      
      // Find the invoice
      final invoiceIndex = _mockInvoices.indexWhere((i) => i.id == id);
      if (invoiceIndex == -1) {
        throw NotFoundException('Invoice not found');
      }
      
      // Get the existing invoice
      final existingInvoice = _mockInvoices[invoiceIndex];
      
      // Create updated invoice
      final updatedInvoice = existingInvoice.copyWith(
        status: status,
        notes: notes,
        paidAt: paidAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the invoice in the list
      _mockInvoices[invoiceIndex] = updatedInvoice;
      
      return Right(updatedInvoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating invoice', e);
      return Left(ServerFailure('Failed to update invoice: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> getAssetMarker(String id) async {
    try {
      Logger.data('Getting asset marker with ID: $id');
      
      // Mock implementation
      final assetMarker = _mockAssetMarkers.firstWhere(
        (a) => a.id == id,
        orElse: () => throw NotFoundException('Asset marker not found'),
      );
      
      return Right(assetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error getting asset marker', e);
      return Left(ServerFailure('Failed to get asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByProduct(String productId) async {
    try {
      Logger.data('Getting asset markers for product ID: $productId');
      
      // Mock implementation
      final assetMarkers = _mockAssetMarkers.where((a) => a.productId == productId).toList();
      
      return Right(assetMarkers);
    } catch (e) {
      Logger.error('Error getting asset markers by product', e);
      return Left(ServerFailure('Failed to get asset markers by product: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AssetMarker>>> getAssetMarkersByOwner(String ownerId) async {
    try {
      Logger.data('Getting asset markers for owner ID: $ownerId');
      
      // Mock implementation
      final assetMarkers = _mockAssetMarkers.where((a) => a.ownerId == ownerId).toList();
      
      return Right(assetMarkers);
    } catch (e) {
      Logger.error('Error getting asset markers by owner', e);
      return Left(ServerFailure('Failed to get asset markers by owner: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> createAssetMarker({
    required String productId,
    required String ownerId,
    required String creatorId,
    required int quantity,
    required AssetMarkerStatus status,
  }) async {
    try {
      Logger.data('Creating asset marker for product ID: $productId');
      
      // Mock implementation
      final newAssetMarker = AssetMarker(
        id: 'a${_mockAssetMarkers.length + 1}',
        productId: productId,
        ownerId: ownerId,
        creatorId: creatorId,
        quantity: quantity,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      _mockAssetMarkers.add(newAssetMarker);
      
      return Right(newAssetMarker);
    } catch (e) {
      Logger.error('Error creating asset marker', e);
      return Left(ServerFailure('Failed to create asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> updateAssetMarker({
    required String id,
    String? ownerId,
    int? quantity,
    AssetMarkerStatus? status,
    DateTime? lastTransferredAt,
  }) async {
    try {
      Logger.data('Updating asset marker with ID: $id');
      
      // Find the asset marker
      final assetMarkerIndex = _mockAssetMarkers.indexWhere((a) => a.id == id);
      if (assetMarkerIndex == -1) {
        throw NotFoundException('Asset marker not found');
      }
      
      // Get the existing asset marker
      final existingAssetMarker = _mockAssetMarkers[assetMarkerIndex];
      
      // Create updated asset marker
      final updatedAssetMarker = existingAssetMarker.copyWith(
        ownerId: ownerId,
        quantity: quantity,
        status: status,
        lastTransferredAt: lastTransferredAt,
        updatedAt: DateTime.now(),
      );
      
      // Update the asset marker in the list
      _mockAssetMarkers[assetMarkerIndex] = updatedAssetMarker;
      
      return Right(updatedAssetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found for update', e);
      return Left(NotFoundFailure(e.message));
    } catch (e) {
      Logger.error('Error updating asset marker', e);
      return Left(ServerFailure('Failed to update asset marker: $e'));
    }
  }

  @override
  Future<Either<Failure, AssetMarker>> transferAssetMarker({
    required String id,
    required String newOwnerId,
  }) async {
    try {
      Logger.data('Transferring asset marker with ID: $id to owner ID: $newOwnerId');
      
      // Find the asset marker
      final assetMarkerIndex = _mockAssetMarkers.indexWhere((a) => a.id == id);
      if (assetMarkerIndex == -1) {
        throw NotFoundException('Asset marker not found');
      }
      
      // Get the existing asset marker
      final existingAssetMarker = _mockAssetMarkers[assetMarkerIndex];
      
      // Check if the asset marker is transferable
      if (!existingAssetMarker.isTransferable) {
        throw const ServerException('Asset marker is not transferable');
      }
      
      // Create updated asset marker
      final updatedAssetMarker = existingAssetMarker.copyWith(
        ownerId: newOwnerId,
        lastTransferredAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Update the asset marker in the list
      _mockAssetMarkers[assetMarkerIndex] = updatedAssetMarker;
      
      return Right(updatedAssetMarker);
    } on NotFoundException catch (e) {
      Logger.error('Asset marker not found for transfer', e);
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      Logger.error('Asset marker not transferable', e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      Logger.error('Error transferring asset marker', e);
      return Left(ServerFailure('Failed to transfer asset marker: $e'));
    }
  }
}
