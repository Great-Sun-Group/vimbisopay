import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/presentation/models/basket_item.dart';

/// Represents a sales basket for a transaction.
///
/// A sales basket contains a collection of products with quantities
/// that a vendor is selling to a buyer.
class SalesBasket {
  /// The items in the basket.
  final List<BasketItem> items;

  /// The vendor creating the sales basket.
  final Vendor vendor;

  /// Optional notes for the transaction.
  String? notes;

  /// Creates a new [SalesBasket] instance.
  SalesBasket({
    required this.vendor,
    List<BasketItem>? items,
    this.notes,
  }) : items = items ?? [];

  /// Gets the total price for all items in the basket.
  int get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  /// Gets the formatted total price with currency symbol.
  ///
  /// Assumes all products use the same currency.
  String get formattedTotalPrice {
    if (items.isEmpty) {
      return '\$0.00'; // Default format when basket is empty
    }

    // Use the currency of the first item for formatting
    String currency = items.first.product.currency;
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
        return '$currency ${(totalPrice / 100).toStringAsFixed(2)}';
    }
    return '$symbol${(totalPrice / 100).toStringAsFixed(2)}';
  }

  /// Gets the number of items in the basket.
  int get itemCount => items.length;

  /// Gets the total quantity of all items in the basket.
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Adds a product to the basket.
  ///
  /// If the product is already in the basket, increments its quantity.
  void addProduct(Product product) {
    // Check if the product is already in the basket
    for (var item in items) {
      if (item.product.id == product.id) {
        item.incrementQuantity();
        return;
      }
    }

    // If not, add it as a new item
    items.add(BasketItem(product: product));
  }

  /// Removes a product from the basket.
  void removeProduct(String productId) {
    items.removeWhere((item) => item.product.id == productId);
  }

  /// Updates the quantity of a product in the basket.
  ///
  /// Returns true if the product was found and updated, false otherwise.
  bool updateQuantity(String productId, int quantity) {
    for (var item in items) {
      if (item.product.id == productId) {
        item.setQuantity(quantity);
        return true;
      }
    }
    return false;
  }

  /// Increments the quantity of a product in the basket.
  ///
  /// Returns true if the product was found and updated, false otherwise.
  bool incrementQuantity(String productId) {
    for (var item in items) {
      if (item.product.id == productId) {
        item.incrementQuantity();
        return true;
      }
    }
    return false;
  }

  /// Decrements the quantity of a product in the basket.
  ///
  /// Returns true if the product was found and updated, false otherwise.
  bool decrementQuantity(String productId) {
    for (var item in items) {
      if (item.product.id == productId) {
        item.decrementQuantity();
        return true;
      }
    }
    return false;
  }

  /// Clears all items from the basket.
  void clear() {
    items.clear();
  }

  /// Checks if the basket is empty.
  bool get isEmpty => items.isEmpty;

  /// Checks if the basket is not empty.
  bool get isNotEmpty => items.isNotEmpty;

  /// Converts the basket to a list of invoice line items.
  List<InvoiceLineItem> toInvoiceLineItems() {
    return items.map((item) => InvoiceLineItem(
      productId: item.product.id,
      productName: item.product.name,
      quantity: 1, // Set quantity to 1 since we're using custom amounts
      unitPrice: item.totalPrice, // Use the total price as the unit price
      totalPrice: item.totalPrice,
    )).toList();
  }
}
