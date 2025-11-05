import 'package:flutter/material.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? unit;
  final IconData? icon;
  final TrendData? trend;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.unit,
    this.icon,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (unit != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          unit!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (trend != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${trend!.isPositive ? '↑' : '↓'} ${trend!.value.abs()}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: trend!.isPositive
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (icon != null)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TrendData {
  final double value;
  final bool isPositive;

  const TrendData({
    required this.value,
    required this.isPositive,
  });
}

