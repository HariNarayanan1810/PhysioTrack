const db = require("../db");

function formatDateOnly(value) {
  if (!value) return "";
  if (typeof value === "string") {
    const match = value.trim().match(/^(\d{4}-\d{2}-\d{2})/);
    return match ? match[1] : value.trim();
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, "0");
  const d = String(date.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

async function hasDoctorPatientAccess(doctorId, patientId) {
  const [rows] = await db.query(
    "SELECT 1 FROM appointments WHERE doctor_id = ? AND patient_id = ? AND status IN ('APPROVED', 'COMPLETED') LIMIT 1",
    [doctorId, patientId]
  );
  return rows.length > 0;
}

async function upsertPatientTreatment({
  doctorId,
  patientId,
  problemDescription,
  adviceNotes,
  suggestedNextAppointment,
}) {
  await db.query(
    `INSERT INTO patient_treatment
      (patient_id, doctor_id, problem_description, advice_notes, suggested_next_appointment)
     VALUES (?, ?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE
       problem_description = COALESCE(VALUES(problem_description), problem_description),
       advice_notes = COALESCE(VALUES(advice_notes), advice_notes),
       suggested_next_appointment = VALUES(suggested_next_appointment)`,
    [
      patientId,
      doctorId,
      problemDescription ?? null,
      adviceNotes ?? null,
      suggestedNextAppointment ?? null,
    ]
  );
}

async function syncAdviceNotesToTreatment(doctorId, patientId) {
  const [rows] = await db.query(
    "SELECT advice_text FROM doctor_patient_advice WHERE doctor_id = ? AND patient_id = ? ORDER BY id ASC",
    [doctorId, patientId]
  );
  const notes = rows.map((r) => String(r.advice_text || "").trim()).filter(Boolean).join("\n");
  await upsertPatientTreatment({
    doctorId,
    patientId,
    adviceNotes: notes,
  });
}

async function getDoctorPatients(req, res) {
  const doctorId = Number(req.params.doctorId);
  const appointmentType = String(req.query.appointment_type || "").toLowerCase();

  if (!Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "Invalid doctor id" });
  }

  const where = ["a.doctor_id = ?", "a.status IN ('APPROVED', 'COMPLETED')"];
  const params = [doctorId];
  if (appointmentType === "clinic") {
    where.push("a.visit_type = 'CLINIC'");
  } else if (appointmentType === "home_visit") {
    where.push("a.visit_type = 'HOME'");
  }

  try {
    const [rows] = await db.query(
      `SELECT
         p.patient_id,
         p.name,
         p.age,
         p.email,
         p.state,
         p.city,
         p.address,
         p.profile_image,
         a.visit_type AS appointment_type,
         a.appointment_date AS last_appointment_date
       FROM appointments a
       JOIN patients p ON p.patient_id = a.patient_id
       WHERE ${where.join(" AND ")}
         AND a.appointment_id = (
           SELECT MAX(a2.appointment_id)
           FROM appointments a2
           WHERE a2.doctor_id = a.doctor_id
             AND a2.patient_id = a.patient_id
             AND a2.visit_type = a.visit_type
         )
       ORDER BY a.appointment_id DESC`,
      params
    );
    return res.json(rows);
  } catch (err) {
    console.error("getDoctorPatients error:", err);
    return res.status(500).json({ message: "Failed to fetch patients" });
  }
}

async function getDoctorPatientDetail(req, res) {
  const doctorId = Number(req.params.doctorId);
  const patientId = Number(req.params.patientId);

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) {
      return res.status(403).json({ message: "Access denied for this patient" });
    }

    const [patientRows] = await db.query(
      "SELECT patient_id, name, email, age, state, city, address, profile_image FROM patients WHERE patient_id = ? LIMIT 1",
      [patientId]
    );
    if (patientRows.length === 0) {
      return res.status(404).json({ message: "Patient not found" });
    }

    const [noteRows] = await db.query(
      "SELECT id, problem_description, created_at, updated_at FROM doctor_patient_notes WHERE doctor_id = ? AND patient_id = ? LIMIT 1",
      [doctorId, patientId]
    );
    const [treatmentRows] = await db.query(
      "SELECT id, problem_description, advice_notes, suggested_next_appointment, updated_at FROM patient_treatment WHERE doctor_id = ? AND patient_id = ? LIMIT 1",
      [doctorId, patientId]
    );
    const [mediaRows] = await db.query(
      "SELECT id, file_path, file_type, created_at FROM doctor_patient_media WHERE doctor_id = ? AND patient_id = ? ORDER BY id DESC",
      [doctorId, patientId]
    );
    const [exerciseRows] = await db.query(
      "SELECT id, exercise_name, created_at FROM doctor_patient_exercises WHERE doctor_id = ? AND patient_id = ? ORDER BY id DESC",
      [doctorId, patientId]
    );
    const [adviceRows] = await db.query(
      "SELECT id, advice_text, created_at FROM doctor_patient_advice WHERE doctor_id = ? AND patient_id = ? ORDER BY id DESC",
      [doctorId, patientId]
    );

    return res.json({
      patient: patientRows[0],
      note: noteRows[0] || null,
      treatment: treatmentRows[0] || null,
      media: mediaRows,
      exercises: exerciseRows,
      advice: adviceRows,
    });
  } catch (err) {
    console.error("getDoctorPatientDetail error:", err);
    return res.status(500).json({ message: "Failed to fetch patient detail" });
  }
}

