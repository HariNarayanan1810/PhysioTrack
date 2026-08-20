const express = require("express");
const {
  getDoctors,
  getApprovedDoctors,
  getDoctorById,
  getDoctorProfile,
  updateDoctorPricing,
  removeDoctor,
} = require("../controllers/doctorsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();
router.get("/", getDoctors);
router.get("/approved", getApprovedDoctors);
router.get("/:id/profile", getDoctorProfile);
router.get("/:id", getDoctorById);
router.put(
  "/:id/pricing",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  updateDoctorPricing
);
router.put("/:id/remove", removeDoctor);

module.exports = router;
