import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

/// Widget that displays the business information section
class StoreBusinessInfo extends StatelessWidget {
  /// The vendor to display
  final Vendor vendor;
  
  /// Whether the current user is the owner of this store
  final bool isOwner;
  
  /// Whether the store is open
  final bool storeOpen;
  
  /// Whether the store status is being updated
  final bool isUpdatingStoreStatus;
  
  /// The current user
  final User? currentUser;
  
  /// Callback when the store status is toggled
  final Function(bool) onStoreStatusToggled;
  
  /// Callback when the settings button is pressed
  final VoidCallback onSettingsPressed;

  /// Creates a new [StoreBusinessInfo] instance
  const StoreBusinessInfo({
    super.key,
    required this.vendor,
    required this.isOwner,
    required this.storeOpen,
    required this.isUpdatingStoreStatus,
    required this.currentUser,
    required this.onStoreStatusToggled,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsContainer(
      title: 'About',
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vendor.description,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              if (isOwner) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: vendor.isActive
                            ? AppColors.successGreen.withOpacity(0.2)
                            : AppColors.errorRed.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        vendor.isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: vendor.isActive ? AppColors.successGreen : AppColors.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('Settings'),
                      onPressed: onSettingsPressed,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Store:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    isUpdatingStoreStatus
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Switch(
                            value: storeOpen,
                            activeColor: AppColors.successGreen,
                            onChanged: onStoreStatusToggled,
                          ),
                    const SizedBox(width: 8),
                    Text(
                      storeOpen ? 'Open' : 'Closed',
                      style: TextStyle(
                        color: storeOpen ? AppColors.successGreen : AppColors.errorRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (currentUser?.latitude != null && currentUser?.longitude != null)
                      Tooltip(
                        message: 'Location: ${currentUser!.latitude!.toStringAsFixed(4)}, ${currentUser!.longitude!.toStringAsFixed(4)}',
                        child: const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
