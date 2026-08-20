const db = require("../db");
const { getDoctorColumnSet } = require("../services/pricingService");

async function createVerificationRequest(req, res) {
  const {
    doctor_id,
    full_name,
    date_of_birth,
    qualification,
    university_name,
    year_of_graduation,
    years_of_experience,
    specialization,
    license_number,
    license_issuing_authority,
    license_expiry_date,
    clinic_name,
    clinic_address,
    city,
    area,
    pincode,
    clinic_contact_number,
    consultation_fee,
    home_visit_available,
    latitude,
    longitude,
    license_certificate_url,
    degree_certificate_url,
  } = req.body;

  if (
    !doctor_id ||
    !full_name ||
    !date_of_birth ||
    !qualification ||
    !university_name ||
    !year_of_graduation ||
    !years_of_experience ||
    !specialization ||
    !license_number ||
    !license_issuing_authority ||
    !license_expiry_date ||
    !clinic_name ||
    !clinic_address ||
    !city ||
    !area ||
    !pincode ||
    !clinic_contact_number ||
    consultation_fee === undefined ||
    latitude === undefined ||
    longitude === undefined
  ) {
    return res.status(400).json({ message: "Missing required fields" });
  }

  try {
    const [doctorRows] = await db.query(
      "SELECT verification_status FROM doctors WHERE doctor_id = ? LIMIT 1",
      [doctor_id]
    );
    if (doctorRows.length === 0) {
      return res.status(404).json({ message: "Doctor not found" });
    }

    const verificationStatus = String(
      doctorRows[0].verification_status || "not_applied"
    ).toLowerCase();
    if (verificationStatus === "approved") {
      return res.status(409).json({
        message: "You are already a verified physiotherapist",
      });
    }
    if (verificationStatus === "pending") {
      return res.status(409).json({
        message: "Your verification request is under review",
      });
    }

    const [result] = await db.query(
      `INSERT INTO doctor_verification_requests
      (doctor_id, full_name, date_of_birth, qualification, university_name,
       year_of_graduation, years_of_experience, specialization, license_number,
       license_issuing_authority, license_expiry_date, clinic_name, clinic_address,
       city, area, pincode, clinic_contact_number, consultation_fee,
       home_visit_available, latitude, longitude, license_certificate_url,
       degree_certificate_url, status)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'PENDING')`,
      [
        doctor_id,
        full_name,
        date_of_birth,
        qualification,
        university_name,
        year_of_graduation,
        years_of_experience,
        specialization,
        license_number,
        license_issuing_authority,
        license_expiry_date,
        clinic_name,
        clinic_address,
        city,
        area,
        pincode,
        clinic_contact_number,
        consultation_fee,
        home_visit_available ? 1 : 0,
        latitude,
        longitude,
        license_certificate_url || null,
        degree_certificate_url || null,
      ]
    );

    await db.query(
      "UPDATE doctors SET verification_status = 'pending', approval_status = 'PENDING', is_verified = 0 WHERE doctor_id = ?",
      [doctor_id]
    );

    res.status(201).json({ request_id: result.insertId, status: "PENDING" });
  } catch (err) {
    console.error("createVerificationRequest error:", err);
    res.status(500).json({ message: "Failed to submit verification request" });
  }
}

async function getVerificationRequests(req, res) {
  const status = req.query.status;
  const hasStatus = status && ["PENDING", "APPROVED", "REJECTED"].includes(status);
  const sql = hasStatus
    ? `SELECT vr.*
       FROM doctor_verification_requests vr
       JOIN doctors d ON d.doctor_id = vr.doctor_id
       WHERE vr.status = ?
         AND (
           (? = 'PENDING' AND d.verification_status = 'pending') OR
           (? = 'APPROVED' AND d.verification_status = 'approved') OR
           (? = 'REJECTED' AND d.verification_status = 'rejected')
         )
       ORDER BY vr.submitted_at DESC`
    : `SELECT vr.*
       FROM doctor_verification_requests vr
       ORDER BY vr.submitted_at DESC`;

  try {
    const [rows] = hasStatus
      ? await db.query(sql, [status, status, status, status])
      : await db.query(sql);
    res.json(rows);
  } catch (err) {
    console.error("getVerificationRequests error:", err);
    res.status(500).json({ message: "Failed to fetch verification requests" });
  }
}

