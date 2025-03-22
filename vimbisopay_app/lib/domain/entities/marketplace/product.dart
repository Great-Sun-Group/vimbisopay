import 'package:vimbisopay_app/domain/entities/base_entity.dart';

/// Represents a product in the marketplace.
///
/// A product is an item or service that can be purchased in the marketplace.
/// Products are associated with vendors and can have various attributes like
/// price, description, and images.
class Product extends Entity {
  /// The unique identifier for the product.
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

  /// The category of the product.
  final String category;

  /// Tags associated with the product for search and filtering.
  final List<String> tags;

  /// Whether the product is currently available.
  final bool isAvailable;

  /// The quantity available in inventory, if applicable.
  final int? inventory;

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
    required this.category,
    required this.tags,
    required this.isAvailable,
    this.inventory,
    required this.createdAt,
    required this.updatedAt,
  }) : super(id);

  /// Creates a [Product] from a JSON map.
  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      vendorId: json['vendor_id'],
      name: json['name'],
      description: json['description'],
      price: json['price'],
      currency: json['currency'],
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      category: json['category'],
      tags: List<String>.from(json['tags'] ?? []),
      isAvailable: json['is_available'],
      inventory: json['inventory'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Converts this [Product] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'currency': currency,
      'image_urls': imageUrls,
      'category': category,
      'tags': tags,
      'is_available': isAvailable,
      'inventory': inventory,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
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
    String? category,
    List<String>? tags,
    bool? isAvailable,
    int? inventory,
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
      category: category ?? this.category,
      tags: tags ?? this.tags,
      isAvailable: isAvailable ?? this.isAvailable,
      inventory: inventory ?? this.inventory,
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
        other.category == category &&
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
        category,
        isAvailable,
      );
}
