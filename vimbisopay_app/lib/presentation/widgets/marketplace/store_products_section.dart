import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/presentation/helpers/store_information_helper.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/add_edit_sku_screen.dart';

/// Widget that displays the products section
class StoreProductsSection extends StatelessWidget {
  /// The products to display
  final List<Product> products;
  
  /// Whether the current user is the owner of this store
  final bool isOwner;
  
  /// The store ID
  final String storeId;
  
  /// Callback when a product is added
  final VoidCallback onProductAdded;
  
  /// Callback when a product is selected
  final Function(Product) onProductSelected;
  
  /// Scroll controller for the list
  final ScrollController scrollController;
  
  /// Whether the FAB is visible
  final bool isFabVisible;

  /// Creates a new [StoreProductsSection] instance
  const StoreProductsSection({
    super.key,
    required this.products,
    required this.isOwner,
    required this.storeId,
    required this.onProductAdded,
    required this.onProductSelected,
    required this.scrollController,
    required this.isFabVisible,
  });

  /// Helper method to get bottom padding based on FAB visibility
  double getBottomPadding() {
    return isOwner && isFabVisible ? 80.0 : 16.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Products',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isOwner)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Product'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditSkuScreen(
                        vendorId: storeId,
                      ),
                    ),
                  ).then((result) {
                    // Check if we got a success result
                    if (result != null && result is Map && result['success'] == true) {
                      // Show success message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(result['message'] ?? 'Product added successfully'),
                          backgroundColor: AppColors.successGreen,
                        ),
                      );
                      
                      // Refresh the store data
                      onProductAdded();
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        products.isEmpty
            ? _buildEmptyProductsView(context)
            : _buildProductsGrid(),
      ],
    );
  }

  Widget _buildEmptyProductsView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              isOwner
                  ? 'You haven\'t added any products yet'
                  : 'This store hasn\'t added any products yet',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (isOwner) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditSkuScreen(
                        vendorId: storeId,
                      ),
                    ),
                  ).then((_) {
                    onProductAdded();
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Your First Product'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      padding: EdgeInsets.fromLTRB(0, 0, 0, getBottomPadding()),
      itemBuilder: (context, index) {
        final product = products[index];
        return _buildProductListItem(product);
      },
    );
  }

  /// Builds the product image widget based on the image URL type.
  Widget _buildProductImage(Product product) {
    if (product.imageUrls.isEmpty) {
      // Show placeholder if no image
      return Container(
        color: AppColors.grey300,
        child: const Center(
          child: Icon(
            Icons.image,
            color: AppColors.grey,
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
          Logger.error('[STORE_INFO] Error loading local image: $filePath', error);
          return Container(
            color: AppColors.grey300,
            child: const Center(
              child: Icon(
                Icons.image_not_supported,
                color: AppColors.grey,
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
          color: AppColors.grey200,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: AppColors.grey300,
          child: const Center(
            child: Icon(
              Icons.image_not_supported,
              color: AppColors.grey,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildProductListItem(Product product) {
    // Extract account balance from product price (which is stored in cents)
    final accountBalance = product.price / 100;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      leading: SizedBox(
        width: 48,
        height: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4.0),
          child: _buildProductImage(product),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        product.description,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            StoreInformationHelper.formatAccountBalance(accountBalance),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.primary,
            ),
          ),
          const Text(
            'Balance',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      onTap: () => onProductSelected(product),
    );
  }
}
