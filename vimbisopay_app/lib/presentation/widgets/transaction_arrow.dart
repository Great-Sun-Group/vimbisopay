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
      pointsRight; // true = arrow points right, false = arrow points left
  final Color arrowColor;
  final double strokeWidth;

  HollowArrowPainter({
    required this.pointsRight,
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

    if (pointsRight) {
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

class AmountWithArrow extends StatelessWidget {
  final String amount;
  final String? denomination;
  final Color amountColor;
  final Color arrowColor;
  final double amountFontSize;
  final double containerSize;
  final bool
      pointsRight; // true = arrow points right, false = arrow points left

  // New independent layout and canvas parameters
  final double? layoutWidth;
  final double? layoutHeight;
  final double? canvasWidth;
  final double? canvasHeight;

  const AmountWithArrow({
    super.key,
    required this.amount,
    this.denomination,
    required this.amountColor,
    required this.arrowColor,
    this.amountFontSize = 24.0,
    this.containerSize = 80.0,
    required this.pointsRight,
    // New independent layout parameters
    this.layoutWidth,
    this.layoutHeight,
    // New independent canvas parameters
    this.canvasWidth,
    this.canvasHeight,
  });

  @override
  Widget build(BuildContext context) {
    // Use new independent parameters if provided, otherwise fallback to containerSize
    final effectiveLayoutWidth = layoutWidth ?? containerSize;
    final effectiveLayoutHeight = layoutHeight ?? containerSize * 0.8;
    final effectiveCanvasWidth = canvasWidth ?? containerSize * 0.9;
    final effectiveCanvasHeight = canvasHeight ?? containerSize * 0.6;

    return SizedBox(
      width: effectiveLayoutWidth,
      height: effectiveLayoutHeight,
      child: CustomPaint(
        size: Size(effectiveCanvasWidth, effectiveCanvasHeight),
        painter: LShapedArrowPainter(
          amount: amount,
          denomination: denomination,
          amountColor: amountColor,
          arrowColor: arrowColor,
          amountFontSize: amountFontSize,
          pointsRight: pointsRight,
        ),
      ),
    );
  }
}

/// Custom painter for L-shaped arrow with amount box
class LShapedArrowPainter extends CustomPainter {
  final String amount;
  final String? denomination;
  final Color amountColor;
  final Color arrowColor;
  final double amountFontSize;
  final bool pointsRight;

  LShapedArrowPainter({
    required this.amount,
    this.denomination,
    required this.amountColor,
    required this.arrowColor,
    required this.amountFontSize,
    required this.pointsRight,
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
    final mainBoxHeight = size.height * 0.85; // Taller for denomination
    final smallerBoxHeight = size.height * 0.1;
    final arrowHeadSize = 35.0; // Larger arrow head

    // Variable width for colored portion (responsive)
    final coloredWidth = size.width - fixedTransparentWidth;

    // Vertical positioning - more top/bottom space
    final mainBoxY = size.height * 0; // More top margin

    // Define variables that will be set based on direction
    late final double horizontalOffset;
    late final double mainBoxWidth;

    if (pointsRight) {
      // For negative amounts: arrow pointing RIGHT (issuer on left)

      // Add horizontal offset to shift entire arrow right
      horizontalOffset = coloredWidth * 0.0;

      // 1. Main horizontal box (contains amount) - positioned on left
      mainBoxWidth =
          coloredWidth * 0.8; // Shorter than before, just enough for text
      final mainBoxRect = Rect.fromLTWH(
          horizontalOffset, mainBoxY, mainBoxWidth, mainBoxHeight);
      canvas.drawRect(mainBoxRect, paint);

      // Draw transparent area on the left and right of the box
      final transparentRect1 =
          Rect.fromLTWH(0, mainBoxY, horizontalOffset, mainBoxHeight);
      canvas.drawRect(transparentRect1, backgroundPaint);
      final transparentRect2 = Rect.fromLTWH(
          horizontalOffset + mainBoxWidth,
          mainBoxY,
          size.width - (horizontalOffset + mainBoxWidth),
          mainBoxHeight);
      canvas.drawRect(transparentRect2, backgroundPaint);

      // 2. Arrowhead pointing right (triangle) - positioned on right side of main rectangle
      final arrowTipX = horizontalOffset +
          mainBoxWidth +
          (arrowHeadSize * 0.6); // Tip right of box
      final arrowTipY =
          mainBoxY + mainBoxHeight / 2; // Center vertically on main box
      final arrowHeight = arrowHeadSize; // Keep same size
      final arrowPath = Path()
        ..moveTo(arrowTipX, arrowTipY) // tip pointing right
        ..lineTo(horizontalOffset + mainBoxWidth,
            arrowTipY - arrowHeight) // top, connecting to box right edge
        ..lineTo(horizontalOffset + mainBoxWidth,
            arrowTipY + arrowHeight) // bottom, connecting to box right edge
        ..close();
      canvas.drawPath(arrowPath, paint);
    } else {
      // For positive amounts: arrow pointing LEFT (issuer on right)

      horizontalOffset = 0.0; // Not used for left arrow
      mainBoxWidth =
          coloredWidth * 0.8; // Shorter than before, just enough for text

      // 1. Main horizontal box (contains amount) - positioned on right
      final mainBoxRect = Rect.fromLTWH(
          size.width - mainBoxWidth, mainBoxY, mainBoxWidth, mainBoxHeight);
      canvas.drawRect(mainBoxRect, paint);

      // Draw transparent area on the left of the box
      final transparentRect1 =
          Rect.fromLTWH(0, mainBoxY, size.width - mainBoxWidth, mainBoxHeight);
      canvas.drawRect(transparentRect1, backgroundPaint);

      // 2. Arrowhead pointing left (triangle) - positioned on left side of main rectangle
      final arrowTipX =
          size.width - mainBoxWidth - (arrowHeadSize * 0.6); // Tip left of box
      final arrowTipY =
          mainBoxY + mainBoxHeight / 2; // Center vertically on main box
      final arrowHeight = arrowHeadSize; // Keep same size
      final arrowPath = Path()
        ..moveTo(arrowTipX, arrowTipY) // tip pointing left
        ..lineTo(size.width - mainBoxWidth,
            arrowTipY - arrowHeight) // top, connecting to box left edge
        ..lineTo(size.width - mainBoxWidth,
            arrowTipY + arrowHeight) // bottom, connecting to box left edge
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

    // Position text in the colored portion of the main box (moved up)
    final textX = (coloredWidth - textPainter.width) / 2;
    final textY = mainBoxY + (mainBoxHeight - textPainter.height) / 3.5; // Moved up more
    textPainter.paint(canvas, Offset(textX, textY));

    // Draw denomination text below amount within the colored box
    if (denomination != null && denomination!.isNotEmpty) {
      final denominationPainter = TextPainter(
        text: TextSpan(
          text: denomination,
          style: TextStyle(
            fontSize: amountFontSize * 0.6, // A little bigger than before
            fontWeight: FontWeight.w500,
            color: AppColors.white.withOpacity(0.8),
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right, // Right aligned
      );
      denominationPainter.layout();

      // Calculate colored box bounds
      final boxLeft =
          pointsRight ? horizontalOffset : size.width - mainBoxWidth;
      final boxRight =
          pointsRight ? horizontalOffset + mainBoxWidth : size.width;

      // Position denomination under the right side of the amount, right-aligned
      final denominationX = textX +
          textPainter.width -
          denominationPainter.width; // Right edge of amount text
      final denominationY =
          textY + textPainter.height - 2; // Closer to amount
      denominationPainter.paint(canvas, Offset(denominationX, denominationY));
    }
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
