const db = require("../db");

async function getExerciseMasterColumnSet() {
  const [rows] = await db.query(
    `SELECT column_name
     FROM information_schema.columns
     WHERE table_schema = DATABASE()
       AND table_name = 'exercise_master'`
  );
  return new Set(
    rows.map((r) => String(r.column_name ?? r.COLUMN_NAME ?? "").toLowerCase())
  );
}

function pickColumn(columns, candidates, alias, fallbackSql) {
  for (const candidate of candidates) {
    if (columns.has(candidate.toLowerCase())) {
      return `${candidate} AS ${alias}`;
    }
  }
  return `${fallbackSql} AS ${alias}`;
}

function buildExerciseMasterSelect(columns) {
  return [
    pickColumn(columns, ["id", "exercise_id"], "id", "NULL"),
    pickColumn(columns, ["name", "exercise_name"], "name", "''"),
    pickColumn(columns, ["description", "notes"], "description", "''"),
    pickColumn(columns, ["demo_media_url", "media_url"], "demo_media_url", "NULL"),
    pickColumn(columns, ["exercise_type"], "exercise_type", "'time'"),
    pickColumn(columns, ["recommended_reps"], "recommended_reps", "NULL"),
    pickColumn(columns, ["rep_count"], "rep_count", "NULL"),
    pickColumn(
      columns,
      ["default_duration_seconds", "duration_seconds"],
      "default_duration_seconds",
      "NULL"
    ),
  ].join(",\n         ");
}

async function getExercises(req, res) {
  const patientId = req.query.patient_id;
  const doctorId = req.query.doctor_id;

  const clauses = [];
  const params = [];

  if (patientId) {
    clauses.push("e.patient_id = ?");
    params.push(patientId);
  }
  if (doctorId) {
    clauses.push("e.doctor_id = ?");
    params.push(doctorId);
  }

  const where = clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";

  try {
    const [rows] = await db.query(
      `SELECT
         e.exercise_id,
         e.patient_id,
         e.doctor_id,
         e.exercise_name,
         e.status,
         e.notes
       FROM exercises e
       ${where}
       ORDER BY e.exercise_id DESC`,
      params
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch exercises" });
  }
}

async function getExerciseLibrary(_req, res) {
  try {
    const columns = await getExerciseMasterColumnSet();
    const selectClause = buildExerciseMasterSelect(columns);
    const [rows] = await db.query(
      `SELECT
         ${selectClause}
       FROM exercise_master
       ORDER BY name ASC`
    );
    return res.json(rows);
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch exercise library" });
  }
}

async function getExerciseLibraryById(req, res) {
  const id = Number(req.params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return res.status(400).json({ message: "Invalid exercise id" });
  }

  try {
    const columns = await getExerciseMasterColumnSet();
    const selectClause = buildExerciseMasterSelect(columns);
    const [rows] = await db.query(
      `SELECT
         ${selectClause}
       FROM exercise_master
       WHERE id = ?
       LIMIT 1`,
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Exercise not found" });
    }
    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ message: "Failed to fetch exercise details" });
  }
}

module.exports = { getExercises, getExerciseLibrary, getExerciseLibraryById };
