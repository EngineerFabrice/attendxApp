const router = require('express').Router()
const { body } = require('express-validator')
const ctrl = require('../controllers/auth.controller')
const { authenticate } = require('../middleware/auth')
const { authLimiter } = require('../middleware/rateLimiter')

router.post('/login',
  authLimiter,
  body('email').isEmail(),
  body('password').notEmpty(),
  ctrl.login
)
router.post('/logout',          authenticate, ctrl.logout)
router.get ('/me',              authenticate, ctrl.me)
router.put ('/profile',         authenticate, ctrl.updateProfile)
router.post('/refresh',         ctrl.refreshToken)
router.post('/forgot-password', authLimiter, body('email').isEmail(), ctrl.forgotPassword)
router.post('/reset-password',
  body('token').notEmpty(),
  body('newPassword').isLength({ min: 8 }),
  ctrl.resetPassword
)

module.exports = router
