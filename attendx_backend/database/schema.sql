-- AttendX Database Schema
-- Compatible with MySQL 8.0+ and MariaDB 10.5+

CREATE DATABASE IF NOT EXISTS attendx CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE attendx;

-- ── Users ────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id            VARCHAR(36)                            NOT NULL,
  full_name     VARCHAR(255)                           NOT NULL,
  email         VARCHAR(255)                           NOT NULL,
  password_hash VARCHAR(255)                           NOT NULL,
  role          ENUM('admin','lecturer','student')     NOT NULL DEFAULT 'student',
  reg_number    VARCHAR(50)                            NULL,
  phone         VARCHAR(20)                            NULL,
  department    VARCHAR(100)                           NULL,
  is_active     TINYINT(1)                             NOT NULL DEFAULT 1,
  created_at    TIMESTAMP                              NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP                              NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Courses ──────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS courses (
  id          VARCHAR(36)   NOT NULL,
  code        VARCHAR(20)   NOT NULL,
  name        VARCHAR(255)  NOT NULL,
  credits     INT           NOT NULL DEFAULT 3,
  department  VARCHAR(100)  NULL,
  lecturer_id VARCHAR(36)   NULL,
  is_active   TINYINT(1)    NOT NULL DEFAULT 1,
  created_at  TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_courses_code (code),
  FOREIGN KEY fk_courses_lecturer (lecturer_id) REFERENCES users(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Enrollments ──────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enrollments (
  id          VARCHAR(36) NOT NULL,
  student_id  VARCHAR(36) NOT NULL,
  course_id   VARCHAR(36) NOT NULL,
  enrolled_at TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_enrollment (student_id, course_id),
  FOREIGN KEY fk_enroll_student (student_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY fk_enroll_course  (course_id)  REFERENCES courses(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Classrooms ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS classrooms (
  id         VARCHAR(36)      NOT NULL,
  name       VARCHAR(100)     NOT NULL,
  building   VARCHAR(100)     NULL,
  capacity   INT              NOT NULL DEFAULT 60,
  latitude   DECIMAL(10, 7)   NOT NULL,
  longitude  DECIMAL(10, 7)   NOT NULL,
  radius_m   INT              NOT NULL DEFAULT 30,
  is_active  TINYINT(1)       NOT NULL DEFAULT 1,
  created_at TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Attendance Sessions ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_sessions (
  id           VARCHAR(36)            NOT NULL,
  session_code VARCHAR(10)            NOT NULL,
  course_id    VARCHAR(36)            NOT NULL,
  classroom_id VARCHAR(36)            NOT NULL,
  lecturer_id  VARCHAR(36)            NOT NULL,
  status       ENUM('active','closed') NOT NULL DEFAULT 'active',
  checkin_open TINYINT(1)             NOT NULL DEFAULT 1,
  started_at   TIMESTAMP              NOT NULL DEFAULT CURRENT_TIMESTAMP,
  closed_at    TIMESTAMP              NULL,
 expires_at DATETIME                  NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_code (session_code),
  FOREIGN KEY fk_sess_course    (course_id)    REFERENCES courses(id),
  FOREIGN KEY fk_sess_classroom (classroom_id) REFERENCES classrooms(id),
  FOREIGN KEY fk_sess_lecturer  (lecturer_id)  REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Attendance Records ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS attendance_records (
  id                VARCHAR(36)              NOT NULL,
  session_id        VARCHAR(36)              NOT NULL,
  student_id        VARCHAR(36)              NOT NULL,
  status            ENUM('present','absent','late') NOT NULL DEFAULT 'present',
  submission_method ENUM('app','manual')     NOT NULL DEFAULT 'app',
  geofence_passed   TINYINT(1)              NOT NULL DEFAULT 1,
  latitude          DECIMAL(10, 7)          NULL,
  longitude         DECIMAL(10, 7)          NULL,
  distance_m        DECIMAL(8, 2)           NULL,
  marked_at         TIMESTAMP               NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_student (session_id, student_id),
  FOREIGN KEY fk_rec_session (session_id) REFERENCES attendance_sessions(id) ON DELETE CASCADE,
  FOREIGN KEY fk_rec_student (student_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ── Notifications ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications (
  id         VARCHAR(36)                                                             NOT NULL,
  user_id    VARCHAR(36)                                                             NOT NULL,
  title      VARCHAR(255)                                                            NOT NULL,
  body       TEXT                                                                    NOT NULL,
  type       ENUM('session_started','attendance_confirmed','absence_warning','system') NOT NULL DEFAULT 'system',
  is_read    TINYINT(1)                                                              NOT NULL DEFAULT 0,
  created_at TIMESTAMP                                                               NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY fk_notif_user (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_notif_user (user_id)
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

-- ── Refresh Tokens ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         VARCHAR(36)  NOT NULL,
  user_id    VARCHAR(36)  NOT NULL,
  token_hash VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP    NOT NULL,
  created_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  FOREIGN KEY fk_rt_user (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
