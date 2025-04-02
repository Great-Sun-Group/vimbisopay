import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/presentation/helpers/store_information_helper.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/edit_vendor_profile_screen.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/inventory/inventory_management_screen.dart';

/// Widget that displays the store profile header with app bar
class StoreProfileHeader extends StatelessWidget {
  /// The vendor to display
  final Vendor vendor;
  
  /// The profile thumbnail URL
  final String? profileThumbnailUrl;
  
  /// Whether the current user is the owner of this store
  final bool isOwner;
  
  /// The store ID
  final String storeId;
  
  /// Callback when the store data needs to be refreshed
  final VoidCallback onRefresh;

  /// Creates a new [StoreProfileHeader] instance
  const StoreProfileHeader({
    super.key,
    required this.vendor,
    required this.profileThumbnailUrl,
    required this.isOwner,
    required this.storeId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            // Banner image
            Positioned.fill(
              child: StoreInformationHelper.buildImageFromUrl(
                vendor.bannerImageUrl,
                placeholder: Container(
                  color: AppColors.primary.withOpacity(0.2),
                  child: const Center(
                    child: Icon(
                      Icons.storefront,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            // Gradient overlay for better text visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.transparent,
                      AppColors.black.withOpacity(0.7),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
            ),
            // Profile image
            Positioned(
              left: 16,
              bottom: 16,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: ClipOval(
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: _buildProfileImage(),
                    ),
                  ),
                ),
              ),
            ),
            // Business name and rating
            Positioned(
              left: 108,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vendor.businessName,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: AppColors.black45,
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: AppColors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        vendor.ratingDisplay,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 2,
                              color: AppColors.black45,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (isOwner) ...[
          IconButton(
            icon: const Icon(Icons.inventory_2),
            tooltip: 'Manage Inventory',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InventoryManagementScreen(
                    vendorId: storeId,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditVendorProfileScreen(
                    vendorId: storeId,
                  ),
                ),
              ).then((result) {
                // Check if we got a success result
                if (result != null && result is Map && result['success'] == true) {
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? 'Store information updated successfully'),
                      backgroundColor: AppColors.successGreen,
                    ),
                  );
                }
                
                // Refresh the store data
                onRefresh();
              });
            },
          ),
        ],
      ],
    );
  }

  /// Builds the profile image for the vendor, using the profile thumbnail URL if available.
  Widget _buildProfileImage() {
    // Use profile thumbnail URL if available
    if (profileThumbnailUrl != null && profileThumbnailUrl!.isNotEmpty) {
      Logger.data('[STORE_INFO] Using profile thumbnail URL: $profileThumbnailUrl');
      return StoreInformationHelper.buildImageFromUrl(
        profileThumbnailUrl,
        placeholder: Container(
          color: AppColors.primary,
          child: const Center(
            child: Icon(
              Icons.person,
              size: 38,
              color: AppColors.white,
            ),
          ),
        ),
      );
    }
    
    // Otherwise use vendor's profile image URL
    return vendor.profileImageUrl != null
        ? StoreInformationHelper.buildImageFromUrl(
            vendor.profileImageUrl,
            placeholder: Container(
              color: AppColors.primary,
              child: const Center(
                child: Icon(
                  Icons.storefront,
                  size: 38,
                  color: AppColors.white,
                ),
              ),
            ),
          )
        : Container(
            color: AppColors.primary,
            child: const Center(
              child: Icon(
                Icons.storefront,
                size: 38,
                color: AppColors.white,
              ),
            ),
          );
  }
}
