import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/analytics_provider.dart';
import 'widgets/attendance_trend_chart.dart';
import 'widgets/course_breakdown_pie.dart';
import 'widgets/course_bar_chart.dart';
import 'widgets/summary_stats_row.dart';
import '../../../../shared/widgets/main_bottom_nav.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  // 0 = Bar chart, 1 = Pie chart
  int _courseViewIndex = 0;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);
    final notifier = ref.read(analyticsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      bottomNavigationBar: const MainBottomNav(currentIndex: 2),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => notifier.loadAnalytics(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Risk Alert ────────────────────────────────────────
                    if (state.atRiskCourses.isNotEmpty) ...[
                      _RiskAlertBanner(courses: state.atRiskCourses),
                      const SizedBox(height: 16),
                    ],

                    // ── Overall Rate ──────────────────────────────────────
                    _OverallRateCard(rate: state.overallRate ?? 0),
                    const SizedBox(height: 12),

                    // ── Summary Stats ─────────────────────────────────────
                    SummaryStatsRow(
                      totalSessions: state.totalSessions,
                      totalPresent: state.totalPresent,
                      totalLate: state.totalLate,
                      totalAbsent: state.totalAbsent,
                    ),
                    const SizedBox(height: 16),

                    // ── Streak Cards ──────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _StreakCard(
                            label: 'Current Streak',
                            value: state.currentStreak,
                            icon: Icons.local_fire_department,
                            color: state.currentStreak >= 5
                                ? Colors.orange
                                : Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StreakCard(
                            label: 'Best Streak',
                            value: state.longestStreak,
                            icon: Icons.emoji_events,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Attendance Trend ──────────────────────────────────
                    Row(
                      children: [
                        const Text(
                          'Attendance Trend',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        _PeriodToggle(
                          selected: state.trendPeriod,
                          onChanged: notifier.setTrendPeriod,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                        child: AttendanceTrendChart(
                            data: state.filteredTrendData),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Course Breakdown ──────────────────────────────────
                    Row(
                      children: [
                        const Text(
                          'Course Breakdown',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        _ChartToggle(
                          selected: _courseViewIndex,
                          onChanged: (v) =>
                              setState(() => _courseViewIndex = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _courseViewIndex == 0
                            ? CourseBarChart(courses: state.courseStats)
                            : CourseBreakdownPie(
                                courses: state.courseStats,
                                overallRate: state.overallRate,
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Per-course detail list ────────────────────────────
                    const Text(
                      'Per-Course Detail',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    ...state.courseStats.map((course) =>
                        _CourseDetailCard(course: course)),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Period toggle ─────────────────────────────────────────────────────────────

class _PeriodToggle extends StatelessWidget {
  final TrendPeriod selected;
  final ValueChanged<TrendPeriod> onChanged;

  const _PeriodToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final options = [
      (TrendPeriod.week, '7d'),
      (TrendPeriod.month, '30d'),
      (TrendPeriod.all, 'All'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = selected == opt.$1;
          return GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                opt.$2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Chart type toggle ─────────────────────────────────────────────────────────

class _ChartToggle extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _ChartToggle(
      {required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleBtn(
          icon: Icons.bar_chart,
          active: selected == 0,
          onTap: () => onChanged(0),
          tooltip: 'Bar chart',
        ),
        const SizedBox(width: 4),
        _ToggleBtn(
          icon: Icons.pie_chart_outline,
          active: selected == 1,
          onTap: () => onChanged(1),
          tooltip: 'Pie chart',
        ),
      ],
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  const _ToggleBtn({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: active
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? primary.withValues(alpha: 0.3)
                  : Colors.grey.shade300,
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: active ? primary : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

// ── Overall rate card ─────────────────────────────────────────────────────────

class _OverallRateCard extends StatelessWidget {
  final double rate;
  const _OverallRateCard({required this.rate});

  @override
  Widget build(BuildContext context) {
    final color = _rateColor(rate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Circular indicator
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: rate / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeWidth: 7,
                  ),
                  Text(
                    '${rate.toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overall Attendance',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rate >= 80
                        ? 'Excellent — keep it up!'
                        : rate >= 75
                            ? 'On track — minimum met'
                            : 'Below 75% — at risk of failing',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                  const SizedBox(height: 8),
                  // Threshold markers
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: rate / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                          minHeight: 8,
                        ),
                      ),
                      // 75% marker
                      Positioned(
                        left: MediaQuery.of(context).size.width *
                            0.75 *
                            0.45, // approximate
                        child: Container(
                          width: 2,
                          height: 8,
                          color: Colors.orange.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text('75% minimum',
                      style: TextStyle(
                          fontSize: 9, color: Colors.orange)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 75) return Colors.orange;
    return Colors.red;
  }
}

// ── Streak card ───────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StreakCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: color),
            ),
            Text(
              label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            Text(
              value == 1 ? 'session' : 'sessions',
              style:
                  TextStyle(fontSize: 10, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Course detail card ────────────────────────────────────────────────────────

class _CourseDetailCard extends StatelessWidget {
  final CourseStat course;
  const _CourseDetailCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final color = _rateColor(course.attendanceRate);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(course.code,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                if (course.isAtRisk)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text('At Risk',
                        style: TextStyle(
                            fontSize: 10,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                Text(
                  '${course.attendanceRate.toInt()}%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: course.attendanceRate / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${course.presentSessions} on-time',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                ),
                if (course.lateSessions > 0) ...[
                  Text('  ·  ',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade400)),
                  Text(
                    '${course.lateSessions} late',
                    style: TextStyle(
                        fontSize: 11, color: Colors.orange.shade700),
                  ),
                ],
                Text('  ·  ',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
                Text(
                  'of ${course.totalSessions} sessions',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
            if (course.lateThresholdMinutes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Late after ${course.lateThresholdMinutes} min',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _rateColor(double rate) {
    if (rate >= 80) return Colors.green;
    if (rate >= 75) return Colors.orange;
    return Colors.red;
  }
}

// ── Risk alert ────────────────────────────────────────────────────────────────

class _RiskAlertBanner extends StatelessWidget {
  final List<CourseStat> courses;
  const _RiskAlertBanner({required this.courses});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.red.shade700, size: 18),
              const SizedBox(width: 6),
              Text(
                'Attendance Risk Alert',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '• ${c.name} — ${c.attendanceRate.toInt()}% (below 75%)',
                  style:
                      TextStyle(fontSize: 13, color: Colors.red.shade800),
                ),
              )),
        ],
      ),
    );
  }
}
