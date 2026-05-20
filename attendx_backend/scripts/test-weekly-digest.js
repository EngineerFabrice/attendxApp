/**
 * Manual trigger for the weekly attendance digest.
 * Use this to test email delivery without waiting for Monday.
 *
 * Usage:
 *   node scripts/test-weekly-digest.js
 *   node scripts/test-weekly-digest.js student@example.com   (single recipient)
 */
require('dotenv').config()
const notify = require('../src/services/notification.service')

async function run() {
  console.log('[Test] Triggering weekly digest...')
  console.log('[Test] SMTP:', process.env.SMTP_HOST, '/', process.env.SMTP_USER)

  try {
    await notify.sendWeeklyDigests()
    console.log('[Test] ✅ Done — check your inbox')
  } catch (err) {
    console.error('[Test] ✗ Failed:', err.message)
  } finally {
    process.exit(0)
  }
}

run()
