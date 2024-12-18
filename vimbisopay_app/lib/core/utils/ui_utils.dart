import 'package:flutter/material.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';

class UIUtils {
  static Size getScreenDimensions(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safePadding = MediaQuery.of(context).padding;
    final availableHeight = screenHeight - 
        HomeConstants.appBarHeight - 
        safePadding.top - 
        safePadding.bottom;
    
    return Size(
      MediaQuery.of(context).size.width,
      availableHeight,
    );
  }

  static double getViewPagerHeight(BuildContext context) {
    return getScreenDimensions(context).height * HomeConstants.accountCardHeight;
  }

  static String getInitials(String? firstname, String? lastname) {
    final first = firstname?.isNotEmpty == true ? firstname![0] : '';
    final last = lastname?.isNotEmpty == true ? lastname![0] : '';
    return '$first$last'.toUpperCase();
  }

  static BoxDecoration get gradientBackground => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.black.withOpacity(0.1),
        Colors.black,
      ],
    ),
  );
}

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: UIUtils.gradientBackground,
      child: child,
    );
  }
}
