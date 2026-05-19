import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class CachedRecord {
  final String id;
  final String status;
  final String? submissionMethod;
  final bool? geofencePassed;
  final DateTime markedAt;
  final String sessionCode;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String classroomName;
  final DateTime sessionStartedAt;

  const CachedRecord({
    required this.id,
    required this.status,
    this.submissionMethod,
    this.geofencePassed,
    required this.markedAt,
    required this.sessionCode,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.classroomName,
    required this.sessionStartedAt,
  });

  Map<String, dynamic> toRow() => {
        'id':                id,
        'status':            status,
        'submission_method': submissionMethod,
        'geofence_passed':   geofencePassed == null ? null : (geofencePassed! ? 1 : 0),
        'marked_at':         markedAt.toIso8601String(),
        'session_code':      sessionCode,
        'course_id':         courseId,
        'course_code':       courseCode,
        'course_name':       courseName,
        'classroom_name':    classroomName,
        'session_started_at': sessionStartedAt.toIso8601String(),
        'cached_at':         DateTime.now().toIso8601String(),
      };

  factory CachedRecord.fromRow(Map<String, dynamic> row) => CachedRecord(
        id:               row['id'] as String,
        status:           row['status'] as String,
        submissionMethod: row['submission_method'] as String?,
        geofencePassed:   row['geofence_passed'] == null
            ? null
            : (row['geofence_passed'] as int) == 1,
        markedAt:         DateTime.parse(row['marked_at'] as String),
        sessionCode:      row['session_code'] as String,
        courseId:         row['course_id'] as String,
        courseCode:       row['course_code'] as String,
        courseName:       row['course_name'] as String,
        classroomName:    row['classroom_name'] as String,
        sessionStartedAt: DateTime.parse(row['session_started_at'] as String),
      );
}

class CachedCourse {
  final String id;
  final String code;
  final String name;

  const CachedCourse({required this.id, required this.code, required this.name});

  Map<String, dynamic> toRow() => {'id': id, 'code': code, 'name': name};

  factory CachedCourse.fromRow(Map<String, dynamic> row) => CachedCourse(
        id:   row['id'] as String,
        code: row['code'] as String,
        name: row['name'] as String,
      );
}

class QueuedCheckin {
  final String id;
  final String sessionId;
  final String? entryCode;
  final String? qrToken;
  final int? qrWindow;
  final double latitude;
  final double longitude;
  final String courseName;
  final Map<String, dynamic>? securityContext;
  final DateTime queuedAt;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String status; // pending | synced | failed

  const QueuedCheckin({
    required this.id,
    required this.sessionId,
    this.entryCode,
    this.qrToken,
    this.qrWindow,
    required this.latitude,
    required this.longitude,
    required this.courseName,
    this.securityContext,
    required this.queuedAt,
    this.attempts = 0,
    this.lastAttemptAt,
    this.status = 'pending',
  });

  Map<String, dynamic> toRow() => {
        'id':               id,
        'session_id':       sessionId,
        'entry_code':       entryCode,
        'qr_token':         qrToken,
        'qr_window':        qrWindow,
        'latitude':         latitude,
        'longitude':        longitude,
        'course_name':      courseName,
        'security_context': securityContext != null
            ? jsonEncode(securityContext)
            : null,
        'queued_at':        queuedAt.toIso8601String(),
        'attempts':         attempts,
        'last_attempt_at':  lastAttemptAt?.toIso8601String(),
        'status':           status,
      };

  factory QueuedCheckin.fromRow(Map<String, dynamic> row) => QueuedCheckin(
        id:         row['id'] as String,
        sessionId:  row['session_id'] as String,
        entryCode:  row['entry_code'] as String?,
        qrToken:    row['qr_token'] as String?,
        qrWindow:   row['qr_window'] as int?,
        latitude:   row['latitude'] as double,
        longitude:  row['longitude'] as double,
        courseName: row['course_name'] as String,
        securityContext: row['security_context'] != null
            ? jsonDecode(row['security_context'] as String)
                as Map<String, dynamic>
            : null,
        queuedAt:      DateTime.parse(row['queued_at'] as String),
        attempts:      row['attempts'] as int,
        lastAttemptAt: row['last_attempt_at'] != null
            ? DateTime.parse(row['last_attempt_at'] as String)
            : null,
        status: row['status'] as String,
      );

