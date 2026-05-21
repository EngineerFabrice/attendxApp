require("dotenv").config();
const db = require("../src/config/database");
const bcrypt = require("bcryptjs");

async function migrate() {
  console.log("Running AttendX migrations…");

  // ── 1. appeals ────────────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS appeals (
      id            VARCHAR(36)  NOT NULL PRIMARY KEY,
      record_id     VARCHAR(36)  NOT NULL,
      student_id    VARCHAR(36)  NOT NULL,
      reason        TEXT         NOT NULL,
      status        ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
      review_note   TEXT         DEFAULT NULL,
      reviewed_by   VARCHAR(36)  DEFAULT NULL,
      reviewed_at   TIMESTAMP    NULL DEFAULT NULL,
      created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_appeal_record  FOREIGN KEY (record_id)   REFERENCES attendance_records (id) ON DELETE CASCADE,
      CONSTRAINT fk_appeal_student FOREIGN KEY (student_id)  REFERENCES users (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ appeals");

  // ── 2. messages ───────────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS messages (
      id            VARCHAR(36)  NOT NULL PRIMARY KEY,
      sender_id     VARCHAR(36)  NOT NULL,
      target_type   ENUM('student','course','all') NOT NULL DEFAULT 'course',
      target_id     VARCHAR(36)  DEFAULT NULL,
      subject       VARCHAR(255) DEFAULT NULL,
      content       TEXT         NOT NULL,
      created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_msg_sender FOREIGN KEY (sender_id) REFERENCES users (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ messages");

  // ── 3. message_reads ─────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS message_reads (
      message_id VARCHAR(36) NOT NULL,
      user_id    VARCHAR(36) NOT NULL,
      read_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (message_id, user_id),
      CONSTRAINT fk_mr_message FOREIGN KEY (message_id) REFERENCES messages (id) ON DELETE CASCADE,
      CONSTRAINT fk_mr_user    FOREIGN KEY (user_id)    REFERENCES users    (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ message_reads");

  // ── 4. attendance_warnings ────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS attendance_warnings (
      id              VARCHAR(36)   NOT NULL PRIMARY KEY,
      student_id      VARCHAR(36)   NOT NULL,
      course_id       VARCHAR(36)   DEFAULT NULL,
      course_name     VARCHAR(255)  NOT NULL,
      attendance_rate DECIMAL(5,2)  NOT NULL DEFAULT 0,
      sent_by         ENUM('system','lecturer','admin') NOT NULL DEFAULT 'system',
      channel         ENUM('push','email','both')       NOT NULL DEFAULT 'push',
      status          ENUM('sent','failed')             NOT NULL DEFAULT 'sent',
      sent_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT fk_aw_student FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ attendance_warnings");

  // ── 5. security_config ────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS security_config (
      config_key   VARCHAR(100) NOT NULL PRIMARY KEY,
      config_value TEXT         NOT NULL,
      updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  // Insert defaults if not yet present
  await db.query(`
    INSERT IGNORE INTO security_config (config_key, config_value) VALUES
      ('weights',    '{"emulator":40,"root":35,"mockGps":45,"vpn":25,"multipleFlags":10}'),
      ('thresholds', '{"medium":31,"high":61}'),
      ('blockLevel', '"high"'),
      ('warnLevel',  '"medium"')
  `);
  console.log("  ✓ security_config");

  // ── 6. security_logs ─────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS security_logs (
      id            VARCHAR(36)  NOT NULL PRIMARY KEY,
      user_id       VARCHAR(36)  DEFAULT NULL,
      risk_level    ENUM('low','medium','high') NOT NULL DEFAULT 'low',
      risk_score    INT          NOT NULL DEFAULT 0,
      flags         JSON         DEFAULT NULL,
      ip_address    VARCHAR(45)  DEFAULT NULL,
      device_model  VARCHAR(255) DEFAULT NULL,
      platform      VARCHAR(50)  DEFAULT NULL,
      action_taken  VARCHAR(100) DEFAULT NULL,
      created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_sl_user (user_id),
      INDEX idx_sl_level (risk_level)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ security_logs");

  // ── 7. fraud_incidents ────────────────────────────────────────────────────────
  await db.query(`
    CREATE TABLE IF NOT EXISTS fraud_incidents (
      id           VARCHAR(36)  NOT NULL PRIMARY KEY,
      user_id      VARCHAR(36)  DEFAULT NULL,
      ip_address   VARCHAR(45)  NOT NULL,
      threat_type  VARCHAR(100) DEFAULT NULL,
      country      VARCHAR(100) DEFAULT NULL,
      isp          VARCHAR(255) DEFAULT NULL,
      blocked      TINYINT(1)   NOT NULL DEFAULT 1,
      details      JSON         DEFAULT NULL,
      created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_fi_ip (ip_address)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci
  `);
  console.log("  ✓ fraud_incidents");

  // ── 8. Add late_threshold_minutes to courses (if missing) ────────────────────
  const [cols] = await db.query(`
    SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'courses' AND COLUMN_NAME = 'late_threshold_minutes'
  `);
  if (cols.length === 0) {
    await db.query(`
      ALTER TABLE courses ADD COLUMN late_threshold_minutes INT DEFAULT NULL
      COMMENT 'Per-course late threshold override (NULL = use system default)'
    `);
    console.log("  ✓ courses.late_threshold_minutes column added");
  } else {
    console.log("  ✓ courses.late_threshold_minutes already exists");
  }

  // ── 9. Fix any unhashed passwords in users table ──────────────────────────────
  const [unhashedUsers] = await db.query(
    `SELECT id, password_hash FROM users WHERE password_hash NOT LIKE '$2b$%' AND password_hash NOT LIKE '$2a$%'`
  );
  for (const u of unhashedUsers) {
    const hashed = await bcrypt.hash(u.password_hash, 12);
    await db.query(`UPDATE users SET password_hash = ? WHERE id = ?`, [hashed, u.id]);
    console.log(`  ✓ Fixed plaintext password for user ${u.id}`);
  }

  console.log("\nAll migrations completed successfully.");
  process.exit(0);
}

migrate().catch(err => {
  console.error("Migration failed:", err.message);
  process.exit(1);
});
