import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/history_api.dart';
import '../../../../core/database/local_database.dart';

class CourseInfo {
  final String id;
  final String code;
  final String name;

  CourseInfo({required this.id, required this.code, required this.name});

  factory CourseInfo.fromJson(Map<String, dynamic> j) => CourseInfo(
        id: j['id'] as String? ?? '',
        code: j['code'] as String,
        name: j['name'] as String,
      );
}

class ClassroomInfo {
  final String name;

  ClassroomInfo({required this.name});

  factory ClassroomInfo.fromJson(Map<String, dynamic> j) =>
      ClassroomInfo(name: j['name'] as String);
}

class SessionInfo {
  final String sessionCode;
  final CourseInfo course;
  final ClassroomInfo classroom;
  final DateTime startedAt;

  SessionInfo({
    required this.sessionCode,
    required this.course,
    required this.classroom,
    required this.startedAt,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
        sessionCode: j['sessionCode'] as String,
        course: CourseInfo.fromJson(j['course'] as Map<String, dynamic>),
        classroom: ClassroomInfo.fromJson(j['classroom'] as Map<String, dynamic>),
        startedAt: DateTime.parse(j['startedAt'] as String),
      );
}

class AppealInfo {
  final String id;
  final String status; // pending | approved | rejected
  final String? reviewNote;

  const AppealInfo({required this.id, required this.status, this.reviewNote});

  factory AppealInfo.fromJson(Map<String, dynamic> j) => AppealInfo(
        id:         j['id']         as String,
        status:     j['status']     as String,
        reviewNote: j['reviewNote'] as String?,
      );
}

class AttendanceRecord {
  final String id;
  final String status;
  final String? submissionMethod;
  final bool? geofencePassed;
  final DateTime markedAt;
  final SessionInfo session;
  final AppealInfo? appeal;

  AttendanceRecord({
    required this.id,
    required this.status,
    this.submissionMethod,
    this.geofencePassed,
    required this.markedAt,
    required this.session,
    this.appeal,
  });

  bool get canAppeal =>
      (status == 'absent' || status == 'late') && appeal == null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id:               j['id'] as String,
        status:           j['status'] as String,
        submissionMethod: j['submissionMethod'] as String?,
        geofencePassed:   j['geofencePassed'] as bool?,
        markedAt:         DateTime.parse(j['markedAt'] as String),
        session:          SessionInfo.fromJson(j['session'] as Map<String, dynamic>),
        appeal: j['appeal'] != null
            ? AppealInfo.fromJson(j['appeal'] as Map<String, dynamic>)
            : null,
      );
}

class HistoryState {
  final List<AttendanceRecord> allRecords;
  final List<CourseInfo> courses;
  final String? selectedCourseId;
  final DateTime? selectedDay;
  final DateTime focusedDay;
  final Map<DateTime, List<AttendanceRecord>> eventsMap;
  final bool isLoading;
  final bool isOffline;
  final DateTime? cachedAt;

  HistoryState({
    this.allRecords = const [],
    this.courses = const [],
    this.selectedCourseId,
    this.selectedDay,
    DateTime? focusedDay,
    this.eventsMap = const {},
    this.isLoading = false,
    this.isOffline = false,
    this.cachedAt,
  }) : focusedDay = focusedDay ?? DateTime.now();

  List<AttendanceRecord> get filteredRecords {
    var records = allRecords;
    if (selectedCourseId != null) {
      records = records
          .where((r) => r.session.course.id == selectedCourseId)
          .toList();
    }
    if (selectedDay != null) {
      final d = _normalizeDate(selectedDay!);
      records = records
          .where((r) => _normalizeDate(r.markedAt) == d)
          .toList();
    }
    return records;
  }

  HistoryState copyWith({
    List<AttendanceRecord>? allRecords,
    List<CourseInfo>? courses,
    String? selectedCourseId,
    DateTime? selectedDay,
    DateTime? focusedDay,
    Map<DateTime, List<AttendanceRecord>>? eventsMap,
    bool? isLoading,
    bool? isOffline,
    DateTime? cachedAt,
    bool clearSelectedDay = false,
    bool clearSelectedCourse = false,
  }) {
    return HistoryState(
      allRecords: allRecords ?? this.allRecords,
      courses: courses ?? this.courses,
      selectedCourseId: clearSelectedCourse ? null : (selectedCourseId ?? this.selectedCourseId),
      selectedDay: clearSelectedDay ? null : (selectedDay ?? this.selectedDay),
      focusedDay: focusedDay ?? this.focusedDay,
      eventsMap: eventsMap ?? this.eventsMap,
      isLoading: isLoading ?? this.isLoading,
      isOffline: isOffline ?? this.isOffline,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }
}

DateTime _normalizeDate(DateTime d) => DateTime.utc(d.year, d.month, d.day);

final historyProvider =
    StateNotifierProvider<HistoryNotifier, HistoryState>((ref) {
  return HistoryNotifier();
});

class HistoryNotifier extends StateNotifier<HistoryState> {
  final _api = HistoryApi();

