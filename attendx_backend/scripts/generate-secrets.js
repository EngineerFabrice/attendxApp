/**
 * Generates strong random secrets for production deployment.
 * Run once before going live:
 *   node scripts/generate-secrets.js
 *
 * Copy the output into your production .env (never commit it).
 */
const crypto = require('crypto')

const gen = (label) => `${label}=${crypto.randomBytes(48).toString('base64url')}`

console.log('\n# ── Paste these into your production .env ──────────────────')
console.log(gen('JWT_SECRET'))
console.log(gen('JWT_REFRESH_SECRET'))
console.log('\n# Keep these secret. Rotating them will invalidate all active sessions.')
