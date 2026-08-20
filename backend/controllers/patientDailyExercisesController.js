const db = require("../db");

function todayDateString() {
  const now = new Date();
  const y = now.getFullYear();
  const m = String(now.getMonth() + 1).padStart(2, "0");
  const d = String(now.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function normalizeDateInput(value) {
  const raw = String(value || "").trim();
  const match = raw.match(/^(\d{4}-\d{2}-\d{2})/);
  return match ? match[1] : todayDateString();
}

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

async function resolvePatientFromToken(req) {
  const firebaseUid = req.user?.firebase_uid;
  if (!firebaseUid) return null;

  const [rows] = await db.query(
    `SELECT p.patient_id, u.id AS user_id
     FROM users u
     JOIN patients p ON p.user_id = u.id
     WHERE u.firebase_uid = ?
     LIMIT 1`,
    [firebaseUid]
  );
  if (rows.length === 0) return null;
  return rows[0];
}

async function getTodayExercises(req, res) {
  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const date = todayDateString();
    const [exerciseRows] = await db.query(
      `SELECT
         pea.exercise_id,
         pea.patient_id,
         pea.doctor_id,
         em.name,
         em.description,
         em.demo_media_url,
         em.exercise_type,
         em.recommended_reps,
         em.rep_count,
         em.default_duration_seconds,
         pea.custom_duration_seconds,
         COALESCE(pea.custom_duration_seconds, em.default_duration_seconds) AS duration_seconds,
         COALESCE(item.completed, 0) AS completed
       FROM patient_exercise_assignments pea
       JOIN exercise_master em ON em.id = pea.exercise_id
       LEFT JOIN patient_daily_exercise_item_log item
         ON item.patient_id = pea.patient_id
        AND item.exercise_id = pea.exercise_id
        AND item.date = ?
       WHERE pea.patient_id = ?
         AND pea.is_active = 1
       ORDER BY pea.id ASC`,
      [date, patient.patient_id]
    );

    const [logRows] = await db.query(
      `SELECT id, completed, total_exercises, completed_exercises, completed_at
       FROM patient_daily_exercise_log
       WHERE patient_id = ? AND date = ?
       LIMIT 1`,
      [patient.patient_id, date]
    );

    return res.json({
      date,
      log: logRows[0] || null,
      exercises: exerciseRows,
    });
  } catch (err) {
    console.error("getTodayExercises error:", err);
    return res.status(500).json({ message: "Failed to fetch today's exercises" });
  }
}

async function startDay(req, res) {
  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const date = todayDateString();
    const [existingRows] = await db.query(
      `SELECT completed
       FROM patient_daily_exercise_log
       WHERE patient_id = ? AND date = ?
       LIMIT 1`,
      [patient.patient_id, date]
    );
    if (existingRows.length > 0 && Number(existingRows[0].completed) === 1) {
      return res.status(400).json({
        message: "Today's exercises already completed.",
      });
    }

    const [assignedRows] = await db.query(
      `SELECT exercise_id
       FROM patient_exercise_assignments
       WHERE patient_id = ? AND is_active = 1`,
      [patient.patient_id]
    );

    const totalExercises = assignedRows.length;
    await db.query(
      `INSERT INTO patient_daily_exercise_log
        (patient_id, date, completed, total_exercises, completed_exercises)
       VALUES (?, ?, 0, ?, 0)
       ON DUPLICATE KEY UPDATE
         total_exercises = VALUES(total_exercises)`,
      [patient.patient_id, date, totalExercises]
    );

    for (const row of assignedRows) {
      await db.query(
        `INSERT INTO patient_daily_exercise_item_log
          (patient_id, date, exercise_id, completed)
         VALUES (?, ?, ?, 0)
         ON DUPLICATE KEY UPDATE exercise_id = exercise_id`,
        [patient.patient_id, date, row.exercise_id]
      );
    }

    return res.status(201).json({
      message: "Day started",
      date,
      total_exercises: totalExercises,
    });
  } catch (err) {
    console.error("startDay error:", err);
    return res.status(500).json({ message: "Failed to start exercise day" });
  }
}

