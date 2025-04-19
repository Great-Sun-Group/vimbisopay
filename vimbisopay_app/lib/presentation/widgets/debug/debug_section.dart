import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A section widget for debug screens with a title and content.
class DebugSection extends StatelessWidget {
  /// The title of the section.
  final String title;
  
  /// The child widget(s) to display in the section.
  final List<Widget> children;
  
  /// Optional padding to apply inside the section.
  final EdgeInsetsGeometry padding;
  
  /// Optional margin to apply around the section.
  final EdgeInsetsGeometry margin;

  const DebugSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: padding,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// A row widget for displaying a label and value in debug screens.
class DebugInfoRow extends StatelessWidget {
  /// The label to display.
  final String label;
  
  /// The value to display.
  final String value;
  
  /// Optional text style for the label.
  final TextStyle? labelStyle;
  
  /// Optional text style for the value.
  final TextStyle? valueStyle;
  
  /// Optional padding to apply around the row.
  final EdgeInsetsGeometry padding;

  const DebugInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
    this.padding = const EdgeInsets.only(bottom: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            '$label: ',
            style: labelStyle ?? const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            value,
            style: valueStyle ?? const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
