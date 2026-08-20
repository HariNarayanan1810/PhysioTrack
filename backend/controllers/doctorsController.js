const db = require("../db");
const { getDoctorColumnSet, roundMoney, toNullableNumber } = require("../services/pricingService");

async function buildDoctorFeeSelects() {
  const columns = await getDoctorColumnSet();
  return {
    clinicFeeSql: columns.has("clinic_fee")
      ? "COALESCE(d.clinic_fee, vr.consultation_fee, 0) AS clinic_fee"
      : "COALESCE(vr.consultation_fee, 0) AS clinic_fee",
    homeVisitBaseFeeSql: columns.has("home_visit_base_fee")
      ? columns.has("clinic_fee")
        ? "COALESCE(d.home_visit_base_fee, d.clinic_fee, vr.consultation_fee, 0) AS home_visit_base_fee"
        : "COALESCE(d.home_visit_base_fee, vr.consultation_fee, 0) AS home_visit_base_fee"
      : columns.has("clinic_fee")
        ? "COALESCE(d.clinic_fee, vr.consultation_fee, 0) AS home_visit_base_fee"
        : "COALESCE(vr.consultation_fee, 0) AS home_visit_base_fee",
    perKmChargeSql: columns.has("per_km_charge")
      ? "d.per_km_charge AS per_km_charge"
      : "NULL AS per_km_charge",
    hasPricingColumns:
      columns.has("clinic_fee") ||
      columns.has("home_visit_base_fee") ||
      columns.has("per_km_charge"),
  };
}

async function getDoctors(req, res) {
  const verified = req.query.verified;
  const removed = req.query.removed;
  const userId = req.query.user_id;

  try {
    if (userId) {
      const [rows] = await db.query(
        `SELECT
           d.*,
           COALESCE((
             SELECT ROUND(AVG(r.rating), 1)
             FROM reviews r
             WHERE r.doctor_id = d.doctor_id
           ), d.rating, 0) AS rating
         FROM doctors d
         WHERE d.user_id = ?
         LIMIT 1`,
        [userId]
      );
      return res.json(rows);
    }

    if (removed === "true" || removed === "1") {
      const [rows] = await db.query(
        `SELECT
           d.*,
           COALESCE((
             SELECT ROUND(AVG(r.rating), 1)
             FROM reviews r
             WHERE r.doctor_id = d.doctor_id
           ), d.rating, 0) AS rating,
           COALESCE(vr.city, '') AS city
         FROM doctors d
         LEFT JOIN doctor_verification_requests vr
           ON vr.request_id = (
             SELECT v2.request_id
             FROM doctor_verification_requests v2
             WHERE v2.doctor_id = d.doctor_id
             ORDER BY v2.request_id DESC
             LIMIT 1
           )
         WHERE d.is_removed = 1`
      );
      return res.json(rows);
    }

    const verifiedOn = verified === "true" || verified === "1";
    const sql = verifiedOn
      ? `SELECT
           d.*,
           COALESCE((
             SELECT ROUND(AVG(r.rating), 1)
             FROM reviews r
             WHERE r.doctor_id = d.doctor_id
           ), d.rating, 0) AS rating
         FROM doctors d
         WHERE d.verification_status = 'approved' AND d.is_removed = 0`
      : `SELECT
           d.*,
           COALESCE((
             SELECT ROUND(AVG(r.rating), 1)
             FROM reviews r
             WHERE r.doctor_id = d.doctor_id
           ), d.rating, 0) AS rating
         FROM doctors d
         WHERE d.is_removed = 0`;
    const [rows] = await db.query(sql);
    return res.json(rows);
  } catch (err) {
    console.error("getDoctors error:", err);
    return res.status(500).json({ message: "Failed to fetch doctors" });
  }
}



