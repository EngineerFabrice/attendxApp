/**
 * Seeds the database with development data.
 * Credentials: admin@attendx.edu / Admin@1234
 *              alice@ur.ac.rw   / Lecturer@1234
 *              student@attendx.com / Student@1234
 */
require('dotenv').config()
const bcrypt = require('bcryptjs')
const { randomUUID } = require('crypto')
const mysql = require('mysql2/promise')

async function run() {
  const db = await mysql.createConnection({
    host:     process.env.DB_HOST     || 'localhost',
    port:     process.env.DB_PORT     || 3306,
    user:     process.env.DB_USER     || 'root',
    password: process.env.DB_PASSWORD || '',
    database: process.env.DB_NAME     || 'attendx',
  })

  // ── Users ──────────────────────────────────────────────────────────────────
  const adminHash    = await bcrypt.hash('Admin@1234', 12)
  const lecturerHash = await bcrypt.hash('Lecturer@1234', 12)
  const studentHash  = await bcrypt.hash('Student@1234', 12)

  const adminId  = randomUUID()
  const lec1Id   = randomUUID()
  const lec2Id   = randomUUID()
  const stu1Id   = randomUUID()
  const stu2Id   = randomUUID()
  const stu3Id   = randomUUID()
  const stu4Id   = randomUUID()
  const stu5Id   = randomUUID()
  const stu6Id   = randomUUID()

  await db.query(`DELETE FROM attendance_records`)
  await db.query(`DELETE FROM attendance_sessions`)
  await db.query(`DELETE FROM enrollments`)
  await db.query(`DELETE FROM notifications`)
  await db.query(`DELETE FROM refresh_tokens`)
  await db.query(`DELETE FROM courses`)
  await db.query(`DELETE FROM classrooms`)
  await db.query(`DELETE FROM users`)

  await db.query(
    `INSERT INTO users (id, full_name, email, password_hash, role, reg_number, department) VALUES ?`,
    [[
      [adminId,  'System Administrator', 'admin@attendx.edu',   adminHash,    'admin',    null,        'Administration'],
      [lec1Id,   'Dr. Alice Uwimana',    'alice@ur.ac.rw',      lecturerHash, 'lecturer', null,        'Computer Science'],
      [lec2Id,   'Dr. Bob Nkurunziza',   'bob@ur.ac.rw',        lecturerHash, 'lecturer', null,        'Mathematics'],
      [stu1Id,   'Fabrice NDAYISABA',    'fabrice@stud.ur.ac.rw', studentHash, 'student', '223008047', 'Computer Science'],
      [stu2Id,   'Marie INGABIRE',       'marie@stud.ur.ac.rw', studentHash,  'student', '223008048', 'Computer Science'],
      [stu3Id,   'Jean HAKIZIMANA',      'jean@stud.ur.ac.rw',  studentHash,  'student', '223008049', 'Computer Science'],
      [stu4Id,   'Grace UWASE',          'grace@stud.ur.ac.rw', studentHash,  'student', '223008050', 'Mathematics'],
      [stu5Id,   'Patrick MUGISHA',      'patrick@stud.ur.ac.rw', studentHash,'student', '223008051', 'Computer Science'],
      [stu6Id,   'Alice UMURERWA',       'alice2@stud.ur.ac.rw', studentHash, 'student', '223008052', 'Computer Science'],
    ]]
  )
  console.log('✓ Users seeded')

  // ── Classrooms ────────────────────────────────────────────────────────────
  const room1 = randomUUID(), room2 = randomUUID(), room3 = randomUUID()
  const room4 = randomUUID(), room5 = randomUUID()
  await db.query(
    `INSERT INTO classrooms (id, name, building, capacity, latitude, longitude, radius_m) VALUES ?`,
    [[
      [room1, 'LT-1', 'Engineering Block A', 60, -1.9450, 30.0625, 30],
      [room2, 'LT-2', 'Engineering Block A', 60, -1.9448, 30.0622, 30],
      [room3, 'LT-3', 'Engineering Block B', 80, -1.9441, 30.0619, 30],
      [room4, 'LT-5', 'Science Block',       50, -1.9460, 30.0630, 25],
      [room5, 'R-102','Main Block',           40, -1.9435, 30.0615, 20],
    ]]
  )
  console.log('✓ Classrooms seeded')

  // ── Courses ───────────────────────────────────────────────────────────────
  const c1 = randomUUID(), c2 = randomUUID(), c3 = randomUUID()
  const c4 = randomUUID(), c5 = randomUUID()
  await db.query(
    `INSERT INTO courses (id, code, name, credits, department, lecturer_id) VALUES ?`,
    [[
      [c1, 'CS301',  'Advanced Databases',    3, 'Computer Science', lec1Id],
      [c2, 'CS201',  'Data Structures',       3, 'Computer Science', lec1Id],
      [c3, 'CS401',  'Software Engineering',  3, 'Computer Science', null],
      [c4, 'MATH301','Numerical Methods',     2, 'Mathematics',      lec2Id],
      [c5, 'CS350',  'Computer Networks',     3, 'Computer Science', lec2Id],
    ]]
  )
  console.log('✓ Courses seeded')

  // ── Enrollments ───────────────────────────────────────────────────────────
  const enrolls = [
    [stu1Id, c1], [stu1Id, c2], [stu1Id, c3], [stu1Id, c4], [stu1Id, c5],
    [stu2Id, c1], [stu2Id, c2], [stu2Id, c5],
    [stu3Id, c1], [stu3Id, c2],
    [stu4Id, c4], [stu4Id, c3],
    [stu5Id, c1], [stu5Id, c5],
    [stu6Id, c2], [stu6Id, c3],
  ]
  await db.query(
    `INSERT INTO enrollments (id, student_id, course_id) VALUES ?`,
    [enrolls.map(([s, c]) => [randomUUID(), s, c])]
  )
  console.log('✓ Enrollments seeded')

  await db.end()
















  
  console.log('\n✅ Database seeded successfully')
  console.log('\nTest accounts:')
  console.log('  Admin:    admin@attendx.edu   / Admin@1234')
  console.log('  Lecturer: alice@ur.ac.rw      / Lecturer@1234')
  console.log('  Lecturer: bob@ur.ac.rw        / Lecturer@1234')
  console.log('  Student:  fabrice@stud.ur.ac.rw / Student@1234')
}

module.exports = { run }
if (require.main === module) {
  run().catch(err => { console.error(err); process.exit(1) })
}
