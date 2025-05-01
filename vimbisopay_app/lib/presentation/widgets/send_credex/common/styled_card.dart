import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A styled card widget with consistent styling and optional title
class StyledCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool showTitleOverlay;
  
  const StyledCard({
    super.key,
    required this.child,
    this.title,
    this.borderColor = AppColors.primary,
    this.borderWidth = 1.0,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = const EdgeInsets.only(bottom: 16.0),
    this.showTitleOverlay = true,
  });
  
  /// Factory constructor for a gold-styled card (used for contracts)
  factory StyledCard.gold({
    required Widget child,
    String? title,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 16.0),
    bool showTitleOverlay = true,
  }) {
    return StyledCard(
      title: title,
      borderColor: AppColors.yellowMain, // Organic gold
      borderWidth: 1.5,
      padding: padding,
      margin: margin,
      showTitleOverlay: showTitleOverlay,
      child: child,
    );
  }
  
  /// Factory constructor for a teal-styled card (used for credex type)
  factory StyledCard.teal({
    required Widget child,
    String? title,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 16.0),
    bool showTitleOverlay = true,
  }) {
    return StyledCard(
      title: title,
      borderColor: AppColors.techAzure, // Tech azure
      borderWidth: 1.5,
      padding: padding,
      margin: margin,
      showTitleOverlay: showTitleOverlay,
      child: child,
    );
  }
  
  /// Factory constructor for a warning-styled card (used for errors)
  factory StyledCard.warning({
    required Widget child,
    String? title,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 16.0),
    bool showTitleOverlay = true,
  }) {
    return StyledCard(
      title: title,
      borderColor: AppColors.darkRed,
      borderWidth: 1.5,
      padding: padding,
      margin: margin,
      showTitleOverlay: showTitleOverlay,
      child: child,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main card
          Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
          
          // Title overlay (if provided)
          if (title != null && showTitleOverlay)
            Positioned(
              top: -10,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: AppColors.surface,
                child: Text(
                  title!,
                  style: TextStyle(
                    color: borderColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
