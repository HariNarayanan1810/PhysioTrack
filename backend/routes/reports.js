const express = require("express");
const {
  createReport,
  getMyReports,
  getAdminReports,
  updateReportStatus,
} = require("../controllers/reportsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.post(
  "/reports",
  verifyToken,
  requireRoles("DOCTOR", "PATIENT"),
  createReport
);
router.get(
  "/reports/mine",
  verifyToken,
  requireRoles("DOCTOR", "PATIENT"),
  getMyReports
);
router.get(
  "/admin/reports",
  verifyToken,
  requireRoles("ADMIN"),
  getAdminReports
);
router.put(
  "/admin/reports/:id",
  verifyToken,
  requireRoles("ADMIN"),
  updateReportStatus
);

module.exports = router;
