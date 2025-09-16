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
  final bool
      isNegative; // true for negative amounts (arrow from left, turns down)
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
        size.width * 0.3,
        size.height * 0.3,
        size.width * 0.5,
        size.height * 0.2,
      );

      // Continue around the top
      path.quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.1,
        size.width * 0.9,
        size.height * 0.2,
      );

      // Turn downward to point at the card
      path.lineTo(endX, endY);

      // Draw arrow head
      _drawArrowHead(
          canvas, Offset(endX, endY), 0.5 * 3.14159, paint); // 90 degrees down
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
        size.width * 0.7,
        size.height * 0.3,
        size.width * 0.8,
        size.height * 0.5,
      );

      // Continue around the right side
      path.quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.7,
        size.width * 0.8,
        size.height * 0.9,
      );

      // Turn leftward to point at the card
      path.lineTo(endX, endY);

      // Draw arrow head
      _drawArrowHead(
          canvas, Offset(endX, endY), 3.14159, paint); // 180 degrees left
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

/// Widget for displaying amount with L-shaped arrow
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
      height: containerSize * 1.2, // More height for arrowhead
      child: CustomPaint(
        size: Size(containerSize, containerSize * 1.2),
        painter: LShapedArrowPainter(
          amount: amount,
          isNegative: isNegative,
          amountColor: amountColor,
          arrowColor: arrowColor,
          amountFontSize: amountFontSize,
        ),
      ),
    );
  }
}

/// Custom painter for L-shaped arrow with amount box
class LShapedArrowPainter extends CustomPainter {
  final String amount;
  final bool isNegative;
  final Color amountColor;
  final Color arrowColor;
  final double amountFontSize;

