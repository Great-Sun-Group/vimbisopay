import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/widgets/network_error_widget.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';

/// A collection of widgets for displaying different states in the marketplace.
class MarketplaceStates {
  /// Displays a loading state with a Lottie animation.
  static Widget buildLoadingState() {
    return const Center(
      child: InlineLoadingAnimation(size: 80),
    );
  }

  /// Displays an error state with an error message and a retry button.
  /// If isNetworkError is true, it will display an offline widget instead.
  static Widget buildErrorState({
    required String errorMessage,
    required VoidCallback onRetry,
    bool isNetworkError = false,
  }) {
    // Check if this is a network error
    if (isNetworkError || 
        errorMessage.toLowerCase().contains('network') ||
        errorMessage.toLowerCase().contains('internet') ||
        errorMessage.toLowerCase().contains('connection') ||
        errorMessage.toLowerCase().contains('socket') ||
        errorMessage.toLowerCase().contains('host lookup') ||
        errorMessage.toLowerCase().contains('timeout')) {
      // Use the OfflineWidget for network errors
      return OfflineWidget(
        onRetry: onRetry,
        message: 'You are currently offline. Please check your internet connection and try again.',
      );
    }
    
    // Use the regular error widget for other errors
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  /// Displays an empty state when no products are found.
  static Widget buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          const Text(
            'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try a different search term',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Displays an initializing state during screen initialization.
  static Widget buildInitializingState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: const SafeArea(
        child: Center(
          child: InlineLoadingAnimation(size: 80),
        ),
      ),
    );
  }
}
