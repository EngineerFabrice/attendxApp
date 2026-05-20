'use strict'
/**
 * IP Intelligence Service
 * Detects VPN, proxy, and TOR connections using ipdata.co (primary)
 * with a local heuristic fallback when the API is unavailable.
 *
 * Zero extra npm dependencies — uses Node's built-in https module.
 */
const https = require('https')

// ── In-memory cache (15-min TTL) ─────────────────────────────────────────────
const _cache = new Map()
const CACHE_TTL_MS = 15 * 60 * 1000

function _cached(ip) {
  const entry = _cache.get(ip)
  if (!entry) return null
  if (Date.now() - entry.ts > CACHE_TTL_MS) { _cache.delete(ip); return null }
  return entry.data
}

function _store(ip, data) {
  _cache.set(ip, { ts: Date.now(), data })
  // Prevent unbounded growth
  if (_cache.size > 2000) {
    const oldest = _cache.keys().next().value
    _cache.delete(oldest)
  }
}

// ── HTTP GET helper ───────────────────────────────────────────────────────────
function _get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: 4000 }, (res) => {
      let body = ''
      res.on('data', chunk => { body += chunk })
      res.on('end', () => {
        try { resolve(JSON.parse(body)) } catch { reject(new Error('Invalid JSON')) }
      })
    })
    req.on('error', reject)
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')) })
  })
}

// ── Private IPs are never suspicious ─────────────────────────────────────────
const PRIVATE_IP_RE = /^(127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|::1$|^$)/

function _isPrivate(ip) {
  return PRIVATE_IP_RE.test(ip)
}

// ── Normalize result shape ────────────────────────────────────────────────────
const _safe = () => ({
  country: null, isp: null,
  isVPN: false, isProxy: false, isTOR: false, isRelay: false,
  threatScore: 0, raw: null,
})

// ── Provider: ipdata.co ───────────────────────────────────────────────────────
async function _fromIpdata(ip) {
  const key = process.env.IPDATA_API_KEY
  if (!key) return null

  const url = `https://api.ipdata.co/${ip}?api-key=${key}&fields=country_code,organisation,threat`
  const data = await _get(url)

  if (data.message) return null  // API error (bad key, quota, etc.)

  const threat = data.threat || {}
  return {
    country:     data.country_code || null,
    isp:         data.organisation  || null,
    isVPN:       threat.is_vpn        ?? false,
    isProxy:     threat.is_proxy      ?? false,
    isTOR:       threat.is_tor        ?? false,
    isRelay:     threat.is_icloud_relay ?? false,
    threatScore: Array.isArray(threat.blocklists) ? threat.blocklists.length : 0,
    raw:         threat,
  }
}

// ── Provider: ip-api.com (free fallback, no key needed) ──────────────────────
async function _fromIpApi(ip) {
  const url = `http://ip-api.com/json/${ip}?fields=status,country,isp,proxy,hosting`
  // Note: ip-api.com does not support https on the free tier
  const data = await new Promise((resolve, reject) => {
    const http = require('http')
    const req  = http.get(url, { timeout: 4000 }, (res) => {
      let body = ''
      res.on('data', c => { body += c })
      res.on('end', () => { try { resolve(JSON.parse(body)) } catch { reject(new Error('Invalid JSON')) } })
    })
    req.on('error', reject)
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')) })
  })

  if (data.status !== 'success') return null

  const isSuspicious = data.proxy === true || data.hosting === true
  return {
    country:     data.country || null,
    isp:         data.isp     || null,
    isVPN:       data.proxy   ?? false,
    isProxy:     data.proxy   ?? false,
    isTOR:       false,
    isRelay:     data.hosting ?? false,
    threatScore: isSuspicious ? 1 : 0,
    raw:         data,
  }
}

// ── Public API ────────────────────────────────────────────────────────────────
/**
 * Look up threat intelligence for an IP address.
 * Returns a normalised result — never throws.
 *
 * @param {string} ip  IPv4 or IPv6 address
 * @returns {Promise<{country,isp,isVPN,isProxy,isTOR,isRelay,threatScore,raw}>}
 */
async function lookup(ip) {
  if (!ip || _isPrivate(ip)) return _safe()

  const hit = _cached(ip)
  if (hit) return hit

  let result = null

  // Try primary provider first
  try {
    result = await _fromIpdata(ip)
  } catch (err) {
    console.debug(`[IpIntel] ipdata failed for ${ip}: ${err.message}`)
  }

  // Fallback to ip-api.com
  if (!result) {
    try {
      result = await _fromIpApi(ip)
    } catch (err) {
      console.debug(`[IpIntel] ip-api fallback failed for ${ip}: ${err.message}`)
    }
  }

  const final = result || _safe()
  _store(ip, final)
  return final
}

/**
 * Quick boolean — true if the IP is a known VPN / proxy / TOR exit.
 */
async function isThreat(ip) {
  const r = await lookup(ip)
  return r.isVPN || r.isProxy || r.isTOR || r.isRelay
}

module.exports = { lookup, isThreat }
