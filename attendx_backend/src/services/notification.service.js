'use strict'
const ATTENDANCE_THRESHOLD = Number(process.env.ATTENDANCE_WARNING_THRESHOLD) || 75
/**
 * Unified Notification Service
 *
 * Single entry point for all notifications in the system.
 * Reads per-user notification_preferences before sending.
 * Sends both push (FCM) and email in parallel when both channels are enabled.
 */
const db      = require('../config/database')
const fcm     = require('./fcm.service')
const email   = require('./email.service')

// ── Preference loader ─────────────────────────────────────────────────────────
async function _prefs(userId) {
  const [[row]] = await db.query(
    'SELECT * FROM notification_preferences WHERE user_id = ?', [userId]
  )
  // Return defaults if user has not saved preferences yet
  return row || { session_start: 1, absence_alert: 1, low_attendance: 1, weekly_report: 0 }
}

// ── User lookup ───────────────────────────────────────────────────────────────
async function _user(userId) {
  const [[row]] = await db.query(
    'SELECT id, email, full_name FROM users WHERE id = ? AND is_active = 1', [userId]
  )
  return row || null
}

// ── 1. Session started — alert all enrolled students ─────────────────────────
async function notifySessionStarted({ sessionId, courseId, courseName, roomName, sessionCode, expiresAt }) {
  try {
    // FCM push to all enrolled (handled by fcm.service which checks preferences via tokens)
    await fcm.notifySessionStarted({ sessionId, courseId, courseName, room: roomName, sessionCode })

    // Email only to students who prefer email AND have session_start enabled
    const [students] = await db.query(
      `SELECT u.id, u.email, u.full_name, np.session_start
         FROM enrollments e
         JOIN users u ON u.id = e.student_id AND u.is_active = 1
    LEFT JOIN notification_preferences np ON np.user_id = u.id
        WHERE e.course_id = ?`,
      [courseId]
    )

    const expiresLabel = expiresAt
      ? new Date(expiresAt).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })
      : 'soon'

    // Fire emails concurrently, ignore individual failures
    await Promise.allSettled(
      students
        .filter(s => (s.session_start ?? 1) === 1)
        .map(s =>
          email.sendSessionStarted(s.email, {
            studentName: s.full_name,
            courseName,
            roomName,
            sessionCode,
            expiresAt: expiresLabel,
          })
        )
    )
  } catch (err) {
    console.error('[Notify] notifySessionStarted:', err.message)
  }
}

// ── 2. Attendance confirmed — individual student push only ───────────────────
async function notifyAttendanceConfirmed(studentId, courseName) {
  try {
    const prefs = await _prefs(studentId)
    if (!prefs.absence_alert) return   // reuse absence_alert pref for confirmation

    await fcm.notifyAttendanceConfirmed(studentId, courseName)
  } catch (err) {
    console.error('[Notify] notifyAttendanceConfirmed:', err.message)
  }
}

// ── 3. Absence warning — push + email ────────────────────────────────────────
async function notifyAbsenceWarning({ studentId, studentName, courseName, attendanceRate, courseId, sentBy }) {
  try {
    const [prefs, user] = await Promise.all([_prefs(studentId), _user(studentId)])

    if (!prefs.absence_alert) return

    const tasks = []

    // FCM push
    tasks.push(
      fcm.notifyAbsenceWarning({ studentId, studentName, attendanceRate, courseName })
    )

    // Email
    if (user?.email) {
      tasks.push(
        email.sendAbsenceWarning(user.email, {
          studentName: studentName || user.full_name,
          courseName,
          attendanceRate,
        })
      )
    }

    await Promise.allSettled(tasks)

    // Log warning (fire-and-forget, table must exist in migrations)
    db.query(
      `INSERT INTO attendance_warnings
         (id, student_id, course_id, course_name, sent_by, channel, attendance_rate, status)
         VALUES (UUID(), ?, ?, ?, ?, 'both', ?, 'sent')`,
      [studentId, courseId || null, courseName, sentBy || null, attendanceRate]
    ).catch(() => {})

  } catch (err) {
    console.error('[Notify] notifyAbsenceWarning:', err.message)
  }
}

