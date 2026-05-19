const bcrypt = require("bcryptjs");
const { randomUUID, createHmac } = require("crypto");
const db = require("../config/database");
const { success, error } = require("../utils/response");
const fcm = require("../services/fcm.service");
const admin = require("firebase-admin");

function generateCode() {
  return Math.random().toString(36).slice(2, 8).toUpperCase();
}

// 30-second rotating QR token signed with JWT_SECRET
function buildQrToken(sessionId) {
  const window = Math.floor(Date.now() / 30000);
  const secret = process.env.JWT_SECRET || "dev_secret";
  const token = createHmac("sha256", secret)
    .update(`${sessionId}|${window}`)
    .digest("hex")
    .slice(0, 16);
  const secondsIntoWindow = Math.floor((Date.now() / 1000) % 30);
  return { token, window, expiresInSeconds: 30 - secondsIntoWindow };
}

// ── Dashboard ─────────────────────────────────────────────────────────────────
async function getDashboard(req, res, next) {
  try {
    const lecturerId = req.user.id;

    const [courses] = await db.query(
      `SELECT c.id, c.code, c.name,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id=c.id) AS students
         FROM courses c WHERE c.lecturer_id = ? AND c.is_active = 1`,
      [lecturerId],
    );

    const [active] = await db.query(
      `SELECT s.id, s.session_code AS code, s.status,
              c.code AS courseCode, c.name AS courseName, cl.name AS roomName
         FROM attendance_sessions s
         JOIN courses c ON c.id = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
        WHERE s.lecturer_id = ? AND s.status = 'active' LIMIT 1`,
      [lecturerId],
    );

    const [[stats]] = await db.query(
      `SELECT COUNT(*) AS totalSessions,
              ROUND(100 * SUM(CASE WHEN r.status='present' THEN 1 ELSE 0 END) / NULLIF(COUNT(r.id),0), 1) AS overallAttendance
         FROM attendance_sessions s
         LEFT JOIN attendance_records r ON r.session_id = s.id
        WHERE s.lecturer_id = ?`,
      [lecturerId],
    );

    res.json(
      success({
        courses: courses.map((c) => ({
          id: c.id,
          code: c.code,
          name: c.name,
          students: Number(c.students),
        })),
        todaySchedule: courses.slice(0, 2).map((c, i) => ({
          time: i === 0 ? "08:00" : "11:00",
          course: c.code,
          room: "LT-3",
          students: Number(c.students),
        })),
        overallAttendance: Number(stats.overallAttendance) || 0,
        totalSessions: Number(stats.totalSessions),
        activeSession: active[0] || null,
      }),
    );
  } catch (err) {
    next(err);
  }
}

