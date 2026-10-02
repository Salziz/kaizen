import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The official Kaizen brand logo widget displaying the interlocking
/// continuous improvement loop emblem in front of the lowercase `kaizen` wordmark.
class KaizenLogo extends StatelessWidget {
  const KaizenLogo({
    super.key,
    this.size = 28,
    this.color = Colors.white,
    this.showWordmark = true,
    this.fontSize = 17,
    this.letterSpacing = -0.5,
  });

  final double size;
  final Color color;
  final bool showWordmark;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: KaizenEmblemPainter(color: color),
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(width: 8),
          Text(
            'kaizen',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: letterSpacing,
              height: 1.0,
            ),
          ),
        ],
      ],
    );
  }
}

/// Paints the Concept 2 interlocking continuous refinement loops emblem.
class KaizenEmblemPainter extends CustomPainter {
  const KaizenEmblemPainter({this.color = Colors.white});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeW = w * 0.16;

    final paintStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(w / 2, h / 2);

    canvas.save();
    // Rotate canvas slightly to align the loop diagonally (-25 degrees)
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 7.2);

    final loopWidth = w * 0.44;
    final loopHeight = h * 0.32;
    final cornerRadius = Radius.circular(loopHeight / 2);

    // Left rounded loop
    final leftRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(-loopWidth * 0.32, 0),
        width: loopWidth,
        height: loopHeight,
      ),
      cornerRadius,
    );

    // Right rounded loop
    final rightRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(loopWidth * 0.32, 0),
        width: loopWidth,
        height: loopHeight,
      ),
      cornerRadius,
    );

    canvas.drawRRect(leftRect, paintStroke);
    canvas.drawRRect(rightRect, paintStroke);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KaizenEmblemPainter oldDelegate) =>
      oldDelegate.color != color;
}
