import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A widget that displays a profile picture with a name split into first and last name
/// on separate lines, alongside a vertical bar graph showing different metrics.
class ProfileWithBarGraph extends StatelessWidget {
  final String? profileImageUrl;
  final String firstName;
  final String lastName;
  final Map<String, double> barValues;
  final bool isRecipient;

  const ProfileWithBarGraph({
    super.key,
    this.profileImageUrl,
    required this.firstName,
    required this.lastName,
    required this.barValues,
    this.isRecipient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Vertical bar graph
        SizedBox(
          width: 20,
          height: 60,
          child: _buildBarGraph(),
        ),
        const SizedBox(width: 8),
        // Profile image and name
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile image
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.secondary,
                  width: 2,
                ),
                // Always use the placeholder icon for now
                image: null,
              ),
              child: const Icon(
                Icons.person,
                size: 24,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: 4),
            // First name
            Text(
              firstName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            // Last name
            Text(
              lastName,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBarGraph() {
    // Extract values with defaults
    final tealValue = barValues['teal'] ?? 0.0;
    final goldValue = barValues['gold'] ?? 0.0;
    final orangeValue = barValues['orange'] ?? 0.0;
    final redValue = barValues['red'] ?? 0.0;
    
    // Calculate heights based on percentages
    final totalHeight = 60.0; // Total height of the bar
    final tealHeight = (tealValue / 100) * totalHeight;
    final goldHeight = (goldValue / 100) * totalHeight;
    final orangeHeight = (orangeValue / 100) * totalHeight;
    final redHeight = (redValue / 100) * totalHeight;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Column(
        children: [
          // Red segment (from top to bottom)
          if (redValue > 0)
            _buildBarSegment(
              height: redHeight,
              color: AppColors.error,
            ),
          // Orange segment
          if (orangeValue > 0)
            _buildBarSegment(
              height: orangeHeight,
              color: AppColors.yellowPrimary,
            ),
          // Gold segment
          if (goldValue > 0)
            _buildBarSegment(
              height: goldHeight,
              color: AppColors.yellowMain,
            ),
          // Teal segment
          if (tealValue > 0)
            _buildBarSegment(
              height: tealHeight,
              color: AppColors.greenMain,
            ),
        ],
      ),
    );
  }

  Widget _buildBarSegment({
    required double height,
    required Color color,
  }) {
    return Container(
      height: height,
      width: 20,
      color: color,
    );
  }

  /// Factory method to create a widget with hardcoded values for the current user
  factory ProfileWithBarGraph.currentUser({
    String? profileImageUrl,
    required String firstName,
    required String lastName,
  }) {
    return ProfileWithBarGraph(
      profileImageUrl: profileImageUrl,
      firstName: firstName,
      lastName: lastName,
      barValues: {
        'teal': 67.0,
        'gold': 33.0,
        'orange': 0.0,
        'red': 0.0,
      },
    );
  }

  /// Factory method to create a widget with hardcoded values for Davidzo
  factory ProfileWithBarGraph.davidzo({
    String? profileImageUrl,
  }) {
    return ProfileWithBarGraph(
      profileImageUrl: profileImageUrl,
      firstName: 'Davidzo',
      lastName: 'Chatanga',
      barValues: {
        'teal': 67.0,
        'gold': 23.0,
        'orange': 7.0,
        'red': 3.0,
      },
      isRecipient: true,
    );
  }
}
