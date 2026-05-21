const bcrypt  = require('bcryptjs')
const { randomUUID } = require('crypto')
const db      = require('../config/database')
const { success, error } = require('../utils/response')

// ── Users ─────────────────────────────────────────────────────────────────────
async function getUsers(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT id, full_name, email, role, reg_number, department, is_active, created_at
         FROM users ORDER BY created_at DESC`
    )
    res.json(success(rows.map(u => ({
      id: u.id, fullName: u.full_name, email: u.email, role: u.role,
      regNumber: u.reg_number, department: u.department,
      isActive: !!u.is_active, createdAt: u.created_at,
    }))))
  } catch (err) { next(err) }
}

async function createUser(req, res, next) {
  try {
    const { fullName, email, password, role, regNumber, department } = req.body
    const hash = await bcrypt.hash(password, 12)
    const id   = randomUUID()
    await db.query(
      'INSERT INTO users (id, full_name, email, password_hash, role, reg_number, department) VALUES (?,?,?,?,?,?,?)',
      [id, fullName, email, hash, role || 'student', regNumber || null, department || null]
    )
    res.status(201).json(success({ id, fullName, email, role, regNumber, department, isActive: true }))
  } catch (err) { next(err) }
}

async function updateUser(req, res, next) {
  try {
    const { id }  = req.params
    const { fullName, email, role, department, isActive } = req.body
    await db.query(
      'UPDATE users SET full_name=?, email=?, role=?, department=?, is_active=? WHERE id=?',
      [fullName, email, role, department, isActive ? 1 : 0, id]
    )
    res.json(success({ id, fullName, email, role, department, isActive }))
  } catch (err) { next(err) }
}

async function deleteUser(req, res, next) {
  try {
    await db.query('UPDATE users SET is_active = 0 WHERE id = ?', [req.params.id])
    res.json(success(null))
  } catch (err) { next(err) }
}

// ── Courses ───────────────────────────────────────────────────────────────────
async function getCourses(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT c.id, c.code, c.name, c.credits, c.department, c.late_threshold_minutes,
              u.id AS lec_id, u.full_name AS lec_name,
              (SELECT COUNT(*) FROM enrollments e WHERE e.course_id = c.id) AS students
         FROM courses c
         LEFT JOIN users u ON u.id = c.lecturer_id
        WHERE c.is_active = 1
        ORDER BY c.code`
    )
    res.json(success(rows.map(r => ({
      id: r.id, code: r.code, name: r.name, credits: r.credits, department: r.department,
      lateThresholdMinutes: r.late_threshold_minutes,
      students: Number(r.students),
      lecturer: r.lec_id ? { id: r.lec_id, fullName: r.lec_name } : null,
    }))))
  } catch (err) { next(err) }
}

async function createCourse(req, res, next) {
  try {
    const { code, name, credits, department, lecturerId, lateThresholdMinutes = 15 } = req.body
    const id = randomUUID()
    await db.query(
      'INSERT INTO courses (id, code, name, credits, department, lecturer_id, late_threshold_minutes) VALUES (?,?,?,?,?,?,?)',
      [id, code, name, credits || 3, department || null, lecturerId || null, lateThresholdMinutes]
    )
    res.status(201).json(success({ id, code, name, credits, department, lateThresholdMinutes, lecturer: null, students: 0 }))
  } catch (err) { next(err) }
}

async function updateCourse(req, res, next) {
  try {
    const { code, name, credits, department, lecturerId, lateThresholdMinutes } = req.body
    await db.query(
      `UPDATE courses SET code=?, name=?, credits=?, department=?, lecturer_id=?
         ${lateThresholdMinutes !== undefined ? ', late_threshold_minutes=?' : ''}
       WHERE id=?`,
      lateThresholdMinutes !== undefined
        ? [code, name, credits, department, lecturerId || null, lateThresholdMinutes, req.params.id]
        : [code, name, credits, department, lecturerId || null, req.params.id]
    )
    res.json(success({ id: req.params.id, ...req.body }))
  } catch (err) { next(err) }
}

async function deleteCourse(req, res, next) {
  try {
    await db.query('UPDATE courses SET is_active = 0 WHERE id = ?', [req.params.id])
    res.json(success(null))
  } catch (err) { next(err) }
}

