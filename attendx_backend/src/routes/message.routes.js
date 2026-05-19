const router = require('express').Router()
const ctrl   = require('../controllers/message.controller')
const { authenticate, requireRole } = require('../middleware/auth')

// ── Lecturer / Admin send messages ────────────────────────────────────────────
router.post(
  '/send',
  authenticate,
  requireRole('lecturer', 'admin'),
  ctrl.sendMessage
)

router.get(
  '/sent',
  authenticate,
  requireRole('lecturer', 'admin'),
  ctrl.getSentMessages
)

// ── Student inbox ─────────────────────────────────────────────────────────────
router.get(
  '/inbox',
  authenticate,
  requireRole('student'),
  ctrl.getStudentMessages
)

router.get(
  '/unread-count',
  authenticate,
  requireRole('student'),
  ctrl.getUnreadCount
)

router.patch(
  '/:id/read',
  authenticate,
  requireRole('student'),
  ctrl.markRead
)

router.patch(
  '/mark-all-read',
  authenticate,
  requireRole('student'),
  ctrl.markAllRead
)

module.exports = router
