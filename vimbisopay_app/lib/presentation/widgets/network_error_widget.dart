import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A widget that displays a user-friendly network error message with an optional retry button
class NetworkErrorWidget extends StatelessWidget {
  /// Callback function to be called when the retry button is pressed
  final VoidCallback? onRetry;
  
  /// The error message to display
  final String message;
  
  /// The icon to display above the error message
  final IconData icon;
  
  /// The color of the icon
  final Color iconColor;
  
  /// The size of the icon
  final double iconSize;

  const NetworkErrorWidget({
    Key? key,
    this.onRetry,
    this.message = 'Unable to connect to the server. Please check your internet connection and try again.',
    this.icon = Icons.wifi_off,
    this.iconColor = AppColors.error,
    this.iconSize = 64,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A widget that displays a user-friendly empty state message with an optional action button
class EmptyStateWidget extends StatelessWidget {
  /// The title of the empty state
  final String title;
  
  /// The message to display
  final String message;
  
  /// The icon to display above the message
  final IconData icon;
  
  /// The color of the icon
  final Color iconColor;
  
  /// The size of the icon
  final double iconSize;
  
  /// The text for the action button
  final String? actionText;
  
  /// Callback function to be called when the action button is pressed
  final VoidCallback? onAction;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline,
    this.iconColor = AppColors.primary,
    this.iconSize = 64,
    this.actionText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (actionText != null && onAction != null)
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionText!),
              ),
          ],
        ),
      ),
    );
  }
}

/// A widget that displays a user-friendly network error message specifically for offline states
class OfflineWidget extends StatelessWidget {
  /// Callback function to be called when the retry button is pressed
  final VoidCallback? onRetry;
  
  /// The message to display
  final String message;

  const OfflineWidget({
    Key? key,
    this.onRetry,
    this.message = 'You are currently offline. Please check your internet connection and try again.',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NetworkErrorWidget(
      icon: Icons.cloud_off,
      message: message,
      onRetry: onRetry,
    );
  }
}