async function getVerificationRequestById(req, res) {
  const requestId = req.params.id;
  try {
    const [rows] = await db.query(
      `SELECT
         vr.*,
         d.email AS doctor_email,
         d.phone AS doctor_phone,
         d.profile_image_url AS doctor_profile_image_url
       FROM doctor_verification_requests vr
       JOIN doctors d ON d.doctor_id = vr.doctor_id
       WHERE vr.request_id = ?`,
      [requestId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    res.json(rows[0]);
  } catch (err) {
    console.error("getVerificationRequestById error:", err);
    res.status(500).json({ message: "Failed to fetch verification request" });
  }
}

async function approveVerificationRequest(req, res) {
  const requestId = req.params.id;

  try {
    const [rows] = await db.query(
      "SELECT doctor_id FROM doctor_verification_requests WHERE request_id = ?",
      [requestId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    const doctorId = rows[0].doctor_id;

    const [verificationRows] = await db.query(
      `SELECT full_name, date_of_birth, qualification, years_of_experience, clinic_name, latitude, longitude, consultation_fee
       FROM doctor_verification_requests
       WHERE request_id = ?`,
      [requestId]
    );

    await db.query(
      "UPDATE doctor_verification_requests SET status = 'APPROVED', rejection_reason = NULL WHERE request_id = ?",
      [requestId]
    );
    const approved = verificationRows[0];
    const age = new Date().getFullYear() - new Date(approved.date_of_birth).getFullYear();

    const doctorColumns = await getDoctorColumnSet();
    const updateFields = [
      "is_verified = 1",
      "approval_status = 'APPROVED'",
      "verification_status = 'approved'",
      "name = ?",
      "age = ?",
      "qualification = ?",
      "years_of_experience = ?",
      "clinic_name = ?",
      "latitude = ?",
      "longitude = ?",
    ];
    const params = [
      approved.full_name,
      age > 0 ? age : 0,
      approved.qualification,
      approved.years_of_experience,
      approved.clinic_name,
      approved.latitude,
      approved.longitude,
    ];

    if (doctorColumns.has("clinic_fee")) {
      updateFields.push("clinic_fee = ?");
      params.push(approved.consultation_fee);
    }
    if (doctorColumns.has("home_visit_base_fee")) {
      updateFields.push("home_visit_base_fee = ?");
      params.push(approved.consultation_fee);
    }

    params.push(doctorId);

    await db.query(
      `UPDATE doctors
       SET ${updateFields.join(", ")}
       WHERE doctor_id = ?`,
      params
    );
    await db.query(
      "UPDATE doctors SET is_removed = 0, removed_reason = NULL, removed_at = NULL WHERE doctor_id = ?",
      [doctorId]
    );

    res.json({ message: "Verification request approved" });
  } catch (err) {
    console.error("approveVerificationRequest error:", err);
    res.status(500).json({ message: "Failed to approve verification request" });
  }
}

async function rejectVerificationRequest(req, res) {
  const requestId = req.params.id;
  const { rejection_reason } = req.body;

  if (!rejection_reason || !rejection_reason.trim()) {
    return res.status(400).json({ message: "rejection_reason is required" });
  }

  try {
    const [result] = await db.query(
      "UPDATE doctor_verification_requests SET status = 'REJECTED', rejection_reason = ? WHERE request_id = ?",
      [rejection_reason.trim(), requestId]
    );

    if (result.affectedRows > 0) {
      const [doctorRows] = await db.query(
        "SELECT doctor_id FROM doctor_verification_requests WHERE request_id = ?",
        [requestId]
      );
      if (doctorRows.length > 0) {
        await db.query(
          "UPDATE doctors SET approval_status = 'REJECTED', verification_status = 'rejected', is_verified = 0 WHERE doctor_id = ?",
          [doctorRows[0].doctor_id]
        );
      }
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Request not found" });
    }

    res.json({ message: "Verification request rejected" });
  } catch (err) {
    console.error("rejectVerificationRequest error:", err);
    res.status(500).json({ message: "Failed to reject verification request" });
  }
}



async function uploadVerificationDocument(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No file uploaded" });
    }

    return res.status(201).json({
      file_url: `/uploads/verification_docs/${req.file.filename}`,
      file_name: req.file.originalname,
    });
  } catch (err) {
    console.error("uploadVerificationDocument error:", err);
    return res
      .status(500)
      .json({ message: "Failed to upload verification document" });
  }
}

module.exports = {
  createVerificationRequest,
  getVerificationRequests,
  getVerificationRequestById,
  approveVerificationRequest,
  rejectVerificationRequest,
  uploadVerificationDocument,
};
