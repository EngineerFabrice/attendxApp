/**
 * FCM Test Script
 * Usage:
 *   node scripts/test_fcm.js                          — sends to all tokens in DB
 *   node scripts/test_fcm.js <fcm-token>              — sends to one specific token
 *   node scripts/test_fcm.js --list                   — lists all tokens stored in DB
 */
require('dotenv').config()
const admin = require('firebase-admin')
const path  = require('path')
const fs    = require('fs')

// ── Check serviceAccountKey.json ─────────────────────────────────────────────
const keyPath = path.resolve(process.env.FCM_SERVICE_ACCOUNT_KEY || './serviceAccountKey.json')

if (!fs.existsSync(keyPath)) {
  console.error('\n❌  serviceAccountKey.json not found at:', keyPath)
  console.error('\nTo fix:')
  console.error('  1. Go to https://console.firebase.google.com/project/attendx-495c9/settings/serviceaccounts/adminsdk')
  console.error('  2. Click "Generate new private key"')
  console.error('  3. Save the file as: attendx_backend/serviceAccountKey.json')
  process.exit(1)
}

const serviceAccount = JSON.parse(fs.readFileSync(keyPath, 'utf8'))

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) })
}

const db = require('../src/config/database')

async function listTokens() {
  const [rows] = await db.query(
    'SELECT dt.token, dt.platform, u.full_name, u.email FROM device_tokens dt JOIN users u ON u.id = dt.user_id ORDER BY dt.updated_at DESC LIMIT 20'
  )
  if (!rows.length) {
    console.log('\n⚠️  No FCM tokens in the database yet.')
    console.log('   → Log in on the Flutter app and open the dashboard to register your device.')
    return []
  }
  console.log(`\n📱  ${rows.length} device token(s) found:\n`)
  rows.forEach((r, i) => {
    console.log(`  ${i + 1}. ${r.full_name} (${r.email}) [${r.platform}]`)
    console.log(`     Token: ${r.token.substring(0, 40)}...`)
  })
  return rows.map(r => r.token)
}

async function sendTest(tokens) {
  if (!tokens.length) return

  console.log(`\n📤  Sending test notification to ${tokens.length} device(s)...\n`)

  const message = {
    notification: {
      title: '🎓 AttendX Test',
      body:  'FCM is working! Push notifications are enabled.',
    },
    data: {
      type:    'test',
      sentAt:  new Date().toISOString(),
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'attendx_main',
        sound:     'default',
      },
    },
    apns: {
      payload: { aps: { sound: 'default', badge: 1 } },
    },
  }

  const results = { success: 0, failed: 0 }

  for (const token of tokens) {
    try {
      const response = await admin.messaging().send({ ...message, token })
      console.log(`  ✅  Sent — Message ID: ${response}`)
      results.success++
    } catch (e) {
      console.log(`  ❌  Failed — ${e.message}`)
      results.failed++
    }
  }

  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`)
  console.log(`  Results: ${results.success} sent, ${results.failed} failed`)
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n`)
}

async function run() {
  const arg = process.argv[2]
  console.log('\n🔥  AttendX FCM Test Tool')
  console.log(`    Project: ${serviceAccount.project_id}`)
  console.log(`    Key:     ${keyPath}\n`)

  if (arg === '--list') {
    await listTokens()
  } else if (arg && arg !== '--list') {
    // Specific token passed as argument
    console.log('📤  Sending to specific token:', arg.substring(0, 40) + '...')
    await sendTest([arg])
  } else {
    // Send to all tokens in DB
    const tokens = await listTokens()
    await sendTest(tokens)
  }

  process.exit(0)
}

run().catch(e => {
  console.error('Error:', e.message)
  process.exit(1)
})
