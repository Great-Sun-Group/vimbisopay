import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';

class PageIndicator extends StatelessWidget {
  final int count;
  final int currentPage;

  const PageIndicator({
    super.key,
    required this.count,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => Container(
          margin: const EdgeInsets.symmetric(
            horizontal: HomeConstants.tinyPadding,
          ),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentPage == index
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.2),
          ),
        ),
      ),
    );
  }
}
