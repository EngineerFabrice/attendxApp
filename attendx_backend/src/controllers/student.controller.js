const { randomUUID, createHmac } = require('crypto')
const db       = require('../config/database')
const { haversine } = require('../utils/haversine')
const { success, error } = require('../utils/response')
const { body, validationResult } = require('express-validator')
const fcm      = require('../services/fcm.service')
const security = require('../services/security.service')

// ── Dashboard ─────────────────────────────────────────────────────────────────
async function getDashboard(req, res, next) {
  try {
    const studentId = req.user.id

    // Profile
    const [[profile]] = await db.query(
      `SELECT u.id, u.full_name, u.email, u.reg_number,
              COUNT(DISTINCT en.course_id) AS enrolledCourses,
              ROUND(100 * SUM(r.status='present') / NULLIF(COUNT(r.id),0), 1) AS attendanceRate
         FROM users u
         LEFT JOIN enrollments en ON en.student_id = u.id
         LEFT JOIN attendance_records r ON r.student_id = u.id
        WHERE u.id = ?`,
      [studentId]
    )

    // Active sessions for enrolled courses
    const [sessions] = await db.query(
      `SELECT s.id, s.session_code AS sessionCode, s.status, s.checkin_open, s.started_at, s.expires_at,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.name AS roomName, cl.latitude, cl.longitude, cl.radius_m
         FROM attendance_sessions s
         JOIN courses c ON c.id = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
         JOIN enrollments en ON en.course_id = s.course_id AND en.student_id = ?
        WHERE s.status = 'active'
        ORDER BY s.started_at`,
      [studentId]
    )

    res.json(success({
      profile: {
        id: profile.id, fullName: profile.full_name, email: profile.email,
        regNumber: profile.reg_number,
        enrolledCourses: Number(profile.enrolledCourses),
        attendanceRate: Number(profile.attendanceRate) || 0,
      },
      overallAttendanceRate: Number(profile.attendanceRate) || 0,
      todaySessions: sessions.map(s => ({
        id: s.id, sessionCode: s.sessionCode, status: s.status,
        checkinOpen: !!s.checkin_open,
        course: { id: s.cId, code: s.cCode, name: s.cName },
        classroom: {
          name: s.roomName,
          latitude: Number(s.latitude), longitude: Number(s.longitude), radiusM: s.radius_m,
        },
        startedAt: s.started_at, expiresAt: s.expires_at,
      })),
    }))
  } catch (err) { next(err) }
}

// ── QR token validator ───────────────────────────────────────────────────────
function validateQrToken(sessionId, token, window) {
  const secret = process.env.JWT_SECRET || 'dev_secret'
  const now = Math.floor(Date.now() / 30000)
  for (const w of [now, now - 1]) {
    if (Number(window) === w) {
      const expected = createHmac('sha256', secret)
        .update(`${sessionId}|${w}`)
        .digest('hex')
        .slice(0, 16)
      if (expected === token) return true
    }
  }
  return false
}

// ── Validation rules for check-in ────────────────────────────────────────────
const checkInValidation = [
  body('sessionId').isUUID().withMessage('Valid session ID required'),
  body('entryCode').isLength({ min: 6, max: 6 }).withMessage('6-digit code required'),
  body('latitude').isFloat({ min: -90, max: 90 }).withMessage('Invalid latitude'),
  body('longitude').isFloat({ min: -180, max: 180 }).withMessage('Invalid longitude'),
]

