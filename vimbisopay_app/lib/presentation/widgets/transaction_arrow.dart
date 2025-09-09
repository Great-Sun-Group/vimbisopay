import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

/// Widget for displaying an arrow connecting member cards in credex transactions
class TransactionArrow extends StatelessWidget {
  final bool pointsRight; // true = → (outgoing), false = ← (incoming)
  final double width;
  final double height;

  const TransactionArrow({
    super.key,
    required this.pointsRight,
    this.width = 40,
    this.height = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      child: Icon(
        pointsRight ? Icons.arrow_forward : Icons.arrow_back,
        color: AppColors.primary,
        size: height * 0.8,
      ),
    );
  }
}

/// A more elaborate arrow widget with custom styling
class TransactionArrowDetailed extends StatelessWidget {
  final bool pointsRight; // true = → (outgoing), false = ← (incoming)
  final String? label;
  final double width;
  final double height;

  const TransactionArrowDetailed({
    super.key,
    required this.pointsRight,
    this.label,
    this.width = 60,
    this.height = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Arrow line
          Container(
            width: width * 0.8,
            height: 2,
            color: AppColors.primary.withOpacity(0.5),
          ),
          // Arrow head
          Positioned(
            left: pointsRight ? null : 0,
            right: pointsRight ? 0 : null,
            child: Icon(
              pointsRight ? Icons.arrow_right : Icons.arrow_left,
              color: AppColors.primary,
              size: height,
            ),
          ),
          // Optional label
          if (label != null)
            Positioned(
              bottom: -height * 0.3,
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
