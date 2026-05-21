const { randomUUID } = require('crypto')
const db = require('../config/database')
const { success, error } = require('../utils/response')

// ── Send a message (lecturer or admin) ────────────────────────────────────────
async function sendMessage(req, res, next) {
  try {
    const { content, targetType, targetId } = req.body
    const sender = req.user

    if (!content?.trim()) {
      return res.status(400).json(error('Message content is required'))
    }
    if (!['course', 'student', 'all'].includes(targetType)) {
      return res.status(400).json(error('targetType must be course, student or all'))
    }
    if ((targetType === 'course' || targetType === 'student') && !targetId) {
      return res.status(400).json(error('targetId is required for course or student messages'))
    }

    // Lecturers can only message their own courses / enrolled students
    if (sender.role === 'lecturer') {
      if (targetType === 'all') {
        return res.status(403).json(error('Lecturers cannot message all users — choose a course'))
      }
      if (targetType === 'course') {
        const [owns] = await db.query(
          'SELECT id FROM courses WHERE id = ? AND lecturer_id = ?',
          [targetId, sender.id]
        )
        if (!owns.length) return res.status(403).json(error('You are not assigned to that course'))
      }
      if (targetType === 'student') {
        const [enrolled] = await db.query(
          `SELECT e.id FROM enrollments e
             JOIN courses c ON c.id = e.course_id
            WHERE e.student_id = ? AND c.lecturer_id = ?`,
          [targetId, sender.id]
        )
        if (!enrolled.length) {
          return res.status(403).json(error('That student is not enrolled in any of your courses'))
        }
      }
    }

    // Fetch sender's full name
    const [[senderRow]] = await db.query(
      'SELECT full_name FROM users WHERE id = ?', [sender.id]
    )

    const id = randomUUID()
    await db.query(
      `INSERT INTO messages (id, sender_id, sender_name, sender_role, target_type, target_id, content)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [id, sender.id, senderRow.full_name, sender.role, targetType, targetId || null, content.trim()]
    )

    const message = {
      id,
      senderId:   sender.id,
      senderName: senderRow.full_name,
      senderRole: sender.role,
      targetType,
      targetId:   targetId || null,
      content:    content.trim(),
      sentAt:     new Date().toISOString(),
    }

    // ── Emit via Socket.io ─────────────────────────────────────────────────
    const io = req.app.get('io')
    if (io) {
      const event = 'new_message'
      if (targetType === 'all') {
        io.emit(event, message)
      } else if (targetType === 'course') {
        io.to(`course:${targetId}`).emit(event, message)
      } else if (targetType === 'student') {
        io.to(`user:${targetId}`).emit(event, message)
      }
    }

    res.status(201).json(success(message))
  } catch (err) { next(err) }
}

// ── Get messages for the authenticated student ────────────────────────────────
async function getStudentMessages(req, res, next) {
  try {
    const studentId = req.user.id

    // Fetch course IDs the student is enrolled in
    const [enrolled] = await db.query(
      'SELECT course_id FROM enrollments WHERE student_id = ?', [studentId]
    )
    const courseIds = enrolled.map(e => e.course_id)

    // Messages addressed to this student directly, their courses, or broadcast
    let rows = []
    if (courseIds.length) {
      const placeholders = courseIds.map(() => '?').join(',')
      ;[rows] = await db.query(
        `SELECT m.id, m.sender_id, m.sender_name, m.sender_role,
                m.target_type, m.target_id, m.content, m.sent_at,
                (SELECT COUNT(*) FROM message_reads mr
                  WHERE mr.message_id = m.id AND mr.student_id = ?) AS is_read
           FROM messages m
          WHERE m.target_type = 'all'
             OR (m.target_type = 'student' AND m.target_id = ?)
             OR (m.target_type = 'course'  AND m.target_id IN (${placeholders}))
          ORDER BY m.sent_at DESC
          LIMIT 100`,
        [studentId, studentId, ...courseIds]
      )
    } else {
      ;[rows] = await db.query(
        `SELECT m.id, m.sender_id, m.sender_name, m.sender_role,
                m.target_type, m.target_id, m.content, m.sent_at,
                (SELECT COUNT(*) FROM message_reads mr
                  WHERE mr.message_id = m.id AND mr.student_id = ?) AS is_read
           FROM messages m
          WHERE m.target_type = 'all'
             OR (m.target_type = 'student' AND m.target_id = ?)
          ORDER BY m.sent_at DESC
          LIMIT 100`,
        [studentId, studentId]
      )
    }

    res.json(success(rows.map(m => ({
      id:         m.id,
      senderName: m.sender_name,
      senderRole: m.sender_role,
      targetType: m.target_type,
      content:    m.content,
      sentAt:     m.sent_at,
      isRead:     !!m.is_read,
    }))))
  } catch (err) { next(err) }
}

// ── Mark a message as read ────────────────────────────────────────────────────
async function markRead(req, res, next) {
  try {
    const { id } = req.params
    const studentId = req.user.id
    await db.query(
      `INSERT IGNORE INTO message_reads (message_id, student_id) VALUES (?, ?)`,
      [id, studentId]
    )
    res.json(success(null))
  } catch (err) { next(err) }
}

// ── Mark ALL unread messages as read ─────────────────────────────────────────
async function markAllRead(req, res, next) {
  try {
    const studentId = req.user.id
    // Get all message IDs visible to this student that are unread
    const [enrolled] = await db.query(
      'SELECT course_id FROM enrollments WHERE student_id = ?', [studentId]
    )
    const courseIds = enrolled.map(e => e.course_id)
    let messageIds = []

    if (courseIds.length) {
      const placeholders = courseIds.map(() => '?').join(',')
      const [rows] = await db.query(
        `SELECT id FROM messages
          WHERE target_type = 'all'
             OR (target_type = 'student' AND target_id = ?)
             OR (target_type = 'course'  AND target_id IN (${placeholders}))`,
        [studentId, ...courseIds]
      )
      messageIds = rows.map(r => r.id)
    }

    if (messageIds.length) {
      const values = messageIds.map(mid => [mid, studentId])
      await db.query(
        'INSERT IGNORE INTO message_reads (message_id, student_id) VALUES ?',
        [values]
      )
    }
    res.json(success({ marked: messageIds.length }))
  } catch (err) { next(err) }
}

// ── Get sent messages (lecturer/admin view) ──────────────────────────────────
async function getSentMessages(req, res, next) {
  try {
    const [rows] = await db.query(
      `SELECT m.id, m.target_type, m.target_id, m.content, m.sent_at,
              COALESCE(c.name, u.full_name, 'All Students') AS target_label,
              (SELECT COUNT(*) FROM message_reads mr WHERE mr.message_id = m.id) AS read_count
         FROM messages m
         LEFT JOIN courses c ON c.id = m.target_id AND m.target_type = 'course'
         LEFT JOIN users   u ON u.id = m.target_id AND m.target_type = 'student'
        WHERE m.sender_id = ?
        ORDER BY m.sent_at DESC
        LIMIT 50`,
      [req.user.id]
    )
    res.json(success(rows.map(m => ({
      id:          m.id,
      targetType:  m.target_type,
      targetLabel: m.target_label,
      content:     m.content,
      sentAt:      m.sent_at,
      readCount:   Number(m.read_count),
    }))))
  } catch (err) { next(err) }
}

// ── Unread count for student (for badge) ─────────────────────────────────────
async function getUnreadCount(req, res, next) {
  try {
    const studentId = req.user.id
    const [enrolled] = await db.query(
      'SELECT course_id FROM enrollments WHERE student_id = ?', [studentId]
    )
    const courseIds = enrolled.map(e => e.course_id)

    let count = 0
    if (courseIds.length) {
      const placeholders = courseIds.map(() => '?').join(',')
      const [[row]] = await db.query(
        `SELECT COUNT(*) AS cnt FROM messages m
          WHERE (m.target_type = 'all'
              OR (m.target_type = 'student' AND m.target_id = ?)
              OR (m.target_type = 'course'  AND m.target_id IN (${placeholders})))
            AND NOT EXISTS (
              SELECT 1 FROM message_reads mr
               WHERE mr.message_id = m.id AND mr.student_id = ?
            )`,
        [studentId, ...courseIds, studentId]
      )
      count = Number(row.cnt)
    }
    res.json(success({ unread: count }))
  } catch (err) { next(err) }
}

module.exports = {
  sendMessage,
  getStudentMessages,
  markRead,
  markAllRead,
  getSentMessages,
  getUnreadCount,
}