async function getApprovedDoctors(_req, res) {
  try {
    const feeSelects = await buildDoctorFeeSelects();
    const [rows] = await db.query(
      `SELECT
         d.doctor_id,
         d.name,
         d.age,
         d.qualification,
         d.years_of_experience,
         d.clinic_name,
         COALESCE((
           SELECT ROUND(AVG(r.rating), 1)
           FROM reviews r
           WHERE r.doctor_id = d.doctor_id
         ), d.rating, 0) AS rating,
         d.profile_image_url,
         d.latitude,
         d.longitude,
         ${feeSelects.clinicFeeSql},
         ${feeSelects.homeVisitBaseFeeSql},
         ${feeSelects.perKmChargeSql},
         COALESCE(vr.city, '') AS city,
         'APPROVED' AS approval_status
       FROM doctors d
       LEFT JOIN doctor_verification_requests vr
         ON vr.request_id = (
           SELECT v2.request_id
           FROM doctor_verification_requests v2
           WHERE v2.doctor_id = d.doctor_id
             AND v2.status = 'APPROVED'
           ORDER BY v2.request_id DESC
           LIMIT 1
         )
       WHERE d.verification_status = 'approved' AND d.is_removed = 0
       ORDER BY d.doctor_id DESC`
    );
    return res.json(rows);
  } catch (err) {
    console.error('getApprovedDoctors error:', err);
    return res.status(500).json({ message: 'Failed to fetch approved doctors' });
  }
}

async function getDoctorById(req, res) {
  try {
    const feeSelects = await buildDoctorFeeSelects();
    const [rows] = await db.query(
      `SELECT
         d.*,
         COALESCE((
           SELECT ROUND(AVG(r.rating), 1)
           FROM reviews r
           WHERE r.doctor_id = d.doctor_id
         ), d.rating, 0) AS rating,
         COALESCE(vr.clinic_address, '') AS clinic_address,
         COALESCE(vr.city, '') AS city,
         COALESCE(vr.consultation_fee, 0) AS consultation_fee,
         ${feeSelects.clinicFeeSql},
         ${feeSelects.homeVisitBaseFeeSql},
         ${feeSelects.perKmChargeSql}
       FROM doctors d
       LEFT JOIN doctor_verification_requests vr
         ON vr.request_id = (
           SELECT v2.request_id
           FROM doctor_verification_requests v2
           WHERE v2.doctor_id = d.doctor_id
             AND v2.status = 'APPROVED'
           ORDER BY v2.request_id DESC
           LIMIT 1
         )
       WHERE d.doctor_id = ?`,
      [req.params.id]
    );
    if (rows.length === 0) return res.status(404).json({ message: "Not found" });
    return res.json(rows[0]);
  } catch (err) {
    console.error("getDoctorById error:", err);
    return res.status(500).json({ message: "Failed to fetch doctor" });
  }
}

async function getDoctorProfile(req, res) {
  const doctorId = req.params.id;
  try {
    const feeSelects = await buildDoctorFeeSelects();
    const [rows] = await db.query(
      `SELECT
         d.doctor_id,
         d.name AS full_name,
         d.email AS doctor_email,
         d.phone AS doctor_phone,
         d.age,
         d.profile_image_url AS doctor_profile_image_url,
         d.is_verified,
         d.is_removed,
         d.removed_reason,
         d.removed_at,
         vr.date_of_birth,
         vr.qualification,
         vr.university_name,
         vr.year_of_graduation,
         vr.years_of_experience,
         vr.specialization,
         vr.license_number,
         vr.license_issuing_authority,
         vr.license_expiry_date,
         vr.license_certificate_url,
         vr.degree_certificate_url,
         vr.clinic_name,
         vr.clinic_address,
         vr.city,
         vr.area,
         vr.pincode,
         vr.latitude,
         vr.longitude,
         vr.clinic_contact_number,
         vr.consultation_fee,
         vr.home_visit_available,
         ${feeSelects.clinicFeeSql},
         ${feeSelects.homeVisitBaseFeeSql},
         ${feeSelects.perKmChargeSql}
       FROM doctors d
       LEFT JOIN doctor_verification_requests vr
         ON vr.request_id = (
           SELECT v2.request_id
           FROM doctor_verification_requests v2
           WHERE v2.doctor_id = d.doctor_id
             AND v2.status = 'APPROVED'
           ORDER BY v2.request_id DESC
           LIMIT 1
         )
       WHERE d.doctor_id = ?`,
      [doctorId]
    );
    if (rows.length === 0) return res.status(404).json({ message: "Not found" });
    return res.json(rows[0]);
  } catch (err) {
    console.error("getDoctorProfile error:", err);
    return res.status(500).json({ message: "Failed to fetch doctor profile" });
  }
}

