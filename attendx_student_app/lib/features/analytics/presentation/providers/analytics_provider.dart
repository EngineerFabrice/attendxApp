import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/analytics_api.dart';

enum TrendPeriod { week, month, all }

class TrendDataPoint {
  final DateTime date;
  final String status;

  TrendDataPoint({required this.date, required this.status});

  factory TrendDataPoint.fromJson(Map<String, dynamic> j) => TrendDataPoint(
        date: DateTime.parse(j['sessionDate'] as String),
        status: j['status'] as String,
      );
}

class CourseStat {
  final String id;
  final String code;
  final String name;
  final double attendanceRate;
  final int totalSessions;
  final int presentSessions;
  final int lateSessions;
  final int absentSessions;
  final int lateThresholdMinutes;

  CourseStat({
    required this.id,
    required this.code,
    required this.name,
    required this.attendanceRate,
    required this.totalSessions,
    required this.presentSessions,
    this.lateSessions = 0,
    this.absentSessions = 0,
    this.lateThresholdMinutes = 15,
  });

  bool get isAtRisk => attendanceRate < 75.0;
  // on-time = present (not late)
  int get onTimeSessions => presentSessions;

  factory CourseStat.fromJson(Map<String, dynamic> j) => CourseStat(
        id: j['id'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        attendanceRate: (j['attendanceRate'] as num).toDouble(),
        totalSessions: (j['totalSessions'] as num).toInt(),
        presentSessions: (j['presentSessions'] as num).toInt(),
        lateSessions: (j['lateSessions'] as num?)?.toInt() ?? 0,
        absentSessions: (j['absentSessions'] as num?)?.toInt() ?? 0,
        lateThresholdMinutes:
            (j['lateThresholdMinutes'] as num?)?.toInt() ?? 15,
      );
}

class AnalyticsState {
  final double? overallRate;
  final int currentStreak;
  final int longestStreak;
  final List<TrendDataPoint> trendData;
  final List<CourseStat> courseStats;
  final bool isLoading;
  final TrendPeriod trendPeriod;

  AnalyticsState({
    this.overallRate,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.trendData = const [],
    this.courseStats = const [],
    this.isLoading = false,
    this.trendPeriod = TrendPeriod.month,
  });

  List<CourseStat> get atRiskCourses =>
      courseStats.where((c) => c.isAtRisk).toList();

  int get totalSessions =>
      courseStats.fold(0, (s, c) => s + c.totalSessions);
  int get totalPresent =>
      courseStats.fold(0, (s, c) => s + c.presentSessions);
  int get totalLate =>
      courseStats.fold(0, (s, c) => s + c.lateSessions);
  int get totalAbsent =>
      courseStats.fold(0, (s, c) => s + c.absentSessions);

  List<TrendDataPoint> get filteredTrendData {
    final now = DateTime.now();
    switch (trendPeriod) {
      case TrendPeriod.week:
        final cutoff = now.subtract(const Duration(days: 7));
        return trendData.where((p) => p.date.isAfter(cutoff)).toList();
      case TrendPeriod.month:
        final cutoff = now.subtract(const Duration(days: 30));
        return trendData.where((p) => p.date.isAfter(cutoff)).toList();
      case TrendPeriod.all:
        return trendData;
    }
  }

  AnalyticsState copyWith({
    double? overallRate,
    int? currentStreak,
    int? longestStreak,
    List<TrendDataPoint>? trendData,
    List<CourseStat>? courseStats,
    bool? isLoading,
    TrendPeriod? trendPeriod,
  }) {
    return AnalyticsState(
      overallRate: overallRate ?? this.overallRate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      trendData: trendData ?? this.trendData,
      courseStats: courseStats ?? this.courseStats,
      isLoading: isLoading ?? this.isLoading,
      trendPeriod: trendPeriod ?? this.trendPeriod,
    );
  }
}

final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  return AnalyticsNotifier();
});

class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final _api = AnalyticsApi();

  AnalyticsNotifier() : super(AnalyticsState()) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.getAnalytics();
      final data = response.data['data'] as Map<String, dynamic>;

      final courseStats = (data['courseStats'] as List)
          .map((j) => CourseStat.fromJson(j as Map<String, dynamic>))
          .toList();

      final trendData = (data['trendData'] as List)
          .map((j) => TrendDataPoint.fromJson(j as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final currentStreak = data['currentStreak'] as int? ??
          _computeCurrentStreak(trendData);
      final longestStreak = data['longestStreak'] as int? ??
          _computeLongestStreak(trendData);

      state = AnalyticsState(
        overallRate: (data['overallRate'] as num).toDouble(),
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        trendData: trendData,
        courseStats: courseStats,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void setTrendPeriod(TrendPeriod period) {
    state = state.copyWith(trendPeriod: period);
  }

  // Count consecutive present sessions from most recent backwards
  int _computeCurrentStreak(List<TrendDataPoint> data) {
    int streak = 0;
    for (final point in data.reversed) {
      if (point.status == 'present') {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _computeLongestStreak(List<TrendDataPoint> data) {
    int longest = 0;
    int current = 0;
    for (final point in data) {
      if (point.status == 'present') {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }
    return longest;
  }
}
