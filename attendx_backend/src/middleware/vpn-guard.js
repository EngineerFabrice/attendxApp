'use strict'
/**
 * VPN Guard Middleware
 *
 * Blocks requests arriving via VPN, proxy, or TOR networks.
 * Logs every detected threat to the fraud_incidents table.
 * Falls through (allows) if the IP intel service is unavailable.
 */
const ipIntel = require('../services/ip-intelligence.service')
const db      = require('../config/database')
const { randomUUID } = require('crypto')

/**
 * Extract the real client IP — respects common reverse-proxy headers.
 */
function clientIp(req) {
  return (
    req.headers['cf-connecting-ip'] ||          // Cloudflare
    req.headers['x-real-ip'] ||                  // Nginx proxy_pass
    (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
    req.socket?.remoteAddress ||
    req.ip
  )
}

/**
 * Attach to any route that requires a clean IP (login, check-in).
 * Sets req.ipIntel for downstream middleware/controllers.
 */
async function vpnGuard(req, res, next) {
  const ip = clientIp(req)
  req.clientIp = ip

  let intel
  try {
    intel = await ipIntel.lookup(ip)
  } catch {
    // If intel service is down, allow through — don't block legitimate traffic
    req.ipIntel = { isVPN: false, isProxy: false, isTOR: false, threatScore: 0 }
    return next()
  }

  req.ipIntel = intel

  const isThreat = intel.isVPN || intel.isProxy || intel.isTOR || intel.isRelay

  if (isThreat) {
    // Persist the incident (non-blocking — fire and forget)
    _logFraudIncident(req, intel).catch(() => {})

    const type = intel.isTOR ? 'tor' : intel.isVPN ? 'vpn' : 'proxy'
    console.warn(`[VpnGuard] Blocked ${type} from ${ip} (user=${req.user?.id ?? 'anon'})`)

    return res.status(403).json({
      success: false,
      error: 'Access denied: VPN, proxy, and TOR connections are not permitted for this endpoint.',
      code:  'VPN_BLOCKED',
    })
  }

  next()
}

async function _logFraudIncident(req, intel) {
  const type = intel.isTOR ? 'tor' : intel.isVPN ? 'vpn' : intel.isProxy ? 'proxy' : 'relay'
  await db.query(
    `INSERT INTO fraud_incidents
       (id, user_id, incident_type, ip_address, ip_country, ip_isp,
        is_vpn, is_proxy, is_tor, risk_score, action_taken, metadata)
       VALUES (UUID(),?,?,?,?,?,?,?,?,?,?,?)`,
    [
      req.user?.id ?? null,
      type,
      req.clientIp,
      intel.country,
      intel.isp,
      intel.isVPN   ? 1 : 0,
      intel.isProxy ? 1 : 0,
      intel.isTOR   ? 1 : 0,
      intel.threatScore ?? 50,
      'blocked',
      JSON.stringify({ path: req.path, method: req.method }),
    ]
  )
}

module.exports = vpnGuard
