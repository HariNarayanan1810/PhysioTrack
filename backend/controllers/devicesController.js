const {
  registerUserDeviceToken,
} = require("../services/notificationsService");

async function registerDeviceToken(req, res) {
  const userId = Number(req.user?.user_id);
  const role = String(req.user?.role || "").toUpperCase();
  const fcmToken = String(req.body.fcm_token || "").trim();
  const platform = String(req.body.platform || "").trim().toLowerCase() || "unknown";

  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(401).json({ message: "Unauthorized user" });
  }
  if (!fcmToken) {
    return res.status(400).json({ message: "fcm_token is required" });
  }

  try {
    await registerUserDeviceToken({
      userId,
      role,
      fcmToken,
      platform,
    });
    return res.status(201).json({ message: "Device token registered" });
  } catch (error) {
    console.error("registerDeviceToken error:", error);
    return res.status(500).json({ message: "Failed to register device token" });
  }
}

module.exports = {
  registerDeviceToken,
};
