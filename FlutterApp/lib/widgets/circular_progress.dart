import 'package:flutter/material.dart';
import 'dart:math' as math;

class CircularProgress extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final double strokeWidth;
  final String label;
  final String unit;

  const CircularProgress({
    super.key,
    required this.value,
    required this.max,
    this.size = 240,
    this.strokeWidth = 12,
    this.label = 'Usage',
    this.unit = 'liters',
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / max) * 100;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: CircularProgressPainter(
              value: value,
              max: max,
              strokeWidth: strokeWidth,
              primaryColor: theme.colorScheme.primary,
              mutedColor: isDark ? const Color(0xFF334155) : Colors.grey[200]!,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'of ${max.toStringAsFixed(0)} $unit',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double value;
  final double max;
  final double strokeWidth;
  final Color primaryColor;
  final Color mutedColor;

  CircularProgressPainter({
    required this.value,
    required this.max,
    required this.strokeWidth,
    required this.primaryColor,
    required this.mutedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final percentage = (value / max).clamp(0.0, 1.0);

    // Background circle
    final backgroundPaint = Paint()
      ..color = mutedColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.max != max;
  }
}