// ── Check-in ──────────────────────────────────────────────────────────────────
async function checkIn(req, res, next) {
  try {
    const errors = validationResult(req)
    if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() })

    const studentId = req.user.id
    const { sessionId, latitude, longitude, entryCode, qrToken, qrWindow } = req.body

    // Validate coordinate ranges
    if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
      return res.status(422).json({ success: false, error: 'Invalid coordinates' })
    }

    // Load session + classroom + course late threshold
    const [[session]] = await db.query(
      `SELECT s.id, s.course_id, s.status, s.checkin_open, s.expires_at, s.session_code,
              s.started_at,
              cl.latitude AS clLat, cl.longitude AS clLon, cl.radius_m,
              c.late_threshold_minutes
         FROM attendance_sessions s
         JOIN classrooms cl ON cl.id = s.classroom_id
         JOIN courses    c  ON c.id  = s.course_id
        WHERE s.id = ?`,
      [sessionId]
    )

    if (!session) return res.status(404).json(error('Session not found'))

    // Verify auth method: QR token OR entry code (one must be provided)
    if (qrToken && qrWindow !== undefined) {
      if (!validateQrToken(sessionId, qrToken, qrWindow)) {
        return res.status(401).json(error('Invalid or expired QR code'))
      }
    } else if (entryCode) {
      if (session.session_code !== entryCode.toUpperCase()) {
        return res.status(401).json(error('Invalid session code'))
      }
    } else {
      return res.status(400).json(error('Provide either a QR token or entry code'))
    }
    
    if (session.status !== 'active' || !session.checkin_open) {
      return res.status(400).json(error('Check-in is not open for this session'))
    }

    // Enforce session expiry even if lecturer forgot to close
    if (new Date() > new Date(session.expires_at)) {
      return res.status(410).json({ success: false, error: 'This session has expired' })
    }

    // ── Security evaluation ───────────────────────────────────────────────────
    const secCtx = req.body.securityContext || {}
    const secResult = await security.evaluate(secCtx)
    const clientIp = req.headers['x-forwarded-for']?.split(',')[0] || req.socket.remoteAddress

    // Log every check-in with its security result (low, medium, high)
    if (secResult.riskLevel !== 'low') {
      await security.log({
        studentId, sessionId, result: secResult,
        securityContext: secCtx, ipAddress: clientIp,
      })
    }

    if (secResult.action === 'blocked') {
      return res.status(403).json({
        success: false,
        error: 'Check-in blocked due to security concerns.',
        security: { riskLevel: secResult.riskLevel, score: secResult.score, flags: secResult.flags },
      })
    }
    // ── End security evaluation ───────────────────────────────────────────────

    // Verify enrollment
    const [[enrolled]] = await db.query(
      'SELECT id FROM enrollments WHERE student_id=? AND course_id=?',
      [studentId, session.course_id]
    )
    if (!enrolled) return res.status(403).json(error('You are not enrolled in this course'))

    // Already checked in?
    const [[existing]] = await db.query(
      'SELECT id FROM attendance_records WHERE session_id=? AND student_id=?',
      [sessionId, studentId]
    )
    if (existing) return res.status(409).json(error('You have already checked in to this session'))

    // Geofence validation
    const distanceM = haversine(latitude, longitude, Number(session.clLat), Number(session.clLon))
    const geofencePassed = distanceM <= session.radius_m

    if (!geofencePassed) {
      return res.status(400).json(error(
        `You are ${Math.round(distanceM)}m away. You must be within ${session.radius_m}m to check in.`
      ))
    }

    // Determine attendance status — late if check-in is past the threshold
    const lateThresholdMs = (session.late_threshold_minutes ?? 15) * 60 * 1000
    const attendanceStatus =
      (new Date() - new Date(session.started_at)) > lateThresholdMs ? 'late' : 'present'

    // Save record
    const recordId = randomUUID()
    const method = (qrToken) ? 'qr' : 'code'
    await db.query(
      `INSERT INTO attendance_records
         (id, session_id, student_id, status, submission_method, geofence_passed, latitude, longitude, distance_m)
       VALUES (?,?,?,?,?,?,?,?,?)`,
      [recordId, sessionId, studentId, attendanceStatus, method, 1, latitude, longitude, distanceM.toFixed(2)]
    )

    // Emit socket event to lecturer's monitoring room
    const io = req.app.get('io')
    if (io) {
      const [[student]] = await db.query(
        'SELECT full_name, reg_number FROM users WHERE id=?', [studentId]
      )
      io.to(`session:${sessionId}`).emit('attendance_update', {
        sessionId, studentId,
        student: { fullName: student.full_name, regNumber: student.reg_number },
        status: attendanceStatus,
        distanceM: Math.round(distanceM), checkedInAt: new Date().toISOString(),
      })
    }

    // Push confirmation to the student's own device
    const [[course]] = await db.query(
      'SELECT c.name FROM courses c JOIN attendance_sessions s ON s.course_id = c.id WHERE s.id = ?',
      [sessionId]
    )
    fcm.notifyAttendanceConfirmed(studentId, course?.name || 'your course')

    res.json(success({
      status: 'checked_in',
      attendanceStatus,
      distanceM: Math.round(distanceM),
      checkedInAt: new Date().toISOString(),
      message: attendanceStatus === 'late'
        ? `Marked as late — arrived ${Math.round((new Date() - new Date(session.started_at)) / 60000)} min after session started.`
        : 'Attendance recorded successfully.',
      security: {
        riskLevel: secResult.riskLevel,
        score: secResult.score,
        flags: secResult.flags,
        warned: secResult.action === 'warned',
      },
    }))
  } catch (err) { next(err) }
}

