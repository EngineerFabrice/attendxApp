const { randomUUID } = require('crypto')
const db  = require('../config/database')
const fcm = require('../services/fcm.service')
const { success, error } = require('../utils/response')

// ── Student: submit an appeal ─────────────────────────────────────────────────
async function submitAppeal(req, res, next) {
  try {
    const studentId = req.user.id
    const { recordId, reason } = req.body

    if (!recordId || !reason?.trim()) {
      return res.status(400).json(error('recordId and reason are required'))
    }
    if (reason.trim().length < 10) {
      return res.status(400).json(error('Reason must be at least 10 characters'))
    }

    // Verify the record belongs to this student and is absent/late
    const [[record]] = await db.query(
      `SELECT r.id, r.status, r.session_id, s.course_id,
              c.name AS courseName, c.lecturer_id,
              u.full_name AS studentName
         FROM attendance_records r
         JOIN attendance_sessions s ON s.id = r.session_id
         JOIN courses c ON c.id = s.course_id
         JOIN users u ON u.id = r.student_id
        WHERE r.id = ? AND r.student_id = ?`,
      [recordId, studentId]
    )
    if (!record) {
      return res.status(404).json(error('Attendance record not found'))
    }
    if (record.status === 'present') {
      return res.status(400).json(error('You can only appeal absent or late records'))
    }

    // One appeal per record
    const [[existing]] = await db.query(
      'SELECT id, status FROM appeals WHERE record_id = ?', [recordId]
    )
    if (existing) {
      return res.status(409).json(error(
        `An appeal for this record already exists (${existing.status})`
      ))
    }

    const id = randomUUID()
    await db.query(
      `INSERT INTO appeals (id, record_id, student_id, session_id, course_id, reason)
       VALUES (?,?,?,?,?,?)`,
      [id, recordId, studentId, record.session_id, record.course_id, reason.trim()]
    )

    // Notify lecturer via FCM
    if (record.lecturer_id) {
      fcm.notifyNewAppeal({
        lecturerId: record.lecturer_id,
        studentName: record.studentName,
        courseName: record.courseName,
        appealId: id,
      })
    }

    // Emit socket to lecturer's personal room
    const io = req.app.get('io')
    if (io) {
      io.to(`user:${record.lecturer_id}`).emit('new_appeal', {
        appealId: id,
        studentName: record.studentName,
        courseName: record.courseName,
        reason: reason.trim(),
        recordStatus: record.status,
        createdAt: new Date().toISOString(),
      })
    }

    res.status(201).json(success({ id, status: 'pending', recordId }))
  } catch (err) { next(err) }
}

// ── Student: list own appeals ─────────────────────────────────────────────────
async function getMyAppeals(req, res, next) {
  try {
    const studentId = req.user.id
    const [rows] = await db.query(
      `SELECT a.id, a.record_id, a.status, a.reason, a.review_note,
              a.created_at, a.reviewed_at,
              c.name AS courseName, c.code AS courseCode,
              s.started_at AS sessionDate,
              r.status AS originalStatus
         FROM appeals a
         JOIN attendance_records r ON r.id = a.record_id
         JOIN attendance_sessions s ON s.id = a.session_id
         JOIN courses c ON c.id = a.course_id
        WHERE a.student_id = ?
        ORDER BY a.created_at DESC`,
      [studentId]
    )
    res.json(success(rows.map(a => ({
      id: a.id,
      recordId: a.record_id,
      status: a.status,
      reason: a.reason,
      reviewNote: a.review_note,
      createdAt: a.created_at,
      reviewedAt: a.reviewed_at,
      courseName: a.courseName,
      courseCode: a.courseCode,
      sessionDate: a.sessionDate,
      originalStatus: a.originalStatus,
    }))))
  } catch (err) { next(err) }
}

// ── Lecturer: list appeals for their courses ──────────────────────────────────
async function getLecturerAppeals(req, res, next) {
  try {
    const lecturerId = req.user.id
    const { status = 'pending' } = req.query

    const [rows] = await db.query(
      `SELECT a.id, a.record_id, a.status, a.reason, a.review_note,
              a.created_at, a.reviewed_at,
              u.id AS studentId, u.full_name AS studentName, u.reg_number AS regNumber,
              c.name AS courseName, c.code AS courseCode,
              s.started_at AS sessionDate,
              r.status AS originalStatus
         FROM appeals a
         JOIN attendance_records r ON r.id = a.record_id
         JOIN attendance_sessions s ON s.id = a.session_id
         JOIN courses c ON c.id = a.course_id AND c.lecturer_id = ?
         JOIN users u ON u.id = a.student_id
        WHERE a.status = ?
        ORDER BY a.created_at DESC
        LIMIT 100`,
      [lecturerId, status]
    )
    res.json(success(rows.map(a => ({
      id: a.id,
      recordId: a.record_id,
      status: a.status,
      reason: a.reason,
      reviewNote: a.review_note,
      createdAt: a.created_at,
      reviewedAt: a.reviewed_at,
      student: { id: a.studentId, fullName: a.studentName, regNumber: a.regNumber },
      courseName: a.courseName,
      courseCode: a.courseCode,
      sessionDate: a.sessionDate,
      originalStatus: a.originalStatus,
    }))))
  } catch (err) { next(err) }
}

// ── Lecturer: review an appeal ────────────────────────────────────────────────
async function reviewAppeal(req, res, next) {
  try {
    const lecturerId = req.user.id
    const { id } = req.params
    const { action, note } = req.body  // action: 'approved' | 'rejected'

    if (!['approved', 'rejected'].includes(action)) {
      return res.status(400).json(error('action must be approved or rejected'))
    }

    // Verify lecturer owns this appeal's course
    const [[appeal]] = await db.query(
      `SELECT a.id, a.record_id, a.student_id, a.course_id, a.status,
              c.name AS courseName
         FROM appeals a
         JOIN courses c ON c.id = a.course_id
        WHERE a.id = ? AND c.lecturer_id = ?`,
      [id, lecturerId]
    )
    if (!appeal) return res.status(404).json(error('Appeal not found'))
    if (appeal.status !== 'pending') {
      return res.status(400).json(error('This appeal has already been reviewed'))
    }

    await db.query(
      `UPDATE appeals
         SET status=?, reviewer_id=?, review_note=?, reviewed_at=NOW()
       WHERE id=?`,
      [action, lecturerId, note || null, id]
    )

    // If approved → update attendance record to present
    if (action === 'approved') {
      await db.query(
        `UPDATE attendance_records SET status='present' WHERE id=?`,
        [appeal.record_id]
      )
    }

    // Notify student
    fcm.notifyAppealResult({
      studentId: appeal.student_id,
      courseName: appeal.courseName,
      status: action,
      note: note || '',
    })

    // Emit socket to student
    const io = req.app.get('io')
    if (io) {
      io.to(`user:${appeal.student_id}`).emit('appeal_result', {
        appealId: id,
        status: action,
        courseName: appeal.courseName,
        reviewNote: note || null,
        reviewedAt: new Date().toISOString(),
      })
    }

    res.json(success({ id, status: action }))
  } catch (err) { next(err) }
}

module.exports = { submitAppeal, getMyAppeals, getLecturerAppeals, reviewAppeal }
