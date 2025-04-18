import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/presentation/widgets/send_credex/common/styled_card.dart';

/// Widget to display status messages
class StatusMessageWidget extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry margin;
  
  const StatusMessageWidget({
    super.key,
    this.message,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });
  
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.primary, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display error messages
class ErrorMessageWidget extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry margin;
  
  const ErrorMessageWidget({
    super.key,
    this.message,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });
  
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    
    return StyledCard.warning(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      showTitleOverlay: false,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.darkRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget to display warning messages
class WarningMessageWidget extends StatelessWidget {
  final String? message;
  final EdgeInsetsGeometry margin;
  
  const WarningMessageWidget({
    super.key,
    this.message,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });
  
  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.warning, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
