import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Subtle dot pattern like [escrow_web] `.pattern-bg`.
class PatternBackground extends StatelessWidget {
  const PatternBackground({super.key, this.opacity = 0.05});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _PatternPainter(opacity: opacity),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = AppColors.gambianRed.withOpacity(opacity);
    final blue = Paint()..color = AppColors.gambianBlue.withOpacity(opacity);
    const step = 20.0;
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1, red);
        canvas.drawCircle(Offset(x + step / 2, y + step / 2), 1, blue);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