// ── History ───────────────────────────────────────────────────────────────────
async function getHistory(req, res, next) {
  try {
    const studentId = req.user.id
    const { courseId, page = 1, limit = 50 } = req.query
    const offset = (Number(page) - 1) * Number(limit)

    let where = 'r.student_id = ?'
    const params = [studentId]
    if (courseId) { where += ' AND s.course_id = ?'; params.push(courseId) }

    const [rows] = await db.query(
      `SELECT r.id, r.status, r.marked_at, r.geofence_passed, r.distance_m,
              s.session_code, s.started_at,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.name AS roomName,
              a.status AS appealStatus, a.id AS appealId, a.review_note AS appealNote
         FROM attendance_records r
         JOIN attendance_sessions s ON s.id = r.session_id
         JOIN courses c ON c.id = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
         LEFT JOIN appeals a ON a.record_id = r.id
        WHERE ${where}
        ORDER BY r.marked_at DESC
        LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    )

    const [[{ total }]] = await db.query(
      `SELECT COUNT(*) AS total FROM attendance_records r
       JOIN attendance_sessions s ON s.id = r.session_id
       WHERE ${where}`,
      params
    )

    res.json(success(
      rows.map(r => ({
        id: r.id, status: r.status, markedAt: r.marked_at,
        geofencePassed: !!r.geofence_passed, distanceM: Number(r.distance_m),
        appeal: r.appealId ? {
          id: r.appealId, status: r.appealStatus, reviewNote: r.appealNote,
        } : null,
        session: {
          sessionCode: r.session_code, startedAt: r.started_at,
          course: { id: r.cId, code: r.cCode, name: r.cName },
          classroom: { name: r.roomName },
        },
      })),
      { page: Number(page), limit: Number(limit), total: Number(total) }
    ))
  } catch (err) { next(err) }
}

// ── Analytics ────────────────────────────────────────────────────────────────
async function getAnalytics(req, res, next) {
  try {
    const studentId = req.user.id

    const [courseStats] = await db.query(
      `SELECT c.id, c.code, c.name, c.late_threshold_minutes AS lateThresholdMinutes,
              COUNT(r.id) AS totalSessions,
              SUM(r.status='present') AS presentSessions,
              SUM(r.status='late')    AS lateSessions,
              SUM(r.status='absent')  AS absentSessions,
              ROUND(100 * (SUM(r.status='present') + SUM(r.status='late')) / NULLIF(COUNT(r.id),0), 1) AS attendanceRate
         FROM courses c
         JOIN enrollments en ON en.course_id = c.id AND en.student_id = ?
         LEFT JOIN attendance_sessions s ON s.course_id = c.id
         LEFT JOIN attendance_records r ON r.session_id = s.id AND r.student_id = ?
        GROUP BY c.id
        ORDER BY c.code`,
      [studentId, studentId]
    )

    const [trend] = await db.query(
      `SELECT DATE(r.marked_at) AS sessionDate, r.status
         FROM attendance_records r
         JOIN attendance_sessions s ON s.id = r.session_id
        WHERE r.student_id = ?
        ORDER BY r.marked_at ASC`,
      [studentId]
    )

    // Compute streaks from trend data
    let currentStreak = 0, longestStreak = 0, running = 0
    for (const t of [...trend].reverse()) {
      if (t.status === 'present') { running++; if (currentStreak === 0) currentStreak = running }
      else { if (currentStreak === 0) { currentStreak = 0 }; running = 0 }
      if (running > longestStreak) longestStreak = running
    }

    const overallRate = courseStats.length
      ? courseStats.reduce((s, c) => s + (Number(c.attendanceRate) || 0), 0) / courseStats.length
      : 0

    res.json(success({
      overallRate: Math.round(overallRate * 10) / 10,
      currentStreak,
      longestStreak,
      courseStats: courseStats.map(c => ({
        id: c.id, code: c.code, name: c.name,
        lateThresholdMinutes: Number(c.lateThresholdMinutes) || 15,
        totalSessions:   Number(c.totalSessions),
        presentSessions: Number(c.presentSessions),
        lateSessions:    Number(c.lateSessions)   || 0,
        absentSessions:  Number(c.absentSessions) || 0,
        attendanceRate:  Number(c.attendanceRate)  || 0,
      })),
      trendData: trend.map(t => ({ sessionDate: t.sessionDate, status: t.status })),
    }))
  } catch (err) { next(err) }
}

// ── Courses ───────────────────────────────────────────────────────────────────
async function getCourses(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT c.id, c.code, c.name, c.credits
         FROM courses c
         JOIN enrollments en ON en.course_id = c.id
        WHERE en.student_id = ? AND c.is_active = 1`,
      [req.user.id]
    )
    res.json(success(rows))
  } catch (err) { next(err) }
}

