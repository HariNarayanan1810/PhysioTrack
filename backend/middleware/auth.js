const { initFirebaseAdmin } = require("../firebaseAdmin");
const db = require("../db");

async function verifyToken(req, res, next) {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : "";

    if (!token) {
      return res.status(401).json({ message: "Missing authorization token" });
    }

    const admin = initFirebaseAdmin();
    const decoded = await admin.auth().verifyIdToken(token);
    req.user = {
      firebase_uid: decoded.uid,
      email: decoded.email || '',
      display_name: decoded.name || '',
    };
    return next();
  } catch (err) {
    return res.status(401).json({ message: "Invalid authorization token" });
  }
}

function requireRoles(...allowedRoles) {
  return async function roleMiddleware(req, res, next) {
    const firebaseUid = req.user?.firebase_uid;
    if (!firebaseUid) {
      return res.status(401).json({ message: "Missing authenticated user" });
    }

    try {
      const [rows] = await db.query(
        "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
        [firebaseUid]
      );
      if (rows.length === 0) {
        return res.status(403).json({ message: "User is not registered" });
      }

      const role = String(rows[0].role || "").toUpperCase();
      req.user.role = role;
      req.user.user_id = rows[0].id;

      if (!allowedRoles.includes(role)) {
        return res.status(403).json({ message: "Access denied for this role" });
      }
      return next();
    } catch (err) {
      return res.status(500).json({ message: "Role validation failed" });
    }
  };
}

module.exports = { verifyToken, requireRoles };