async function getDoctorPatientCompletedDays(req, res) {
  const doctorId = Number(req.params.doctorId);
  const patientId = Number(req.params.patientId);
  const month = Number(req.query.month);
  const year = Number(req.query.year);

  if (
    !Number.isInteger(doctorId) ||
    doctorId <= 0 ||
    !Number.isInteger(patientId) ||
    patientId <= 0
  ) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!Number.isInteger(month) || month < 1 || month > 12) {
    return res.status(400).json({ message: "Valid month is required" });
  }
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    return res.status(400).json({ message: "Valid year is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) {
      return res.status(403).json({ message: "Access denied for this patient" });
    }

    const [rows] = await db.query(
      `SELECT DATE_FORMAT(COALESCE(completed_at, date), '%Y-%m-%d') AS completed_day
       FROM patient_daily_exercise_log
       WHERE patient_id = ?
         AND completed = 1
         AND MONTH(COALESCE(completed_at, date)) = ?
         AND YEAR(COALESCE(completed_at, date)) = ?
       ORDER BY COALESCE(completed_at, date) DESC`,
      [patientId, month, year]
    );

    return res.json(
      rows.map((row) => formatDateOnly(row.completed_day)).filter(Boolean)
    );
  } catch (err) {
    console.error("getDoctorPatientCompletedDays error:", err);
    return res.status(500).json({ message: "Failed to fetch completed days" });
  }
}

async function createProblem(req, res) {
  const doctorId = Number(req.body.doctor_id);
  const patientId = Number(req.body.patient_id);
  const problemDescription = String(req.body.problem_description || "").trim();
  const suggestedNextAppointmentRaw = String(
    req.body.suggested_next_appointment || ""
  ).trim();
  const suggestedNextAppointment = suggestedNextAppointmentRaw || null;

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!problemDescription) {
    return res.status(400).json({ message: "problem_description is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) return res.status(403).json({ message: "Access denied for this patient" });

    await db.query(
      `INSERT INTO doctor_patient_notes (doctor_id, patient_id, problem_description)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE
         problem_description = VALUES(problem_description),
         updated_at = CURRENT_TIMESTAMP`,
      [doctorId, patientId, problemDescription]
    );
    await upsertPatientTreatment({
      doctorId,
      patientId,
      problemDescription,
      suggestedNextAppointment,
    });
    return res.status(201).json({ message: "Problem description saved" });
  } catch (err) {
    console.error("createProblem error:", err);
    return res.status(500).json({ message: "Failed to save problem description" });
  }
}

async function updateProblem(req, res) {
  const doctorId = Number(req.body.doctor_id);
  const patientId = Number(req.body.patient_id);
  const problemDescription = String(req.body.problem_description || "").trim();
  const suggestedNextAppointmentRaw = String(
    req.body.suggested_next_appointment || ""
  ).trim();
  const suggestedNextAppointment = suggestedNextAppointmentRaw || null;

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!problemDescription) {
    return res.status(400).json({ message: "problem_description is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) return res.status(403).json({ message: "Access denied for this patient" });

    await db.query(
      `INSERT INTO doctor_patient_notes (doctor_id, patient_id, problem_description)
       VALUES (?, ?, ?)
       ON DUPLICATE KEY UPDATE
         problem_description = VALUES(problem_description),
         updated_at = CURRENT_TIMESTAMP`,
      [doctorId, patientId, problemDescription]
    );
    await upsertPatientTreatment({
      doctorId,
      patientId,
      problemDescription,
      suggestedNextAppointment,
    });
    return res.json({ message: "Problem description updated" });
  } catch (err) {
    console.error("updateProblem error:", err);
    return res.status(500).json({ message: "Failed to update problem description" });
  }
}

async function createMedia(req, res) {
  const doctorId = Number(req.body.doctor_id);
  const patientId = Number(req.body.patient_id);

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!req.file) {
    return res.status(400).json({ message: "File is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) return res.status(403).json({ message: "Access denied for this patient" });

    const filePath = `/uploads/${req.file.filename}`;
    const ext = (req.file.originalname.split(".").pop() || "").toLowerCase();
    const fileType = ["png", "jpg", "jpeg", "gif", "webp"].includes(ext)
      ? "image"
      : ext === "pdf"
        ? "pdf"
        : ext === "docx"
          ? "docx"
          : "file";

    const [result] = await db.query(
      `INSERT INTO doctor_patient_media (doctor_id, patient_id, file_path, file_type)
       VALUES (?, ?, ?, ?)`,
      [doctorId, patientId, filePath, fileType]
    );

    return res.status(201).json({
      id: result.insertId,
      file_path: filePath,
      file_type: fileType,
    });
  } catch (err) {
    console.error("createMedia error:", err);
    return res.status(500).json({ message: "Failed to upload media" });
  }
}

async function deleteMedia(req, res) {
  const id = Number(req.params.id);
  const doctorId = Number(req.query.doctor_id);

  if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "Invalid id" });
  }

  try {
    const [result] = await db.query(
      "DELETE FROM doctor_patient_media WHERE id = ? AND doctor_id = ?",
      [id, doctorId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Media not found" });
    }
    return res.json({ message: "Media deleted" });
  } catch (err) {
    console.error("deleteMedia error:", err);
    return res.status(500).json({ message: "Failed to delete media" });
  }
}

async function createExercise(req, res) {
  const doctorId = Number(req.body.doctor_id);
  const patientId = Number(req.body.patient_id);
  const exerciseName = String(req.body.exercise_name || "").trim();

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!exerciseName) {
    return res.status(400).json({ message: "exercise_name is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) return res.status(403).json({ message: "Access denied for this patient" });

    const [result] = await db.query(
      "INSERT INTO doctor_patient_exercises (doctor_id, patient_id, exercise_name) VALUES (?, ?, ?)",
      [doctorId, patientId, exerciseName]
    );
    await db.query(
      "INSERT INTO patient_exercises (patient_id, doctor_id, exercise_name, completed_flag) VALUES (?, ?, ?, 0)",
      [patientId, doctorId, exerciseName]
    );
    return res.status(201).json({ id: result.insertId, exercise_name: exerciseName });
  } catch (err) {
    console.error("createExercise error:", err);
    return res.status(500).json({ message: "Failed to add exercise" });
  }
}

async function deleteExercise(req, res) {
  const id = Number(req.params.id);
  const doctorId = Number(req.query.doctor_id);

  if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "Invalid id" });
  }

  try {
    const [existingRows] = await db.query(
      "SELECT patient_id, exercise_name FROM doctor_patient_exercises WHERE id = ? AND doctor_id = ? LIMIT 1",
      [id, doctorId]
    );
    if (existingRows.length === 0) {
      return res.status(404).json({ message: "Exercise not found" });
    }

    const [result] = await db.query(
      "DELETE FROM doctor_patient_exercises WHERE id = ? AND doctor_id = ?",
      [id, doctorId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Exercise not found" });
    }
    await db.query(
      `DELETE FROM patient_exercises
       WHERE doctor_id = ? AND patient_id = ? AND exercise_name = ?
       ORDER BY id DESC
       LIMIT 1`,
      [doctorId, existingRows[0].patient_id, existingRows[0].exercise_name]
    );
    return res.json({ message: "Exercise deleted" });
  } catch (err) {
    console.error("deleteExercise error:", err);
    return res.status(500).json({ message: "Failed to delete exercise" });
  }
}

