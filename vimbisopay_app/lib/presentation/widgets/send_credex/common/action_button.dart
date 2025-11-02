import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// A standardized action button widget
class ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final Color backgroundColor;
  final Color textColor;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Widget? icon;
  final String? loadingAnimationAsset;
  final double loadingAnimationSize;
  
  const ActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor = AppColors.primary,
    this.textColor = AppColors.textPrimary,
    this.height = 48.0,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.bold,
    this.borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    this.padding = const EdgeInsets.symmetric(vertical: 16.0),
    this.icon,
    this.loadingAnimationAsset,
    this.loadingAnimationSize = 24.0,
  });
  
  /// Factory constructor for a teal-styled button
  factory ActionButton.teal({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    double height = 48.0,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.bold,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 16.0),
    Widget? icon,
  }) {
    return ActionButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      backgroundColor: AppColors.techAzure,
      textColor: AppColors.textPrimary,
      height: height,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
      padding: padding,
      icon: icon,
    );
  }
  
  /// Factory constructor for a secondary button
  factory ActionButton.secondary({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    bool isFullWidth = true,
    double height = 48.0,
    double fontSize = 16.0,
    FontWeight fontWeight = FontWeight.bold,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(4.0)),
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(vertical: 16.0),
    Widget? icon,
  }) {
    return ActionButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isFullWidth,
      backgroundColor: AppColors.surface,
      textColor: AppColors.textSecondary,
      height: height,
      fontSize: fontSize,
      fontWeight: fontWeight,
      borderRadius: borderRadius,
      padding: padding,
      icon: icon,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final buttonChild = isLoading
        ? (loadingAnimationAsset != null
            ? SizedBox(
                height: loadingAnimationSize,
                width: loadingAnimationSize,
                child: Lottie.asset(
                  loadingAnimationAsset!,
                  fit: BoxFit.contain,
                ),
              )
            : const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                ),
              ))
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                icon!,
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: textColor,
                ),
              ),
            ],
          );
    
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: padding,
        minimumSize: Size(0, height),
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
        ),
        disabledBackgroundColor: AppColors.grey.withOpacity(0.3),
        disabledForegroundColor: AppColors.textSecondary,
      ),
      child: buttonChild,
    );
    
    return isFullWidth
        ? SizedBox(
            width: double.infinity,
            child: button,
          )
        : button;
  }
}
