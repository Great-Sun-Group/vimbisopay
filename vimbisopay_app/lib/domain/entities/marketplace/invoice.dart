import 'package:vimbisopay_app/domain/entities/base_entity.dart';

/// Represents an invoice in the marketplace.
///
/// An invoice is a record of a transaction between a buyer and a seller.
/// It contains information about the products purchased, the payment status,
/// and the parties involved.
class Invoice extends Entity {
  /// The unique identifier for the invoice.
  final String id;

  /// The ID of the buyer (member).
  /// This is optional as the invoice can be buyer-agnostic.
  final String? buyerId;

  /// The ID of the seller (vendor).
  final String vendorId;

  /// The list of line items in the invoice.
  final List<InvoiceLineItem> lineItems;

  /// The total amount of the invoice in the smallest currency unit (e.g., cents).
  final int totalAmount;

  /// The currency code for the invoice (e.g., USD, EUR).
  final String currency;

  /// The current status of the invoice.
  final InvoiceStatus status;

  /// The payment method used for the invoice.
  final String paymentMethod;

  /// Any notes or comments on the invoice.
  final String? notes;

  /// The date when the invoice was created.
  final DateTime createdAt;

  /// The date when the invoice was last updated.
  final DateTime updatedAt;

  /// The date when the invoice was paid, if applicable.
  final DateTime? paidAt;

  /// The URL to the QR code for this invoice.
  final String? invoiceQrLink;
  
  /// The ID of the account used for payment.
  final String? paymentAccountId;

  /// Creates a new [Invoice] instance.
  Invoice({
    required this.id,
    this.buyerId,
    required this.vendorId,
    required this.lineItems,
    required this.totalAmount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    this.invoiceQrLink,
    this.paymentAccountId,
  }) : super(id);

  /// Creates an [Invoice] from a JSON map.
  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'],
      buyerId: json['buyer_id'],
      vendorId: json['vendor_id'],
      lineItems: (json['line_items'] as List)
          .map((item) => InvoiceLineItem.fromJson(item))
          .toList(),
      totalAmount: json['total_amount'],
      currency: json['currency'],
      status: InvoiceStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => InvoiceStatus.pending,
      ),
      paymentMethod: json['payment_method'],
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      invoiceQrLink: json['invoice_qr_link'],
      paymentAccountId: json['payment_account_id'],
    );
  }

  /// Converts this [Invoice] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyer_id': buyerId,
      'vendor_id': vendorId,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'total_amount': totalAmount,
      'currency': currency,
      'status': status.toString().split('.').last,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'invoice_qr_link': invoiceQrLink,
      'payment_account_id': paymentAccountId,
    };
  }

  /// Returns the formatted total amount with currency symbol.
  String get formattedTotalAmount {
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
        return '$currency ${(totalAmount / 100).toStringAsFixed(2)}';
    }
    return '$symbol${(totalAmount / 100).toStringAsFixed(2)}';
  }

  /// Creates a copy of this [Invoice] with the given fields replaced.
  Invoice copyWith({
    String? id,
    String? buyerId,
    String? vendorId,
    List<InvoiceLineItem>? lineItems,
    int? totalAmount,
    String? currency,
    InvoiceStatus? status,
    String? paymentMethod,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? paidAt,
    String? invoiceQrLink,
    String? paymentAccountId,
  }) {
    return Invoice(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      vendorId: vendorId ?? this.vendorId,
      lineItems: lineItems ?? this.lineItems,
      totalAmount: totalAmount ?? this.totalAmount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAt: paidAt ?? this.paidAt,
      invoiceQrLink: invoiceQrLink ?? this.invoiceQrLink,
      paymentAccountId: paymentAccountId ?? this.paymentAccountId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Invoice &&
        other.id == id &&
        other.buyerId == buyerId &&
        other.vendorId == vendorId &&
        other.totalAmount == totalAmount &&
        other.currency == currency &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(
        id,
        buyerId,
        vendorId,
        totalAmount,
        currency,
        status,
      );
}

/// Represents a line item in an invoice.
///
/// A line item is a single product or service in an invoice.
class InvoiceLineItem {
  /// The ID of the product.
  final String productId;

  /// The name of the product.
  final String productName;

  /// The quantity of the product.
  final int quantity;

  /// The unit price of the product in the smallest currency unit (e.g., cents).
  final int unitPrice;

  /// The total price for this line item in the smallest currency unit (e.g., cents).
  final int totalPrice;

  /// Creates a new [InvoiceLineItem] instance.
  InvoiceLineItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  /// Creates an [InvoiceLineItem] from a JSON map.
  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) {
    return InvoiceLineItem(
      productId: json['product_id'],
      productName: json['product_name'],
      quantity: json['quantity'],
      unitPrice: json['unit_price'],
      totalPrice: json['total_price'],
    );
  }

  /// Converts this [InvoiceLineItem] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
    };
  }
}

/// Represents the status of an invoice.
enum InvoiceStatus {
  /// The invoice has been created but not yet paid.
  pending,

  /// The invoice has been paid.
  paid,

  /// The invoice has been cancelled.
  cancelled,

  /// The invoice has been refunded.
  refunded,

  /// The invoice payment has failed.
  failed,
}