// ── Active sessions ───────────────────────────────────────────────────────────
async function getActiveSessions(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT s.id, s.session_code AS sessionCode, s.status, s.checkin_open, s.started_at, s.expires_at,
              c.id AS cId, c.code AS cCode, c.name AS cName,
              cl.name AS roomName, cl.latitude, cl.longitude, cl.radius_m
         FROM attendance_sessions s
         JOIN courses c ON c.id = s.course_id
         JOIN classrooms cl ON cl.id = s.classroom_id
         JOIN enrollments en ON en.course_id = s.course_id AND en.student_id = ?
        WHERE s.status = 'active'`,
      [req.user.id]
    )
    res.json(success(rows.map(s => ({
      id: s.id, sessionCode: s.sessionCode, status: s.status, checkinOpen: !!s.checkin_open,
      course: { id: s.cId, code: s.cCode, name: s.cName },
      classroom: {
        name: s.roomName,
        latitude: Number(s.latitude), longitude: Number(s.longitude), radiusM: s.radius_m,
      },
      startedAt: s.started_at, expiresAt: s.expires_at,
    }))))
  } catch (err) { next(err) }
}

// ── Notification preferences ──────────────────────────────────────────────────
async function getNotifPrefs(req, res, next) {
  try {
    const [rows] = await db.query(
      'SELECT * FROM notification_preferences WHERE user_id = ?', [req.user.id]
    )
    if (!rows.length) {
      // Return defaults if not yet saved
      return res.json(success({ sessionStart: true, absenceAlert: true, lowAttendance: true, weeklyReport: false }))
    }
    const p = rows[0]
    res.json(success({
      sessionStart:  !!p.session_start,
      absenceAlert:  !!p.absence_alert,
      lowAttendance: !!p.low_attendance,
      weeklyReport:  !!p.weekly_report,
    }))
  } catch (err) { next(err) }
}

async function updateNotifPrefs(req, res, next) {
  try {
    const { sessionStart = true, absenceAlert = true, lowAttendance = true, weeklyReport = false } = req.body
    await db.query(
      `INSERT INTO notification_preferences (user_id, session_start, absence_alert, low_attendance, weekly_report)
       VALUES (?,?,?,?,?)
       ON DUPLICATE KEY UPDATE
         session_start  = VALUES(session_start),
         absence_alert  = VALUES(absence_alert),
         low_attendance = VALUES(low_attendance),
         weekly_report  = VALUES(weekly_report)`,
      [req.user.id, sessionStart ? 1 : 0, absenceAlert ? 1 : 0, lowAttendance ? 1 : 0, weeklyReport ? 1 : 0]
    )
    res.json(success({ sessionStart, absenceAlert, lowAttendance, weeklyReport }))
  } catch (err) { next(err) }
}

// ── Device token (FCM) ────────────────────────────────────────────────────────
async function registerDeviceToken(req, res, next) {
  try {
    const { fcmToken, platform = 'android' } = req.body
    if (!fcmToken || !fcmToken.trim()) {
      return res.status(422).json({ success: false, error: 'fcmToken is required' })
    }

    await db.query(
      `INSERT INTO device_tokens (id, user_id, token, platform)
       VALUES (?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE token = ?, updated_at = NOW()`,
      [randomUUID(), req.user.id, fcmToken.trim(), platform, fcmToken.trim()]
    )

    res.json(success(null))
  } catch (err) { next(err) }
}

// Export validation middleware
module.exports = {
  getDashboard, checkIn, checkInValidation, getHistory, getAnalytics, getCourses, getActiveSessions,
  getNotifPrefs, updateNotifPrefs, registerDeviceToken,
}