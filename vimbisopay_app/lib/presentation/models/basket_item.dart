import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';

/// Represents an item in the sales basket.
///
/// A basket item is a product with a quantity that has been added to the
/// sales basket for purchase.
class BasketItem {
  /// The product being purchased.
  final Product product;

  /// The quantity of the product being purchased.
  int quantity;
  
  /// The custom amount for this item.
  double amount;

  /// Creates a new [BasketItem] instance.
  BasketItem({
    required this.product,
    this.quantity = 1,
    this.amount = 0.0, // Default to 0
  }) {
    // Initialize amount based on product price if not specified
    if (amount == 0.0) {
      amount = product.price / 100; // Convert cents to dollars
    }
  }

  /// Gets the total price for this basket item.
  ///
  /// The total price is based on the custom amount.
  int get totalPrice => (amount * 100).round(); // Convert dollars to cents

  /// Gets the formatted total price with currency symbol.
  String get formattedTotalPrice {
    // Use the product's formatted price logic but with the total price
    String symbol = '';
    switch (product.currency) {
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
        return '${product.currency} ${totalPrice / 100}';
    }
    return '$symbol${totalPrice / 100}';
  }

  /// Increments the quantity by 1.
  void incrementQuantity() {
    quantity++;
  }

  /// Decrements the quantity by 1, but not below 1.
  void decrementQuantity() {
    if (quantity > 1) {
      quantity--;
    }
  }

  /// Sets the quantity to a specific value, but not below 1.
  void setQuantity(int newQuantity) {
    if (newQuantity >= 1) {
      quantity = newQuantity;
    }
  }
}