  HistoryNotifier() : super(HistoryState()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _api.getHistory(),
        _api.getCourses(),
      ]);

      final records = (results[0].data['data'] as List)
          .map((j) => AttendanceRecord.fromJson(j as Map<String, dynamic>))
          .toList();

      final courses = (results[1].data['data'] as List)
          .map((j) => CourseInfo.fromJson(j as Map<String, dynamic>))
          .toList();

      // Persist to local cache
      await _saveToCache(records, courses);

      final eventsMap = _buildEventsMap(records);
      state = HistoryState(
        allRecords: records,
        courses: courses,
        eventsMap: eventsMap,
        isLoading: false,
        isOffline: false,
      );
    } catch (_) {
      // Network failed — load from local cache
      await _loadFromCache();
    }
  }

  Future<void> _saveToCache(
      List<AttendanceRecord> records, List<CourseInfo> courses) async {
    final db = LocalDatabase.instance;
    await db.saveHistory(records
        .map((r) => CachedRecord(
              id: r.id,
              status: r.status,
              submissionMethod: r.submissionMethod,
              geofencePassed: r.geofencePassed,
              markedAt: r.markedAt,
              sessionCode: r.session.sessionCode,
              courseId: r.session.course.id,
              courseCode: r.session.course.code,
              courseName: r.session.course.name,
              classroomName: r.session.classroom.name,
              sessionStartedAt: r.session.startedAt,
            ))
        .toList());
    await db.saveCourses(
        courses.map((c) => CachedCourse(id: c.id, code: c.code, name: c.name)).toList());
  }

  Future<void> _loadFromCache() async {
    final db = LocalDatabase.instance;
    final cached = await db.getHistory();
    final cachedCourses = await db.getCourses();
    final cachedAt = await db.getHistoryCachedAt();

    final records = cached
        .map((c) => AttendanceRecord(
              id: c.id,
              status: c.status,
              submissionMethod: c.submissionMethod,
              geofencePassed: c.geofencePassed,
              markedAt: c.markedAt,
              session: SessionInfo(
                sessionCode: c.sessionCode,
                course: CourseInfo(
                    id: c.courseId, code: c.courseCode, name: c.courseName),
                classroom: ClassroomInfo(name: c.classroomName),
                startedAt: c.sessionStartedAt,
              ),
            ))
        .toList();

    final courses = cachedCourses
        .map((c) => CourseInfo(id: c.id, code: c.code, name: c.name))
        .toList();

    state = HistoryState(
      allRecords: records,
      courses: courses,
      eventsMap: _buildEventsMap(records),
      isLoading: false,
      isOffline: true,
      cachedAt: cachedAt,
    );
  }

  Map<DateTime, List<AttendanceRecord>> _buildEventsMap(
      List<AttendanceRecord> records) {
    final map = <DateTime, List<AttendanceRecord>>{};
    for (final r in records) {
      final day = _normalizeDate(r.markedAt);
      map.putIfAbsent(day, () => []).add(r);
    }
    return map;
  }

  void selectDay(DateTime day) {
    final norm = _normalizeDate(day);
    if (state.selectedDay != null && _normalizeDate(state.selectedDay!) == norm) {
      // Tap again to deselect
      state = state.copyWith(clearSelectedDay: true, focusedDay: day);
    } else {
      state = state.copyWith(selectedDay: day, focusedDay: day);
    }
  }

  void selectCourse(String? courseId) {
    if (courseId == null) {
      state = state.copyWith(clearSelectedCourse: true);
    } else {
      state = state.copyWith(selectedCourseId: courseId);
    }
  }

  // Returns null on success, error message on failure
  Future<String?> submitAppeal(String recordId, String reason) async {
    try {
      final res = await _api.submitAppeal(recordId, reason);
      if (res.data['success'] == true) {
        // Optimistically update the record with pending appeal
        final appealId = res.data['data']['id'] as String;
        final updated = state.allRecords.map((r) {
          if (r.id == recordId) {
            return AttendanceRecord(
              id: r.id, status: r.status,
              submissionMethod: r.submissionMethod,
              geofencePassed: r.geofencePassed,
              markedAt: r.markedAt, session: r.session,
              appeal: AppealInfo(id: appealId, status: 'pending'),
            );
          }
          return r;
        }).toList();
        state = state.copyWith(
          allRecords: updated,
          eventsMap: _buildEventsMap(updated),
        );
        return null;
      }
      return 'Failed to submit appeal.';
    } catch (e) {
      final msg = (e as dynamic).response?.data?['error'] as String?;
      return msg ?? 'Failed to submit appeal.';
    }
  }
}
