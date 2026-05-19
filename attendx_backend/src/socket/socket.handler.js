const { verifyAccess } = require('../utils/jwt')

/**
 * Socket.io handler.
 *
 * Rooms:
 *   session:{id}   – lecturer monitor page joins this to receive check-in updates
 *   course:{id}    – enrolled students join this to receive session_started events
 *   student:{id}   – personal room for notifications (absence warnings etc.)
 *
 * Events emitted by server:
 *   session_started   → course room   – lecturer started a session
 *   attendance_update → session room  – a student just checked in
 *   session_closed    → session room  – lecturer ended the session
 *
 * Events emitted by client:
 *   join_session   { sessionId }  – lecturer starts monitoring
 *   join_courses   { courseIds }  – student subscribes to their courses
 *   student_checkin              – (optional) client-side confirmation pulse
 */
function initSocket(io) {
  // ── Authentication middleware ──────────────────────────────────────────────
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token
    if (!token) return next(new Error('Authentication required'))
    try {
      socket.user = verifyAccess(token)
      next()
    } catch {
      next(new Error('Invalid or expired token'))
    }
  })

  io.on('connection', socket => {
    const { id: userId, role } = socket.user

    // Every user joins their personal room for direct notifications
    socket.join(`user:${userId}`)

    // Lecturer: join monitoring room for a specific session
    socket.on('join_session', ({ sessionId }) => {
      if (role === 'lecturer' || role === 'admin') {
        socket.join(`session:${sessionId}`)
      }
    })

    // Student: join course rooms to receive session_started notifications
    socket.on('join_courses', ({ courseIds }) => {
      if (Array.isArray(courseIds)) {
        courseIds.forEach(cid => socket.join(`course:${cid}`))
      }
    })

    // Optional: student confirmation pulse after check-in
    socket.on('student_checkin', data => {
      // Forward to session room so lecturer sees it (backup for HTTP flow)
      if (data?.sessionId) {
        socket.to(`session:${data.sessionId}`).emit('attendance_update', {
          ...data,
          source: 'socket',
        })
      }
    })

    socket.on('disconnect', () => {
      // Rooms are cleaned up automatically
    })
  })
}

module.exports = { initSocket }
