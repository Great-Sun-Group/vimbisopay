import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A card widget specifically styled for the debug screens.
class DebugCard extends StatelessWidget {
  /// The child widget to display inside the card.
  final Widget child;
  
  /// Optional padding to apply inside the card.
  final EdgeInsetsGeometry? padding;
  
  /// Optional margin to apply around the card.
  final EdgeInsetsGeometry? margin;
  
  /// Optional color for the card background.
  final Color? color;
  
  /// Optional border for the card.
  final BoxBorder? border;

  const DebugCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color ?? AppColors.surface,
      margin: margin,
      shape: border != null 
          ? RoundedRectangleBorder(
              side: BorderSide(color: border!.top.color),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Padding(
        padding: padding!,
        child: child,
      ),
    );
  }
}
