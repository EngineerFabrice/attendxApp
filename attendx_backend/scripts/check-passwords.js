require('dotenv').config()
const bcrypt = require('bcryptjs')
const db = require('../src/config/database')

const candidates = ['password', 'Password@1234', 'Student@1234', 'Admin@1234', 'Lecturer@1234', 'attendx123', '123456']

async function go() {
  const [users] = await db.query('SELECT email, role, password_hash FROM users ORDER BY role')
  for (const u of users) {
    for (const p of candidates) {
      const ok = await bcrypt.compare(p, u.password_hash)
      if (ok) { console.log(u.role.padEnd(10) + u.email.padEnd(35) + '  →  ' + p); break }
    }
  }
  process.exit(0)
}
go().catch(e => { console.error(e.message); process.exit(1) })