async function createAdvice(req, res) {
  const doctorId = Number(req.body.doctor_id);
  const patientId = Number(req.body.patient_id);
  const adviceText = String(req.body.advice_text || "").trim();

  if (!Number.isInteger(doctorId) || doctorId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid doctor or patient id" });
  }
  if (!adviceText) {
    return res.status(400).json({ message: "advice_text is required" });
  }

  try {
    const hasAccess = await hasDoctorPatientAccess(doctorId, patientId);
    if (!hasAccess) return res.status(403).json({ message: "Access denied for this patient" });

    const [result] = await db.query(
      "INSERT INTO doctor_patient_advice (doctor_id, patient_id, advice_text) VALUES (?, ?, ?)",
      [doctorId, patientId, adviceText]
    );
    await syncAdviceNotesToTreatment(doctorId, patientId);
    return res.status(201).json({ id: result.insertId, advice_text: adviceText });
  } catch (err) {
    console.error("createAdvice error:", err);
    return res.status(500).json({ message: "Failed to add advice" });
  }
}

async function deleteAdvice(req, res) {
  const id = Number(req.params.id);
  const doctorId = Number(req.query.doctor_id);

  if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "Invalid id" });
  }

  try {
    const [existingRows] = await db.query(
      "SELECT patient_id FROM doctor_patient_advice WHERE id = ? AND doctor_id = ? LIMIT 1",
      [id, doctorId]
    );
    if (existingRows.length === 0) {
      return res.status(404).json({ message: "Advice not found" });
    }

    const [result] = await db.query(
      "DELETE FROM doctor_patient_advice WHERE id = ? AND doctor_id = ?",
      [id, doctorId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Advice not found" });
    }
    await syncAdviceNotesToTreatment(doctorId, existingRows[0].patient_id);
    return res.json({ message: "Advice deleted" });
  } catch (err) {
    console.error("deleteAdvice error:", err);
    return res.status(500).json({ message: "Failed to delete advice" });
  }
}

module.exports = {
  getDoctorPatients,
  getDoctorPatientDetail,
  getDoctorPatientCompletedDays,
  createProblem,
  updateProblem,
  createMedia,
  deleteMedia,
  createExercise,
  deleteExercise,
  createAdvice,
  deleteAdvice,
};
