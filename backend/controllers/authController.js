const db = require("../db");

const ALLOWED_ROLES = new Set(["ADMIN", "DOCTOR", "PATIENT"]);

async function buildUserPayload(userId) {
  const [userRows] = await db.query(
    "SELECT id, email, role FROM users WHERE id = ?",
    [userId]
  );
  if (userRows.length === 0) return null;

  const user = userRows[0];
  const role = String(user.role || "").toUpperCase();

  let name = user.email;
  let doctorId = null;
  let patientId = null;

  if (role === "DOCTOR") {
    const [doctorRows] = await db.query(
      "SELECT doctor_id, name, email FROM doctors WHERE user_id = ? LIMIT 1",
      [user.id]
    );
    if (doctorRows.length > 0) {
      doctorId = doctorRows[0].doctor_id;
      name = doctorRows[0].name || name;
      user.email = doctorRows[0].email || user.email;
    }
  }

  if (role === "PATIENT") {
    const [patientRows] = await db.query(
      "SELECT patient_id, name, email FROM patients WHERE user_id = ? LIMIT 1",
      [user.id]
    );
    if (patientRows.length > 0) {
      patientId = patientRows[0].patient_id;
      name = patientRows[0].name || name;
      user.email = patientRows[0].email || user.email;
    }
  }

  return {
    user_id: user.id,
    name,
    role,
    email: user.email,
    doctor_id: doctorId,
    patient_id: patientId,
  };
}

async function register(req, res) {
  const role = String(req.body.role || "").toUpperCase();
  const displayName = String(req.body.name || "").trim();
  const firebaseUid = req.user?.firebase_uid;
  const email = req.user?.email;
  const tokenDisplayName = String(req.user?.display_name || "").trim();

  if (!ALLOWED_ROLES.has(role)) {
    return res.status(400).json({ message: "Invalid role" });
  }
  if (!firebaseUid || !email) {
    return res.status(400).json({ message: "Missing firebase user context" });
  }

  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();

    const [userRows] = await conn.query(
      "SELECT id, role FROM users WHERE firebase_uid = ?",
      [firebaseUid]
    );

    let userId;
    if (userRows.length === 0) {
      const [insertUser] = await conn.query(
        "INSERT INTO users (firebase_uid, email, role) VALUES (?, ?, ?)",
        [firebaseUid, email, role]
      );
      userId = insertUser.insertId;
    } else {
      const existingRole = String(userRows[0].role || "").toUpperCase();
      if (existingRole !== role) {
        await conn.rollback();
        return res.status(409).json({
          message: `Role mismatch. Existing role is ${existingRole}`,
        });
      }
      userId = userRows[0].id;
    }

    if (role === "DOCTOR") {
      const [doctorRows] = await conn.query(
        "SELECT doctor_id FROM doctors WHERE user_id = ?",
        [userId]
      );
      if (doctorRows.length === 0) {
        await conn.query(
          `INSERT INTO doctors
            (user_id, name, email, phone, age, qualification, years_of_experience,
             clinic_name, rating, profile_image_url, latitude, longitude, is_verified, approval_status, verification_status, is_removed)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            userId,
            displayName || "New Doctor",
            email,
            "NA",
            0,
            "NA",
            0,
            "NA",
            0.0,
            "https://via.placeholder.com/150",
            0,
            0,
            0,
            "PENDING",
            "not_applied",
            0,
          ]
        );
      } else if (displayName) {
        await conn.query('UPDATE doctors SET name = ? WHERE user_id = ?', [displayName, userId]);
      }
    }

    if (role === "PATIENT") {
      const [patientRows] = await conn.query(
        "SELECT patient_id FROM patients WHERE user_id = ?",
        [userId]
      );
      if (patientRows.length === 0) {
        await conn.query(
          `INSERT INTO patients (user_id, name, age, email, phone, address)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [userId, displayName || tokenDisplayName || "New Patient", 0, email, "NA", "NA"]
        );
      } else if (displayName) {
        await conn.query('UPDATE patients SET name = ? WHERE user_id = ?', [displayName, userId]);
      }
    }

    await conn.commit();
    return res.status(201).json({ message: "Registered successfully" });
  } catch (err) {
    await conn.rollback();
    return res.status(500).json({ message: "Register failed" });
  } finally {
    conn.release();
  }
}

async function login(req, res) {
  const firebaseUid = req.user?.firebase_uid;
  const tokenDisplayName = String(req.user?.display_name || "").trim();
  const selectedRole = String(req.body.role || "").toUpperCase();

  if (!firebaseUid) {
    return res.status(400).json({ message: "Missing firebase user context" });
  }
  if (!ALLOWED_ROLES.has(selectedRole)) {
    return res.status(400).json({ message: "Invalid role" });
  }

  const invalidMessageByRole = {
    DOCTOR: "Invalid credentials for Doctor",
    PATIENT: "Invalid credentials for Patient",
    ADMIN: "Invalid credentials for Admin",
  };

  try {
    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [firebaseUid]
    );

    if (userRows.length === 0) {
      return res.status(401).json({
        message: invalidMessageByRole[selectedRole] ||
          "Invalid credentials for selected role",
      });
    }

    const userId = userRows[0].id;
    const actualRole = String(userRows[0].role || "").toUpperCase();

    if (actualRole !== selectedRole) {
      return res.status(401).json({
        message: invalidMessageByRole[selectedRole] ||
          "Invalid credentials for selected role",
      });
    }

    if (selectedRole === "DOCTOR") {
      const [doctorRows] = await db.query(
        "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (doctorRows.length === 0) {
        return res.status(401).json({ message: "Invalid credentials for Doctor" });
      }
    } else if (selectedRole === "PATIENT") {
      const [patientRows] = await db.query(
        "SELECT patient_id FROM patients WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (patientRows.length === 0) {
        return res.status(401).json({ message: "Invalid credentials for Patient" });
      }
    } else if (selectedRole === "ADMIN") {
      const [adminRows] = await db.query(
        "SELECT id FROM users WHERE id = ? AND role = 'ADMIN' LIMIT 1",
        [userId]
      );
      if (adminRows.length === 0) {
        return res.status(401).json({ message: "Invalid credentials for Admin" });
      }
    }

    let payload = await buildUserPayload(userId);
    if (!payload) {
      return res.status(401).json({
        message: invalidMessageByRole[selectedRole] ||
          "Invalid credentials for selected role",
      });
    }

    const placeholderNames = new Set(["New Patient", "New Doctor"]);
    if (tokenDisplayName && placeholderNames.has(payload.name)) {
      if (payload.role === "PATIENT" && payload.patient_id) {
        await db.query("UPDATE patients SET name = ? WHERE patient_id = ?", [
          tokenDisplayName,
          payload.patient_id,
        ]);
      }
      if (payload.role === "DOCTOR" && payload.doctor_id) {
        await db.query("UPDATE doctors SET name = ? WHERE doctor_id = ?", [
          tokenDisplayName,
          payload.doctor_id,
        ]);
      }
      payload = await buildUserPayload(userId);
    }

    return res.json(payload);
  } catch (err) {
    return res.status(500).json({ message: "Login failed" });
  }
}

async function getUserById(req, res) {
  const userId = Number(req.params.id);
  if (!Number.isInteger(userId) || userId <= 0) {
    return res.status(400).json({ message: "Invalid user id" });
  }

  try {
    const payload = await buildUserPayload(userId);
    if (!payload) return res.status(404).json({ message: "User not found" });
    return res.json(payload);
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch user" });
  }
}

module.exports = { register, login, getUserById };
