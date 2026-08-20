const db = require("../db");

async function getPatientTreatment(req, res) {
  const patientId = Number(req.params.patientId);
  if (!Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid patient id" });
  }

  try {
    const [rows] = await db.query(
      `SELECT
         pt.id,
         pt.patient_id,
         pt.doctor_id,
         pt.problem_description,
         pt.advice_notes,
         pt.suggested_next_appointment,
         pt.updated_at,
         d.name AS doctor_name
       FROM patient_treatment pt
       JOIN doctors d ON d.doctor_id = pt.doctor_id
       WHERE pt.patient_id = ?
       ORDER BY pt.updated_at DESC
       LIMIT 1`,
      [patientId]
    );

    const [visitRows] = await db.query(
      `SELECT appointment_date
       FROM appointments
       WHERE patient_id = ? AND status = 'COMPLETED'
       ORDER BY appointment_id DESC
       LIMIT 1`,
      [patientId]
    );

    if (rows.length === 0) {
      return res.json({
        id: null,
        patient_id: patientId,
        doctor_id: null,
        doctor_name: "",
        problem_description: "",
        advice_notes: "",
        suggested_next_appointment: null,
        updated_at: null,
        last_visit_date: visitRows[0]?.appointment_date || null,
      });
    }

    return res.json({
      ...rows[0],
      last_visit_date: visitRows[0]?.appointment_date || null,
    });
  } catch (err) {
    console.error("getPatientTreatment error:", err);
    return res.status(500).json({ message: "Failed to fetch treatment" });
  }
}

async function getPatientExercises(req, res) {
  const patientId = Number(req.params.patientId);
  if (!Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid patient id" });
  }

  try {
    const [rows] = await db.query(
      `SELECT
         pe.id,
         pe.patient_id,
         pe.doctor_id,
         pe.exercise_name,
         pe.completed_flag,
         pe.created_at,
         em.id AS master_exercise_id,
         COALESCE(em.description, '') AS description,
         COALESCE(em.demo_media_url, '') AS demo_media_url,
         COALESCE(em.exercise_type, 'time') AS exercise_type,
         em.recommended_reps,
         em.rep_count,
         em.default_duration_seconds
       FROM patient_exercises pe
       LEFT JOIN exercise_master em
         ON LOWER(TRIM(em.name)) = LOWER(TRIM(pe.exercise_name))
       WHERE pe.patient_id = ?
       ORDER BY pe.id DESC`,
      [patientId]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getPatientExercises error:", err);
    return res.status(500).json({ message: "Failed to fetch exercises" });
  }
}

async function markExerciseDone(req, res) {
  const id = Number(req.body.id);
  const patientId = Number(req.body.patient_id);
  const completedFlag = Number(req.body.completed_flag) === 1 ? 1 : 0;

  if (!Number.isInteger(id) || id <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid id or patient id" });
  }

  try {
    const [result] = await db.query(
      "UPDATE patient_exercises SET completed_flag = ? WHERE id = ? AND patient_id = ?",
      [completedFlag, id, patientId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Exercise not found" });
    }
    return res.json({ message: "Exercise progress updated" });
  } catch (err) {
    console.error("markExerciseDone error:", err);
    return res.status(500).json({ message: "Failed to update exercise progress" });
  }
}

module.exports = {
  getPatientTreatment,
  getPatientExercises,
  markExerciseDone,
};
