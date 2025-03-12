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
      description: 'The latest tech gadgets at affordable prices. We offer a curated selection of high-quality electronics and accessories.',
      email: 'contact@techgadgets.com',
      phone: '+1234567890',
      profileImageUrl: 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=800', // Modern store interior
      bannerImageUrl: 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=1600', // Tech gadgets display
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
      description: 'Unique handmade crafts for your home. Each piece is carefully crafted with attention to detail and quality materials.',
      email: 'info@handmadecrafts.com',
      phone: '+1987654321',
      profileImageUrl: 'https://images.unsplash.com/photo-1452860606245-08befc0ff44b?w=800', // Artisan workshop
      bannerImageUrl: 'https://images.unsplash.com/photo-1464316325666-63beaf639dbb?w=1600', // Handmade crafts display
      rating: 4.8,
      ratingCount: 36,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Vendor(
      id: 'v3',
      memberId: 'm3',
      businessName: 'Artisanal Delights',
      description: 'Premium artisanal food products made with the finest ingredients. From specialty coffee to handcrafted chocolates, we bring you gourmet experiences.',
      email: 'taste@artisanaldelights.com',
      phone: '+1765432109',
      profileImageUrl: 'https://images.unsplash.com/photo-1556740758-90de374c12ad?w=800', // Artisanal food shop
      bannerImageUrl: 'https://images.unsplash.com/photo-1495147466023-ac5c588e2e94?w=1600', // Gourmet food display
      rating: 4.9,
      ratingCount: 28,
      isActive: true,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Mock products for testing.
  final List<Product> _mockProducts = [
    // Tech Gadgets Store Products
    Product(
      id: 'p1',
      vendorId: 'v1',
      name: 'Wireless Earbuds Pro',
      description: 'High-quality wireless earbuds with active noise cancellation, touch controls, and premium sound quality. Perfect for music lovers and professionals.',
      price: 9999, // $99.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1590658268037-6bf12165a8df?w=800', // Earbuds in case
        'https://images.unsplash.com/photo-1631867675167-1bb40de8f57f?w=800', // Close-up of earbuds
        'https://images.unsplash.com/photo-1606220838315-056192d5e927?w=800', // Lifestyle shot
      ],
      category: 'Electronics',
      tags: ['audio', 'wireless', 'earbuds', 'noise cancellation'],
      isAvailable: true,
      inventory: 50,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Product(
      id: 'p2',
      vendorId: 'v1',
      name: 'SmartFit Watch X1',
      description: 'Advanced smartwatch with health tracking, heart rate monitoring, sleep analysis, and workout modes. Stay connected and healthy.',
      price: 14999, // $149.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1617043786394-f977fa12eddf?w=800', // Main product shot
        'https://images.unsplash.com/photo-1508685096489-7aacd43bd3b1?w=800', // On wrist
        'https://images.unsplash.com/photo-1544117519-31a4b719223d?w=800', // Features display
      ],
      category: 'Electronics',
      tags: ['wearable', 'smart watch', 'fitness', 'health'],
      isAvailable: true,
      inventory: 25,
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    // Tech Gadgets Store Products (continued)
    Product(
      id: 'p4',
      vendorId: 'v1',
      name: 'Portable Power Bank 20000mAh',
      description: 'High-capacity power bank with fast charging support, dual USB ports, and LED display. Never run out of battery again.',
      price: 4999, // $49.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1544866092-1935c5ef2a8f?w=800', // Main product shot
        'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=800', // LED display view
      ],
      category: 'Electronics',
      tags: ['power bank', 'charger', 'portable', 'accessories'],
      isAvailable: true,
      inventory: 100,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Product(
      id: 'p5',
      vendorId: 'v1',
      name: 'Wireless Charging Pad',
      description: 'Sleek wireless charging pad compatible with all Qi-enabled devices. Features LED indicator and fast charging support.',
      price: 2999, // $29.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1615526675159-e248c3021d3f?w=800', // Product shot
        'https://images.unsplash.com/photo-1612086636303-92244b5c4ccd?w=800', // In use with phone
      ],
      category: 'Electronics',
      tags: ['wireless charging', 'charger', 'accessories'],
      isAvailable: true,
      inventory: 75,
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
    
    // Handmade Crafts Store Products
    Product(
      id: 'p3',
      vendorId: 'v2',
      name: 'Artisan Ceramic Vase',
      description: 'Handcrafted ceramic vase with unique glazing pattern. Each piece is one-of-a-kind and perfect for modern home decor.',
      price: 3999, // $39.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1578500351865-d6c3706f46bc?w=800', // Main product shot
        'https://images.unsplash.com/photo-1612196808214-b8e1d6145a8c?w=800', // With flowers
        'https://images.unsplash.com/photo-1581783342308-f792d22116c7?w=800', // Detail shot
      ],
      category: 'Home Decor',
      tags: ['handmade', 'ceramic', 'vase', 'pottery'],
      isAvailable: true,
      inventory: 10,
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    Product(
      id: 'p6',
      vendorId: 'v2',
      name: 'Macrame Wall Hanging',
      description: 'Beautiful handwoven macrame wall hanging made from 100% cotton rope. Adds texture and bohemian charm to any room.',
      price: 4999, // $49.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1595408076683-5d0c866c96db?w=800', // Full view
        'https://images.unsplash.com/photo-1594040226829-7f251ab46d80?w=800', // Detail shot
      ],
      category: 'Home Decor',
      tags: ['handmade', 'macrame', 'wall decor', 'boho'],
      isAvailable: true,
      inventory: 8,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Product(
      id: 'p7',
      vendorId: 'v2',
      name: 'Handwoven Table Runner',
      description: 'Elegant table runner handwoven with natural fibers and subtle patterns. Perfect for dining table or console decoration.',
      price: 3499, // $34.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1619911013257-8f1fbc919fc9?w=800', // Full view
        'https://images.unsplash.com/photo-1619911013146-5f6e64d991d7?w=800', // Styled shot
      ],
      category: 'Home Decor',
      tags: ['handmade', 'textile', 'table decor', 'woven'],
      isAvailable: true,
      inventory: 15,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      updatedAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    Product(
      id: 'p8',
      vendorId: 'v2',
      name: 'Ceramic Plant Pots Set',
      description: 'Set of 3 handmade ceramic plant pots in varying sizes. Features drainage holes and modern minimalist design.',
      price: 5999, // $59.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=800', // Set display
        'https://images.unsplash.com/photo-1602662954993-a53d7c2f6e18?w=800', // With plants
      ],
      category: 'Home Decor',
      tags: ['handmade', 'ceramic', 'planters', 'pottery'],
      isAvailable: true,
      inventory: 12,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    
    // Fashion & Accessories
    Product(
      id: 'p9',
      vendorId: 'v2',
      name: 'Handmade Leather Wallet',
      description: 'Premium handcrafted leather wallet with multiple card slots and coin pocket. Made from genuine leather with expert stitching.',
      price: 4499, // $44.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1627123424574-724758594e93?w=800', // Main product
        'https://images.unsplash.com/photo-1627123424574-724758594e93?w=800', // Detail view
      ],
      category: 'Fashion',
      tags: ['leather', 'wallet', 'accessories', 'handmade'],
      isAvailable: true,
      inventory: 20,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Product(
      id: 'p10',
      vendorId: 'v2',
      name: 'Woven Tote Bag',
      description: 'Spacious handwoven tote bag perfect for daily use. Features strong handles and inner pocket.',
      price: 5999, // $59.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1591561954557-26941169b49e?w=800', // Full view
        'https://images.unsplash.com/photo-1591561954555-5c7a1f2e0e52?w=800', // Detail shot
      ],
      category: 'Fashion',
      tags: ['bag', 'tote', 'handwoven', 'accessories'],
      isAvailable: true,
      inventory: 15,
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
      updatedAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    
    // Food & Beverages
    Product(
      id: 'p11',
      vendorId: 'v3',
      name: 'Artisanal Coffee Beans',
      description: 'Freshly roasted specialty coffee beans with notes of chocolate and caramel. Medium roast, perfect for espresso or filter coffee.',
      price: 1899, // $18.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1587734005433-8a2fb6a6dd52?w=800', // Beans close-up
        'https://images.unsplash.com/photo-1587734005433-8a2fb6a6dd52?w=800', // Packaging
      ],
      category: 'Food & Beverages',
      tags: ['coffee', 'beans', 'artisanal', 'specialty'],
      isAvailable: true,
      inventory: 50,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Product(
      id: 'p12',
      vendorId: 'v3',
      name: 'Handmade Chocolate Box',
      description: 'Assorted artisanal chocolates in an elegant gift box. Includes dark, milk, and white chocolate varieties with unique fillings.',
      price: 2999, // $29.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=800', // Box view
        'https://images.unsplash.com/photo-1549007994-cb92caebd54b?w=800', // Chocolates detail
      ],
      category: 'Food & Beverages',
      tags: ['chocolate', 'handmade', 'gift', 'artisanal'],
      isAvailable: true,
      inventory: 30,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    Product(
      id: 'p13',
      vendorId: 'v3',
      name: 'Gourmet Spice Set',
      description: 'Collection of premium hand-blended spices in beautiful glass jars. Perfect for elevating your cooking.',
      price: 3499, // $34.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=800', // Set display
        'https://images.unsplash.com/photo-1505714197102-6ae95091ed70?w=800', // Individual jars
      ],
      category: 'Food & Beverages',
      tags: ['spices', 'gourmet', 'cooking', 'gift set'],
      isAvailable: true,
      inventory: 25,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    Product(
      id: 'p14',
      vendorId: 'v3',
      name: 'Local Honey Collection',
      description: 'Pure, raw honey sourced from local beekeepers. Set includes three varieties: wildflower, clover, and orange blossom.',
      price: 2499, // $24.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1587049352846-4a222e784d38?w=800', // Honey jars
        'https://images.unsplash.com/photo-1587049352847-de8f3b2b6154?w=800', // Dripping honey
      ],
      category: 'Food & Beverages',
      tags: ['honey', 'natural', 'local', 'organic'],
      isAvailable: true,
      inventory: 40,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    Product(
      id: 'p15',
      vendorId: 'v3',
      name: 'Artisanal Tea Collection',
      description: 'Curated selection of premium loose-leaf teas including green, black, and herbal blends. Each tin contains 50g of tea.',
      price: 3999, // $39.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1564890369478-c89ca6d9cde9?w=800', // Tea collection
        'https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=800', // Loose tea leaves
      ],
      category: 'Food & Beverages',
      tags: ['tea', 'organic', 'loose leaf', 'gift set'],
      isAvailable: true,
      inventory: 35,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      updatedAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    Product(
      id: 'p16',
      vendorId: 'v3',
      name: 'Artisanal Jam Set',
      description: 'Handcrafted fruit preserves made in small batches. Set includes strawberry, raspberry, and blueberry jams.',
      price: 2799, // $27.99
      currency: 'USD',
      imageUrls: [
        'https://images.unsplash.com/photo-1622484211817-4f764a714eee?w=800', // Jam jars
        'https://images.unsplash.com/photo-1622484211817-4f764a714eee?w=800', // Close-up of jam
      ],
      category: 'Food & Beverages',
      tags: ['jam', 'preserves', 'handmade', 'fruit'],
      isAvailable: true,
      inventory: 45,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
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
    // Additional mock invoices for the buyer workflow simulation
    Invoice(
      id: 'face-to-face-1',
      buyerId: '', // Empty because this is a face-to-face transaction where buyer isn't known yet
      vendorId: 'v1',
      lineItems: [
        InvoiceLineItem(
          productId: 'p1',
          productName: 'Wireless Earbuds',
          quantity: 1,
          unitPrice: 9999,
          totalPrice: 9999,
        ),
        InvoiceLineItem(
          productId: 'p2',
          productName: 'Smart Watch',
          quantity: 1,
          unitPrice: 14999,
          totalPrice: 14999,
        ),
      ],
      totalAmount: 24998,
      currency: 'USD',
      status: InvoiceStatus.pending,
      paymentMethod: 'credex',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      notes: 'Face-to-face transaction at Tech Gadgets store',
    ),
    Invoice(
      id: 'face-to-face-2',
      buyerId: '', // Empty because this is a face-to-face transaction where buyer isn't known yet
      vendorId: 'v2',
      lineItems: [
        InvoiceLineItem(
          productId: 'p3',
          productName: 'Handmade Vase',
          quantity: 1,
          unitPrice: 3999,
          totalPrice: 3999,
        ),
      ],
      totalAmount: 3999,
      currency: 'USD',
      status: InvoiceStatus.pending,
      paymentMethod: 'credex',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      notes: 'Face-to-face transaction at Handmade Crafts store',
    ),
    Invoice(
      id: 'face-to-face-3',
      buyerId: '', // Empty because this is a face-to-face transaction where buyer isn't known yet
      vendorId: 'v1',
      lineItems: [
        InvoiceLineItem(
          productId: 'p2',
          productName: 'Smart Watch',
          quantity: 1,
          unitPrice: 14999,
          totalPrice: 14999,
        ),
      ],
      totalAmount: 14999,
      currency: 'USD',
      status: InvoiceStatus.pending,
      paymentMethod: 'credex',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      notes: 'Face-to-face transaction at Tech Gadgets store',
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
  
  @override
  Future<Either<Failure, Invoice>> createCredexOffer({
    required String invoiceId,
    required String accountId,
    required int amount,
    String? note,
  }) async {
    try {
      Logger.data('Creating Credex offer for invoice ID: $invoiceId from account ID: $accountId');
      
      // Find the invoice
      final invoiceIndex = _mockInvoices.indexWhere((i) => i.id == invoiceId);
      if (invoiceIndex == -1) {
        throw NotFoundException('Invoice not found');
      }
      
      // Get the existing invoice
      final existingInvoice = _mockInvoices[invoiceIndex];
      
      // Check if the invoice is already paid
      if (existingInvoice.status != InvoiceStatus.pending) {
        throw const ServerException('Invoice is not in pending status');
      }
      
      // Check if the amount matches the invoice total
      if (amount != existingInvoice.totalAmount) {
        throw const ServerException('Payment amount does not match invoice total');
      }
      
      // Create updated invoice with paid status
      final updatedInvoice = existingInvoice.copyWith(
        status: InvoiceStatus.paid,
        notes: note != null ? (existingInvoice.notes != null ? '${existingInvoice.notes}\n$note' : note) : existingInvoice.notes,
        paidAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Update the invoice in the list
      _mockInvoices[invoiceIndex] = updatedInvoice;
      
      // Create asset markers for the purchased products (in a real implementation)
      // This would involve creating asset markers for each line item in the invoice
      
      return Right(updatedInvoice);
    } on NotFoundException catch (e) {
      Logger.error('Invoice not found for payment', e);
      return Left(NotFoundFailure(e.message));
    } on ServerException catch (e) {
      Logger.error('Error processing payment', e);
      return Left(ServerFailure(e.message));
    } catch (e) {
      Logger.error('Error creating Credex offer', e);
      return Left(ServerFailure('Failed to create Credex offer: $e'));
    }
  }
}
