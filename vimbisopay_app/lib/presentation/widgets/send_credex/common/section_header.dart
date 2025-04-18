import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A standardized section header widget
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.fontSize = 14,
    this.fontWeight = FontWeight.w500,
    this.textColor = AppColors.textSecondary,
    this.padding = const EdgeInsets.only(bottom: 8.0),
  });
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
