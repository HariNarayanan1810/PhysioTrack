const admin = require("firebase-admin");
const path = require("path");

let initialized = false;

function getServiceAccountPath() {
  const fromEnv = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (fromEnv && fromEnv.trim()) return fromEnv.trim();
  return path.join(__dirname, "serviceAccountKey.json");
}

function initFirebaseAdmin() {
  if (initialized) return admin;

  const serviceAccountPath = getServiceAccountPath();
  // Require is intentional here because Firebase Admin expects JSON object.
  // eslint-disable-next-line import/no-dynamic-require, global-require
  const serviceAccount = require(serviceAccountPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
  initialized = true;
  return admin;
}

module.exports = { initFirebaseAdmin };