// ── Course Enrollments ────────────────────────────────────────────────────────
async function getCourseEnrollments(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT u.id, u.full_name, u.email, u.reg_number, e.enrolled_at
         FROM enrollments e
         JOIN users u ON u.id = e.student_id
        WHERE e.course_id = ?
        ORDER BY u.full_name`,
      [req.params.id]
    )
    res.json(success(rows.map(r => ({
      id: r.id, fullName: r.full_name, email: r.email,
      regNumber: r.reg_number, enrolledAt: r.enrolled_at,
    }))))
  } catch (err) { next(err) }
}

async function enrollStudent(req, res, next) {
  try {
    const { studentId } = req.body
    if (!studentId) return res.status(400).json(error('studentId is required'))
    const [[student]] = await db.query('SELECT id, full_name, email FROM users WHERE id=? AND role=?', [studentId, 'student'])
    if (!student) return res.status(404).json(error('Student not found'))
    const id = randomUUID()
    await db.query(
      'INSERT IGNORE INTO enrollments (id, student_id, course_id) VALUES (?,?,?)',
      [id, studentId, req.params.id]
    )
    res.status(201).json(success({ id: student.id, fullName: student.full_name, email: student.email }))
  } catch (err) { next(err) }
}

async function unenrollStudent(req, res, next) {
  try {
    await db.query(
      'DELETE FROM enrollments WHERE course_id=? AND student_id=?',
      [req.params.id, req.params.studentId]
    )
    res.json(success(null))
  } catch (err) { next(err) }
}

// ── Classrooms ────────────────────────────────────────────────────────────────
async function getClassrooms(req, res, next) {
  try {
    const [rows] = await db.query(
      'SELECT id, name, building, capacity, latitude, longitude, radius_m FROM classrooms WHERE is_active=1 ORDER BY name'
    )
    res.json(success(rows.map(r => ({
      id: r.id, name: r.name, building: r.building, capacity: r.capacity,
      latitude: Number(r.latitude), longitude: Number(r.longitude), radiusM: r.radius_m,
    }))))
  } catch (err) { next(err) }
}

async function createClassroom(req, res, next) {
  try {
    const { name, building, capacity, latitude, longitude, radiusM } = req.body
    const id = randomUUID()
    await db.query(
      'INSERT INTO classrooms (id, name, building, capacity, latitude, longitude, radius_m) VALUES (?,?,?,?,?,?,?)',
      [id, name, building || null, capacity || 60, latitude, longitude, radiusM || 30]
    )
    res.status(201).json(success({ id, name, building, capacity, latitude, longitude, radiusM }))
  } catch (err) { next(err) }
}

async function updateClassroom(req, res, next) {
  try {
    const { name, building, capacity, latitude, longitude, radiusM } = req.body
    await db.query(
      'UPDATE classrooms SET name=?, building=?, capacity=?, latitude=?, longitude=?, radius_m=? WHERE id=?',
      [name, building || null, capacity || 60, latitude, longitude, radiusM || 30, req.params.id]
    )
    res.json(success({ id: req.params.id, name, building, capacity, latitude, longitude, radiusM }))
  } catch (err) { next(err) }
}

async function deleteClassroom(req, res, next) {
  try {
    await db.query('UPDATE classrooms SET is_active = 0 WHERE id = ?', [req.params.id])
    res.json(success(null))
  } catch (err) { next(err) }
}

// ── Analytics ────────────────────────────────────────────────────────────────
async function getAnalytics(req, res, next) {
  try {
    const [[totals]] = await db.query(
      `SELECT
        (SELECT COUNT(*) FROM users WHERE is_active=1 AND role != 'admin') AS totalUsers,
        (SELECT COUNT(*) FROM courses WHERE is_active=1)                   AS totalCourses,
        (SELECT COUNT(*) FROM attendance_sessions WHERE status='active')   AS activeSessions,
        (SELECT ROUND(100 * SUM(status='present') / NULLIF(COUNT(*),0), 1)
           FROM attendance_records)                                        AS overallAttendanceRate`
    )

    const [atRisk] = await db.query(
      `SELECT u.full_name AS student, c.code AS course,
              ROUND(100 * SUM(ar.status='present') / COUNT(*), 1) AS rate
         FROM attendance_records ar
         JOIN attendance_sessions s ON s.id = ar.session_id
         JOIN users u ON u.id = ar.student_id
         JOIN courses c ON c.id = s.course_id
        GROUP BY ar.student_id, s.course_id
       HAVING rate < 75
        ORDER BY rate ASC
        LIMIT 10`
    )

    const [trend] = await db.query(
      `SELECT DATE_FORMAT(s.started_at,'%Y-W%u') AS week,
              ROUND(100 * SUM(r.status='present') / COUNT(*), 1) AS rate
         FROM attendance_records r
         JOIN attendance_sessions s ON s.id = r.session_id
        WHERE s.started_at >= DATE_SUB(NOW(), INTERVAL 8 WEEK)
        GROUP BY week
        ORDER BY week`
    )

    res.json(success({
      totalUsers: Number(totals.totalUsers),
      totalCourses: Number(totals.totalCourses),
      activeSessions: Number(totals.activeSessions),
      overallAttendanceRate: Number(totals.overallAttendanceRate ?? 0),
      trend: trend.map(t => ({ week: t.week, rate: Number(t.rate) })),
      atRisk: atRisk.map(r => ({ student: r.student, course: r.course, rate: Number(r.rate) })),
    }))
  } catch (err) { next(err) }
}

// ── Bulk user import ──────────────────────────────────────────────────────────
async function bulkCreateUsers(req, res, next) {
  try {
    const { users } = req.body
    if (!Array.isArray(users) || !users.length) {
      return res.status(400).json(error('Provide a non-empty users array'))
    }

    const results = { created: 0, skipped: 0, errors: [] }

    for (const u of users) {
      try {
        const { fullName, email, password, role, regNumber, department } = u
        if (!fullName || !email) { results.errors.push(`${email}: missing fullName or email`); results.skipped++; continue }
        const hash = await bcrypt.hash(password || 'Student@1234', 12)
        await db.query(
          'INSERT INTO users (id, full_name, email, password_hash, role, reg_number, department) VALUES (?,?,?,?,?,?,?)',
          [randomUUID(), fullName, email, hash, role || 'student', regNumber || null, department || null]
        )
        results.created++
      } catch (e) {
        results.skipped++
        results.errors.push(`${u.email}: ${e.code === 'ER_DUP_ENTRY' ? 'email already exists' : e.message}`)
      }
    }

    res.status(201).json(success(results))
  } catch (err) { next(err) }
}

// ── Security Config ───────────────────────────────────────────────────────────
async function getSecurityConfig(req, res, next) {
  try {
    const secSvc = require('../services/security.service')
    const cfg = await secSvc.loadConfig()
    res.json(success(cfg))
  } catch (err) { next(err) }
}

async function updateSecurityConfig(req, res, next) {
  try {
    const { weights, thresholds, blockLevel, warnLevel } = req.body
    const updates = []
    if (weights)    updates.push(['weights',    JSON.stringify(weights)])
    if (thresholds) updates.push(['thresholds', JSON.stringify(thresholds)])
    if (blockLevel) updates.push(['blockLevel', JSON.stringify(blockLevel)])
    if (warnLevel)  updates.push(['warnLevel',  JSON.stringify(warnLevel)])

    for (const [key, val] of updates) {
      await db.query(
        'INSERT INTO security_config (config_key, config_value) VALUES (?,?) ON DUPLICATE KEY UPDATE config_value=?',
        [key, val, val]
      )
    }

    // Bust the cache
    const secSvc = require('../services/security.service')
    const cfg = await secSvc.loadConfig()
    res.json(success(cfg))
  } catch (err) { next(err) }
}

// ── Security Logs ─────────────────────────────────────────────────────────────
async function getSecurityLogs(req, res, next) {
  try {
    const { level, page = 1, limit = 50 } = req.query
    const offset = (Number(page) - 1) * Number(limit)

    let where = '1=1'
    const params = []
    if (level) { where += ' AND sl.risk_level = ?'; params.push(level) }

    const [rows] = await db.query(
      `SELECT sl.id, sl.risk_level, sl.risk_score, sl.flags, sl.ip_address,
              sl.device_model, sl.platform, sl.action_taken, sl.created_at,
              u.full_name AS studentName, u.email AS studentEmail, u.reg_number AS regNumber,
              s.session_code, c.name AS courseName
         FROM security_logs sl
         JOIN users u ON u.id = sl.student_id
         LEFT JOIN attendance_sessions s ON s.id = sl.session_id
         LEFT JOIN courses c ON c.id = s.course_id
        WHERE ${where}
        ORDER BY sl.created_at DESC
        LIMIT ? OFFSET ?`,
      [...params, Number(limit), offset]
    )

    const [[{ total }]] = await db.query(
      `SELECT COUNT(*) AS total FROM security_logs sl WHERE ${where}`, params
    )

    res.json(success(
      rows.map(r => ({
        id: r.id, riskLevel: r.risk_level, riskScore: r.risk_score,
        flags: r.flags, ipAddress: r.ip_address,
        deviceModel: r.device_model, platform: r.platform,
        actionTaken: r.action_taken, createdAt: r.created_at,
        student: { name: r.studentName, email: r.studentEmail, regNumber: r.regNumber },
        session: r.session_code ? { code: r.session_code, course: r.courseName } : null,
      })),
      { page: Number(page), limit: Number(limit), total: Number(total) }
    ))
  } catch (err) { next(err) }
}

// ── System Settings ───────────────────────────────────────────────────────────
async function getSettings(req, res, next) {
  try {
    const [rows] = await db.query(`SELECT config_key, config_value FROM security_config`)
    const cfg = {}
    rows.forEach(r => { try { cfg[r.config_key] = JSON.parse(r.config_value) } catch { cfg[r.config_key] = r.config_value } })

    res.json(success({
      notificationPrefs: {
        sessionStart:  true,
        absenceAlert:  true,
        lowAttendance: true,
        weeklyReport:  false,
      },
      sessionTtlMinutes:    Number(process.env.SESSION_TTL_MINUTES)          || 90,
      geofenceRadiusM:      Number(process.env.DEFAULT_RADIUS_M)             || 30,
      lateThresholdMinutes: Number(process.env.LATE_THRESHOLD_MINUTES)       || 15,
      attendanceWarning:    Number(process.env.ATTENDANCE_WARNING_THRESHOLD)  || 75,
      securityConfig:       cfg,
    }))
  } catch (err) { next(err) }
}

async function updateSettings(req, res, next) {
  try {
    const { sessionTtlMinutes, geofenceRadiusM, lateThresholdMinutes } = req.body

    // Persist to security_config as a simple key-value store
    const updates = []
    if (sessionTtlMinutes    != null) updates.push(['session_ttl_minutes',    String(sessionTtlMinutes)])
    if (geofenceRadiusM      != null) updates.push(['geofence_radius_m',      String(geofenceRadiusM)])
    if (lateThresholdMinutes != null) updates.push(['late_threshold_minutes', String(lateThresholdMinutes)])

    for (const [key, value] of updates) {
      await db.query(
        `INSERT INTO security_config (config_key, config_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE config_value = ?`,
        [key, value, value]
      )
    }

    res.json(success({ message: 'Settings saved successfully' }))
  } catch (err) { next(err) }
}

// ── Data Export ───────────────────────────────────────────────────────────────
async function exportData(req, res, next) {
  try {
    const format = req.query.format === 'json' ? 'json' : 'csv'

    const [records] = await db.query(`
      SELECT u.full_name AS student, u.reg_number AS regNumber,
             c.code AS courseCode, c.name AS courseName,
             s.session_code AS sessionCode, r.status,
             r.submission_method AS method, r.marked_at AS markedAt
        FROM attendance_records r
        JOIN attendance_sessions s ON s.id = r.session_id
        JOIN courses c ON c.id = s.course_id
        JOIN users u ON u.id = r.student_id
       ORDER BY r.marked_at DESC
    `)

    if (format === 'json') {
      res.setHeader('Content-Type', 'application/json')
      res.setHeader('Content-Disposition', 'attachment; filename="attendx_export.json"')
      return res.json(records)
    }

    // CSV
    const header = 'Student,Reg Number,Course Code,Course Name,Session Code,Status,Method,Marked At'
    const rows = records.map(r =>
      [r.student, r.regNumber, r.courseCode, r.courseName, r.sessionCode, r.status, r.method, r.markedAt]
        .map(v => `"${String(v ?? '').replace(/"/g, '""')}"`)
        .join(',')
    )
    res.setHeader('Content-Type', 'text/csv')
    res.setHeader('Content-Disposition', 'attachment; filename="attendx_export.csv"')
    res.send([header, ...rows].join('\n'))
  } catch (err) { next(err) }
}

module.exports = {
  getUsers, createUser, updateUser, deleteUser, bulkCreateUsers,
  getCourses, createCourse, updateCourse, deleteCourse,
  getCourseEnrollments, enrollStudent, unenrollStudent,
  getClassrooms, createClassroom, updateClassroom, deleteClassroom,
  getAnalytics,
  getSecurityConfig, updateSecurityConfig, getSecurityLogs,
  getSettings, updateSettings, exportData,
}
