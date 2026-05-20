-- AttendX migrations — run after schema.sql
USE attendx;

-- Attendance appeals / disputes
CREATE TABLE IF NOT EXISTS appeals (
  id            VARCHAR(36)                              NOT NULL,
  record_id     VARCHAR(36)                              NOT NULL,
  student_id    VARCHAR(36)                              NOT NULL,
  session_id    VARCHAR(36)                              NOT NULL,
  course_id     VARCHAR(36)                              NOT NULL,
  reason        TEXT                                     NOT NULL,
  status        ENUM('pending','approved','rejected')    NOT NULL DEFAULT 'pending',
  reviewer_id   VARCHAR(36)                              NULL,
  review_note   TEXT                                     NULL,
  created_at    TIMESTAMP                                NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at   TIMESTAMP                                NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_record_appeal (record_id),
  FOREIGN KEY fk_appeal_record  (record_id)   REFERENCES attendance_records(id) ON DELETE CASCADE,
  FOREIGN KEY fk_appeal_student (student_id)  REFERENCES users(id) ON DELETE CASCADE,
  KEY idx_appeals_course  (course_id),
  KEY idx_appeals_status  (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Late check-in threshold per course (minutes after session start → marked late)
ALTER TABLE courses
  ADD COLUMN IF NOT EXISTS late_threshold_minutes SMALLINT NOT NULL DEFAULT 15
    COMMENT 'Minutes after session start before check-in is considered late';

-- Security engine: configurable weights and thresholds (no hardcoding)
CREATE TABLE IF NOT EXISTS security_config (
  config_key   VARCHAR(50)   NOT NULL,
  config_value TEXT          NOT NULL,
  updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (config_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Default weights and thresholds — admin can update via API
INSERT INTO security_config (config_key, config_value) VALUES
  ('weights',    '{"emulator":40,"root":35,"mockGps":45,"vpn":25,"multipleFlags":10}'),
  ('thresholds', '{"medium":31,"high":61}'),
  ('blockLevel', '"high"'),
  ('warnLevel',  '"medium"')
ON DUPLICATE KEY UPDATE config_key = config_key;

-- Audit log for all flagged check-in attempts
CREATE TABLE IF NOT EXISTS security_logs (
  id              VARCHAR(36)  NOT NULL,
  student_id      VARCHAR(36)  NOT NULL,
  session_id      VARCHAR(36),
  risk_level      ENUM('low','medium','high') NOT NULL,
  risk_score      SMALLINT     NOT NULL DEFAULT 0,
  flags           JSON,
  ip_address      VARCHAR(45),
  device_model    VARCHAR(100),
  platform        VARCHAR(20),
  action_taken    ENUM('allowed','warned','blocked') NOT NULL,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_sl_student  (student_id),
  KEY idx_sl_level    (risk_level),
  KEY idx_sl_created  (created_at),
  FOREIGN KEY fk_sl_user (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS notification_preferences (
  user_id        VARCHAR(36) NOT NULL,
  session_start  TINYINT(1)  NOT NULL DEFAULT 1,
  absence_alert  TINYINT(1)  NOT NULL DEFAULT 1,
  low_attendance TINYINT(1)  NOT NULL DEFAULT 1,
  weekly_report  TINYINT(1)  NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id),
  FOREIGN KEY fk_np_user (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  id         VARCHAR(36) NOT NULL,
  user_id    VARCHAR(36) NOT NULL,
  token      VARCHAR(64) NOT NULL,
  expires_at TIMESTAMP   NOT NULL,
  created_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_prt_token (token),
  FOREIGN KEY fk_prt_user (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ════════════════════════════════════════════════════════════════════════════
-- ENTERPRISE TABLES — added in migration 002
-- ════════════════════════════════════════════════════════════════════════════

-- ── Attendance warnings log (persists every FCM/email warning sent) ───────────
CREATE TABLE IF NOT EXISTS attendance_warnings (
  id              VARCHAR(36)   NOT NULL,
  student_id      VARCHAR(36)   NOT NULL,
  course_id       VARCHAR(36)   NULL,
  course_name     VARCHAR(200)  NOT NULL,
  sent_by         VARCHAR(36)   NULL,
  channel         ENUM('push','email','both') NOT NULL DEFAULT 'both',
  attendance_rate DECIMAL(5,2)  NOT NULL,
  message         TEXT          NULL,
  status          ENUM('sent','failed') NOT NULL DEFAULT 'sent',
  sent_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_aw_student (student_id),
  KEY idx_aw_course  (course_id),
  KEY idx_aw_sent    (sent_at),
  FOREIGN KEY fk_aw_student (student_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY fk_aw_course  (course_id)  REFERENCES courses(id) ON DELETE SET NULL,
  FOREIGN KEY fk_aw_sent_by (sent_by)    REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Device bindings — one trusted device per student ─────────────────────────
CREATE TABLE IF NOT EXISTS device_bindings (
  id            VARCHAR(36)   NOT NULL,
  user_id       VARCHAR(36)   NOT NULL,
  device_id     VARCHAR(255)  NOT NULL,
  device_hash   VARCHAR(64)   NOT NULL  COMMENT 'SHA-256 of device fingerprint',
  device_model  VARCHAR(100)  NULL,
  os_version    VARCHAR(50)   NULL,
  platform      ENUM('android','ios','web') NOT NULL DEFAULT 'android',
  is_emulator   TINYINT(1)    NOT NULL DEFAULT 0,
  is_rooted     TINYINT(1)    NOT NULL DEFAULT 0,
  bound_at      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_db_user   (user_id),
  KEY idx_db_hash (device_hash),
  FOREIGN KEY fk_db_user (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Immutable audit trail for every appeal state change ──────────────────────
CREATE TABLE IF NOT EXISTS appeals_history (
  id          VARCHAR(36)   NOT NULL,
  appeal_id   VARCHAR(36)   NOT NULL,
  actor_id    VARCHAR(36)   NULL,
  action      ENUM('submitted','evidence_added','reviewed','approved','rejected','reopened') NOT NULL,
  note        TEXT          NULL,
  metadata    JSON          NULL,
  created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ah_appeal  (appeal_id),
  KEY idx_ah_created (created_at),
  FOREIGN KEY fk_ah_appeal (appeal_id) REFERENCES appeals(id) ON DELETE CASCADE,
  FOREIGN KEY fk_ah_actor  (actor_id)  REFERENCES users(id)   ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Evidence files attached to appeals ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS appeal_evidence (
  id           VARCHAR(36)   NOT NULL,
  appeal_id    VARCHAR(36)   NOT NULL,
  file_url     VARCHAR(500)  NOT NULL,
  file_name    VARCHAR(255)  NOT NULL,
  mime_type    VARCHAR(100)  NOT NULL,
  uploaded_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_ae_appeal (appeal_id),
  FOREIGN KEY fk_ae_appeal (appeal_id) REFERENCES appeals(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── System-wide immutable audit log ──────────────────────────────────────────
-- Note: No UPDATE or DELETE triggers should be added to this table.
CREATE TABLE IF NOT EXISTS audit_logs (
  id          BIGINT        NOT NULL AUTO_INCREMENT,
  actor_id    VARCHAR(36)   NULL,
  actor_role  VARCHAR(20)   NULL,
  actor_ip    VARCHAR(45)   NULL,
  action      VARCHAR(100)  NOT NULL COMMENT 'e.g. user.create, session.close, appeal.approve',
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
  FOREIGN KEY fk_al_actor (actor_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Fraud incidents — one row per detected threat event ──────────────────────
CREATE TABLE IF NOT EXISTS fraud_incidents (
  id            VARCHAR(36)    NOT NULL,
  user_id       VARCHAR(36)    NULL,
  session_id    VARCHAR(36)    NULL,
  incident_type VARCHAR(50)    NOT NULL COMMENT 'vpn|proxy|tor|mock_gps|emulator|location_jump',
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
  action_taken  VARCHAR(20)    NULL COMMENT 'blocked|warned|allowed',
  metadata      JSON           NULL,
  created_at    TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_fi_user    (user_id),
  KEY idx_fi_type    (incident_type),
  KEY idx_fi_created (created_at),
  FOREIGN KEY fk_fi_user    (user_id)    REFERENCES users(id)               ON DELETE SET NULL,
  FOREIGN KEY fk_fi_session (session_id) REFERENCES attendance_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ── Security columns on users table ──────────────────────────────────────────
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS last_login_at  DATETIME NULL,
  ADD COLUMN IF NOT EXISTS last_login_ip  VARCHAR(45) NULL,
  ADD COLUMN IF NOT EXISTS failed_logins  TINYINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS locked_until   DATETIME NULL,
  ADD COLUMN IF NOT EXISTS phone          VARCHAR(20) NULL;

-- ════════════════════════════════════════════════════════════════════════════
-- MESSAGES / ANNOUNCEMENTS
-- ════════════════════════════════════════════════════════════════════════════

-- ── Messages / Announcements ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS messages (
  id          VARCHAR(36)                          NOT NULL,
  sender_id   VARCHAR(36)                          NOT NULL,
  sender_name VARCHAR(120)                         NOT NULL,
  sender_role ENUM('admin','lecturer')             NOT NULL,
  target_type ENUM('all','course','student')       NOT NULL,
  target_id   VARCHAR(36)                              NULL,
  content     TEXT                                 NOT NULL,
  sent_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_msg_sender (sender_id),
  KEY idx_msg_target (target_type, target_id),
  FOREIGN KEY fk_msg_sender (sender_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS message_reads (
  message_id  VARCHAR(36) NOT NULL,
  student_id  VARCHAR(36) NOT NULL,
  read_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (message_id, student_id),
  FOREIGN KEY fk_mr_message (message_id) REFERENCES messages(id)  ON DELETE CASCADE,
  FOREIGN KEY fk_mr_student (student_id) REFERENCES users(id)     ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
