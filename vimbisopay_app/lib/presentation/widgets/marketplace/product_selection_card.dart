import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';

/// A card widget that displays a product for selection.
///
/// This widget shows the product information and allows the user to
/// add the product to the basket.
class ProductSelectionCard extends StatelessWidget {
  /// The product to display.
  final Product product;

  /// Callback when the product is added to the basket.
  final VoidCallback? onAddToBasket;

  /// Whether the product is already in the basket.
  final bool isInBasket;

  /// Creates a new [ProductSelectionCard] instance.
  const ProductSelectionCard({
    super.key,
    required this.product,
    this.onAddToBasket,
    this.isInBasket = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: InkWell(
        onTap: isInBasket ? null : onAddToBasket,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            AspectRatio(
              aspectRatio: 1.0,
              child: Stack(
                children: [
                  // Product image
                  Positioned.fill(
                    child: _buildProductImage(product),
                  ),
                  // "In Basket" indicator
                  if (isInBasket)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.8),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shopping_basket,
                              color: AppColors.white,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'In Basket',
                              style: TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Availability indicator
                  if (!product.isAvailable)
                    Positioned.fill(
                      child: Container(
                        color: AppColors.black.withOpacity(0.6),
                        child: const Center(
                          child: Text(
                            'Unavailable',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 2),
                  Text(
                    product.formattedPrice,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (!isInBasket && product.isAvailable)
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_shopping_cart, size: 14),
                        label: const Text('Add', style: TextStyle(fontSize: 12)),
                        onPressed: onAddToBasket,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  if (isInBasket)
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          disabledForegroundColor: AppColors.primary.withOpacity(0.5),
                        ),
                        child: const Text('Added', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }
  }
}
