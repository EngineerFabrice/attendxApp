import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'providers/history_provider.dart';
import 'widgets/attendance_list_item.dart';
import '../../../../shared/widgets/main_bottom_nav.dart';
import '../../../../shared/widgets/offline_banner.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final notifier = ref.read(historyProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance History'),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 1),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (state.isOffline)
                  OfflineBanner(cachedAt: state.cachedAt),
                Expanded(child: RefreshIndicator(
              onRefresh: () => notifier.loadHistory(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Calendar ──────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: TableCalendar<AttendanceRecord>(
                      firstDay: DateTime.now().subtract(const Duration(days: 180)),
                      lastDay: DateTime.now(),
                      focusedDay: state.focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) =>
                          state.selectedDay != null &&
                          isSameDay(state.selectedDay!, day),
                      eventLoader: (day) {
                        final key = DateTime.utc(day.year, day.month, day.day);
                        return state.eventsMap[key] ?? [];
                      },
                      onDaySelected: (selected, focused) {
                        notifier.selectDay(selected);
                      },
                      onFormatChanged: (format) {
                        setState(() => _calendarFormat = format);
                      },
                      onPageChanged: (focused) {
                        // update focused day without selecting
                      },
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return const SizedBox.shrink();
                          final hasPresent =
                              events.any((e) => e.status == 'present');
                          final hasAbsent =
                              events.any((e) => e.status == 'absent');
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasPresent)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                ),
                              if (hasAbsent)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.red,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: true,
                        titleCentered: true,
                      ),
                    ),
                  ),

                  // ── Course filter chips ────────────────────────────────
                  SliverToBoxAdapter(
                    child: state.courses.isNotEmpty
                        ? _CourseFilterBar(
                            courses: state.courses,
                            selectedId: state.selectedCourseId,
                            onSelect: notifier.selectCourse,
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ── Active filter summary ──────────────────────────────
                  if (state.selectedDay != null || state.selectedCourseId != null)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            Text(
                              _filterLabel(state),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () {
                                notifier.selectCourse(null);
                                if (state.selectedDay != null) {
                                  notifier.selectDay(state.selectedDay!);
                                }
                              },
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Record list ────────────────────────────────────────
                  state.filteredRecords.isEmpty
                      ? const SliverFillRemaining(
                          child: Center(
                              child: Text('No records for this selection')),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: AttendanceListItem(
                                  record: state.filteredRecords[index],
                                ),
                              ),
                              childCount: state.filteredRecords.length,
                            ),
                          ),
                        ),
                ],
              ),
            )),
              ],
            ),
    );
  }

  String _filterLabel(HistoryState state) {
    final parts = <String>[];
    if (state.selectedDay != null) {
      parts.add(DateFormat('MMM d, y').format(state.selectedDay!));
    }
    if (state.selectedCourseId != null) {
      final course = state.courses
          .where((c) => c.id == state.selectedCourseId)
          .firstOrNull;
      if (course != null) parts.add(course.code);
    }
    return 'Showing: ${parts.join(' · ')} (${state.filteredRecords.length} records)';
  }
}

class _CourseFilterBar extends StatelessWidget {
  final List<CourseInfo> courses;
  final String? selectedId;
  final void Function(String?) onSelect;

  const _CourseFilterBar({
    required this.courses,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selectedId == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...courses.map((c) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.code),
                  selected: selectedId == c.id,
                  onSelected: (_) => onSelect(c.id),
                ),
              )),
        ],
      ),
    );
  }
}
