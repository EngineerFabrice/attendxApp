/**
 * Creates the 5 missing production tables.
 * Run once: node scripts/run-missing-migrations.js
 */
require('dotenv').config()
const db = require('../src/config/database')

// All tables use the same charset/collation as the existing schema (utf8mb4_general_ci)
// FK constraint names are inlined without explicit CONSTRAINT names to avoid naming conflicts
const tables = [
  {
    name: 'messages',
    sql: `CREATE TABLE IF NOT EXISTS messages (
      id          VARCHAR(36)                          NOT NULL,
      sender_id   VARCHAR(36)                          NOT NULL,
      sender_name VARCHAR(120)                         NOT NULL,
      sender_role ENUM('admin','lecturer')             NOT NULL,
      target_type ENUM('all','course','student')       NOT NULL,
      target_id   VARCHAR(36)                          NULL,
      content     TEXT                                 NOT NULL,
      sent_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_msg_sender (sender_id),
      KEY idx_msg_target (target_type, target_id),
      FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
  },
  {
    name: 'message_reads',
    sql: `CREATE TABLE IF NOT EXISTS message_reads (
      message_id  VARCHAR(36) NOT NULL,
      student_id  VARCHAR(36) NOT NULL,
      read_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (message_id, student_id),
      FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE,
      FOREIGN KEY (student_id) REFERENCES users(id)    ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
  },
  {
    name: 'device_bindings',
    sql: `CREATE TABLE IF NOT EXISTS device_bindings (
      id            VARCHAR(36)   NOT NULL,
      user_id       VARCHAR(36)   NOT NULL,
      device_id     VARCHAR(255)  NOT NULL,
      device_hash   VARCHAR(64)   NOT NULL,
      device_model  VARCHAR(100)  NULL,
      os_version    VARCHAR(50)   NULL,
      platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
      is_emulator   TINYINT(1)    NOT NULL DEFAULT 0,
      is_rooted     TINYINT(1)    NOT NULL DEFAULT 0,
      bound_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_seen_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_db_user (user_id),
      KEY idx_db_hash (device_hash),
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
  },
  {
    name: 'audit_logs',
    sql: `CREATE TABLE IF NOT EXISTS audit_logs (
      id          BIGINT        NOT NULL AUTO_INCREMENT,
      actor_id    VARCHAR(36)   NULL,
      actor_role  VARCHAR(20)   NULL,
      actor_ip    VARCHAR(45)   NULL,
      action      VARCHAR(100)  NOT NULL,
      resource    VARCHAR(60)   NULL,
      resource_id VARCHAR(36)   NULL,
      before_val  JSON          NULL,
      after_val   JSON          NULL,
      status      ENUM('success','failure') NOT NULL DEFAULT 'success',
      created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_al_actor    (actor_id),
      KEY idx_al_action   (action),
      KEY idx_al_resource (resource, resource_id),
      KEY idx_al_created  (created_at),
      FOREIGN KEY (actor_id) REFERENCES users(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
  },
  {
    name: 'fraud_incidents',
    sql: `CREATE TABLE IF NOT EXISTS fraud_incidents (
      id            VARCHAR(36)    NOT NULL,
      user_id       VARCHAR(36)    NULL,
      session_id    VARCHAR(36)    NULL,
      incident_type VARCHAR(50)    NOT NULL,
      ip_address    VARCHAR(45)    NULL,
      ip_country    VARCHAR(10)    NULL,
      ip_isp        VARCHAR(150)   NULL,
      is_vpn        TINYINT(1)     NOT NULL DEFAULT 0,
      is_proxy      TINYINT(1)     NOT NULL DEFAULT 0,
      is_tor        TINYINT(1)     NOT NULL DEFAULT 0,
      device_hash   VARCHAR(64)    NULL,
      latitude      DECIMAL(10,7)  NULL,
      longitude     DECIMAL(10,7)  NULL,
      risk_score    DECIMAL(5,2)   NOT NULL DEFAULT 0,
      action_taken  VARCHAR(20)    NULL,
      metadata      JSON           NULL,
      created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_fi_user    (user_id),
      KEY idx_fi_type    (incident_type),
      KEY idx_fi_created (created_at),
      FOREIGN KEY (user_id)    REFERENCES users(id)               ON DELETE SET NULL,
      FOREIGN KEY (session_id) REFERENCES attendance_sessions(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci`
  },
]

async function run() {
  console.log('Running missing table migrations...\n')
  for (const t of tables) {
    try {
      await db.query(t.sql)
      console.log(`  ✓  ${t.name} — created`)
    } catch (e) {
      if (e.message.includes('already exists')) {
        console.log(`  -  ${t.name} — already exists`)
      } else {
        console.log(`  ✗  ${t.name} — ${e.message}`)
      }
    }
  }

  // Final verification
  console.log('\nVerification:')
  const [rows] = await db.query('SHOW TABLES FROM attendx_db')
  const names  = rows.map(r => Object.values(r)[0])
  const needed = tables.map(t => t.name)
  let allOk = true
  needed.forEach(n => {
    const ok = names.includes(n)
    if (!ok) allOk = false
    console.log(`  ${ok ? '✓' : '✗'}  ${n}`)
  })

  console.log(allOk ? '\n✅ All tables ready — database is complete.' : '\n⚠  Some tables still missing.')
  process.exit(0)
}

run().catch(e => { console.error(e.message); process.exit(1) })
