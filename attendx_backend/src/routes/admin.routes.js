const router = require('express').Router()
const ctrl   = require('../controllers/admin.controller')
const { authenticate, requireRole } = require('../middleware/auth')

router.use(authenticate, requireRole('admin'))

// Users
router.get   ('/users',              ctrl.getUsers)
router.post  ('/users',              ctrl.createUser)
router.post  ('/users/bulk',         ctrl.bulkCreateUsers)
router.put   ('/users/:id',          ctrl.updateUser)
router.delete('/users/:id',          ctrl.deleteUser)

// Courses
router.get   ('/courses',                              ctrl.getCourses)
router.post  ('/courses',                              ctrl.createCourse)
router.put   ('/courses/:id',                          ctrl.updateCourse)
router.delete('/courses/:id',                          ctrl.deleteCourse)

// Course enrollments
router.get   ('/courses/:id/enrollments',              ctrl.getCourseEnrollments)
router.post  ('/courses/:id/enrollments',              ctrl.enrollStudent)
router.delete('/courses/:id/enrollments/:studentId',   ctrl.unenrollStudent)

// Classrooms
router.get   ('/classrooms',         ctrl.getClassrooms)
router.post  ('/classrooms',         ctrl.createClassroom)
router.delete('/classrooms/:id',     ctrl.deleteClassroom)

// Analytics
router.get   ('/analytics',          ctrl.getAnalytics)

// Security engine
router.get   ('/security/config',    ctrl.getSecurityConfig)
router.put   ('/security/config',    ctrl.updateSecurityConfig)
router.get   ('/security/logs',      ctrl.getSecurityLogs)

// System settings
router.get   ('/settings',           ctrl.getSettings)
router.put   ('/settings',           ctrl.updateSettings)

// Data export
router.get   ('/export',             ctrl.exportData)

module.exports = router
