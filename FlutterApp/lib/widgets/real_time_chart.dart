import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/irrigation_provider.dart';
import '../models/live_data_point.dart';

/// Real-time line chart for flow rate
class RealTimeFlowChart extends StatelessWidget {
  final Duration timeRange;
  final double height;

  const RealTimeFlowChart({
    super.key,
    this.timeRange = const Duration(hours: 1),
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final dataPoints = provider.getFlowRateForRange(timeRange);
        
        if (dataPoints.isEmpty) {
          return SizedBox(
            height: height,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.water_drop_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for real-time data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: 1,
                verticalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
                getDrawingVerticalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: timeRange.inMinutes / 4,
                    getTitlesWidget: (value, meta) {
                      final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              minX: dataPoints.first.milliseconds.toDouble(),
              maxX: dataPoints.last.milliseconds.toDouble(),
              minY: 0,
              maxY: _getMaxY(dataPoints),
              lineBarsData: [
                LineChartBarData(
                  spots: dataPoints.map((point) {
                    return FlSpot(
                      point.milliseconds.toDouble(),
                      point.value,
                    );
                  }).toList(),
                  isCurved: true,
                  color: const Color(0xFF3B82F6),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF3B82F6).withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final time = DateTime.fromMillisecondsSinceEpoch(
                        spot.x.toInt(),
                      );
                      return LineTooltipItem(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}\n${spot.y.toStringAsFixed(2)} L/min',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  double _getMaxY(List<ChartDataPoint> points) {
    if (points.isEmpty) return 5.0;
    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    return (maxValue * 1.2).ceilToDouble(); // 20% padding
  }
}

/// Real-time line chart for water usage
class RealTimeWaterUsageChart extends StatelessWidget {
  final Duration timeRange;
  final double height;

  const RealTimeWaterUsageChart({
    super.key,
    this.timeRange = const Duration(hours: 24),
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        final dataPoints = provider.getWaterUsageForRange(timeRange);
        
        if (dataPoints.isEmpty) {
          return SizedBox(
            height: height,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for water usage data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                horizontalInterval: 10,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.2),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                      return Text(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}L',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: dataPoints.map((point) {
                    return FlSpot(
                      point.milliseconds.toDouble(),
                      point.value,
                    );
                  }).toList(),
                  isCurved: true,
                  color: const Color(0xFF10B981),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final time = DateTime.fromMillisecondsSinceEpoch(
                        spot.x.toInt(),
                      );
                      return LineTooltipItem(
                        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}\n${spot.y.toStringAsFixed(1)} L',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Real-time statistics card
class RealTimeStatsCard extends StatelessWidget {
  const RealTimeStatsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<IrrigationProvider>(
      builder: (context, provider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Real-Time Statistics',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Statistics Grid
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Current Flow',
                        value: provider.flowRate.toStringAsFixed(2),
                        unit: 'L/min',
                        icon: Icons.speed,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatItem(
                        label: 'Average Flow',
                        value: provider.averageFlowRate.toStringAsFixed(2),
                        unit: 'L/min',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Peak Flow',
                        value: provider.peakFlowRate.toStringAsFixed(2),
                        unit: 'L/min',
                        icon: Icons.arrow_upward,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatItem(
                        label: 'Data Points',
                        value: provider.flowRateHistory.length.toString(),
                        unit: 'pts',
                        icon: Icons.data_usage,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Moisture Level Card
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        label: 'Soil Moisture',
                        value: provider.soilMoisture.toStringAsFixed(1),
                        unit: '%',
                        icon: Icons.water_drop,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatItem(
                        label: 'Temperature',
                        value: provider.temperature.toStringAsFixed(1),
                        unit: '°C',
                        icon: Icons.thermostat,
                        color: Colors.deepOrange,
                      ),
                    ),
                  ],
                ),
                
                // Last Update
                if (provider.lastPumpUpdate != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Last update: ${_formatTime(provider.lastPumpUpdate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

