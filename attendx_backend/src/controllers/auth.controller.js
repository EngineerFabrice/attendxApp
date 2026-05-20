const bcrypt       = require('bcryptjs')
const { randomUUID } = require('crypto')
const db           = require('../config/database')
const { generateTokens, signAccess } = require('../utils/jwt')
const { success, error } = require('../utils/response')
const { validationResult } = require('express-validator')
const emailService = require('../services/email.service')

async function login(req, res, next) {
  try {
    const errors = validationResult(req)
    if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() })

    const { email, password } = req.body
    const [rows] = await db.query(
      'SELECT * FROM users WHERE email = ? AND is_active = 1 LIMIT 1', [email]
    )
    if (!rows.length) return res.status(401).json(error('Invalid email or password'))

    const user = rows[0]
    const valid = await bcrypt.compare(password, user.password_hash)
    if (!valid) return res.status(401).json(error('Invalid email or password'))

    const { accessToken, refreshToken } = await generateTokens(user)

    res.json(success({
      user: {
        id: user.id, fullName: user.full_name, email: user.email,
        role: user.role, regNumber: user.reg_number,
        department: user.department, isActive: !!user.is_active, createdAt: user.created_at,
      },
      tokens: { accessToken, refreshToken, expiresIn: 3600 },
    }))
  } catch (err) { next(err) }
}

async function logout(req, res, next) {
  try {
    await db.query('DELETE FROM refresh_tokens WHERE user_id = ?', [req.user.id])
    res.json(success(null))
  } catch (err) { next(err) }
}

async function me(req, res, next) {
  try {
    const [rows] = await db.query(
      'SELECT id, full_name, email, role, reg_number, department, is_active, created_at FROM users WHERE id = ?',
      [req.user.id]
    )
    if (!rows.length) return res.status(404).json(error('User not found'))
    const u = rows[0]
    res.json(success({
      id: u.id, fullName: u.full_name, email: u.email, role: u.role,
      regNumber: u.reg_number, department: u.department,
      isActive: !!u.is_active, createdAt: u.created_at,
    }))
  } catch (err) { next(err) }
}

async function forgotPassword(req, res, next) {
  try {
    const errors = validationResult(req)
    if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() })

    const { email } = req.body
    const [rows] = await db.query(
      'SELECT id FROM users WHERE email = ? AND is_active = 1 LIMIT 1', [email]
    )

    // Always respond the same way — don't reveal whether email exists
    if (!rows.length) {
      return res.json(success({ message: 'If that email exists a reset code was sent.' }))
    }

    const userId = rows[0].id
    const token  = randomUUID().replace(/-/g, '').slice(0, 32)
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000) // 15 min

    await db.query('DELETE FROM password_reset_tokens WHERE user_id = ?', [userId])
    await db.query(
      'INSERT INTO password_reset_tokens (id, user_id, token, expires_at) VALUES (?,?,?,?)',
      [randomUUID(), userId, token, expiresAt]
    )

    // Send email (non-blocking — always return same response regardless of email result)
    emailService.sendPasswordReset(email, token).catch(err =>
      console.warn('[Auth] Failed to send reset email:', err.message)
    )

    // In dev mode also return the token so you can test without real SMTP
    const isDev = process.env.NODE_ENV !== 'production'
    res.json(success({
      message: 'If that email exists a reset code was sent.',
      ...(isDev && { resetToken: token, note: 'Dev mode only — not returned in production' }),
    }))
  } catch (err) { next(err) }
}

async function resetPassword(req, res, next) {
  try {
    const errors = validationResult(req)
    if (!errors.isEmpty()) return res.status(422).json({ success: false, errors: errors.array() })

    const { token, newPassword } = req.body
    if (!token || !newPassword) return res.status(400).json(error('token and newPassword are required'))
    if (newPassword.length < 8) return res.status(400).json(error('Password must be at least 8 characters'))

    const [rows] = await db.query(
      'SELECT * FROM password_reset_tokens WHERE token = ? AND expires_at > NOW() LIMIT 1', [token]
    )
    if (!rows.length) return res.status(400).json(error('Invalid or expired reset token'))

    const hash = await bcrypt.hash(newPassword, 12)
    await db.query('UPDATE users SET password_hash = ? WHERE id = ?', [hash, rows[0].user_id])
    await db.query('DELETE FROM password_reset_tokens WHERE token = ?', [token])

    res.json(success({ message: 'Password updated successfully.' }))
  } catch (err) { next(err) }
}

async function refreshToken(req, res, next) {
  try {
    const { refreshToken: token } = req.body
    if (!token) return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' })

    // Clean up expired tokens first
    await db.query('DELETE FROM refresh_tokens WHERE expires_at < NOW()')

    // Decode token (without verify) to extract user_id
    let userId
    try {
      const jwt = require('jsonwebtoken')
      const decoded = jwt.decode(token)
      if (!decoded || !decoded.id) throw new Error('malformed token')
      userId = decoded.id
    } catch {
      return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' })
    }

    // Find non-expired stored hashes for this user
    const [storedTokens] = await db.query(
      'SELECT * FROM refresh_tokens WHERE user_id = ? AND expires_at > NOW()',
      [userId]
    )

    // bcrypt.compare against each stored hash
    let matched = false
    for (const row of storedTokens) {
      const ok = await bcrypt.compare(token, row.token_hash)
      if (ok) { matched = true; break }
    }

    if (!matched) {
      return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' })
    }

    // Fetch user to sign a fresh access token
    const [users] = await db.query(
      'SELECT id, email, role FROM users WHERE id = ? AND is_active = 1 LIMIT 1', [userId]
    )
    if (!users.length) {
      return res.status(401).json({ success: false, error: 'Invalid or expired refresh token' })
    }

    const accessToken = signAccess(users[0])
    res.json(success({ accessToken, expiresIn: 3600 }))
  } catch (err) { next(err) }
}

async function updateProfile(req, res, next) {
  try {
    const { fullName, phone } = req.body
    if (!fullName?.trim()) return res.status(400).json(error('fullName is required'))
    await db.query(
      'UPDATE users SET full_name = ?, phone = ? WHERE id = ?',
      [fullName.trim(), phone?.trim() || null, req.user.id]
    )
    const [[u]] = await db.query(
      'SELECT id, full_name, email, role, reg_number, department, phone, is_active, created_at FROM users WHERE id = ?',
      [req.user.id]
    )
    res.json(success({
      id: u.id, fullName: u.full_name, email: u.email, role: u.role,
      regNumber: u.reg_number, department: u.department,
      phone: u.phone, isActive: !!u.is_active, createdAt: u.created_at,
    }))
  } catch (err) { next(err) }
}

module.exports = { login, logout, me, forgotPassword, resetPassword, refreshToken, updateProfile }