  LShapedArrowPainter({
    required this.amount,
    required this.isNegative,
    required this.amountColor,
    required this.arrowColor,
    required this.amountFontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = arrowColor
      ..style = PaintingStyle.fill;

    final backgroundPaint = Paint()
      ..color = AppColors.background
      ..style = PaintingStyle.fill;

    // Calculate dimensions for stepped arrow design
    final fixedTransparentWidth = 10.0;
    final mainBoxHeight = size.height * 0.25;
    final smallerBoxHeight = size.height * 0.1;
    final arrowHeadSize = 22.0;
    
    // Variable width for colored portion (responsive)
    final coloredWidth = size.width - fixedTransparentWidth;
    
    // Vertical positioning
    final mainBoxY = (size.height - mainBoxHeight) / 2;

    if (isNegative) {
      // For negative amounts: stepped arrow pointing down
      
      // 1. Main horizontal box (contains amount) - no rounded corners
      final mainBoxRect = Rect.fromLTWH(0, mainBoxY, size.width, mainBoxHeight);
      canvas.drawRect(mainBoxRect, paint);
      
      // Draw transparent area on right side of main box
      final transparentRect1 = Rect.fromLTWH(coloredWidth, mainBoxY, fixedTransparentWidth, mainBoxHeight);
      canvas.drawRect(transparentRect1, backgroundPaint);

      // 2. Smaller rectangle below (aligned to right side of main box) - no gap
      final smallerBoxY = mainBoxY + mainBoxHeight; // No gap
      final smallerBoxX = coloredWidth - (coloredWidth * 0.35); // Align to right portion
      final smallerBoxWidth = coloredWidth * 0.3 + fixedTransparentWidth;
      
      final smallerBoxRect = Rect.fromLTWH(smallerBoxX, smallerBoxY, smallerBoxWidth, smallerBoxHeight);
      canvas.drawRect(smallerBoxRect, paint);
      
      // Draw transparent area on right side of smaller box
      final transparentRect2 = Rect.fromLTWH(coloredWidth, smallerBoxY, fixedTransparentWidth, smallerBoxHeight);
      canvas.drawRect(transparentRect2, backgroundPaint);

      // 3. Arrowhead pointing down (triangle) - shorter height, same width, centered on colored portion
      final coloredSmallerBoxWidth = coloredWidth * 0.35; // Width of colored portion only
      final arrowTipX = smallerBoxX + coloredSmallerBoxWidth / 2; // Center of colored portion
      final arrowHeadHeight = arrowHeadSize * 0.6; // Shorter height
      final arrowTipY = smallerBoxY + smallerBoxHeight + arrowHeadHeight; // Below smaller box
      final arrowWidth = arrowHeadSize; // Keep same width
      final arrowPath = Path()
        ..moveTo(arrowTipX, arrowTipY) // tip
        ..lineTo(arrowTipX - arrowWidth, smallerBoxY + smallerBoxHeight) // left
        ..lineTo(arrowTipX + arrowWidth, smallerBoxY + smallerBoxHeight) // right
        ..close();
      canvas.drawPath(arrowPath, paint);

    } else {
      // For positive amounts: stepped arrow pointing up
      
      // 1. Smaller rectangle above (aligned to right side)
      final smallerBoxY = mainBoxY - smallerBoxHeight;
      final smallerBoxX = coloredWidth - (coloredWidth * 0.35); // Match the negative case alignment
      final smallerBoxWidth = coloredWidth * 0.3 + fixedTransparentWidth;
      
      final smallerBoxRect = Rect.fromLTWH(smallerBoxX, smallerBoxY, smallerBoxWidth, smallerBoxHeight);
      canvas.drawRect(smallerBoxRect, paint);
      
      // Draw transparent area on right side of smaller box
      final transparentRect2 = Rect.fromLTWH(coloredWidth, smallerBoxY, fixedTransparentWidth, smallerBoxHeight);
      canvas.drawRect(transparentRect2, backgroundPaint);

      // 2. Main horizontal box (contains amount) - no rounded corners
      final mainBoxRect = Rect.fromLTWH(0, mainBoxY, size.width, mainBoxHeight);
      canvas.drawRect(mainBoxRect, paint);
      
      // Draw transparent area on right side of main box
      final transparentRect1 = Rect.fromLTWH(coloredWidth, mainBoxY, fixedTransparentWidth, mainBoxHeight);
      canvas.drawRect(transparentRect1, backgroundPaint);
      
      // 3. Arrowhead pointing left (triangle) - positioned on left side of main rectangle
      final arrowTipX = -(arrowHeadSize * 0.6); // Left of main box
      final arrowTipY = mainBoxY + mainBoxHeight / 2; // Center vertically on main box
      final arrowHeight = arrowHeadSize; // Keep same size
      final arrowPath = Path()
        ..moveTo(arrowTipX, arrowTipY) // tip pointing left
        ..lineTo(0, arrowTipY - arrowHeight) // top, connecting to main box left edge
        ..lineTo(0, arrowTipY + arrowHeight) // bottom, connecting to main box left edge
        ..close();
      canvas.drawPath(arrowPath, paint);
    }

    // Draw the amount text in the main horizontal box
    final textPainter = TextPainter(
      text: TextSpan(
        text: amount,
        style: TextStyle(
          fontSize: amountFontSize * 0.8,
          fontWeight: FontWeight.bold,
          color: AppColors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // Position text in the colored portion of the main box
    final textX = (coloredWidth - textPainter.width) / 2;
    final textY = mainBoxY + (mainBoxHeight - textPainter.height) / 2;
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void _drawArrowHead(
      Canvas canvas, Offset tip, double angle, double size, Paint paint) {
    const arrowHeadAngle = 0.4; // radians

    final arrowPoint1 = Offset(
      tip.dx - size * cos(angle - arrowHeadAngle),
      tip.dy - size * sin(angle - arrowHeadAngle),
    );

    final arrowPoint2 = Offset(
      tip.dx - size * cos(angle + arrowHeadAngle),
      tip.dy - size * sin(angle + arrowHeadAngle),
    );

    final arrowHeadPath = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    canvas.drawPath(arrowHeadPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
