/**
 * Generates serviceAccountKey.json from .env variables.
 *
 * Usage:
 *   node scripts/generate_service_account.js
 *
 * Fill these in your .env first:
 *   FCM_PROJECT_ID
 *   FCM_PRIVATE_KEY_ID
 *   FCM_PRIVATE_KEY
 *   FCM_CLIENT_EMAIL
 *   FCM_CLIENT_ID
 */
require('dotenv').config()
const fs   = require('fs')
const path = require('path')

const {
  FCM_PROJECT_ID,
  FCM_PRIVATE_KEY_ID,
  FCM_PRIVATE_KEY,
  FCM_CLIENT_EMAIL,
  FCM_CLIENT_ID,
} = process.env

// ── Validate ──────────────────────────────────────────────────────────────────
const errors = []
if (!FCM_PROJECT_ID)   errors.push('FCM_PROJECT_ID')
if (!FCM_PRIVATE_KEY_ID || FCM_PRIVATE_KEY_ID === 'your_private_key_id')
  errors.push('FCM_PRIVATE_KEY_ID')
if (!FCM_PRIVATE_KEY || FCM_PRIVATE_KEY.includes('Your private key here'))
  errors.push('FCM_PRIVATE_KEY')
if (!FCM_CLIENT_EMAIL || FCM_CLIENT_EMAIL.includes('xxxxx'))
  errors.push('FCM_CLIENT_EMAIL')
if (!FCM_CLIENT_ID || FCM_CLIENT_ID === 'your_client_id')
  errors.push('FCM_CLIENT_ID')

if (errors.length) {
  console.error('\n❌  These .env values are still placeholders:\n')
  errors.forEach(e => console.error(`   • ${e}`))
  console.error('\n📋  How to get real values:')
  console.error('   1. Go to https://console.firebase.google.com/project/attendx-495c9/settings/serviceaccounts/adminsdk')
  console.error('   2. Click "Generate new private key" → Download JSON file')
  console.error('   3. Open the file and copy each field into .env')
  console.error('   4. Run this script again\n')
  console.error('   OR simply place the downloaded JSON file as:')
  console.error('   attendx_backend/serviceAccountKey.json\n')
  process.exit(1)
}

// ── Build the JSON ────────────────────────────────────────────────────────────
const serviceAccount = {
  type:                        'service_account',
  project_id:                  FCM_PROJECT_ID,
  private_key_id:              FCM_PRIVATE_KEY_ID,
  private_key:                 FCM_PRIVATE_KEY.replace(/\\n/g, '\n'),
  client_email:                FCM_CLIENT_EMAIL,
  client_id:                   FCM_CLIENT_ID,
  auth_uri:                    'https://accounts.google.com/o/oauth2/auth',
  token_uri:                   'https://oauth2.googleapis.com/token',
  auth_provider_x509_cert_url: 'https://www.googleapis.com/oauth2/v1/certs',
  client_x509_cert_url:        `https://www.googleapis.com/robot/v1/metadata/x509/${encodeURIComponent(FCM_CLIENT_EMAIL)}`,
  universe_domain:             'googleapis.com',
}

const outPath = path.join(__dirname, '..', 'serviceAccountKey.json')
fs.writeFileSync(outPath, JSON.stringify(serviceAccount, null, 2))

console.log('\n✅  serviceAccountKey.json created at:', outPath)
console.log('\n   Next steps:')
console.log('   1. Restart the backend: pnpm dev')
console.log('   2. Watch for: [FCM] ✅ Initialized — project:', FCM_PROJECT_ID)
console.log('   3. Run: node scripts/test_fcm.js\n')
