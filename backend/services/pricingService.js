const db = require("../db");

let _doctorColumnSet = null;
let _appointmentColumnSet = null;

async function getTableColumnSet(tableName, cacheValue, conn = db) {
  if (cacheValue != null) {
    return cacheValue;
  }

  try {
    const [rows] = await conn.query(
      `SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = ?`,
      [tableName]
    );
    return new Set(
      rows.map((row) => String(row.column_name || row.COLUMN_NAME || "").toLowerCase())
    );
  } catch (_) {
    return new Set();
  }
}

async function getDoctorColumnSet(conn = db) {
  _doctorColumnSet = await getTableColumnSet("doctors", _doctorColumnSet, conn);
  return _doctorColumnSet;
}

async function getAppointmentColumnSet(conn = db) {
  _appointmentColumnSet = await getTableColumnSet(
    "appointments",
    _appointmentColumnSet,
    conn
  );
  return _appointmentColumnSet;
}

function roundMoney(value) {
  return Math.round((Number(value) || 0) * 100) / 100;
}

function toNullableNumber(value) {
  if (value === null || value === undefined || value === "") return null;
  const numeric = Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function calculateDistanceKm(originLat, originLng, destinationLat, destinationLng) {
  const values = [originLat, originLng, destinationLat, destinationLng].map((value) =>
    Number(value)
  );
  if (values.some((value) => !Number.isFinite(value))) {
    return null;
  }

  const [lat1, lon1, lat2, lon2] = values;
  const toRadians = (deg) => (deg * Math.PI) / 180;
  const earthRadiusKm = 6371;
  const deltaLat = toRadians(lat2 - lat1);
  const deltaLon = toRadians(lon2 - lon1);
  const a =
    Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
    Math.cos(toRadians(lat1)) *
      Math.cos(toRadians(lat2)) *
      Math.sin(deltaLon / 2) *
      Math.sin(deltaLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(earthRadiusKm * c * 100) / 100;
}

function calculateSessionFee({
  visitType,
  clinicFee,
  homeVisitBaseFee,
  perKmCharge,
  distanceKm,
  specialFeeAmount,
}) {
  const normalizedVisitType = String(visitType || "").toUpperCase();
  const resolvedClinicFee = roundMoney(clinicFee);
  const resolvedHomeFee = roundMoney(homeVisitBaseFee || clinicFee);
  const resolvedPerKmCharge = toNullableNumber(perKmCharge);
  const resolvedDistanceKm = toNullableNumber(distanceKm);
  const resolvedSpecialFee = toNullableNumber(specialFeeAmount);

  const baseFee =
    normalizedVisitType === "HOME" ? resolvedHomeFee : resolvedClinicFee;
  const distanceCharge =
    normalizedVisitType === "HOME" &&
    resolvedDistanceKm != null &&
    resolvedPerKmCharge != null
      ? roundMoney(resolvedDistanceKm * resolvedPerKmCharge)
      : 0;
  const specialCharge = resolvedSpecialFee != null ? roundMoney(resolvedSpecialFee) : 0;

  return {
    baseFee: roundMoney(baseFee),
    distanceKm: resolvedDistanceKm,
    distanceCharge,
    specialCharge,
    sessionFee: roundMoney(baseFee + distanceCharge + specialCharge),
  };
}

async function getDoctorPricing(doctorId, conn = db) {
  const columns = await getDoctorColumnSet(conn);
  const clinicFeeSql = columns.has("clinic_fee")
    ? "COALESCE(d.clinic_fee, vr.consultation_fee, 0)"
    : "COALESCE(vr.consultation_fee, 0)";
  const homeVisitBaseFeeSql = columns.has("home_visit_base_fee")
    ? columns.has("clinic_fee")
      ? "COALESCE(d.home_visit_base_fee, d.clinic_fee, vr.consultation_fee, 0)"
      : "COALESCE(d.home_visit_base_fee, vr.consultation_fee, 0)"
    : columns.has("clinic_fee")
      ? "COALESCE(d.clinic_fee, vr.consultation_fee, 0)"
      : "COALESCE(vr.consultation_fee, 0)";
  const perKmChargeSql = columns.has("per_km_charge")
    ? "d.per_km_charge"
    : "NULL";
  const [rows] = await conn.query(
    `SELECT
       d.doctor_id,
       d.latitude,
       d.longitude,
       ${clinicFeeSql} AS clinic_fee,
       ${homeVisitBaseFeeSql} AS home_visit_base_fee,
       ${perKmChargeSql} AS per_km_charge
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
     WHERE d.doctor_id = ?
     LIMIT 1`,
    [doctorId]
  );

  if (rows.length === 0) {
    return null;
  }

  const row = rows[0];
  return {
    doctorId: Number(row.doctor_id),
    latitude: toNullableNumber(row.latitude),
    longitude: toNullableNumber(row.longitude),
    clinicFee: roundMoney(row.clinic_fee),
    homeVisitBaseFee: roundMoney(row.home_visit_base_fee),
    perKmCharge: toNullableNumber(row.per_km_charge),
  };
}

module.exports = {
  getDoctorColumnSet,
  getAppointmentColumnSet,
  getDoctorPricing,
  calculateDistanceKm,
  calculateSessionFee,
  roundMoney,
  toNullableNumber,
};
