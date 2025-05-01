import 'package:vimbisopay_app/domain/entities/base_entity.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/store.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/vendor.dart';

/// Represents a product in the marketplace.
///
/// A product is an item or service that can be purchased in the marketplace.
/// Products are associated with vendors and can have various attributes like
/// price, description, and images.
/// 
/// Each product is linked to an internal account of type PRODUCTION for inventory tracking.
class Product extends Entity {
  /// The unique identifier for the product.
  @override
  final String id;

  /// The vendor ID associated with this product.
  final String vendorId;

  /// The name of the product.
  final String name;

  /// A detailed description of the product.
  final String description;

  /// The price of the product in the smallest currency unit (e.g., cents).
  final int price;

  /// The currency code for the price (e.g., USD, EUR).
  final String currency;

  /// URLs to product images.
  final List<String> imageUrls;

  /// Whether the product is currently available.
  final bool isAvailable;
  
  /// The ID of the internal account associated with this product.
  final String? accountId;
  
  /// The name of the store selling this product.
  final String? storeName;
  
  /// The store information for this product.
  final Store? store;
  
  /// The vendor information for this product.
  final Vendor? vendor;

  /// The date when the product was created.
  final DateTime createdAt;

  /// The date when the product was last updated.
  final DateTime updatedAt;

  /// Creates a new [Product] instance.
  Product({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.price,
    required this.currency,
    required this.imageUrls,
    required this.isAvailable,
    this.accountId,
    this.storeName,
    this.store,
    this.vendor,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  /// Creates a [Product] from a JSON map.
  factory Product.fromJson(Map<String, dynamic> json) {
    // Extract store data if available
    Store? store;
    if (json.containsKey('store') && json['store'] is Map<String, dynamic>) {
      store = Store.fromJson(json['store'] as Map<String, dynamic>);
    }
    
    // Extract vendor data if available
    Vendor? vendor;
    if (json.containsKey('vendor') && json['vendor'] is Map<String, dynamic>) {
      vendor = Vendor.fromJson(json['vendor'] as Map<String, dynamic>);
    }
    
    return Product(
      id: json['id'],
      vendorId: json['vendor_id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      currency: json['currency'],
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      isAvailable: json['is_available'],
      accountId: json['account_id'],
      storeName: json['store_name'],
      store: store,
      vendor: vendor,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Converts this [Product] to a JSON map.
  Map<String, dynamic> toJson() {
    final json = {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'image_urls': imageUrls,
      'is_available': isAvailable,
      'account_id': accountId,
      'store_name': storeName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
    
    // Add store and vendor if available
    if (store != null) {
      json['store'] = store!.toJson();
    }
    
    if (vendor != null) {
      json['vendor'] = vendor!.toJson();
    }
    
    return json;
  }

  /// Returns the formatted price with currency symbol.
  String get formattedPrice {
    // Simple formatting for common currencies
    String symbol = '';
    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      default:
        return '$currency ${price / 100}';
    }
    return '$symbol${price / 100}';
  }

  /// Creates a copy of this [Product] with the given fields replaced.
  Product copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    int? price,
    String? currency,
    List<String>? imageUrls,
    bool? isAvailable,
    String? accountId,
    String? storeName,
    Store? store,
    Vendor? vendor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Product(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      imageUrls: imageUrls ?? this.imageUrls,
      isAvailable: isAvailable ?? this.isAvailable,
      accountId: accountId ?? this.accountId,
      storeName: storeName ?? this.storeName,
      store: store ?? this.store,
      vendor: vendor ?? this.vendor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Product &&
        other.id == id &&
        other.vendorId == vendorId &&
        other.name == name &&
        other.description == description &&
        other.price == price &&
        other.currency == currency &&
        other.isAvailable == isAvailable;
  }

  @override
  int get hashCode => Object.hash(
        id,
        vendorId,
        name,
        description,
        price,
        currency,
        isAvailable,
      );
}
