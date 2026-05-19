const router = require("express").Router();
const ctrl = require("../controllers/lecturer.controller");
const { authenticate, requireRole } = require("../middleware/auth");

router.use(authenticate, requireRole("lecturer", "admin"));

router.get("/dashboard", ctrl.getDashboard);
router.get("/courses", ctrl.getCourses);
router.get("/classrooms", ctrl.getClassrooms);
router.get("/sessions", ctrl.getSessions);
router.post("/sessions/start", ctrl.startSession);
router.post("/sessions/:id/close", ctrl.closeSession);
router.get("/sessions/:id/attendance", ctrl.getSessionAttendance);
router.get("/students", ctrl.getStudents);
router.post("/students", ctrl.createStudent);
router.get("/sessions/:id/enrolled-students", ctrl.getSessionEnrolledStudents);
router.get("/sessions/:id/qr", ctrl.getSessionQrToken);
router.post("/sessions/:id/mark-present", ctrl.markStudentPresent);

module.exports = router;
