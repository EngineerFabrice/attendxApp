const router = require('express').Router()
const ctrl   = require('../controllers/appeal.controller')
const { authenticate, requireRole } = require('../middleware/auth')

// Student
router.post('/',     authenticate, requireRole('student'), ctrl.submitAppeal)
router.get('/mine',  authenticate, requireRole('student'), ctrl.getMyAppeals)

// Lecturer
router.get('/',              authenticate, requireRole('lecturer', 'admin'), ctrl.getLecturerAppeals)
router.post('/:id/review',   authenticate, requireRole('lecturer', 'admin'), ctrl.reviewAppeal)

module.exports = router
