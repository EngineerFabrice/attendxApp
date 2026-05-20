'use strict'
const jwt    = require('jsonwebtoken')
const bcrypt = require('bcryptjs')
const { randomUUID } = require('crypto')
const db     = require('../config/database')

// Fail fast at startup if secrets are missing or left as default
const JWT_SECRET         = process.env.JWT_SECRET
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET
const JWT_EXPIRES_IN     = process.env.JWT_EXPIRES_IN     || '1h'
const JWT_REFRESH_EXPIRES = process.env.JWT_REFRESH_EXPIRES_IN || '7d'
const BCRYPT_ROUNDS      = Number(process.env.BCRYPT_ROUNDS) || 12

if (!JWT_SECRET || JWT_SECRET === 'dev_secret') {
  throw new Error('FATAL: JWT_SECRET env var is missing or insecure. Set a strong random secret.')
}
if (!JWT_REFRESH_SECRET || JWT_REFRESH_SECRET === 'dev_refresh_secret') {
  throw new Error('FATAL: JWT_REFRESH_SECRET env var is missing or insecure.')
}

function signAccess(user) {
  return jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  )
}

function signRefresh(user) {
  return jwt.sign(
    { id: user.id },
    JWT_REFRESH_SECRET,
    { expiresIn: JWT_REFRESH_EXPIRES }
  )
}

function verifyAccess(token) {
  return jwt.verify(token, JWT_SECRET)
}

function verifyRefresh(token) {
  return jwt.verify(token, JWT_REFRESH_SECRET)
}

async function generateTokens(user) {
  const accessToken  = signAccess(user)
  const refreshToken = signRefresh(user)

  const hash      = await bcrypt.hash(refreshToken, BCRYPT_ROUNDS)
  const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
  await db.query(
    'INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) VALUES (?,?,?,?)',
    [randomUUID(), user.id, hash, expiresAt]
  )

  return { accessToken, refreshToken }
}

module.exports = { signAccess, signRefresh, verifyAccess, verifyRefresh, generateTokens }
