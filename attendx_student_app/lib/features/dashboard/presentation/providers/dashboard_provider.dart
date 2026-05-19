import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/dashboard_api.dart';
import '../../../../core/database/local_database.dart';

class DashboardProfile {
  final String id;
  final String fullName;
  final String? regNumber;
  final int enrolledCourses;
  final double attendanceRate;

  DashboardProfile({
    required this.id,
    required this.fullName,
    this.regNumber,
    required this.enrolledCourses,
    required this.attendanceRate,
  });

  factory DashboardProfile.fromJson(Map<String, dynamic> j) => DashboardProfile(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        regNumber: j['regNumber'] as String?,
        enrolledCourses: j['enrolledCourses'] as int,
        attendanceRate: (j['attendanceRate'] as num).toDouble(),
      );
}

class Course {
  final String id;
  final String code;
  final String name;

  Course({required this.id, required this.code, required this.name});

  factory Course.fromJson(Map<String, dynamic> j) => Course(
        id: j['id'] as String? ?? '',
        code: j['code'] as String,
        name: j['name'] as String,
      );
}

class Classroom {
  final String name;
  final double latitude;
  final double longitude;
  final double radiusM;

  Classroom({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
  });

  factory Classroom.fromJson(Map<String, dynamic> j) => Classroom(
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        radiusM: (j['radiusM'] as num).toDouble(),
      );
}

class TodaySession {
  final String id;
  final String sessionCode;
  final String status;
  final bool checkinOpen;
  final Course course;
  final Classroom classroom;
  final DateTime startedAt;
  final DateTime expiresAt;

  TodaySession({
    required this.id,
    required this.sessionCode,
    required this.status,
    required this.checkinOpen,
    required this.course,
    required this.classroom,
    required this.startedAt,
    required this.expiresAt,
  });

  bool get isActive => status == 'active' && checkinOpen;

  factory TodaySession.fromJson(Map<String, dynamic> j) => TodaySession(
        id: j['id'] as String,
        sessionCode: j['sessionCode'] as String,
        status: j['status'] as String,
        checkinOpen: j['checkinOpen'] as bool,
        course: Course.fromJson(j['course'] as Map<String, dynamic>),
        classroom: Classroom.fromJson(j['classroom'] as Map<String, dynamic>),
        startedAt: DateTime.parse(j['startedAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
      );
}

class DashboardState {
  final DashboardProfile? profile;
  final List<TodaySession> todaySessions;
  final double? overallAttendanceRate;
  final bool isLoading;
  final String? error;
  final bool isOffline;

  DashboardState({
    this.profile,
    this.todaySessions = const [],
    this.overallAttendanceRate,
    this.isLoading = false,
    this.error,
    this.isOffline = false,
  });

  DashboardState copyWith({
    DashboardProfile? profile,
    List<TodaySession>? todaySessions,
    double? overallAttendanceRate,
    bool? isLoading,
    String? error,
    bool? isOffline,
  }) {
    return DashboardState(
      profile: profile ?? this.profile,
      todaySessions: todaySessions ?? this.todaySessions,
      overallAttendanceRate:
          overallAttendanceRate ?? this.overallAttendanceRate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  final _api = DashboardApi();

  DashboardNotifier() : super(DashboardState()) {
    loadDashboard();
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.getDashboard();
      final data = response.data['data'] as Map<String, dynamic>;

      final profile = DashboardProfile.fromJson(
          data['profile'] as Map<String, dynamic>);
      final sessions = (data['todaySessions'] as List)
          .map((s) => TodaySession.fromJson(s as Map<String, dynamic>))
          .toList();

      // Persist to cache
      await _saveDashboardCache(data);

      state = DashboardState(
        profile: profile,
        todaySessions: sessions,
        overallAttendanceRate:
            (data['overallAttendanceRate'] as num).toDouble(),
        isLoading: false,
        isOffline: false,
      );
    } catch (_) {
      // Try cache
      final cached = await _loadDashboardCache();
      if (cached != null) {
        state = cached.copyWith(isLoading: false, isOffline: true);
      } else {
        state = state.copyWith(isLoading: false, isOffline: true,
            error: 'No internet connection');
      }
    }
  }

  Future<void> _saveDashboardCache(Map<String, dynamic> data) async {
    await LocalDatabase.instance.saveKv('dashboard', jsonEncode(data));
  }

  Future<DashboardState?> _loadDashboardCache() async {
    try {
      final raw = await LocalDatabase.instance.getKv('dashboard');
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final profile =
          DashboardProfile.fromJson(data['profile'] as Map<String, dynamic>);
      final sessions = (data['todaySessions'] as List)
          .map((s) => TodaySession.fromJson(s as Map<String, dynamic>))
          .toList();
      return DashboardState(
        profile: profile,
        todaySessions: sessions,
        overallAttendanceRate:
            (data['overallAttendanceRate'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async => loadDashboard();
}
