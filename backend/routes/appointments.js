const express = require("express");
const {
  getAppointments,
  createAppointment,
  updateAppointmentStatus,
  cancelAppointment,
  confirmSuggestedAppointment,
  rescheduleSuggestedAppointment,
  updateHomeVisitLiveTracking,
  stopDoctorHomeVisitDay,
  getPatientHomeVisitTracking,
} = require("../controllers/appointmentsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();
router.get("/", getAppointments);
router.post("/", verifyToken, requireRoles("PATIENT", "ADMIN"), createAppointment);
router.post(
  "/confirm",
  verifyToken,
  requireRoles("PATIENT", "ADMIN"),
  confirmSuggestedAppointment
);
router.post(
  "/reschedule",
  verifyToken,
  requireRoles("PATIENT", "ADMIN"),
  rescheduleSuggestedAppointment
);
router.get(
  "/home-visit/live/:patientId",
  verifyToken,
  requireRoles("PATIENT", "DOCTOR", "ADMIN"),
  getPatientHomeVisitTracking
);
router.put(
  "/home-visit/stop-day",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  stopDoctorHomeVisitDay
);
router.put(
  "/:id/cancel",
  verifyToken,
  requireRoles("PATIENT", "ADMIN"),
  cancelAppointment
);
router.put(
  "/:id/live-tracking",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  updateHomeVisitLiveTracking
);
router.put(
  "/:id/status",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  updateAppointmentStatus
);

module.exports = router;
