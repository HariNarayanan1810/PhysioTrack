const db = require("../db");

async function getPatientByFirebaseUid(firebaseUid) {
  const [userRows] = await db.query("SELECT id, email FROM users WHERE firebase_uid = ?", [
    firebaseUid,
  ]);
  if (userRows.length === 0) {
    return null;
  }

  const user = userRows[0];
  const [patientRows] = await db.query(
    "SELECT * FROM patients WHERE user_id = ? LIMIT 1",
    [user.id]
  );

  if (patientRows.length === 0) {
    return { user, patient: null };
  }
  return { user, patient: patientRows[0] };
}

async function getPatients(req, res) {
  const doctorId = req.query.doctor_id;
  const userId = req.query.user_id;
  const removed = req.query.removed;

  try {
    if (doctorId) {
      const [rows] = await db.query(
        `SELECT DISTINCT p.*
         FROM patients p
         JOIN appointments a ON a.patient_id = p.patient_id
         WHERE a.doctor_id = ?
         ORDER BY p.patient_id DESC`,
        [doctorId]
      );
      return res.json(rows);
    }

    if (userId) {
      const [rows] = await db.query("SELECT * FROM patients WHERE user_id = ?", [
        userId,
      ]);
      return res.json(rows);
    }

    if (removed === "true" || removed === "1") {
      const [rows] = await db.query(
        `SELECT p.*
         FROM patients p
         WHERE p.is_removed = 1
         ORDER BY p.patient_id DESC`
      );
      return res.json(rows);
    }

    const [rows] = await db.query(
      `SELECT p.*
       FROM patients p
       JOIN users u ON u.id = p.user_id
       WHERE UPPER(u.role) = 'PATIENT'
         AND p.is_removed = 0
       ORDER BY p.patient_id DESC`
    );
    return res.json(rows);
  } catch (err) {
    console.error("getPatients error:", err);
    return res.status(500).json({ message: "Failed to fetch patients" });
  }
}

async function getPatientById(req, res) {
  const patientId = Number(req.params.id);
  if (!Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid patient id" });
  }

  try {
    const [rows] = await db.query(
      "SELECT * FROM patients WHERE patient_id = ? LIMIT 1",
      [patientId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Patient not found" });
    }
    return res.json(rows[0]);
  } catch (err) {
    console.error("getPatientById error:", err);
    return res.status(500).json({ message: "Failed to fetch patient" });
  }
}

async function getPatientProfile(req, res) {
  const firebaseUid = req.user?.firebase_uid;
  if (!firebaseUid) {
    return res.status(401).json({ message: "Missing user context" });
  }

  try {
    const record = await getPatientByFirebaseUid(firebaseUid);
    if (!record) {
      return res.status(404).json({ message: "User not found" });
    }

    if (!record.patient) {
      return res.json({
        exists: false,
        profile: {
          name: "",
          email: record.user.email || "",
          phone: "",
          dob: null,
          age: 0,
          state: "",
          city: "",
          address: "",
          latitude: null,
          longitude: null,
          profile_image: "",
        },
      });
    }

    return res.json({ exists: true, profile: record.patient });
  } catch (err) {
    console.error("getPatientProfile error:", err);
    return res.status(500).json({ message: "Failed to fetch profile" });
  }
}

function parseAgeFromDob(dob) {
  if (!dob) return 0;
  const birth = new Date(dob);
  if (Number.isNaN(birth.getTime())) return 0;

  const today = new Date();
  let age = today.getFullYear() - birth.getFullYear();
  const monthDiff = today.getMonth() - birth.getMonth();
  const dayDiff = today.getDate() - birth.getDate();
  if (monthDiff < 0 || (monthDiff === 0 && dayDiff < 0)) {
    age -= 1;
  }
  return age < 0 ? 0 : age;
}

function validateProfileInput(body) {
  const dob = String(body.dob || "").trim();
  const state = String(body.state || "").trim();
  const city = String(body.city || "").trim();
  const address = String(body.address || "").trim();
  const latitude = Number(body.latitude);
  const longitude = Number(body.longitude);

  if (!dob) return "DOB is required";
  const dobDate = new Date(dob);
  if (Number.isNaN(dobDate.getTime())) return "DOB is invalid";
  if (dobDate > new Date()) return "DOB cannot be in future";

  if (!state) return "State is required";
  if (!city) return "City is required";
  if (!address) return "Address is required";

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return "Location is required";
  }
  return null;
}