  QueuedCheckin copyWith({int? attempts, DateTime? lastAttemptAt, String? status}) =>
      QueuedCheckin(
        id: id, sessionId: sessionId, entryCode: entryCode,
        qrToken: qrToken, qrWindow: qrWindow,
        latitude: latitude, longitude: longitude,
        courseName: courseName, securityContext: securityContext,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
        lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
        status: status ?? this.status,
      );
}

// ── Database ──────────────────────────────────────────────────────────────────

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._();
  LocalDatabase._();

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'attendx_local.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE kv_cache (
            key       TEXT PRIMARY KEY,
            value     TEXT NOT NULL,
            cached_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_history (
            id                 TEXT PRIMARY KEY,
            status             TEXT NOT NULL,
            submission_method  TEXT,
            geofence_passed    INTEGER,
            marked_at          TEXT NOT NULL,
            session_code       TEXT NOT NULL,
            course_id          TEXT NOT NULL,
            course_code        TEXT NOT NULL,
            course_name        TEXT NOT NULL,
            classroom_name     TEXT NOT NULL,
            session_started_at TEXT NOT NULL,
            cached_at          TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE cached_courses (
            id   TEXT PRIMARY KEY,
            code TEXT NOT NULL,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE checkin_queue (
            id               TEXT PRIMARY KEY,
            session_id       TEXT NOT NULL,
            entry_code       TEXT,
            qr_token         TEXT,
            qr_window        INTEGER,
            latitude         REAL NOT NULL,
            longitude        REAL NOT NULL,
            course_name      TEXT NOT NULL,
            security_context TEXT,
            queued_at        TEXT NOT NULL,
            attempts         INTEGER NOT NULL DEFAULT 0,
            last_attempt_at  TEXT,
            status           TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
      },
    );
  }

  // ── History cache ─────────────────────────────────────────────────────────

  Future<void> saveHistory(List<CachedRecord> records) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('cached_history');
    for (final r in records) {
      batch.insert('cached_history', r.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<CachedRecord>> getHistory() async {
    final db = await _database;
    final rows = await db.query(
        'cached_history', orderBy: 'marked_at DESC');
    return rows.map(CachedRecord.fromRow).toList();
  }

  Future<DateTime?> getHistoryCachedAt() async {
    final db = await _database;
    final rows = await db.query('cached_history',
        columns: ['cached_at'], limit: 1, orderBy: 'cached_at DESC');
    if (rows.isEmpty) return null;
    return DateTime.parse(rows.first['cached_at'] as String);
  }

  // ── Course cache ──────────────────────────────────────────────────────────

  Future<void> saveCourses(List<CachedCourse> courses) async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('cached_courses');
    for (final c in courses) {
      batch.insert('cached_courses', c.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<CachedCourse>> getCourses() async {
    final db = await _database;
    final rows = await db.query('cached_courses', orderBy: 'code');
    return rows.map(CachedCourse.fromRow).toList();
  }

  // ── Key-value cache (dashboard etc.) ─────────────────────────────────────

  Future<void> saveKv(String key, String value) async {
    final db = await _database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv_cache (
        key       TEXT PRIMARY KEY,
        value     TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    await db.insert(
      'kv_cache',
      {'key': key, 'value': value, 'cached_at': DateTime.now().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getKv(String key) async {
    final db = await _database;
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv_cache (
        key       TEXT PRIMARY KEY,
        value     TEXT NOT NULL,
        cached_at TEXT NOT NULL
      )
    ''');
    final rows = await db.query('kv_cache', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  // ── Check-in queue ────────────────────────────────────────────────────────

  Future<void> enqueue(QueuedCheckin item) async {
    final db = await _database;
    await db.insert('checkin_queue', item.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<QueuedCheckin>> getPendingQueue() async {
    final db = await _database;
    final rows = await db.query(
      'checkin_queue',
      where: 'status = ? AND attempts < 3',
      whereArgs: ['pending'],
      orderBy: 'queued_at ASC',
    );
    return rows.map(QueuedCheckin.fromRow).toList();
  }

  Future<int> getPendingCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as c FROM checkin_queue WHERE status = 'pending' AND attempts < 3",
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> updateQueueItem(QueuedCheckin item) async {
    final db = await _database;
    await db.update(
      'checkin_queue',
      item.toRow(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<List<QueuedCheckin>> getAllQueue() async {
    final db = await _database;
    final rows = await db.query('checkin_queue',
        orderBy: 'queued_at DESC', limit: 50);
    return rows.map(QueuedCheckin.fromRow).toList();
  }

  Future<void> clearSyncedQueue() async {
    final db = await _database;
    await db.delete('checkin_queue',
        where: 'status = ?', whereArgs: ['synced']);
  }
}
