import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom painter to draw curved text around a circle
class CurvedTextPainter extends CustomPainter {
  final String text;
  final Color color;
  final double fontSize;

  CurvedTextPainter({
    required this.text,
    required this.color,
    required this.fontSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Calculate the angle between each character
    final charCount = text.length;
    const totalAngle = math.pi; // Half circle (top half)
    final anglePerChar = totalAngle / (charCount - 1);
    
    // Start from the left side of the top half circle (-90 degrees + half of the total angle)
    const startAngle = -math.pi / 2 - totalAngle / 2;
    
    for (int i = 0; i < charCount; i++) {
      final char = text[i];
      final angle = startAngle + anglePerChar * i;
      
      // Calculate position on the circle
      final x = center.dx + (radius - fontSize) * math.cos(angle);
      final y = center.dy + (radius - fontSize) * math.sin(angle);
      
      // Create text painter
      final textPainter = TextPainter(
        text: TextSpan(
          text: char,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      // Layout the text
      textPainter.layout();
      
      // Calculate rotation angle (perpendicular to the radius)
      final rotationAngle = angle + math.pi / 2;
      
      // Save canvas state
      canvas.save();
      
      // Translate to the position and rotate
      canvas.translate(x, y);
      canvas.rotate(rotationAngle);
      
      // Draw the character centered
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
      
      // Restore canvas state
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