// ── Sessions ──────────────────────────────────────────────────────────────────
async function getSessions(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT s.id, s.session_code AS sessionCode, s.status, s.started_at, s.closed_at, s.expires_at,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.id AS rId, cl.name AS rName,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id=s.course_id) AS totalStudents,
              (SELECT COUNT(*) FROM attendance_records r WHERE r.session_id=s.id AND r.status='present') AS presentCount,
              (SELECT COUNT(*) FROM attendance_records r WHERE r.session_id=s.id AND r.status='late')    AS lateCount
         FROM attendance_sessions s
         JOIN courses c ON c.id = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
        WHERE s.lecturer_id = ?
        ORDER BY s.started_at DESC`,
      [req.user.id],
    );
    res.json(
      success(
        rows.map((r) => ({
          id: r.id,
          sessionCode: r.sessionCode,
          status: r.status,
          course: { id: r.cId, code: r.cCode, name: r.cName },
          classroom: { id: r.rId, name: r.rName },
          startedAt: r.started_at,
          closedAt: r.closed_at,
          expiresAt: r.expires_at,
          totalStudents: Number(r.totalStudents),
          presentCount: Number(r.presentCount),
          lateCount: Number(r.lateCount),
        })),
      ),
    );
  } catch (err) {
    next(err);
  }
}

async function startSession(req, res, next) {
  try {
    const { courseId, classroomId } = req.body;
    const lecturerId = req.user.id;

    // Check lecturer owns course
    const [owns] = await db.query(
      "SELECT id FROM courses WHERE id = ? AND lecturer_id = ?",
      [courseId, lecturerId],
    );
    if (!owns.length)
      return res.status(403).json(error("You are not assigned to this course"));

    // Check no active session for this course
    const [existing] = await db.query(
      `SELECT id FROM attendance_sessions WHERE course_id=? AND lecturer_id=? AND status='active'`,
      [courseId, lecturerId],
    );
    if (existing.length)
      return res
        .status(409)
        .json(error("A session is already active for this course"));

    const id = randomUUID();
    const code = generateCode();
    const expiresAt = new Date(Date.now() + 90 * 60 * 1000);

    await db.query(
      `INSERT INTO attendance_sessions (id, session_code, course_id, classroom_id, lecturer_id, expires_at)
       VALUES (?,?,?,?,?,?)`,
      [id, code, courseId, classroomId, lecturerId, expiresAt],
    );

    const [session] = await db.query(
      `SELECT s.id, s.session_code AS sessionCode, s.status, s.started_at, s.expires_at,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.id AS rId, cl.name AS rName, cl.latitude, cl.longitude, cl.radius_m,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id=s.course_id) AS totalStudents
         FROM attendance_sessions s
         JOIN courses c  ON c.id  = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
        WHERE s.id = ?`,
      [id],
    );
    const s = session[0];

    // Emit socket event (stored in app locals by server.js)
    const io = req.app.get("io");
    if (io) {
      io.to(`course:${courseId}`).emit("session_started", {
        sessionId: id,
        courseId,
        courseName: s.cName,
        room: s.rName,
        sessionCode: code,
      });
    }

    // Push notification — enrolled students who are offline will still be alerted
    fcm.notifySessionStarted({
      sessionId: id,
      courseId,
      courseName: s.cName,
      room: s.rName,
      sessionCode: code,
    });

    res.status(201).json(
      success({
        id: s.id,
        sessionCode: s.sessionCode,
        status: s.status,
        code: s.sessionCode,
        course: { id: s.cId, code: s.cCode, name: s.cName },
        classroom: {
          id: s.rId,
          name: s.rName,
          latitude: Number(s.latitude),
          longitude: Number(s.longitude),
          radiusM: s.radius_m,
        },
        startedAt: s.started_at,
        expiresAt: s.expires_at,
        totalStudents: Number(s.totalStudents),
        presentCount: 0,
        checkinOpen: true,
      }),
    );
  } catch (err) {
    next(err);
  }
}

async function closeSession(req, res, next) {
  try {
    const { id } = req.params;
    const [owns] = await db.query(
      `SELECT id, course_id FROM attendance_sessions WHERE id=? AND lecturer_id=? AND status='active'`,
      [id, req.user.id],
    );
    if (!owns.length)
      return res.status(404).json(error("Active session not found"));

    const courseId = owns[0].course_id;

    await db.query(
      `UPDATE attendance_sessions SET status='closed', checkin_open=0, closed_at=NOW() WHERE id=?`,
      [id],
    );

    // Auto-mark absent for enrolled students who never checked in
    const [notCheckedIn] = await db.query(
      `SELECT en.student_id FROM enrollments en
        WHERE en.course_id = ?
          AND en.student_id NOT IN (
            SELECT ar.student_id FROM attendance_records ar WHERE ar.session_id = ?
          )`,
      [courseId, id],
    );
    if (notCheckedIn.length) {
      const absentRows = notCheckedIn.map((e) => [
        randomUUID(),
        id,
        e.student_id,
        "absent",
        "app",
        0,
        null,
        null,
        null,
      ]);
      await db.query(
        `INSERT INTO attendance_records
           (id, session_id, student_id, status, submission_method, geofence_passed, latitude, longitude, distance_m)
         VALUES ?`,
        [absentRows],
      );
    }

    const io = req.app.get("io");
    if (io) {
      io.to(`session:${id}`).emit("session_closed", {
        sessionId: id,
        absentCount: notCheckedIn.length,
      });
    }

    // Push absence warnings to students who missed the session
    fcm.notifyAbsentStudents({ sessionId: id, courseId });

    res.json(success({ absentMarked: notCheckedIn.length }));
  } catch (err) {
    next(err);
  }
}

async function getSessionAttendance(req, res, next) {
  try {
    const [sessions] = await db.query(
      `SELECT s.id, s.status,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.name AS roomName, cl.radius_m,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = s.course_id) AS totalStudents
         FROM attendance_sessions s
         JOIN courses c    ON c.id  = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
        WHERE s.id = ? AND s.lecturer_id = ?`,
      [req.params.id, req.user.id],
    );
    if (!sessions.length) return res.status(404).json(error("Session not found"));
    const sess = sessions[0];

    const [rows] = await db.query(
      `SELECT r.id, r.status, r.marked_at, r.distance_m, r.geofence_passed, r.submission_method,
              u.id AS uid, u.full_name, u.reg_number
         FROM attendance_records r
         JOIN users u ON u.id = r.student_id
        WHERE r.session_id = ?
        ORDER BY r.marked_at ASC`,
      [req.params.id],
    );

    res.json(success({
      totalStudents: Number(sess.totalStudents),
      classroom: { name: sess.roomName, radiusM: sess.radius_m },
      course: { id: sess.cId, code: sess.cCode, name: sess.cName },
      records: rows.map((r) => ({
        id: r.id,
        status: r.status,
        checkedInAt: r.marked_at,
        distanceM: Number(r.distance_m),
        geofencePassed: !!r.geofence_passed,
        submissionMethod: r.submission_method,
        student: { id: r.uid, fullName: r.full_name, regNumber: r.reg_number },
      })),
    }));
  } catch (err) {
    next(err);
  }
}

// ── Students ──────────────────────────────────────────────────────────────────
async function getStudents(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT u.id, u.full_name, u.email, u.reg_number, c.code AS course,
              ROUND(100 * SUM(r.status='present') / NULLIF(COUNT(r.id),0), 1) AS attendanceRate
         FROM users u
         JOIN enrollments en ON en.student_id = u.id
         JOIN courses c ON c.id = en.course_id AND c.lecturer_id = ?
         LEFT JOIN attendance_records r ON r.student_id = u.id
         LEFT JOIN attendance_sessions s ON s.id = r.session_id AND s.course_id = c.id
        GROUP BY u.id, c.id
        ORDER BY u.full_name`,
      [req.user.id],
    );
    res.json(
      success(
        rows.map((r) => ({
          id: r.id,
          fullName: r.full_name,
          email: r.email,
          regNumber: r.reg_number,
          course: r.course,
          attendanceRate: Number(r.attendanceRate) || 0,
        })),
      ),
    );
  } catch (err) {
    next(err);
  }
}

