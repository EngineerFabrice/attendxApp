import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../providers/analytics_provider.dart';

class CourseBarChart extends StatefulWidget {
  final List<CourseStat> courses;

  const CourseBarChart({super.key, required this.courses});

  @override
  State<CourseBarChart> createState() => _CourseBarChartState();
}

class _CourseBarChartState extends State<CourseBarChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.courses.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('No course data')),
      );
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: 110,
          minY: 0,
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              setState(() {
                _touchedIndex =
                    response?.spot?.touchedBarGroupIndex;
              });
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) =>
                  Colors.black.withValues(alpha: 0.8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final course = widget.courses[groupIndex];
                return BarTooltipItem(
                  '${course.name}\n',
                  const TextStyle(
                      color: Colors.white70, fontSize: 11),
                  children: [
                    TextSpan(
                      text:
                          '${course.attendanceRate.toInt()}%  (${course.presentSessions}/${course.totalSessions})',
                      style: TextStyle(
                        color: _rateColor(course.attendanceRate),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              // Bold dashed line at 75% threshold
              if (value == 75) {
                return FlLine(
                  color: Colors.orange.withValues(alpha: 0.6),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                );
              }
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.12),
                strokeWidth: 1,
              );
            },
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 25,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value > 100) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(
                        fontSize: 9, color: Colors.grey),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= widget.courses.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      widget.courses[idx].code,
                      style: const TextStyle(
                          fontSize: 9, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: widget.courses.asMap().entries.map((entry) {
            final idx = entry.key;
            final course = entry.value;
            final isTouched = idx == _touchedIndex;
            final color = _rateColor(course.attendanceRate);

            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: course.attendanceRate,
                  color: isTouched
                      ? color.withValues(alpha: 0.7)
                      : color,
                  width: isTouched ? 26 : 22,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: Colors.grey.withValues(alpha: 0.07),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 80) return Colors.green.shade500;
    if (rate >= 75) return Colors.orange;
    return Colors.red.shade400;
  }
}
