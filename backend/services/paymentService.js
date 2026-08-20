const db = require("../db");
const {
  getAppointmentColumnSet,
  getDoctorPricing,
  calculateDistanceKm,
  calculateSessionFee,
  roundMoney,
  toNullableNumber,
} = require("./pricingService");

let _hasPreferredPaymentMethodColumn = null;

async function hasPreferredPaymentMethodColumn(conn) {
  if (_hasPreferredPaymentMethodColumn != null) {
    return _hasPreferredPaymentMethodColumn;
  }

  try {
    const [rows] = await conn.query(
      `SELECT COUNT(*) AS cnt
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'appointments'
         AND column_name = 'preferred_payment_method'`
    );
    _hasPreferredPaymentMethodColumn = Number(rows[0]?.cnt || 0) > 0;
  } catch (_) {
    _hasPreferredPaymentMethodColumn = false;
  }

  return _hasPreferredPaymentMethodColumn;
}


async function createPendingPaymentForCompletedAppointment(appointmentId, conn = db) {
  const [existing] = await conn.query(
    "SELECT id FROM payments WHERE appointment_id = ? LIMIT 1",
    [appointmentId]
  );
  if (existing.length > 0) {
    return existing[0].id;
  }

  const hasPreferredMethod = await hasPreferredPaymentMethodColumn(conn);
  const appointmentColumns = await getAppointmentColumnSet(conn);
  const preferredSelect = hasPreferredMethod
    ? "preferred_payment_method"
    : "'cash' AS preferred_payment_method";
  const sessionFeeSelect = appointmentColumns.has("session_fee")
    ? "session_fee"
    : "NULL AS session_fee";
  const distanceSelect = appointmentColumns.has("distance_km")
    ? "distance_km"
    : "NULL AS distance_km";
  const specialFeeSelect = appointmentColumns.has("special_fee_amount")
    ? "special_fee_amount"
    : "NULL AS special_fee_amount";

  const [appointmentRows] = await conn.query(
    `SELECT
       appointment_id,
       doctor_id,
       patient_id,
       visit_type,
       ${sessionFeeSelect},
       ${distanceSelect},
       ${specialFeeSelect},
       ${preferredSelect}
     FROM appointments
     WHERE appointment_id = ? AND status = 'COMPLETED'
     LIMIT 1`,
    [appointmentId]
  );
  if (appointmentRows.length === 0) {
    return null;
  }

  const appointment = appointmentRows[0];
  let amount = toNullableNumber(appointment.session_fee);
  if (amount == null) {
    const pricing = await getDoctorPricing(appointment.doctor_id, conn);
    if (pricing != null) {
      const [patientRows] = await conn.query(
        "SELECT latitude, longitude FROM patients WHERE patient_id = ? LIMIT 1",
        [appointment.patient_id]
      );
      const patient = patientRows[0] || {};
      const computedDistance =
        toNullableNumber(appointment.distance_km) ??
        calculateDistanceKm(
          pricing.latitude,
          pricing.longitude,
          patient.latitude,
          patient.longitude
        );
      amount = calculateSessionFee({
        visitType: appointment.visit_type,
        clinicFee: pricing.clinicFee,
        homeVisitBaseFee: pricing.homeVisitBaseFee,
        perKmCharge: pricing.perKmCharge,
        distanceKm: computedDistance,
        specialFeeAmount: appointment.special_fee_amount,
      }).sessionFee;
    } else {
      amount = String(appointment.visit_type || "").toUpperCase() === "HOME" ? 700 : 500;
    }
  }
  amount = roundMoney(amount);
  const preferredMethod = String(
    appointment.preferred_payment_method || "cash"
  ).toLowerCase();
  const paymentMethod = ["cash", "online", "credit", "debit"].includes(preferredMethod)
    ? preferredMethod
    : "cash";

  const [insertResult] = await conn.query(
    `INSERT INTO payments
      (appointment_id, patient_id, doctor_id, amount, payment_method, payment_status, payment_date, created_at)
     VALUES (?, ?, ?, ?, ?, 'pending', NULL, NOW())`,
    [
      appointment.appointment_id,
      appointment.patient_id,
      appointment.doctor_id,
      amount,
      paymentMethod,
    ]
  );
  return insertResult.insertId;
}

module.exports = { createPendingPaymentForCompletedAppointment };