// ── 4. Absent students after session close — push + conditional email ─────────
async function notifyAbsentStudents({ sessionId, courseId }) {
  try {
    // FCM handled by existing fcm.service
    await fcm.notifyAbsentStudents({ sessionId, courseId })

    // Email those who have absence_alert enabled
    const [absents] = await db.query(
      `SELECT u.id, u.email, u.full_name, c.name AS courseName,
              COALESCE(np.absence_alert, 1) AS wantsEmail
         FROM attendance_records ar
         JOIN attendance_sessions s ON s.id = ar.session_id
         JOIN courses c ON c.id = s.course_id
         JOIN users u ON u.id = ar.student_id AND u.is_active = 1
    LEFT JOIN notification_preferences np ON np.user_id = u.id
        WHERE ar.session_id = ? AND ar.status = 'absent'`,
      [sessionId]
    )

    // Compute attendance rate per student and send warning email if below 75%
    await Promise.allSettled(
      absents
        .filter(a => a.wantsEmail)
        .map(async (a) => {
          const [[stat]] = await db.query(
            `SELECT ROUND(100*SUM(ar2.status='present')/COUNT(*), 1) AS rate
               FROM attendance_records ar2
               JOIN attendance_sessions s2 ON s2.id = ar2.session_id
              WHERE ar2.student_id = ? AND s2.course_id = ?`,
            [a.id, courseId]
          )
          const rate = Number(stat?.rate ?? 0)
          if (rate < ATTENDANCE_THRESHOLD) {
            await notifyAbsenceWarning({
              studentId:      a.id,
              studentName:    a.full_name,
              courseName:     a.courseName,
              attendanceRate: rate,
              courseId,
            })
          }
        })
    )
  } catch (err) {
    console.error('[Notify] notifyAbsentStudents:', err.message)
  }
}

// ── 5. Appeal submitted — notify lecturer ────────────────────────────────────
async function notifyNewAppeal({ lecturerId, studentName, courseName, appealId }) {
  try {
    await fcm.notifyNewAppeal({ lecturerId, studentName, courseName, appealId })
  } catch (err) {
    console.error('[Notify] notifyNewAppeal:', err.message)
  }
}

// ── 6. Appeal result — push + email ──────────────────────────────────────────
async function notifyAppealResult({ studentId, courseName, status, reviewNote }) {
  try {
    const user = await _user(studentId)

    await Promise.allSettled([
      fcm.notifyAppealResult({ studentId, courseName, status, note: reviewNote }),
      user?.email
        ? email.sendAppealResult(user.email, {
            studentName: user.full_name,
            courseName,
            status,
            reviewNote,
          })
        : Promise.resolve(),
    ])
  } catch (err) {
    console.error('[Notify] notifyAppealResult:', err.message)
  }
}

// ── 7. Weekly digest (called from cron) ──────────────────────────────────────
async function sendWeeklyDigests() {
  try {
    const [students] = await db.query(
      `SELECT DISTINCT u.id, u.email, u.full_name
         FROM users u
         JOIN notification_preferences np ON np.user_id = u.id
        WHERE u.role = 'student' AND u.is_active = 1 AND np.weekly_report = 1`
    )

    let sent = 0
    for (const s of students) {
      try {
        const [courses] = await db.query(
          `SELECT c.code, c.name,
                  ROUND(100 * SUM(ar.status = 'present') / COUNT(*), 1) AS rate
             FROM attendance_records ar
             JOIN attendance_sessions sess ON sess.id = ar.session_id
             JOIN courses c ON c.id = sess.course_id
            WHERE ar.student_id = ?
              AND sess.started_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
            GROUP BY c.id`,
          [s.id]
        )

        const [[overall]] = await db.query(
          `SELECT ROUND(100 * SUM(ar.status = 'present') / NULLIF(COUNT(*), 0), 1) AS rate
             FROM attendance_records ar
             JOIN attendance_sessions sess ON sess.id = ar.session_id
            WHERE ar.student_id = ?`,
          [s.id]
        )

        await email.sendWeeklyDigest(s.email, {
          studentName: s.full_name,
          overallRate: Number(overall?.rate ?? 0),
          courses,
        })
        sent++
      } catch (innerErr) {
        console.warn(`[Notify] Weekly digest failed for ${s.email}:`, innerErr.message)
      }
    }

    console.log(`[Notify] Weekly digests sent: ${sent}/${students.length}`)
  } catch (err) {
    console.error('[Notify] sendWeeklyDigests:', err.message)
  }
}

module.exports = {
  notifySessionStarted,
  notifyAttendanceConfirmed,
  notifyAbsenceWarning,
  notifyAbsentStudents,
  notifyNewAppeal,
  notifyAppealResult,
  sendWeeklyDigests,
}