async function completeOne(req, res) {
  const exerciseId = Number(req.body.exercise_id);
  const date = normalizeDateInput(req.body.date);

  if (!Number.isInteger(exerciseId) || exerciseId <= 0) {
    return res.status(400).json({ message: "exercise_id is required" });
  }

  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    // Accept exercise completion from either:
    // 1) patient_exercise_assignments (new flow), or
    // 2) patient_exercises mapped to exercise_master (legacy/current flow).
    const [assignmentRows] = await db.query(
      `SELECT id
       FROM patient_exercise_assignments
       WHERE patient_id = ? AND exercise_id = ? AND is_active = 1
       LIMIT 1`,
      [patient.patient_id, exerciseId]
    );

    let isValidForPatient = assignmentRows.length > 0;
    if (!isValidForPatient) {
      const [legacyRows] = await db.query(
        `SELECT pe.id
         FROM patient_exercises pe
         JOIN exercise_master em
           ON LOWER(TRIM(em.name)) = LOWER(TRIM(pe.exercise_name))
         WHERE pe.patient_id = ?
           AND em.id = ?
         LIMIT 1`,
        [patient.patient_id, exerciseId]
      );
      isValidForPatient = legacyRows.length > 0;
    }

    if (!isValidForPatient) {
      return res.status(400).json({
        message: "Exercise is not assigned for patient",
      });
    }

    await db.query(
      `INSERT INTO patient_daily_exercise_item_log
        (patient_id, date, exercise_id, completed, completed_at)
       VALUES (?, ?, ?, 1, NOW())
       ON DUPLICATE KEY UPDATE
         completed = 1,
         completed_at = COALESCE(completed_at, NOW())`,
      [patient.patient_id, date, exerciseId]
    );

    const [[countRow]] = await db.query(
      `SELECT
         COUNT(*) AS total,
         SUM(CASE WHEN completed = 1 THEN 1 ELSE 0 END) AS done_count
       FROM patient_daily_exercise_item_log
       WHERE patient_id = ? AND date = ?`,
      [patient.patient_id, date]
    );

    const total = Number(countRow.total || 0);
    const done = Number(countRow.done_count || 0);
    await db.query(
      `INSERT INTO patient_daily_exercise_log
        (patient_id, date, completed, total_exercises, completed_exercises)
       VALUES (?, ?, 0, ?, ?)
       ON DUPLICATE KEY UPDATE
         total_exercises = VALUES(total_exercises),
         completed_exercises = VALUES(completed_exercises)`,
      [patient.patient_id, date, total, done]
    );

    return res.json({
      message: "Exercise marked complete",
      total_exercises: total,
      completed_exercises: done,
    });
  } catch (err) {
    console.error("completeOne error:", err);
    return res.status(500).json({ message: "Failed to mark exercise complete" });
  }
}

async function completeDay(req, res) {
  const date = normalizeDateInput(req.body.date);

  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT id, total_exercises, completed_exercises
       FROM patient_daily_exercise_log
       WHERE patient_id = ? AND date = ?
       LIMIT 1`,
      [patient.patient_id, date]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Day log not found. Start day first." });
    }

    const row = rows[0];
    if (row.total_exercises <= 0) {
      return res.status(400).json({ message: "No assigned exercises for today" });
    }
    if (row.completed_exercises < row.total_exercises) {
      return res.status(400).json({
        message: "Complete all exercises before marking day complete",
      });
    }

    await db.query(
      `UPDATE patient_daily_exercise_log
       SET completed = 1,
           completed_at = NOW()
       WHERE id = ?`,
      [row.id]
    );
    return res.json({ message: "Day completed successfully" });
  } catch (err) {
    console.error("completeDay error:", err);
    return res.status(500).json({ message: "Failed to complete day" });
  }
}

async function getExerciseCalendar(req, res) {
  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT DATE_FORMAT(COALESCE(completed_at, date), '%Y-%m-%d') AS completed_day
       FROM patient_daily_exercise_log
       WHERE patient_id = ? AND completed = 1
       ORDER BY COALESCE(completed_at, date) DESC`,
      [patient.patient_id]
    );
    return res.json(
      rows.map((r) => formatDateOnly(r.completed_day)).filter(Boolean)
    );
  } catch (err) {
    console.error("getExerciseCalendar error:", err);
    return res.status(500).json({ message: "Failed to fetch calendar" });
  }
}



async function getCompletedDaysByMonth(req, res) {
  const month = Number(req.query.month);
  const year = Number(req.query.year);

  if (!Number.isInteger(month) || month < 1 || month > 12) {
    return res.status(400).json({ message: "Valid month is required" });
  }
  if (!Number.isInteger(year) || year < 2000 || year > 2100) {
    return res.status(400).json({ message: "Valid year is required" });
  }

  try {
    const patient = await resolvePatientFromToken(req);
    if (!patient) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT DATE_FORMAT(COALESCE(completed_at, date), '%Y-%m-%d') AS completed_day
       FROM patient_daily_exercise_log
       WHERE patient_id = ?
         AND completed = 1
         AND MONTH(COALESCE(completed_at, date)) = ?
         AND YEAR(COALESCE(completed_at, date)) = ?
       ORDER BY COALESCE(completed_at, date) DESC`,
      [patient.patient_id, month, year]
    );

    return res.json(
      rows.map((r) => formatDateOnly(r.completed_day)).filter(Boolean)
    );
  } catch (err) {
    console.error("getCompletedDaysByMonth error:", err);
    return res.status(500).json({ message: "Failed to fetch completed days" });
  }
}

module.exports = {
  getTodayExercises,
  startDay,
  completeOne,
  completeDay,
  getExerciseCalendar,
  getCompletedDaysByMonth,
};
