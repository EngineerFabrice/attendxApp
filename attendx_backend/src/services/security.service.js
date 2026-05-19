const { randomUUID } = require('crypto')
const db = require('../config/database')

// ── Config cache (refreshed every 5 minutes) ─────────────────────────────────
let _cache = null
let _cacheAt = 0
const CACHE_TTL = 5 * 60 * 1000

async function loadConfig() {
  if (_cache && Date.now() - _cacheAt < CACHE_TTL) return _cache
  const [rows] = await db.query('SELECT config_key, config_value FROM security_config')
  const cfg = {}
  for (const r of rows) {
    try { cfg[r.config_key] = JSON.parse(r.config_value) } catch { cfg[r.config_key] = r.config_value }
  }
  _cache = cfg
  _cacheAt = Date.now()
  return cfg
}

// ── Risk scorer ───────────────────────────────────────────────────────────────
async function evaluate(securityContext = {}) {
  const cfg = await loadConfig()

  const weights    = cfg.weights    || { emulator: 40, root: 35, mockGps: 45, vpn: 25, multipleFlags: 10 }
  const thresholds = cfg.thresholds || { medium: 31, high: 61 }
  const blockLevel = cfg.blockLevel || 'high'
  const warnLevel  = cfg.warnLevel  || 'medium'

  const { isEmulator = false, isRooted = false, isMockGps = false, isVpn = false } = securityContext

  const activeFlags = []
  let score = 0

  if (isEmulator) { activeFlags.push('emulator'); score += weights.emulator }
  if (isRooted)   { activeFlags.push('root');      score += weights.root }
  if (isMockGps)  { activeFlags.push('mockGps');   score += weights.mockGps }
  if (isVpn)      { activeFlags.push('vpn');       score += weights.vpn }
  if (activeFlags.length > 1) score += weights.multipleFlags || 0

  const riskLevel = score >= thresholds.high
    ? 'high'
    : score >= thresholds.medium
      ? 'medium'
      : 'low'

  const action = riskLevel === blockLevel
    ? 'blocked'
    : riskLevel === warnLevel
      ? 'warned'
      : 'allowed'

  return { score, riskLevel, flags: activeFlags, action, blockLevel, warnLevel }
}

// ── Logger ────────────────────────────────────────────────────────────────────
async function log({ studentId, sessionId, result, securityContext, ipAddress }) {
  try {
    await db.query(
      `INSERT INTO security_logs
         (id, student_id, session_id, risk_level, risk_score, flags, ip_address, device_model, platform, action_taken)
       VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [
        randomUUID(),
        studentId,
        sessionId || null,
        result.riskLevel,
        result.score,
        JSON.stringify(result.flags),
        ipAddress || null,
        securityContext?.deviceModel || null,
        securityContext?.platform    || null,
        result.action,
      ]
    )
  } catch (_) {
    // Non-critical — don't fail check-in if logging fails
  }
}

module.exports = { evaluate, log, loadConfig }
