import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../providers/analytics_provider.dart';

// Palette for course slices — rotates if more than 6 courses
const _kPalette = [
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFE53935), // red
  Color(0xFFFF9800), // orange
  Color(0xFF8E24AA), // purple
  Color(0xFF00ACC1), // teal
];

class CourseBreakdownPie extends StatefulWidget {
  final List<CourseStat> courses;
  final double? overallRate;

  const CourseBreakdownPie({
    super.key,
    required this.courses,
    this.overallRate,
  });

  @override
  State<CourseBreakdownPie> createState() => _CourseBreakdownPieState();
}

class _CourseBreakdownPieState extends State<CourseBreakdownPie> {
  int _touchedIndex = -1;

  List<CourseStat> get _validCourses =>
      widget.courses.where((c) => c.presentSessions > 0).toList();

  @override
  Widget build(BuildContext context) {
    if (_validCourses.isEmpty) {
      return SizedBox(
        height: 220,
        child: Center(
          child: Text('No attendance data yet',
              style: TextStyle(color: Colors.grey.shade500)),
        ),
      );
    }

    final total =
        _validCourses.fold<int>(0, (s, c) => s + c.presentSessions);

    return Row(
      children: [
        // Pie chart
        SizedBox(
          width: 180,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touchedIndex =
                            response?.touchedSection?.touchedSectionIndex ??
                                -1;
                      });
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: _validCourses.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final course = entry.value;
                    final isTouched = idx == _touchedIndex;
                    final color = _kPalette[idx % _kPalette.length];
                    final pct = (course.presentSessions / total * 100);

                    return PieChartSectionData(
                      value: course.presentSessions.toDouble(),
                      color: color,
                      radius: isTouched ? 58 : 48,
                      title: pct >= 12 ? '${pct.toInt()}%' : '',
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Center label
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(widget.overallRate ?? 0).toInt()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _rateColor(widget.overallRate ?? 0),
                    ),
                  ),
                  Text(
                    'overall',
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _validCourses.asMap().entries.map((entry) {
              final idx = entry.key;
              final course = entry.value;
              final color = _kPalette[idx % _kPalette.length];
              final isTouched = idx == _touchedIndex;

              return GestureDetector(
                onTap: () =>
                    setState(() => _touchedIndex = isTouched ? -1 : idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: EdgeInsets.symmetric(
                      horizontal: isTouched ? 10 : 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isTouched
                        ? color.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isTouched
                        ? Border.all(color: color.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              course.code,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isTouched
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${course.presentSessions} sessions attended',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${course.attendanceRate.toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _rateColor(course.attendanceRate),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 75) return Colors.orange;
    return Colors.red;
  }
}
