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
