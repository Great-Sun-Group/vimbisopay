import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/presentation/models/basket_item.dart';

/// A card widget that displays a basket item.
///
/// This widget shows the product information, quantity, and price
/// for an item in the sales basket.
class BasketItemCard extends StatefulWidget {
  /// The basket item to display.
  final BasketItem item;

  /// Callback when the quantity is changed.
  final Function(int)? onQuantityChanged;

  /// Callback when the item is removed from the basket.
  final VoidCallback? onRemove;

  /// Creates a new [BasketItemCard] instance.
  const BasketItemCard({
    super.key,
    required this.item,
    this.onQuantityChanged,
    this.onRemove,
  });

  @override
  State<BasketItemCard> createState() => _BasketItemCardState();
}

class _BasketItemCardState extends State<BasketItemCard> {
  late TextEditingController _amountController;
  late FocusNode _amountFocusNode;
  bool _isFirstTap = true;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: widget.item.amount.toStringAsFixed(2));
    _amountFocusNode = FocusNode();
    _amountFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _amountFocusNode.removeListener(_handleFocusChange);
    _amountFocusNode.dispose();
    _amountController.dispose();
    super.dispose();
  }
  
  void _handleFocusChange() {
    if (_amountFocusNode.hasFocus && _isFirstTap) {
      // Select all text when the field receives focus for the first time
      _amountController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _amountController.text.length,
      );
    }
  }
  
  @override
  void didUpdateWidget(BasketItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update the controller if the item's amount has changed
    if (oldWidget.item.amount != widget.item.amount) {
      _amountController.text = widget.item.amount.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      elevation: 2, // Add subtle elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0), // More rounded corners
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center, // Center align vertically
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: _buildProductImage(widget.item.product),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Product name - takes available space
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text(
                      widget.item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2, // Allow 2 lines for long names
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                
                // Amount field - fixed width
                SizedBox(
                  width: 132, // Fixed comfortable width (increased by 10%)
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount in USD',
                      prefixText: '\$',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 16),
                    onTap: () {
                      if (_isFirstTap) {
                        // Clear the field on first tap
                        _amountController.clear();
                        _isFirstTap = false;
                      }
                    },
                    onChanged: (value) {
                      Logger.data('Amount field changed: "$value"');
                      
                      // If this is the first keystroke and the value still contains the original value
                      if (_isFirstTap && value.contains(widget.item.amount.toStringAsFixed(2))) {
                        // Clear the field and set the value to just the new character
                        final newChar = value.replaceAll(widget.item.amount.toStringAsFixed(2), '');
                        _amountController.text = newChar;
                        // Move cursor to the end
                        _amountController.selection = TextSelection.fromPosition(
                          TextPosition(offset: newChar.length),
                        );
                        _isFirstTap = false;
                        return;
                      }
                      
                      if (value.isNotEmpty) {
                        try {
                          final newAmount = double.parse(value);
                          if (newAmount >= 0) {
                            Logger.data('Setting new amount: $newAmount');
                            setState(() {
                              widget.item.amount = newAmount;
                            });
                            // Force parent widget to rebuild
                            if (widget.onQuantityChanged != null) {
                              widget.onQuantityChanged!(widget.item.quantity);
                              Logger.data('Notified parent of amount change');
                            }
                          } else {
                            Logger.data('Rejected negative amount: $newAmount');
                          }
                        } catch (e) {
                          Logger.data('Invalid amount input: "$value", error: $e');
                        }
                      } else {
                        Logger.data('Empty amount input');
                        // Set amount to 0 when field is empty
                        setState(() {
                          widget.item.amount = 0;
                        });
                        if (widget.onQuantityChanged != null) {
                          widget.onQuantityChanged!(widget.item.quantity);
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Remove button in top-right corner
          if (widget.onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onRemove,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  padding: const EdgeInsets.all(4),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  /// Builds the product image widget based on the image URL type.
  Widget _buildProductImage(Product product) {
    if (product.imageUrls.isEmpty || product.imageUrls.first == 'https://example.com/product_placeholder.jpg') {
      // Show placeholder if no image
      return Container(
        color: Colors.grey[300],
        child: const Center(
          child: Icon(
            Icons.image,
            color: Colors.grey,
            size: 20,
          ),
        ),
      );
    }
    
    final imageUrl = product.imageUrls.first;
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('Error loading local image: $filePath', error);
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.grey,
                size: 20,
              ),
            ),
          );
        },
      );
    } else {
      // Show remote image
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 20,
            ),
          ),
        ),
      );
    }
  }
}
