const db = require("../db");

async function resolveUser(firebaseUid) {
  const [rows] = await db.query(
    "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
    [firebaseUid]
  );
  if (rows.length === 0) return null;
  return {
    userId: rows[0].id,
    role: String(rows[0].role || "").toUpperCase(),
  };
}

async function getDiscussions(_req, res) {
  try {
    const [questionRows] = await db.query(
      `SELECT
         q.id,
         q.patient_id,
         q.question_text,
         q.created_at,
         p.name AS patient_name
       FROM discussion_questions q
       JOIN patients p ON p.patient_id = q.patient_id
       ORDER BY q.created_at DESC`
    );

    if (questionRows.length === 0) {
      return res.json([]);
    }

    const questionIds = questionRows.map((q) => q.id);
    const [answerRows] = await db.query(
      `SELECT
         a.id,
         a.question_id,
         a.doctor_id,
         a.answer_text,
         a.created_at,
         d.name AS doctor_name
       FROM discussion_answers a
       JOIN doctors d ON d.doctor_id = a.doctor_id
       WHERE a.question_id IN (?)
       ORDER BY a.created_at ASC`,
      [questionIds]
    );

    const answersMap = new Map();
    for (const answer of answerRows) {
      if (!answersMap.has(answer.question_id)) {
        answersMap.set(answer.question_id, []);
      }
      answersMap.get(answer.question_id).push(answer);
    }

    const result = questionRows.map((q) => ({
      ...q,
      answers: answersMap.get(q.id) || [],
    }));
    return res.json(result);
  } catch (err) {
    console.error("getDiscussions error:", err);
    return res.status(500).json({ message: "Failed to fetch discussions" });
  }
}

async function createQuestion(req, res) {
  const text = String(req.body.question_text || "").trim();
  if (!text) {
    return res.status(400).json({ message: "question_text is required" });
  }

  try {
    const user = await resolveUser(req.user?.firebase_uid);
    if (!user) return res.status(401).json({ message: "Unauthorized user" });

    const [patientRows] = await db.query(
      "SELECT patient_id FROM patients WHERE user_id = ? LIMIT 1",
      [user.userId]
    );
    if (patientRows.length === 0) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [result] = await db.query(
      "INSERT INTO discussion_questions (patient_id, question_text) VALUES (?, ?)",
      [patientRows[0].patient_id, text]
    );
    return res.status(201).json({ id: result.insertId });
  } catch (err) {
    console.error("createQuestion error:", err);
    return res.status(500).json({ message: "Failed to create question" });
  }
}

async function createAnswer(req, res) {
  const questionId = Number(req.params.id);
  const text = String(req.body.answer_text || "").trim();

  if (!Number.isInteger(questionId) || questionId <= 0) {
    return res.status(400).json({ message: "Invalid question id" });
  }
  if (!text) {
    return res.status(400).json({ message: "answer_text is required" });
  }

  try {
    const user = await resolveUser(req.user?.firebase_uid);
    if (!user) return res.status(401).json({ message: "Unauthorized user" });

    const [doctorRows] = await db.query(
      "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
      [user.userId]
    );
    if (doctorRows.length === 0) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [questionRows] = await db.query(
      "SELECT id FROM discussion_questions WHERE id = ? LIMIT 1",
      [questionId]
    );
    if (questionRows.length === 0) {
      return res.status(404).json({ message: "Question not found" });
    }

    const [result] = await db.query(
      "INSERT INTO discussion_answers (question_id, doctor_id, answer_text) VALUES (?, ?, ?)",
      [questionId, doctorRows[0].doctor_id, text]
    );
    return res.status(201).json({ id: result.insertId });
  } catch (err) {
    console.error("createAnswer error:", err);
    return res.status(500).json({ message: "Failed to submit answer" });
  }
}

module.exports = {
  getDiscussions,
  createQuestion,
  createAnswer,
};
