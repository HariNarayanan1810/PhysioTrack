const express = require("express");
const { registerDeviceToken } = require("../controllers/devicesController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.post(
  "/devices/register-token",
  verifyToken,
  requireRoles("ADMIN", "DOCTOR", "PATIENT"),
  registerDeviceToken
);

module.exports = router;
