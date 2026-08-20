const db = require("../db");

let ensureReportsTablePromise;

async function ensureReportsTable() {
  if (!ensureReportsTablePromise) {
    ensureReportsTablePromise = db.query(`
      CREATE TABLE IF NOT EXISTS user_reports (
        id INT AUTO_INCREMENT PRIMARY KEY,
        reporter_user_id INT NOT NULL,
        reporter_role ENUM('DOCTOR','PATIENT') NOT NULL,
        reporter_doctor_id INT NULL,
        reporter_patient_id INT NULL,
        target_user_id INT NOT NULL,
        target_role ENUM('DOCTOR','PATIENT') NOT NULL,
        target_doctor_id INT NULL,
        target_patient_id INT NULL,
        reason_category VARCHAR(100) NOT NULL,
        description TEXT NOT NULL,
        status ENUM('SUBMITTED','UNDER_REVIEW','ACTION_TAKEN','CLOSED') NOT NULL DEFAULT 'SUBMITTED',
        admin_note TEXT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        resolved_at DATETIME NULL,
        INDEX idx_user_reports_reporter (reporter_user_id, created_at),
        INDEX idx_user_reports_target_doctor (target_doctor_id, created_at),
        INDEX idx_user_reports_target_patient (target_patient_id, created_at),
        INDEX idx_user_reports_status (status, created_at),
        FOREIGN KEY (reporter_user_id) REFERENCES users(id),
        FOREIGN KEY (target_user_id) REFERENCES users(id),
        FOREIGN KEY (reporter_doctor_id) REFERENCES doctors(doctor_id),
        FOREIGN KEY (reporter_patient_id) REFERENCES patients(patient_id),
        FOREIGN KEY (target_doctor_id) REFERENCES doctors(doctor_id),
        FOREIGN KEY (target_patient_id) REFERENCES patients(patient_id)
      )
    `);
  }
  await ensureReportsTablePromise;
}

async function resolveActorFromToken(req) {
  const firebaseUid = req.user?.firebase_uid;
  if (!firebaseUid) return null;

  const [rows] = await db.query(
    `SELECT
       u.id AS user_id,
       u.role,
       d.doctor_id,
       d.name AS doctor_name,
       p.patient_id,
       p.name AS patient_name
     FROM users u
     LEFT JOIN doctors d ON d.user_id = u.id
     LEFT JOIN patients p ON p.user_id = u.id
     WHERE u.firebase_uid = ?
     LIMIT 1`,
    [firebaseUid]
  );
  if (rows.length === 0) return null;
  return rows[0];
}

async function resolveTarget(targetRole, targetId) {
  if (targetRole === "DOCTOR") {
    const [rows] = await db.query(
      `SELECT d.user_id, d.doctor_id, d.name
       FROM doctors d
       WHERE d.doctor_id = ?
       LIMIT 1`,
      [targetId]
    );
    if (rows.length === 0) return null;
    return {
      userId: rows[0].user_id,
      doctorId: rows[0].doctor_id,
      patientId: null,
      name: rows[0].name,
    };
  }

  const [rows] = await db.query(
    `SELECT p.user_id, p.patient_id, p.name
     FROM patients p
     WHERE p.patient_id = ?
     LIMIT 1`,
    [targetId]
  );
  if (rows.length === 0) return null;
  return {
    userId: rows[0].user_id,
    doctorId: null,
    patientId: rows[0].patient_id,
    name: rows[0].name,
  };
}

async function hasRelationship(reporter, targetRole, targetId) {
  if (String(reporter.role).toUpperCase() === "PATIENT" && targetRole === "DOCTOR") {
    const [rows] = await db.query(
      `SELECT 1
       FROM appointments
       WHERE patient_id = ? AND doctor_id = ?
       LIMIT 1`,
      [reporter.patient_id, targetId]
    );
    return rows.length > 0;
  }

  if (String(reporter.role).toUpperCase() === "DOCTOR" && targetRole === "PATIENT") {
    const [rows] = await db.query(
      `SELECT 1
       FROM appointments
       WHERE doctor_id = ? AND patient_id = ?
       LIMIT 1`,
      [reporter.doctor_id, targetId]
    );
    return rows.length > 0;
  }

  return false;
}

