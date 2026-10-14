import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A single labelled value used by [SimpleBarChart].
class ChartSlice {
  const ChartSlice({required this.label, required this.value});

  final String label;
  final double value;
}

const _barPalette = <Color>[
  Color(0xFF3F51B5),
  Color(0xFF009688),
  Color(0xFFE91E63),
  Color(0xFFFF9800),
  Color(0xFF9C27B0),
  Color(0xFF03A9F4),
  Color(0xFF795548),
  Color(0xFF607D8B),
];

/// A compact vertical bar chart with a colour-coded legend underneath.
///
/// Deliberately axis-label free so long category names cannot overflow; the
/// legend carries the names instead.
class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({super.key, required this.slices, this.height = 180});

  final List<ChartSlice> slices;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (slices.isEmpty) return const SizedBox.shrink();
    final maxValue = slices
        .map((s) => s.value)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxValue <= 0 ? 1 : maxValue * 1.15,
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(enabled: false),
              barGroups: [
                for (var i = 0; i < slices.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: slices[i].value,
                        width: 18,
                        borderRadius: BorderRadius.circular(4),
                        color: _barPalette[i % _barPalette.length],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            for (var i = 0; i < slices.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _barPalette[i % _barPalette.length],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(slices[i].label, style: theme.textTheme.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A smooth line chart with a subtle fill, y-axis labels and short x labels.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({super.key, required this.points, this.height = 180});

  final List<ChartSlice> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.length < 2) return const SizedBox.shrink();

    final values = points.map((p) => p.value).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span = (maxValue - minValue).abs();
    final pad = span == 0 ? (maxValue.abs() * 0.05 + 1) : span * 0.15;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: minValue - pad,
          maxY: maxValue + pad,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget:
                    (value, meta) => Text(
                      value.toStringAsFixed(1),
                      style: theme.textTheme.bodySmall,
                    ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length || index != value) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      points[index].label,
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < points.length; i++)
                  FlSpot(i.toDouble(), points[i].value),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              barWidth: 3,
              color: theme.colorScheme.primary,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
