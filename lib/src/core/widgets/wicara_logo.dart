import 'package:flutter/material.dart';

import '../theme/wicara_colors.dart';

class WicaraLogo extends StatelessWidget {
  const WicaraLogo({
    this.markWidth = 116,
    this.markHeight = 62,
    this.wordSize = 31,
    super.key,
  });

  final double markWidth;
  final double markHeight;
  final double wordSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'WICARA',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(markWidth, markHeight),
            painter: const _WicaraMarkPainter(),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: 'WICARA'
                .split('')
                .map(
                  (letter) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5.5),
                    child: Text(
                      letter,
                      style: TextStyle(
                        color: WicaraColors.ink,
                        fontSize: wordSize,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _WicaraMarkPainter extends CustomPainter {
  const _WicaraMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final softBlue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.height * 0.34
      ..color = WicaraColors.periwinkle.withValues(alpha: 0.24);
    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.height * 0.34
      ..color = WicaraColors.secondary.withValues(alpha: 0.42);
    final violet = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.height * 0.34
      ..color = WicaraColors.secondaryLight.withValues(alpha: 0.7);

    final first = Path()
      ..moveTo(size.width * 0.14, size.height * 0.28)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.56,
        size.width * 0.29,
        size.height * 0.72,
        size.width * 0.38,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.47,
        size.height * 0.72,
        size.width * 0.50,
        size.height * 0.36,
        size.width * 0.58,
        size.height * 0.28,
      );

    final second = Path()
      ..moveTo(size.width * 0.36, size.height * 0.28)
      ..cubicTo(
        size.width * 0.44,
        size.height * 0.56,
        size.width * 0.51,
        size.height * 0.72,
        size.width * 0.60,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.36,
        size.width * 0.80,
        size.height * 0.28,
      );

    final third = Path()
      ..moveTo(size.width * 0.58, size.height * 0.28)
      ..cubicTo(
        size.width * 0.66,
        size.height * 0.56,
        size.width * 0.73,
        size.height * 0.72,
        size.width * 0.82,
        size.height * 0.72,
      )
      ..cubicTo(
        size.width * 0.88,
        size.height * 0.72,
        size.width * 0.92,
        size.height * 0.46,
        size.width * 0.94,
        size.height * 0.28,
      );

    canvas.drawPath(third, softBlue);
    canvas.drawPath(first, blue);
    canvas.drawPath(second, violet);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
