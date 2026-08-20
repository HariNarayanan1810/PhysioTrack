const db = require("../db");

async function getReviews(req, res) {
  const doctorId = Number(req.query.doctor_id);
  if (!Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "doctor_id is required" });
  }

  try {
    const [rows] = await db.query(
      `SELECT review_id, doctor_id, patient_id, patient_name, rating, review_text, created_at
       FROM reviews
       WHERE doctor_id = ?
       ORDER BY created_at DESC`,
      [doctorId]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getReviews error:", err);
    return res.status(500).json({ message: "Failed to fetch reviews" });
  }
}

async function createReview(req, res) {
  const { doctor_id, patient_id, patient_name, rating, review_text } = req.body;
  if (!doctor_id || !patient_name || !rating || !review_text) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const [result] = await db.query(
      `INSERT INTO reviews (doctor_id, patient_id, patient_name, rating, review_text)
       VALUES (?, ?, ?, ?, ?)`,
      [doctor_id, patient_id || null, patient_name, rating, review_text]
    );
    await db.query(
      `UPDATE doctors d
       SET d.rating = (
         SELECT COALESCE(ROUND(AVG(r.rating), 1), 0)
         FROM reviews r
         WHERE r.doctor_id = d.doctor_id
       )
       WHERE d.doctor_id = ?`,
      [doctor_id]
    );
    return res.status(201).json({ review_id: result.insertId });
  } catch (err) {
    console.error("createReview error:", err);
    return res.status(500).json({ message: "Failed to create review" });
  }
}

module.exports = { getReviews, createReview };
