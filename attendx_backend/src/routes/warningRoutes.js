const express = require("express");
const router = express.Router();
const fcmService = require("../services/fcm.service");
const { authenticate, requireRole } = require("../middleware/auth");

// Initialize FCM on server start
fcmService.init();

// Send warning to a single student
router.post("/send-warning", authenticate, requireRole("lecturer", "admin"), async (req, res) => {
  try {
    const db = require("../config/database");
    let { studentId, studentName, attendanceRate, courseName, sessionId } = req.body;

    if (!studentId) return res.status(400).json({ error: "Missing required field: studentId" });
    if (!courseName && !sessionId) return res.status(400).json({ error: "Missing required field: courseName or sessionId" });

    // Resolve courseName from sessionId when not provided
    if (!courseName && sessionId) {
      const [[sess]] = await db.query(
        `SELECT c.name AS courseName FROM attendance_sessions s JOIN courses c ON c.id = s.course_id WHERE s.id = ?`,
        [sessionId]
      );
      courseName = sess?.courseName || "Unknown Course";
    }

    // Auto-derive actual attendance rate from DB when not provided or is 0
    if (!attendanceRate || attendanceRate === 0) {
      const [[rate]] = await db.query(
        `SELECT ROUND(100 * SUM(CASE WHEN r.status='present' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1) AS rate
           FROM attendance_records r
           JOIN attendance_sessions s ON s.id = r.session_id
           JOIN courses c ON c.name = ?
          WHERE r.student_id = ? AND s.course_id = c.id`,
        [courseName, studentId]
      );
      attendanceRate = Number(rate?.rate) || 0;
    }

    await fcmService.notifyAbsenceWarning({
      studentId,
      studentName: studentName || "Student",
      attendanceRate,
      courseName,
    });

    res.json({
      success: true,
      message: `Warning sent to ${studentName || studentId}`,
    });
  } catch (error) {
    console.error("Error sending warning:", error);
    res.status(500).json({
      error: "Failed to send warning",
      details: error.message,
    });
  }
});

// Send warnings to multiple students
router.post("/send-bulk-warnings", authenticate, requireRole("lecturer", "admin"), async (req, res) => {
  try {
    const db = require("../config/database");
    let { students, sessionId } = req.body;

    if (!students || !students.length) {
      return res.status(400).json({ error: "No students provided" });
    }

    // Resolve course name from sessionId when students have no courseName
    let sessionCourseName = null;
    if (sessionId) {
      const [[sess]] = await db.query(
        `SELECT c.name AS courseName FROM attendance_sessions s JOIN courses c ON c.id = s.course_id WHERE s.id = ?`,
        [sessionId]
      );
      sessionCourseName = sess?.courseName;
    }

    // For each student with missing/zero rate, derive from DB
    const enriched = await Promise.all(students.map(async s => {
      const courseName = s.course || s.courseName || sessionCourseName || "Unknown Course";
      let rate = s.attendanceRate;
      if (!rate || rate === 0) {
        const [[r]] = await db.query(
          `SELECT ROUND(100 * SUM(CASE WHEN ar.status='present' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1) AS rate
             FROM attendance_records ar
             JOIN attendance_sessions ses ON ses.id = ar.session_id
             JOIN courses c ON c.name = ?
            WHERE ar.student_id = ? AND ses.course_id = c.id`,
          [courseName, s.id]
        );
        rate = Number(r?.rate) || 0;
      }
      return { ...s, attendanceRate: rate, course: courseName };
    }));

    const results = await fcmService.notifyBulkAbsenceWarnings(enriched);

    res.json({
      success: true,
      ...results,
      total: students.length,
    });
  } catch (error) {
    console.error("Error sending bulk warnings:", error);
    res.status(500).json({
      error: "Failed to send bulk warnings",
      details: error.message,
    });
  }
});

// Get warning history for a student
router.get("/warnings/:studentId", authenticate, requireRole("lecturer", "admin"), async (req, res) => {
  try {
    const { studentId } = req.params;
    const db = require("../config/database");

    const [rows] = await db.query(
      `SELECT * FROM attendance_warnings 
       WHERE student_id = ? 
       ORDER BY sent_at DESC`,
      [studentId],
    );

    res.json({ success: true, warnings: rows });
  } catch (error) {
    console.error("Error fetching warnings:", error);
    res.status(500).json({ error: "Failed to fetch warnings" });
  }
});

module.exports = router;
