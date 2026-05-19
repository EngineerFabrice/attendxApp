import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/analytics_provider.dart';

class AttendanceTrendChart extends StatefulWidget {
  final List<TrendDataPoint> data;

  const AttendanceTrendChart({super.key, required this.data});

  @override
  State<AttendanceTrendChart> createState() => _AttendanceTrendChartState();
}

class _AttendanceTrendChartState extends State<AttendanceTrendChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _EmptyChart(
        message: 'No attendance data for this period',
        icon: Icons.bar_chart_outlined,
      );
    }

    // Limit to last 30 entries for readability
    final display = widget.data.length > 30
        ? widget.data.sublist(widget.data.length - 30)
        : widget.data;

    final barWidth = display.length <= 10
        ? 18.0
        : display.length <= 20
            ? 12.0
            : 8.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Legend(),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: 1.25,
              minY: 0,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedIndex = response?.spot?.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) =>
                      Colors.black.withValues(alpha: 0.75),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = display[groupIndex];
                    final (label, color) = switch (point.status) {
                      'present' => ('✓ Present', Colors.greenAccent),
                      'late'    => ('⏱ Late',    Colors.orangeAccent),
                      _         => ('✗ Absent',  Colors.redAccent),
                    };
                    return BarTooltipItem(
                      '${DateFormat('MMM d').format(point.date)}\n',
                      const TextStyle(color: Colors.white70, fontSize: 11),
                      children: [
                        TextSpan(
                          text: label,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= display.length) {
                        return const SizedBox.shrink();
                      }
                      // Show label every N entries to avoid crowding
                      final step = display.length <= 10
                          ? 1
                          : display.length <= 20
                              ? 2
                              : 5;
                      if (idx % step != 0 && idx != display.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('d/M').format(display[idx].date),
                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 0.5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: display.asMap().entries.map((entry) {
                final idx   = entry.key;
                final point = entry.value;
                final isTouched = idx == _touchedIndex;
                final (barColor, barHeight) = switch (point.status) {
                  'present' => (isTouched ? Colors.green.shade300  : Colors.green.shade500,  1.0),
                  'late'    => (isTouched ? Colors.orange.shade300 : Colors.orange.shade500, 0.65),
                  _         => (isTouched ? Colors.red.shade300    : Colors.red.shade400,    0.18),
                };

                return BarChartGroupData(
                  x: idx,
                  barRods: [
                    BarChartRodData(
                      toY: barHeight,
                      color: barColor,
                      width: isTouched ? barWidth + 2 : barWidth,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _AttendanceSummaryBar(data: display),
      ],
    );
  }
}

// Shows present/absent ratio as a mini progress bar
class _AttendanceSummaryBar extends StatelessWidget {
  final List<TrendDataPoint> data;
  const _AttendanceSummaryBar({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final presentCount = data.where((d) => d.status == 'present').length;
    final lateCount    = data.where((d) => d.status == 'late').length;
    final attendedCount = presentCount + lateCount;
    final rate = attendedCount / data.length;

    return Row(
      children: [
        Text('${(rate * 100).toInt()}%',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _rateColor(rate * 100))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 6,
              backgroundColor: Colors.red.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(
                  _rateColor(rate * 100)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          lateCount > 0
              ? '$presentCount on-time · $lateCount late / ${data.length}'
              : '$attendedCount/${data.length} sessions',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
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

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Dot(color: Colors.green.shade500),
        const SizedBox(width: 4),
        const Text('On-time', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 12),
        _Dot(color: Colors.orange.shade500),
        const SizedBox(width: 4),
        const Text('Late', style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(width: 12),
        _Dot(color: Colors.red.shade400),
        const SizedBox(width: 4),
        const Text('Absent', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _EmptyChart extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyChart({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            Text(message,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
