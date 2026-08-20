const express = require("express");
const {
  getTodayExercises,
  startDay,
  completeOne,
  completeDay,
  getExerciseCalendar,
  getCompletedDaysByMonth,
} = require("../controllers/patientDailyExercisesController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.get(
  "/patients/exercises/today",
  verifyToken,
  requireRoles("PATIENT"),
  getTodayExercises
);
router.post(
  "/patients/exercises/start-day",
  verifyToken,
  requireRoles("PATIENT"),
  startDay
);
router.post(
  "/patients/exercises/complete-one",
  verifyToken,
  requireRoles("PATIENT"),
  completeOne
);
router.post(
  "/patients/exercises/complete-day",
  verifyToken,
  requireRoles("PATIENT"),
  completeDay
);
router.get(
  "/patients/exercises/calendar",
  verifyToken,
  requireRoles("PATIENT"),
  getExerciseCalendar
);


router.get(
  "/patient/exercise/completed-days",
  verifyToken,
  requireRoles("PATIENT"),
  getCompletedDaysByMonth
);

module.exports = router;