async function createStudent(req, res, next) {
  try {
    const { fullName, email, regNumber, courseId, password } = req.body;
    const hash = await bcrypt.hash(password || "Student@1234", 12);
    const id = randomUUID();
    await db.query(
      "INSERT INTO users (id, full_name, email, password_hash, role, reg_number) VALUES (?,?,?,?,?,?)",
      [id, fullName, email, hash, "student", regNumber || null],
    );
    if (courseId) {
      await db.query(
        "INSERT INTO enrollments (id, student_id, course_id) VALUES (?,?,?)",
        [randomUUID(), id, courseId],
      );
    }
    res
      .status(201)
      .json(success({ id, fullName, email, regNumber, attendanceRate: 0 }));
  } catch (err) {
    next(err);
  }
}

// ── Courses / Classrooms (for selects) ───────────────────────────────────────
async function getCourses(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT c.id, c.code, c.name,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id=c.id) AS students
         FROM courses c WHERE c.lecturer_id=? AND c.is_active=1`,
      [req.user.id],
    );
    res.json(
      success(
        rows.map((r) => ({
          id: r.id,
          code: r.code,
          name: r.name,
          students: Number(r.students),
        })),
      ),
    );
  } catch (err) {
    next(err);
  }
}

async function getClassrooms(req, res, next) {
  try {
    const [rows] = await db.query(
      "SELECT id, name, latitude, longitude, radius_m FROM classrooms WHERE is_active=1 ORDER BY name",
    );
    res.json(
      success(
        rows.map((r) => ({
          id: r.id,
          name: r.name,
          latitude: Number(r.latitude),
          longitude: Number(r.longitude),
          radiusM: r.radius_m,
        })),
      ),
    );
  } catch (err) {
    next(err);
  }
}

async function getSessionEnrolledStudents(req, res, next) {
  try {
    const { id } = req.params;

    // Verify lecturer owns this session
    const [session] = await db.query(
      "SELECT course_id FROM attendance_sessions WHERE id = ? AND lecturer_id = ?",
      [id, req.user.id],
    );

    if (!session.length) {
      return res.status(404).json(error("Session not found"));
    }

    const courseId = session[0].course_id;

    // Get all enrolled students for this course
    const [students] = await db.query(
      `SELECT u.id, u.full_name AS fullName, u.reg_number AS regNumber, u.email
       FROM users u
       JOIN enrollments e ON u.id = e.student_id
       WHERE e.course_id = ?
       ORDER BY u.full_name`,
      [courseId],
    );

    res.json(success(students));
  } catch (err) {
    next(err);
  }
}

async function getSessionQrToken(req, res, next) {
  try {
    const { id } = req.params;
    const [owns] = await db.query(
      "SELECT id FROM attendance_sessions WHERE id=? AND lecturer_id=? AND status='active'",
      [id, req.user.id],
    );
    if (!owns.length)
      return res.status(404).json(error("Active session not found"));

    const { token, window, expiresInSeconds } = buildQrToken(id);
    // QR payload the student app will scan
    const payload = JSON.stringify({ s: id, t: token, w: window });
    res.json(success({ payload, expiresInSeconds, windowDurationSeconds: 30 }));
  } catch (err) {
    next(err);
  }
}

async function markStudentPresent(req, res, next) {
  try {
    const { id: sessionId } = req.params;
    const { studentId } = req.body;
    if (!studentId) return res.status(400).json(error('studentId is required'));

    // Verify session belongs to this lecturer
    const [sessions] = await db.query(
      'SELECT id FROM attendance_sessions WHERE id = ? AND lecturer_id = ?',
      [sessionId, req.user.id],
    );
    if (!sessions.length) return res.status(403).json(error('Access denied'));

    // Upsert attendance record as manually marked present
    const [existing] = await db.query(
      'SELECT id FROM attendance_records WHERE session_id = ? AND student_id = ?',
      [sessionId, studentId],
    );
    if (existing.length) {
      await db.query(
        "UPDATE attendance_records SET status = 'present', submission_method = 'manual' WHERE id = ?",
        [existing[0].id],
      );
    } else {
      await db.query(
        `INSERT INTO attendance_records (id, session_id, student_id, status, submission_method, distance_m, checked_in_at)
         VALUES (?, ?, ?, 'present', 'manual', 0, NOW())`,
        [randomUUID(), sessionId, studentId],
      );
    }

    // Emit real-time update
    const io = req.app.get('io');
    if (io) {
      const [[u]] = await db.query(
        'SELECT full_name, reg_number FROM users WHERE id = ?', [studentId],
      );
      io.to(`session:${sessionId}`).emit('attendance_update', {
        student: { id: studentId, fullName: u?.full_name, regNumber: u?.reg_number },
        status: 'present',
        submissionMethod: 'manual',
        checkedInAt: new Date().toISOString(),
        distanceM: 0,
      });
    }

    res.json(success({ message: 'Marked present' }));
  } catch (err) { next(err); }
}

module.exports = {
  getDashboard,
  getSessions,
  startSession,
  closeSession,
  getSessionAttendance,
  getStudents,
  createStudent,
  getCourses,
  getClassrooms,
  getSessionEnrolledStudents,
  getSessionQrToken,
  markStudentPresent,
};
