import 'dart:math';
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

/// Custom painter for drawing hollow arrows around amount elements
class HollowArrowPainter extends CustomPainter {
  final bool isNegative; // true for negative amounts (arrow from left, turns down)
  final Color arrowColor;
  final double strokeWidth;

  HollowArrowPainter({
    required this.isNegative,
    required this.arrowColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();

    if (isNegative) {
      // For negative amounts: arrow from left side, around number, turns downward
      final startX = 0.0;
      final startY = size.height * 0.5;
      final endX = size.width;
      final endY = size.height;

      // Start from left side
      path.moveTo(startX, startY);

      // Curve around the left side of the amount element
      path.quadraticBezierTo(
        size.width * 0.3, size.height * 0.3,
        size.width * 0.5, size.height * 0.2,
      );

      // Continue around the top
      path.quadraticBezierTo(
        size.width * 0.7, size.height * 0.1,
        size.width * 0.9, size.height * 0.2,
      );

      // Turn downward to point at the card
      path.lineTo(endX, endY);

      // Draw arrow head
      _drawArrowHead(canvas, Offset(endX, endY), 0.5 * 3.14159, paint); // 90 degrees down
    } else {
      // For positive amounts: arrow from top side, around number, turns leftward
      final startX = size.width * 0.5;
      final startY = 0.0;
      final endX = 0.0;
      final endY = size.height;

      // Start from top center
      path.moveTo(startX, startY);

      // Curve around the top of the amount element
      path.quadraticBezierTo(
        size.width * 0.7, size.height * 0.3,
        size.width * 0.8, size.height * 0.5,
      );

      // Continue around the right side
      path.quadraticBezierTo(
        size.width * 0.9, size.height * 0.7,
        size.width * 0.8, size.height * 0.9,
      );

      // Turn leftward to point at the card
      path.lineTo(endX, endY);

      // Draw arrow head
      _drawArrowHead(canvas, Offset(endX, endY), 3.14159, paint); // 180 degrees left
    }

    canvas.drawPath(path, paint);
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
    const arrowHeadLength = 8.0;
    const arrowHeadAngle = 0.3; // radians

    final arrowPoint1 = Offset(
      tip.dx - arrowHeadLength * cos(angle - arrowHeadAngle),
      tip.dy - arrowHeadLength * sin(angle - arrowHeadAngle),
    );

    final arrowPoint2 = Offset(
      tip.dx - arrowHeadLength * cos(angle + arrowHeadAngle),
      tip.dy - arrowHeadLength * sin(angle + arrowHeadAngle),
    );

    final arrowHeadPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy);

    canvas.drawPath(arrowHeadPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

/// Widget for displaying amount with hollow arrow
class AmountWithArrow extends StatelessWidget {
  final String amount;
  final bool isNegative;
  final Color amountColor;
  final Color arrowColor;
  final double amountFontSize;
  final double containerSize;

  const AmountWithArrow({
    super.key,
    required this.amount,
    required this.isNegative,
    required this.amountColor,
    required this.arrowColor,
    this.amountFontSize = 24.0,
    this.containerSize = 80.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: containerSize,
      height: containerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hollow arrow background
          CustomPaint(
            size: Size(containerSize, containerSize),
            painter: HollowArrowPainter(
              isNegative: isNegative,
              arrowColor: arrowColor,
              strokeWidth: 2.0,
            ),
          ),
          // Amount text in center
          Container(
            width: containerSize * 0.6,
            height: containerSize * 0.6,
            decoration: BoxDecoration(
              color: AppColors.background.withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: amountColor.withOpacity(0.3),
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              amount,
              style: TextStyle(
                fontSize: amountFontSize * 0.8,
                fontWeight: FontWeight.bold,
                color: amountColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
