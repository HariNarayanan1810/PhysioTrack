const { initFirebaseAdmin } = require("../firebaseAdmin");
const db = require("../db");

async function registerUserDeviceToken({
  userId,
  role,
  fcmToken,
  platform,
}) {
  await db.query(
    `INSERT INTO user_device_tokens (user_id, role, fcm_token, platform, updated_at)
     VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
     ON DUPLICATE KEY UPDATE
       user_id = VALUES(user_id),
       role = VALUES(role),
       platform = VALUES(platform),
       updated_at = CURRENT_TIMESTAMP`,
    [userId, role, fcmToken, platform]
  );
}

async function getUserDeviceTokens(userId) {
  const [rows] = await db.query(
    `SELECT fcm_token
     FROM user_device_tokens
     WHERE user_id = ?`,
    [userId]
  );
  return rows
    .map((row) => String(row.fcm_token || "").trim())
    .filter(Boolean);
}

async function sendPushToUser({
  userId,
  title,
  body,
  data = {},
}) {
  const tokens = await getUserDeviceTokens(userId);
  if (tokens.length === 0) {
    return { attempted: 0, sent: 0 };
  }

  const admin = initFirebaseAdmin();
  let sent = 0;

  for (const token of tokens) {
    try {
      await admin.messaging().send({
        token,
        notification: {
          title,
          body,
        },
        data: Object.fromEntries(
          Object.entries(data).map(([key, value]) => [key, String(value ?? "")])
        ),
        android: {
          priority: "high",
          notification: {
            channelId: "physiotrack_alerts",
          },
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
      sent += 1;
    } catch (error) {
      console.error("sendPushToUser error:", error);
    }
  }

  return {
    attempted: tokens.length,
    sent,
  };
}

module.exports = {
  registerUserDeviceToken,
  getUserDeviceTokens,
  sendPushToUser,
};
