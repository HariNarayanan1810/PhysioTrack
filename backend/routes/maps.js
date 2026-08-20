const express = require("express");
const { getDirections } = require("../controllers/mapsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.get(
  "/maps/directions",
  verifyToken,
  requireRoles("PATIENT", "DOCTOR", "ADMIN"),
  getDirections
);

module.exports = router;