async function removeDoctor(req, res) {
  const doctorId = req.params.id;
  const { removed_reason } = req.body;
  if (!removed_reason || !removed_reason.trim()) {
    return res.status(400).json({ message: "removed_reason is required" });
  }
  try {
    const [result] = await db.query(
      "UPDATE doctors SET is_removed = 1, removed_reason = ?, removed_at = CURRENT_TIMESTAMP WHERE doctor_id = ?",
      [removed_reason.trim(), doctorId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Doctor not found" });
    }
    return res.json({ message: "Doctor removed successfully" });
  } catch (err) {
    console.error("removeDoctor error:", err);
    return res.status(500).json({ message: "Failed to remove doctor" });
  }
}

async function updateDoctorPricing(req, res) {
  const doctorId = Number(req.params.id);
  if (!Number.isInteger(doctorId) || doctorId <= 0) {
    return res.status(400).json({ message: "Invalid doctor id" });
  }

  const clinicFee = toNullableNumber(req.body.clinic_fee);
  const homeVisitBaseFee = toNullableNumber(req.body.home_visit_base_fee);
  const perKmCharge = toNullableNumber(req.body.per_km_charge);

  if (clinicFee == null || clinicFee < 0) {
    return res.status(400).json({ message: "clinic_fee is required" });
  }
  if (homeVisitBaseFee == null || homeVisitBaseFee < 0) {
    return res.status(400).json({ message: "home_visit_base_fee is required" });
  }
  if (perKmCharge != null && perKmCharge < 0) {
    return res.status(400).json({ message: "per_km_charge cannot be negative" });
  }
  try {
    const columns = await getDoctorColumnSet();
    const missingColumns = [
      "clinic_fee",
      "home_visit_base_fee",
      "per_km_charge",
    ].filter((column) => !columns.has(column));
    if (missingColumns.length > 0) {
      return res.status(500).json({
        message: `Missing doctor pricing columns: ${missingColumns.join(", ")}`,
      });
    }

    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [req.user?.firebase_uid || ""]
    );
    if (userRows.length === 0) {
      return res.status(401).json({ message: "Unauthorized user" });
    }

    const role = String(userRows[0].role || "").toUpperCase();
    if (role === "DOCTOR") {
      const [doctorRows] = await db.query(
        "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
        [userRows[0].id]
      );
      if (doctorRows.length === 0 || Number(doctorRows[0].doctor_id) !== doctorId) {
        return res.status(403).json({ message: "Forbidden doctor access" });
      }
    }

    const [result] = await db.query(
      `UPDATE doctors
       SET clinic_fee = ?,
           home_visit_base_fee = ?,
           per_km_charge = ?
       WHERE doctor_id = ?`,
      [
        roundMoney(clinicFee),
        roundMoney(homeVisitBaseFee),
        perKmCharge == null ? null : roundMoney(perKmCharge),
        doctorId,
      ]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Doctor not found" });
    }

    return res.json({ message: "Doctor pricing updated" });
  } catch (err) {
    console.error("updateDoctorPricing error:", err);
    return res.status(500).json({ message: "Failed to update doctor pricing" });
  }
}

module.exports = {
  getDoctors,
  getApprovedDoctors,
  getDoctorById,
  getDoctorProfile,
  updateDoctorPricing,
  removeDoctor,
};