async function createPatientProfile(req, res) {
  const firebaseUid = req.user?.firebase_uid;
  if (!firebaseUid) {
    return res.status(401).json({ message: "Missing user context" });
  }

  const validationError = validateProfileInput(req.body);
  if (validationError) {
    return res.status(400).json({ message: validationError });
  }

  try {
    const record = await getPatientByFirebaseUid(firebaseUid);
    if (!record) {
      return res.status(404).json({ message: "User not found" });
    }

    if (record.patient) {
      return res.status(409).json({ message: "Profile already exists. Use update." });
    }

    const name = String(req.body.name || "").trim() || "Patient";
    const email = String(req.body.email || "").trim() || record.user.email;
    const phone = String(req.body.phone || "").trim() || "NA";
    const dob = String(req.body.dob || "").trim();
    const age = parseAgeFromDob(dob);
    const state = String(req.body.state || "").trim();
    const city = String(req.body.city || "").trim();
    const address = String(req.body.address || "").trim();
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    const profileImage = String(req.body.profile_image || "").trim();

    const [result] = await db.query(
      `INSERT INTO patients
        (user_id, name, age, email, phone, address, dob, profile_image, state, city, latitude, longitude)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        record.user.id,
        name,
        age,
        email,
        phone,
        address,
        dob,
        profileImage || null,
        state,
        city,
        latitude,
        longitude,
      ]
    );

    return res.status(201).json({ message: "Profile created", patient_id: result.insertId });
  } catch (err) {
    console.error("createPatientProfile error:", err);
    return res.status(500).json({ message: "Failed to create profile" });
  }
}

async function updatePatientProfile(req, res) {
  const firebaseUid = req.user?.firebase_uid;
  if (!firebaseUid) {
    return res.status(401).json({ message: "Missing user context" });
  }

  const validationError = validateProfileInput(req.body);
  if (validationError) {
    return res.status(400).json({ message: validationError });
  }

  try {
    const record = await getPatientByFirebaseUid(firebaseUid);
    if (!record) {
      return res.status(404).json({ message: "User not found" });
    }
    if (!record.patient) {
      return res.status(404).json({ message: "Profile not found. Use create." });
    }

    const name = String(req.body.name || "").trim() || record.patient.name;
    const phone = String(req.body.phone || "").trim() || record.patient.phone || "NA";
    const dob = String(req.body.dob || "").trim();
    const age = parseAgeFromDob(dob);
    const state = String(req.body.state || "").trim();
    const city = String(req.body.city || "").trim();
    const address = String(req.body.address || "").trim();
    const latitude = Number(req.body.latitude);
    const longitude = Number(req.body.longitude);
    const incomingImage = String(req.body.profile_image || "").trim();
    const profileImage = incomingImage || record.patient.profile_image || "";

    await db.query(
      `UPDATE patients
       SET name = ?, age = ?, phone = ?, address = ?, dob = ?, profile_image = ?, state = ?, city = ?, latitude = ?, longitude = ?
       WHERE patient_id = ?`,
      [
        name,
        age,
        phone,
        address,
        dob,
        profileImage || null,
        state,
        city,
        latitude,
        longitude,
        record.patient.patient_id,
      ]
    );

    return res.json({ message: "Profile updated" });
  } catch (err) {
    console.error("updatePatientProfile error:", err);
    return res.status(500).json({ message: "Failed to update profile" });
  }
}

async function uploadPatientProfileImage(req, res) {
  if (!req.file) {
    return res.status(400).json({ message: "Image is required" });
  }

  const imageUrl = `/uploads/${req.file.filename}`;
  return res.status(201).json({ image_url: imageUrl });
}

async function removePatient(req, res) {
  const patientId = Number(req.params.id);
  const removedReason = String(req.body.removed_reason || "").trim();

  if (!Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid patient id" });
  }
  if (!removedReason) {
    return res.status(400).json({ message: "removed_reason is required" });
  }

  try {
    const [result] = await db.query(
      "UPDATE patients SET is_removed = 1, removed_reason = ?, removed_at = CURRENT_TIMESTAMP WHERE patient_id = ?",
      [removedReason, patientId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Patient not found" });
    }
    return res.json({ message: "Patient removed successfully" });
  } catch (err) {
    console.error("removePatient error:", err);
    return res.status(500).json({ message: "Failed to remove patient" });
  }
}

module.exports = {
  getPatients,
  getPatientById,
  getPatientProfile,
  createPatientProfile,
  updatePatientProfile,
  uploadPatientProfileImage,
  removePatient,
};