async function createReport(req, res) {
  const targetRole = String(req.body.target_role || "").trim().toUpperCase();
  const reasonCategory = String(req.body.reason_category || "").trim();
  const description = String(req.body.description || "").trim();
  const targetId = Number(
    targetRole === "DOCTOR"
      ? req.body.target_doctor_id
      : req.body.target_patient_id
  );

  if (!["DOCTOR", "PATIENT"].includes(targetRole)) {
    return res.status(400).json({ message: "Valid target_role is required" });
  }
  if (!Number.isInteger(targetId) || targetId <= 0) {
    return res.status(400).json({ message: "Valid target id is required" });
  }
  if (!reasonCategory) {
    return res.status(400).json({ message: "reason_category is required" });
  }
  if (!description) {
    return res.status(400).json({ message: "description is required" });
  }

  try {
    await ensureReportsTable();
    const reporter = await resolveActorFromToken(req);
    if (!reporter) {
      return res.status(404).json({ message: "Reporter profile not found" });
    }

    const reporterRole = String(reporter.role || "").toUpperCase();
    if (!["DOCTOR", "PATIENT"].includes(reporterRole)) {
      return res.status(403).json({ message: "Only doctor or patient can report users" });
    }
    if (reporterRole === targetRole) {
      return res.status(400).json({ message: "Invalid report target" });
    }

    const related = await hasRelationship(reporter, targetRole, targetId);
    if (!related) {
      return res.status(403).json({ message: "Report is allowed only for connected users" });
    }

    const target = await resolveTarget(targetRole, targetId);
    if (!target || !target.userId) {
      return res.status(404).json({ message: "Target user not found" });
    }
    if (target.userId === reporter.user_id) {
      return res.status(400).json({ message: "You cannot report yourself" });
    }

    const [result] = await db.query(
      `INSERT INTO user_reports
        (
          reporter_user_id,
          reporter_role,
          reporter_doctor_id,
          reporter_patient_id,
          target_user_id,
          target_role,
          target_doctor_id,
          target_patient_id,
          reason_category,
          description
        )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        reporter.user_id,
        reporterRole,
        reporter.doctor_id || null,
        reporter.patient_id || null,
        target.userId,
        targetRole,
        target.doctorId,
        target.patientId,
        reasonCategory,
        description,
      ]
    );

    return res.status(201).json({ id: result.insertId, message: "Report submitted" });
  } catch (err) {
    console.error("createReport error:", err);
    return res.status(500).json({ message: "Failed to submit report" });
  }
}

async function getMyReports(req, res) {
  try {
    await ensureReportsTable();
    const reporter = await resolveActorFromToken(req);
    if (!reporter) {
      return res.status(404).json({ message: "Reporter profile not found" });
    }

    const [rows] = await db.query(
      `SELECT
         r.id,
         r.reporter_role,
         r.target_role,
         r.target_doctor_id,
         r.target_patient_id,
         r.reason_category,
         r.description,
         r.status,
         r.admin_note,
         r.created_at,
         r.updated_at,
         r.resolved_at,
         COALESCE(d.name, p.name, 'Unknown User') AS target_name
       FROM user_reports r
       LEFT JOIN doctors d ON d.doctor_id = r.target_doctor_id
       LEFT JOIN patients p ON p.patient_id = r.target_patient_id
       WHERE r.reporter_user_id = ?
       ORDER BY r.created_at DESC`,
      [reporter.user_id]
    );

    return res.json(rows);
  } catch (err) {
    console.error("getMyReports error:", err);
    return res.status(500).json({ message: "Failed to load reports" });
  }
}

async function getAdminReports(req, res) {
  const status = String(req.query.status || "").trim().toUpperCase();
  const targetRole = String(req.query.target_role || "").trim().toUpperCase();
  const targetDoctorId = Number(req.query.target_doctor_id);
  const targetPatientId = Number(req.query.target_patient_id);

  const where = ["1 = 1"];
  const params = [];

  if (["SUBMITTED", "UNDER_REVIEW", "ACTION_TAKEN", "CLOSED"].includes(status)) {
    where.push("r.status = ?");
    params.push(status);
  }
  if (["DOCTOR", "PATIENT"].includes(targetRole)) {
    where.push("r.target_role = ?");
    params.push(targetRole);
  }
  if (Number.isInteger(targetDoctorId) && targetDoctorId > 0) {
    where.push("r.target_doctor_id = ?");
    params.push(targetDoctorId);
  }
  if (Number.isInteger(targetPatientId) && targetPatientId > 0) {
    where.push("r.target_patient_id = ?");
    params.push(targetPatientId);
  }

  try {
    await ensureReportsTable();
    const [rows] = await db.query(
      `SELECT
         r.id,
         r.reporter_role,
         r.target_role,
         r.reporter_doctor_id,
         r.reporter_patient_id,
         r.target_doctor_id,
         r.target_patient_id,
         r.reason_category,
         r.description,
         r.status,
         r.admin_note,
         r.created_at,
         r.updated_at,
         r.resolved_at,
         COALESCE(rd.name, rp.name, 'Unknown User') AS reporter_name,
         COALESCE(td.name, tp.name, 'Unknown User') AS target_name
       FROM user_reports r
       LEFT JOIN doctors rd ON rd.doctor_id = r.reporter_doctor_id
       LEFT JOIN patients rp ON rp.patient_id = r.reporter_patient_id
       LEFT JOIN doctors td ON td.doctor_id = r.target_doctor_id
       LEFT JOIN patients tp ON tp.patient_id = r.target_patient_id
       WHERE ${where.join(" AND ")}
       ORDER BY r.created_at DESC`,
      params
    );

    return res.json(rows);
  } catch (err) {
    console.error("getAdminReports error:", err);
    return res.status(500).json({ message: "Failed to load admin reports" });
  }
}

async function updateReportStatus(req, res) {
  const reportId = Number(req.params.id);
  const status = String(req.body.status || "").trim().toUpperCase();
  const adminNote = String(req.body.admin_note || "").trim();

  if (!Number.isInteger(reportId) || reportId <= 0) {
    return res.status(400).json({ message: "Invalid report id" });
  }
  if (!["SUBMITTED", "UNDER_REVIEW", "ACTION_TAKEN", "CLOSED"].includes(status)) {
    return res.status(400).json({ message: "Valid status is required" });
  }

  try {
    await ensureReportsTable();
    const [result] = await db.query(
      `UPDATE user_reports
       SET status = ?,
           admin_note = ?,
           resolved_at = CASE
             WHEN ? IN ('ACTION_TAKEN', 'CLOSED') THEN NOW()
             ELSE NULL
           END
       WHERE id = ?`,
      [status, adminNote || null, status, reportId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Report not found" });
    }

    return res.json({ message: "Report updated" });
  } catch (err) {
    console.error("updateReportStatus error:", err);
    return res.status(500).json({ message: "Failed to update report" });
  }
}

module.exports = {
  createReport,
  getMyReports,
  getAdminReports,
  updateReportStatus,
};
