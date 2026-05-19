import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/dashboard_provider.dart';
import 'widgets/active_session_card.dart';
import 'widgets/attendance_summary_card.dart';
import '../../../../shared/widgets/main_bottom_nav.dart';
import '../../../../shared/widgets/offline_banner.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.isOffline)
                  const OfflineBanner(showSyncQueue: true),
                const SyncStatusCard(),
                Expanded(child: RefreshIndicator(
              onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      'Hello, ${state.profile?.fullName.split(' ').first ?? 'Student'}!',
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Reg: ${state.profile?.regNumber ?? 'N/A'}',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 24),

                    // Attendance summary
                    AttendanceSummaryCard(
                      rate: state.overallAttendanceRate ?? 0,
                    ),
                    const SizedBox(height: 24),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            title: 'Courses',
                            value: '${state.profile?.enrolledCourses ?? 0}',
                            icon: Icons.book_outlined,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            title: 'Attendance',
                            value:
                                '${state.overallAttendanceRate?.toInt() ?? 0}%',
                            icon: Icons.trending_up,
                            color: (state.overallAttendanceRate ?? 0) >= 75
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Quick links row
                    Row(
                      children: [
                        _QuickLink(
                          icon: Icons.school_outlined,
                          label: 'My Courses',
                          color: Colors.blue,
                          onTap: () =>
                              Navigator.pushNamed(context, '/courses'),
                        ),
                        const SizedBox(width: 12),
                        _QuickLink(
                          icon: Icons.bar_chart_outlined,
                          label: 'Analytics',
                          color: Colors.purple,
                          onTap: () =>
                              Navigator.pushNamed(context, '/analytics'),
                        ),
                        const SizedBox(width: 12),
                        _QuickLink(
                          icon: Icons.history_outlined,
                          label: 'History',
                          color: Colors.teal,
                          onTap: () =>
                              Navigator.pushNamed(context, '/history'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Today's Classes
                    const Text(
                      "Today's Classes",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),

                    if (state.todaySessions.isEmpty)
                      _EmptyClassesCard()
                    else
                      ...state.todaySessions.map((session) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ActiveSessionCard(session: session),
                          )),
                  ],
                ),
              ),
            )),
              ],
            ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 0),
    );
  }
}

class _EmptyClassesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No classes today',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 4),
            Text('Check back during class time',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickLink({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
