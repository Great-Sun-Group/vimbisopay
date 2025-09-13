/// Centralized layout dimensions specifically for Credex Detail Screen.
/// This class eliminates magic numbers and ensures consistent sizing
/// across the credex detail screen components.

import 'package:flutter/material.dart';

class CredexDetailDimensions {
  // Base header dimensions - easy to understand/modify
  static const double titleHeight = 56.0;          // Standard AppBar height
  static const double barGraphContentHeight = 93.0; // Content space for bar graph
  static const double borderWidth = 1.0;           // Clear visual separator thickness

  // Computed header dimensions - automatically maintained
  static const double darkSectionTotalHeight = barGraphContentHeight + borderWidth;
  static const double headerTotalHeight = titleHeight + darkSectionTotalHeight;

  // Standard padding constants
  static const double standardSidePadding = 16.0;
  static const double standardVerticalPadding = 16.0;
  static const double borderBottomPadding = 3.0;

  // Widget-specific size constants
  static const double transactionArrowContainerSize = 100.0;
  static const double standardIconSize = 20.0;

  // Header padding configurations
  static EdgeInsets get headerContentPadding => const EdgeInsets.only(
    top: standardVerticalPadding,
    left: standardSidePadding,
    right: standardSidePadding,
    bottom: borderBottomPadding,
  );

  // Loading animation sizes
  static const double largeLoadingAnimationSize = 80.0;
  static const double smallLoadingAnimationSize = 20.0;
}
