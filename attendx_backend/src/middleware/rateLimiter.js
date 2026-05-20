'use strict'
const rateLimit = require('express-rate-limit')

const WINDOW_MS           = Number(process.env.RATE_LIMIT_WINDOW_MS)  || 15 * 60 * 1000
const AUTH_MAX            = Number(process.env.AUTH_RATE_LIMIT_MAX)   || 20
const GENERAL_MAX         = Number(process.env.GENERAL_RATE_LIMIT_MAX)|| 200
const CHECKIN_MAX         = Number(process.env.CHECKIN_RATE_LIMIT_MAX)|| 10
const CHECKIN_WINDOW_MS   = Number(process.env.CHECKIN_WINDOW_MS)     || 60 * 1000

const authLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max:      AUTH_MAX,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: 'Too many login attempts. Please try again later.' },
  skipSuccessfulRequests: true,
})

const generalLimiter = rateLimit({
  windowMs: WINDOW_MS,
  max:      GENERAL_MAX,
  standardHeaders: true,
  legacyHeaders:   false,
  message: { success: false, error: 'Too many requests. Please slow down.' },
})

const checkinLimiter = rateLimit({
  windowMs: CHECKIN_WINDOW_MS,
  max:      CHECKIN_MAX,
  standardHeaders: true,
  legacyHeaders:   false,
  keyGenerator: (req) => req.user?.id ?? req.ip,
  message: { success: false, error: 'Too many check-in attempts.' },
})

module.exports = { authLimiter, generalLimiter, checkinLimiter }
