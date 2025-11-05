import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/stat_card.dart';

class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Water Usage Statistics',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Analyze your irrigation efficiency and patterns',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 768) {
              return const Row(
                children: [
                  Expanded(
                    child: StatCard(
                      title: 'Average Flow Rate',
                      value: '2.3',
                      unit: 'L/min',
                      icon: Icons.water_drop,
                      trend: TrendData(value: 8, isPositive: true),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Total This Week',
                      value: '155',
                      unit: 'liters',
                      icon: Icons.trending_up,
                      trend: TrendData(value: 12, isPositive: true),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: StatCard(
                      title: 'Efficiency',
                      value: '94',
                      unit: '%',
                      icon: Icons.show_chart,
                      trend: TrendData(value: 3, isPositive: true),
                    ),
                  ),
                ],
              );
            } else {
              return const Column(
                children: [
                  StatCard(
                    title: 'Average Flow Rate',
                    value: '2.3',
                    unit: 'L/min',
                    icon: Icons.water_drop,
                    trend: TrendData(value: 8, isPositive: true),
                  ),
                  SizedBox(height: 16),
                  StatCard(
                    title: 'Total This Week',
                    value: '155',
                    unit: 'liters',
                    icon: Icons.trending_up,
                    trend: TrendData(value: 12, isPositive: true),
                  ),
                  SizedBox(height: 16),
                  StatCard(
                    title: 'Efficiency',
                    value: '94',
                    unit: '%',
                    icon: Icons.show_chart,
                    trend: TrendData(value: 3, isPositive: true),
                  ),
                ],
              );
            }
          },
        ),
        const SizedBox(height: 24),

        // Water Usage Trend
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Water Usage Trend',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 1,
                            dashArray: [5, 5],
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
                            getTitlesWidget: (value, meta) {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              if (value.toInt() >= 0 && value.toInt() < days.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    days[value.toInt()],
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: 6,
                      minY: 0,
                      maxY: 50,
                      lineBarsData: [
                        LineChartBarData(
                          spots: const [
                            FlSpot(0, 10),
                            FlSpot(1, 15),
                            FlSpot(2, 20),
                            FlSpot(3, 18),
                            FlSpot(4, 22),
                            FlSpot(5, 25),
                            FlSpot(6, 45),
                          ],
                          isCurved: true,
                          color: const Color(0xFF0EA5E9),
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 5,
                                color: const Color(0xFF0EA5E9),
                                strokeWidth: 2,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFF0EA5E9).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Scheduled vs Actual
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled vs Actual Irrigation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: BarChart(
                    BarChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 5,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[300]!,
                            strokeWidth: 1,
                            dashArray: [5, 5],
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
                            getTitlesWidget: (value, meta) {
                              const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                              if (value.toInt() >= 0 && value.toInt() < days.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    days[value.toInt()],
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toInt().toString(),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _buildBarGroup(0, 10, 12),
                        _buildBarGroup(1, 15, 14),
                        _buildBarGroup(2, 20, 18),
                        _buildBarGroup(3, 18, 16),
                        _buildBarGroup(4, 22, 20),
                        _buildBarGroup(5, 25, 22),
                        _buildBarGroup(6, 45, 40),
                      ],
                      maxY: 50,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Irrigation Events Table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Irrigation Events',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                    dataRowMinHeight: 48,
                    dataRowMaxHeight: 48,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Time')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Volume')),
                    ],
                    rows: const [
                      DataRow(cells: [
                        DataCell(Text('2025-10-30')),
                        DataCell(Text('08:00')),
                        DataCell(Text('15 min')),
                        DataCell(Text('25 liters', style: TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('2025-10-29')),
                        DataCell(Text('08:00')),
                        DataCell(Text('15 min')),
                        DataCell(Text('22 liters', style: TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('2025-10-28')),
                        DataCell(Text('08:00')),
                        DataCell(Text('15 min')),
                        DataCell(Text('18 liters', style: TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                      DataRow(cells: [
                        DataCell(Text('2025-10-27')),
                        DataCell(Text('08:00')),
                        DataCell(Text('15 min')),
                        DataCell(Text('20 liters', style: TextStyle(fontWeight: FontWeight.w600))),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _buildBarGroup(int x, double actual, double scheduled) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: scheduled,
          color: Colors.grey[400]!,
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
        BarChartRodData(
          toY: actual,
          color: const Color(0xFF0EA5E9),
          width: 12,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
          ),
        ),
      ],
      barsSpace: 4,
    );
  }
}

