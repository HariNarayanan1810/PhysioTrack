const db = require("../db");
const { createPendingPaymentForCompletedAppointment } = require("../services/paymentService");
const {
  getAppointmentColumnSet: getPricingAppointmentColumnSet,
  getDoctorPricing,
  calculateDistanceKm,
  calculateSessionFee,
  toNullableNumber,
} = require("../services/pricingService");
const { sendPushToUser } = require("../services/notificationsService");

let _hasPreferredPaymentMethodColumn = null;
let _appointmentColumnSet = null;
const ROUTE_OPTIMIZATION_TIME_TOLERANCE_MINUTES = 45;

async function getAppointmentColumnSet() {
  if (_appointmentColumnSet != null) {
    return _appointmentColumnSet;
  }

  try {
    const [rows] = await db.query(
      `SELECT column_name
       FROM information_schema.columns
       WHERE table_schema = DATABASE()
         AND table_name = 'appointments'`
    );
    _appointmentColumnSet = new Set(
      rows.map((row) => String(row.column_name || row.COLUMN_NAME || '').toLowerCase())
    );
  } catch (_) {
    _appointmentColumnSet = new Set();
  }

  return _appointmentColumnSet;
}

function selectAppointmentColumn(columns, columnName, fallbackSql = 'NULL') {
  return columns.has(columnName.toLowerCase())
    ? `a.${columnName}`
    : `${fallbackSql} AS ${columnName}`;
}

function resolveSpecialFeePayload(body) {
  const isSpecialSession =
    body.is_special_session === true ||
    body.is_special_session == 1 ||
    String(body.is_special_session || '').toLowerCase() == 'true';
  const rawAmount = body.special_fee_amount;
  const specialFeeAmount =
    rawAmount === null || rawAmount === undefined || rawAmount === ''
      ? null
      : Number(rawAmount);
  const specialFeeReason = String(body.special_fee_reason || '').trim();

  return {
    isSpecialSession,
    specialFeeAmount,
    specialFeeReason,
  };
}

async function hasPreferredPaymentMethodColumn() {
  if (_hasPreferredPaymentMethodColumn != null) {
    return _hasPreferredPaymentMethodColumn;
  }

  try {
    const [rows] = await db.query(
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

function parseTimeAsMinutes(rawValue) {
  const value = String(rawValue || "").trim().toUpperCase();
  const match = /^(\d{1,2}):(\d{2})\s*(AM|PM)?$/.exec(value);
  if (!match) return 0;
  let hours = Number(match[1]);
  const minutes = Number(match[2]);
  const suffix = match[3] || "";
  if (suffix === "PM" && hours < 12) hours += 12;
  if (suffix === "AM" && hours === 12) hours = 0;
  return hours * 60 + minutes;
}

function estimateEtaMinutes(distanceKm) {
  const value = Number(distanceKm);
  if (!Number.isFinite(value) || value <= 0) return null;
  return Math.max(1, Math.ceil((value * 1000) / 416.67));
}

async function findOptimizedNextHomeVisit({
  conn,
  doctorId,
  appointmentDate,
  originPatientId,
}) {
  const [originRows] = await conn.query(
    `SELECT latitude, longitude
     FROM patients
     WHERE patient_id = ?
     LIMIT 1`,
    [originPatientId]
  );
  if (originRows.length === 0) return null;

  const originLat = Number(originRows[0].latitude);
  const originLng = Number(originRows[0].longitude);
  if (!Number.isFinite(originLat) || !Number.isFinite(originLng)) return null;

  const [candidateRows] = await conn.query(
    `SELECT
       a.appointment_id,
       a.patient_id,
       a.appointment_time,
       d.name AS doctor_name,
       p.user_id,
       p.name AS patient_name,
       p.latitude,
       p.longitude
     FROM appointments a
     JOIN doctors d ON d.doctor_id = a.doctor_id
     JOIN patients p ON p.patient_id = a.patient_id
     WHERE a.doctor_id = ?
       AND a.visit_type = 'HOME'
       AND a.status = 'APPROVED'
       AND a.appointment_date = ?`,
    [doctorId, appointmentDate]
  );
  if (candidateRows.length === 0) return null;

  const withTime = candidateRows.map((row) => ({
    ...row,
    appointment_minutes: parseTimeAsMinutes(row.appointment_time),
  }));
  const earliestMinutes = withTime.reduce(
    (minimum, row) => Math.min(minimum, row.appointment_minutes),
    withTime[0].appointment_minutes
  );
  const rankedPool = withTime.filter(
    (row) =>
      row.appointment_minutes <=
      earliestMinutes + ROUTE_OPTIMIZATION_TIME_TOLERANCE_MINUTES
  );
  const candidates = rankedPool.length > 0 ? rankedPool : withTime;

  candidates.sort((a, b) => {
    const distanceA = calculateDistanceKm(originLat, originLng, a.latitude, a.longitude);
    const distanceB = calculateDistanceKm(originLat, originLng, b.latitude, b.longitude);
    const safeDistanceA = Number.isFinite(distanceA) ? distanceA : Number.POSITIVE_INFINITY;
    const safeDistanceB = Number.isFinite(distanceB) ? distanceB : Number.POSITIVE_INFINITY;
    if (safeDistanceA !== safeDistanceB) return safeDistanceA - safeDistanceB;
    return a.appointment_minutes - b.appointment_minutes;
  });

  const selected = candidates[0];
  if (!selected || !selected.user_id) return null;

  const distanceKm = calculateDistanceKm(
    originLat,
    originLng,
    selected.latitude,
    selected.longitude
  );
  return {
    appointmentId: Number(selected.appointment_id),
    patientId: Number(selected.patient_id),
    patientUserId: Number(selected.user_id),
    patientName: String(selected.patient_name || "Patient"),
    doctorName: String(selected.doctor_name || "Doctor"),
    distanceKm,
    etaMinutes: estimateEtaMinutes(distanceKm),
  };
}

async function sendNextPatientHomeVisitNotification(nextVisit) {
  if (!nextVisit || !nextVisit.patientUserId) return;
  const etaLabel = nextVisit.etaMinutes == null
    ? "soon"
    : `within ${nextVisit.etaMinutes} min`;
  const doctorName = String(nextVisit.doctorName || "Doctor");
  const doctorLabel = doctorName.toLowerCase().startsWith("dr.")
    ? doctorName
    : `Dr. ${doctorName}`;

  await sendPushToUser({
    userId: nextVisit.patientUserId,
    title: "Doctor is on the way",
    body: `${doctorLabel} will arrive ${etaLabel}.`,
    data: {
      type: "home_visit_eta",
      appointment_id: nextVisit.appointmentId,
      patient_id: nextVisit.patientId,
      doctor_name: doctorName,
      eta_minutes: nextVisit.etaMinutes ?? "",
    },
  });
}

async function sendAppointmentOnTheWayNotificationForActivation(conn, appointmentId) {
  const [rows] = await conn.query(
    `SELECT
       a.appointment_id,
       a.patient_id,
       a.current_eta_minutes,
       p.user_id,
       d.name AS doctor_name
     FROM appointments a
     JOIN patients p ON p.patient_id = a.patient_id
     JOIN doctors d ON d.doctor_id = a.doctor_id
     WHERE a.appointment_id = ?
       AND a.visit_type = 'HOME'
       AND a.status = 'APPROVED'
     LIMIT 1`,
    [appointmentId]
  );

  if (rows.length === 0) return;

  const row = rows[0];
  const patientUserId = Number(row.user_id);
  if (!patientUserId) return;

  const etaMinutes = row.current_eta_minutes == null
    ? null
    : Number(row.current_eta_minutes);
  const etaLabel = Number.isFinite(etaMinutes)
    ? `within ${etaMinutes} min`
    : 'soon';
  const doctorName = String(row.doctor_name || 'Doctor');
  const doctorLabel = doctorName.toLowerCase().startsWith('dr.')
    ? doctorName
    : `Dr. ${doctorName}`;

  await sendPushToUser({
    userId: patientUserId,
    title: 'Doctor is on the way',
    body: `${doctorLabel} will arrive ${etaLabel}.`,
    data: {
      type: 'home_visit_eta',
      appointment_id: row.appointment_id,
      patient_id: row.patient_id,
      doctor_name: doctorName,
      eta_minutes: Number.isFinite(etaMinutes) ? etaMinutes : '',
    },
  });
}


async function getAppointments(req, res) {
  const doctorId = req.query.doctor_id;
  const patientId = req.query.patient_id;

  const clauses = [];
  const params = [];

  if (doctorId) {
    clauses.push("a.doctor_id = ?");
    params.push(doctorId);
  }
  if (patientId) {
    clauses.push("a.patient_id = ?");
    params.push(patientId);
  }

  const where = clauses.length > 0 ? `WHERE ${clauses.join(" AND ")}` : "";

  try {
    const hasPreferredMethod = await hasPreferredPaymentMethodColumn();
    const columns = await getAppointmentColumnSet();
    const preferredSelect = hasPreferredMethod
      ? "a.preferred_payment_method"
      : "'cash' AS preferred_payment_method";

    const [rows] = await db.query(
      `SELECT
         a.appointment_id,
         a.doctor_id,
         a.patient_id,
         a.appointment_date,
         a.appointment_time,
         a.status,
         a.visit_type,
         ${selectAppointmentColumn(columns, 'distance_km')},
         ${selectAppointmentColumn(columns, 'session_fee')},
         ${selectAppointmentColumn(columns, 'is_special_session', '0')},
         ${selectAppointmentColumn(columns, 'special_fee_amount')},
         ${selectAppointmentColumn(columns, 'special_fee_reason')},
         ${selectAppointmentColumn(columns, 'actual_start_time')},
         ${selectAppointmentColumn(columns, 'actual_end_time')},
         ${selectAppointmentColumn(columns, 'live_tracking_enabled', '0')},
         ${selectAppointmentColumn(columns, 'doctor_live_latitude')},
         ${selectAppointmentColumn(columns, 'doctor_live_longitude')},
         ${selectAppointmentColumn(columns, 'current_eta_minutes')},
         ${selectAppointmentColumn(columns, 'last_location_updated_at')},
         ${preferredSelect},
         d.name AS doctor_name,
         p.name AS patient_name
       FROM appointments a
       JOIN doctors d ON a.doctor_id = d.doctor_id
       JOIN patients p ON a.patient_id = p.patient_id
       ${where}
       ORDER BY a.appointment_id DESC`,
      params
    );
    res.json(rows);
  } catch (err) {
    console.error("getAppointments error:", err);
    res.status(500).json({ message: "Failed to fetch appointments" });
  }
}

async function updateAppointmentStatus(req, res) {
  const appointmentId = Number(req.params.id);
  const status = String(req.body.status || '').toUpperCase();

  if (!Number.isInteger(appointmentId) || appointmentId <= 0) {
    return res.status(400).json({ message: 'Invalid appointment id' });
  }
  if (!['REQUESTED', 'APPROVED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'REJECTED'].includes(status)) {
    return res.status(400).json({ message: 'Invalid status' });
  }

  const conn = await db.getConnection();
  let nextHomeVisitNotification = null;
  try {
    await conn.beginTransaction();
    const columns = await getAppointmentColumnSet();
    const { isSpecialSession, specialFeeAmount, specialFeeReason } =
      resolveSpecialFeePayload(req.body);
    const [appointmentRows] = await conn.query(
      `SELECT appointment_id, doctor_id, patient_id, appointment_date, visit_type,
              ${columns.has('distance_km') ? 'distance_km' : 'NULL AS distance_km'}
       FROM appointments
       WHERE appointment_id = ?
       LIMIT 1`,
      [appointmentId]
    );
    if (appointmentRows.length === 0) {
      await conn.rollback();
      return res.status(404).json({ message: 'Appointment not found' });
    }

    const currentAppointment = appointmentRows[0];

    let result;
    if (status === 'IN_PROGRESS') {
      if (
        columns.has('live_tracking_enabled') ||
        columns.has('current_eta_minutes')
      ) {
        const clearUpdates = [];
        if (columns.has('live_tracking_enabled')) {
          clearUpdates.push('live_tracking_enabled = 0');
        }
        if (columns.has('current_eta_minutes')) {
          clearUpdates.push('current_eta_minutes = NULL');
        }
        await conn.query(
          `UPDATE appointments
           SET ${clearUpdates.join(', ')}
           WHERE doctor_id = ?
             AND visit_type = 'HOME'
             AND appointment_date = ?
             AND appointment_id <> ?`,
          [
            currentAppointment.doctor_id,
            currentAppointment.appointment_date,
            appointmentId,
          ]
        );
      }

      const updates = ["status = ?"];
      if (columns.has('actual_start_time')) {
        updates.push("actual_start_time = COALESCE(actual_start_time, CURRENT_TIMESTAMP)");
      }
      if (columns.has('live_tracking_enabled')) {
        updates.push("live_tracking_enabled = 0");
      }
      if (columns.has('current_eta_minutes')) {
        updates.push("current_eta_minutes = NULL");
      }
      if (columns.has('doctor_live_latitude')) {
        updates.push("doctor_live_latitude = NULL");
      }
      if (columns.has('doctor_live_longitude')) {
        updates.push("doctor_live_longitude = NULL");
      }
      if (columns.has('last_location_updated_at')) {
        updates.push("last_location_updated_at = NULL");
      }
      [result] = await conn.query(
        `UPDATE appointments
         SET ${updates.join(', ')}
         WHERE appointment_id = ?`,
        [status, appointmentId]
      );
    } else if (status === 'COMPLETED') {
      if (isSpecialSession && (!Number.isFinite(specialFeeAmount) || specialFeeAmount < 0)) {
        await conn.rollback();
        return res.status(400).json({ message: 'Invalid special fee amount' });
      }
      if (!isSpecialSession && specialFeeAmount != null && (!Number.isFinite(specialFeeAmount) || specialFeeAmount < 0)) {
        await conn.rollback();
        return res.status(400).json({ message: 'Invalid special fee amount' });
      }
      if (isSpecialSession && !specialFeeReason) {
        await conn.rollback();
        return res.status(400).json({ message: 'special_fee_reason is required for special sessions' });
      }

      let calculatedFee = null;
      if (columns.has('session_fee')) {
        const pricing = await getDoctorPricing(currentAppointment.doctor_id, conn);
        if (pricing != null) {
          calculatedFee = calculateSessionFee({
            visitType: currentAppointment.visit_type,
            clinicFee: pricing.clinicFee,
            homeVisitBaseFee: pricing.homeVisitBaseFee,
            perKmCharge: pricing.perKmCharge,
            distanceKm: currentAppointment.distance_km,
            specialFeeAmount: isSpecialSession ? specialFeeAmount : null,
          }).sessionFee;
        }
      }

      const updates = ["status = ?"];
      if (columns.has('actual_end_time')) {
        updates.push("actual_end_time = CURRENT_TIMESTAMP");
      }
      if (columns.has('live_tracking_enabled')) {
        updates.push("live_tracking_enabled = 0");
      }
      if (columns.has('current_eta_minutes')) {
        updates.push("current_eta_minutes = NULL");
      }
      if (columns.has('doctor_live_latitude')) {
        updates.push("doctor_live_latitude = NULL");
      }
      if (columns.has('doctor_live_longitude')) {
        updates.push("doctor_live_longitude = NULL");
      }
      if (columns.has('last_location_updated_at')) {
        updates.push("last_location_updated_at = NULL");
      }
      if (columns.has('is_special_session')) {
        updates.push("is_special_session = ?");
      }
      if (columns.has('special_fee_amount')) {
        updates.push("special_fee_amount = ?");
      }
      if (columns.has('special_fee_reason')) {
        updates.push("special_fee_reason = ?");
      }
      if (columns.has('session_fee') && calculatedFee != null) {
        updates.push("session_fee = ?");
      }
      const values = [status];
      if (columns.has('is_special_session')) {
        values.push(isSpecialSession ? 1 : 0);
      }
      if (columns.has('special_fee_amount')) {
        values.push(isSpecialSession ? toNullableNumber(specialFeeAmount) : null);
      }
      if (columns.has('special_fee_reason')) {
        values.push(isSpecialSession ? specialFeeReason : null);
      }
      if (columns.has('session_fee') && calculatedFee != null) {
        values.push(calculatedFee);
      }
      values.push(appointmentId);
      [result] = await conn.query(
        `UPDATE appointments
         SET ${updates.join(', ')}
         WHERE appointment_id = ?`,
        values
      );
    } else if (status === 'CANCELLED' || status === 'REJECTED') {
      const updates = ["status = ?"];
      if (columns.has('live_tracking_enabled')) {
        updates.push("live_tracking_enabled = 0");
      }
      if (columns.has('current_eta_minutes')) {
        updates.push("current_eta_minutes = NULL");
      }
      if (columns.has('doctor_live_latitude')) {
        updates.push("doctor_live_latitude = NULL");
      }
      if (columns.has('doctor_live_longitude')) {
        updates.push("doctor_live_longitude = NULL");
      }
      if (columns.has('last_location_updated_at')) {
        updates.push("last_location_updated_at = NULL");
      }
      [result] = await conn.query(
        `UPDATE appointments
         SET ${updates.join(', ')}
         WHERE appointment_id = ?`,
        [status, appointmentId]
      );
    } else {
      [result] = await conn.query(
        'UPDATE appointments SET status = ? WHERE appointment_id = ?',
        [status, appointmentId]
      );
    }
    if (result.affectedRows === 0) {
      await conn.rollback();
      return res.status(404).json({ message: 'Appointment not found' });
    }

    if (status === "COMPLETED") {
      await createPendingPaymentForCompletedAppointment(appointmentId, conn);
      if (String(currentAppointment.visit_type || "").toUpperCase() === "HOME") {
        nextHomeVisitNotification = await findOptimizedNextHomeVisit({
          conn,
          doctorId: currentAppointment.doctor_id,
          appointmentDate: currentAppointment.appointment_date,
          originPatientId: currentAppointment.patient_id,
        });
      }
    }

    await conn.commit();
    if (status === "COMPLETED" && nextHomeVisitNotification) {
      await sendNextPatientHomeVisitNotification(nextHomeVisitNotification);
    }
    return res.json({
      message: 'Appointment status updated',
      next_home_visit: nextHomeVisitNotification,
    });
  } catch (err) {
    await conn.rollback();
    console.error('updateAppointmentStatus error:', err);
    return res.status(500).json({ message: 'Failed to update appointment' });
  } finally {
    conn.release();
  }
}

async function cancelAppointment(req, res) {
  const appointmentId = Number(req.params.id);

  if (!Number.isInteger(appointmentId) || appointmentId <= 0) {
    return res.status(400).json({ message: "Invalid appointment id" });
  }

  try {
    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [req.user?.firebase_uid || ""]
    );
    if (userRows.length === 0) {
      return res.status(401).json({ message: "Unauthorized user" });
    }

    const role = String(userRows[0].role || "").toUpperCase();
    const userId = Number(userRows[0].id);
    let patientId = null;

    if (role === "PATIENT") {
      const [patientRows] = await db.query(
        "SELECT patient_id FROM patients WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (patientRows.length === 0) {
        return res.status(404).json({ message: "Patient profile not found" });
      }
      patientId = Number(patientRows[0].patient_id);
    }

    const params = [appointmentId];
    let sql =
      "SELECT appointment_id, status FROM appointments WHERE appointment_id = ?";
    if (role === "PATIENT") {
      sql += " AND patient_id = ?";
      params.push(patientId);
    }
    sql += " LIMIT 1";

    const [rows] = await db.query(sql, params);
    if (rows.length === 0) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    const currentStatus = String(rows[0].status || "").toUpperCase();
    if (currentStatus === "COMPLETED") {
      return res.status(400).json({ message: "Completed appointments cannot be cancelled" });
    }
    if (currentStatus === "CANCELLED") {
      return res.status(400).json({ message: "Appointment already cancelled" });
    }

    await db.query(
      "UPDATE appointments SET status = 'CANCELLED' WHERE appointment_id = ?",
      [appointmentId]
    );

    return res.json({ message: "Appointment cancelled successfully" });
  } catch (err) {
    console.error("cancelAppointment error:", err);
    return res.status(500).json({ message: "Failed to cancel appointment" });
  }
}

async function createAppointment(req, res) {
  const {
    doctor_id,
    patient_id,
    appointment_date,
    appointment_time,
    visit_type,
    payment_method,
  } = req.body;

  if (!doctor_id || !patient_id || !appointment_date || !appointment_time) {
    return res.status(400).json({ message: "Missing fields" });
  }

  const preferredPaymentMethod = String(payment_method || "cash").toLowerCase();
  const allowedMethods = new Set(["cash", "online", "credit", "debit"]);
  if (!allowedMethods.has(preferredPaymentMethod)) {
    return res.status(400).json({ message: "Invalid payment method" });
  }

  try {
    const hasPreferredMethod = await hasPreferredPaymentMethodColumn();
    const appointmentColumns = await getPricingAppointmentColumnSet();
    const pricing = await getDoctorPricing(doctor_id);
    if (!pricing) {
      return res.status(404).json({ message: "Doctor not found" });
    }

    const [patientRows] = await db.query(
      "SELECT latitude, longitude FROM patients WHERE patient_id = ? LIMIT 1",
      [patient_id]
    );
    if (patientRows.length === 0) {
      return res.status(404).json({ message: "Patient not found" });
    }

    let distanceKm = null;
    if (String(visit_type || "").toUpperCase() === "HOME") {
      distanceKm = calculateDistanceKm(
        pricing.latitude,
        pricing.longitude,
        patientRows[0].latitude,
        patientRows[0].longitude
      );
    }

    const fee = calculateSessionFee({
      visitType: visit_type,
      clinicFee: pricing.clinicFee,
      homeVisitBaseFee: pricing.homeVisitBaseFee,
      perKmCharge: pricing.perKmCharge,
      distanceKm,
    });

    const columns = [
      "doctor_id",
      "patient_id",
      "appointment_date",
      "appointment_time",
      "status",
      "visit_type",
    ];
    const placeholders = ["?", "?", "?", "?", "'REQUESTED'", "?"];
    const values = [
      doctor_id,
      patient_id,
      appointment_date,
      appointment_time,
      visit_type,
    ];

    if (hasPreferredMethod) {
      columns.push("preferred_payment_method");
      placeholders.push("?");
      values.push(preferredPaymentMethod);
    }
    if (appointmentColumns.has("distance_km")) {
      columns.push("distance_km");
      placeholders.push("?");
      values.push(toNullableNumber(distanceKm));
    }
    if (appointmentColumns.has("session_fee")) {
      columns.push("session_fee");
      placeholders.push("?");
      values.push(fee.sessionFee);
    }

    const [result] = await db.query(
      `INSERT INTO appointments (${columns.join(", ")})
       VALUES (${placeholders.join(", ")})`,
      values
    );
    res.status(201).json({
      appointment_id: result.insertId,
      distance_km: fee.distanceKm,
      session_fee: fee.sessionFee,
      base_fee: fee.baseFee,
      distance_charge: fee.distanceCharge,
      special_charge: fee.specialCharge,
    });
  } catch (err) {
    console.error("createAppointment error:", err);
    res.status(500).json({ message: "Failed to create appointment" });
  }
}

function formatDateForAppointment(dateValue) {
  const dt = new Date(dateValue);
  if (Number.isNaN(dt.getTime())) return null;
  const day = String(dt.getDate()).padStart(2, "0");
  const month = String(dt.getMonth() + 1).padStart(2, "0");
  const year = dt.getFullYear();
  return `${day}-${month}-${year}`;
}

function formatTimeForAppointment(dateValue) {
  const dt = new Date(dateValue);
  if (Number.isNaN(dt.getTime())) return null;
  let hours = dt.getHours();
  const mins = String(dt.getMinutes()).padStart(2, "0");
  const suffix = hours >= 12 ? "PM" : "AM";
  hours = hours % 12;
  if (hours === 0) hours = 12;
  return `${String(hours).padStart(2, "0")}:${mins} ${suffix}`;
}

async function confirmSuggestedAppointment(req, res) {
  const treatmentId = Number(req.body.treatment_id);
  const patientId = Number(req.body.patient_id);

  if (!Number.isInteger(treatmentId) || treatmentId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid treatment or patient id" });
  }

  try {
    const [rows] = await db.query(
      `SELECT id, doctor_id, patient_id, suggested_next_appointment
       FROM patient_treatment
       WHERE id = ? AND patient_id = ?
       LIMIT 1`,
      [treatmentId, patientId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Treatment not found" });
    }
    const row = rows[0];
    if (!row.suggested_next_appointment) {
      return res.status(400).json({ message: "No suggested appointment available" });
    }

    const appointmentDate = formatDateForAppointment(row.suggested_next_appointment);
    const appointmentTime = formatTimeForAppointment(row.suggested_next_appointment);
    if (!appointmentDate || !appointmentTime) {
      return res.status(400).json({ message: "Invalid suggested appointment date" });
    }

    const appointmentColumns = await getPricingAppointmentColumnSet();
    const pricing = await getDoctorPricing(row.doctor_id);
    const fee = calculateSessionFee({
      visitType: "CLINIC",
      clinicFee: pricing?.clinicFee ?? 0,
      homeVisitBaseFee: pricing?.homeVisitBaseFee ?? pricing?.clinicFee ?? 0,
      perKmCharge: pricing?.perKmCharge,
      distanceKm: null,
    });

    const columns = [
      "doctor_id",
      "patient_id",
      "appointment_date",
      "appointment_time",
      "status",
      "visit_type",
    ];
    const placeholders = ["?", "?", "?", "?", "'REQUESTED'", "'CLINIC'"];
    const values = [row.doctor_id, row.patient_id, appointmentDate, appointmentTime];

    if (appointmentColumns.has("session_fee")) {
      columns.push("session_fee");
      placeholders.push("?");
      values.push(fee.sessionFee);
    }

    const [result] = await db.query(
      `INSERT INTO appointments (${columns.join(", ")})
       VALUES (${placeholders.join(", ")})`,
      values
    );
    await db.query(
      "UPDATE patient_treatment SET suggested_next_appointment = NULL WHERE id = ?",
      [treatmentId]
    );

    return res.status(201).json({ appointment_id: result.insertId });
  } catch (err) {
    console.error("confirmSuggestedAppointment error:", err);
    return res.status(500).json({ message: "Failed to confirm appointment" });
  }
}

async function rescheduleSuggestedAppointment(req, res) {
  const treatmentId = Number(req.body.treatment_id);
  const patientId = Number(req.body.patient_id);
  const suggestedNextAppointment = String(req.body.suggested_next_appointment || "").trim();

  if (!Number.isInteger(treatmentId) || treatmentId <= 0 || !Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: "Invalid treatment or patient id" });
  }
  if (!suggestedNextAppointment) {
    return res.status(400).json({ message: "suggested_next_appointment is required" });
  }
  const dt = new Date(suggestedNextAppointment);
  if (Number.isNaN(dt.getTime()) || dt <= new Date()) {
    return res.status(400).json({ message: "Suggested date must be in future" });
  }

  try {
    const [result] = await db.query(
      `UPDATE patient_treatment
       SET suggested_next_appointment = ?
       WHERE id = ? AND patient_id = ?`,
      [suggestedNextAppointment, treatmentId, patientId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Treatment not found" });
    }
    return res.json({ message: "Suggested appointment rescheduled" });
  } catch (err) {
    console.error("rescheduleSuggestedAppointment error:", err);
    return res.status(500).json({ message: "Failed to reschedule appointment" });
  }
}

async function updateHomeVisitLiveTracking(req, res) {
  const appointmentId = Number(req.params.id);
  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  const etaMinutesRaw = req.body.eta_minutes;
  const etaMinutes =
    etaMinutesRaw === null || etaMinutesRaw === undefined || etaMinutesRaw === ''
      ? null
      : Number(etaMinutesRaw);

  if (!Number.isInteger(appointmentId) || appointmentId <= 0) {
    return res.status(400).json({ message: 'Invalid appointment id' });
  }
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return res.status(400).json({ message: 'Latitude and longitude are required' });
  }
  if (etaMinutes !== null && (!Number.isFinite(etaMinutes) || etaMinutes < 0)) {
    return res.status(400).json({ message: 'Invalid ETA minutes' });
  }

  try {
    const columns = await getAppointmentColumnSet();
    const requiredColumns = [
      'live_tracking_enabled',
      'doctor_live_latitude',
      'doctor_live_longitude',
      'current_eta_minutes',
      'last_location_updated_at',
    ];
    const missingColumns = requiredColumns.filter((column) => !columns.has(column));
    if (missingColumns.length > 0) {
      return res.status(500).json({
        message: `Missing appointment tracking columns: ${missingColumns.join(', ')}`,
      });
    }

    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [req.user?.firebase_uid || ""]
    );
    if (userRows.length === 0) {
      return res.status(401).json({ message: 'Unauthorized user' });
    }

    const role = String(userRows[0].role || '').toUpperCase();
    const userId = Number(userRows[0].id);
    let doctorId = null;
    if (role === 'DOCTOR') {
      const [doctorRows] = await db.query(
        "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (doctorRows.length === 0) {
        return res.status(404).json({ message: 'Doctor profile not found' });
      }
      doctorId = Number(doctorRows[0].doctor_id);
    }

    const [existingRows] = await db.query(
      `SELECT
         appointment_id,
         live_tracking_enabled,
         current_eta_minutes
       FROM appointments
       WHERE appointment_id = ?
       LIMIT 1`,
      [appointmentId]
    );
    const previousTracking = existingRows[0] || null;

    const ownerSql =
      role === 'DOCTOR'
        ? `UPDATE appointments
           SET live_tracking_enabled = 1,
               doctor_live_latitude = ?,
               doctor_live_longitude = ?,
               current_eta_minutes = ?,
               last_location_updated_at = CURRENT_TIMESTAMP
           WHERE appointment_id = ?
             AND doctor_id = ?
             AND visit_type = 'HOME'
             AND status = 'APPROVED'`
        : `UPDATE appointments
           SET live_tracking_enabled = 1,
               doctor_live_latitude = ?,
               doctor_live_longitude = ?,
               current_eta_minutes = ?,
               last_location_updated_at = CURRENT_TIMESTAMP
           WHERE appointment_id = ?
             AND visit_type = 'HOME'
             AND status = 'APPROVED'`;
    const [result] = await db.query(
      ownerSql,
      role === 'DOCTOR'
          ? [latitude, longitude, etaMinutes, appointmentId, doctorId]
          : [latitude, longitude, etaMinutes, appointmentId]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({
        message: 'Active approved home visit appointment not found',
      });
    }

    const wasLiveTrackingEnabled =
      previousTracking?.live_tracking_enabled === 1 ||
      previousTracking?.live_tracking_enabled === true;
    if (!wasLiveTrackingEnabled) {
      await sendAppointmentOnTheWayNotificationForActivation(db, appointmentId);
    }

    return res.json({ message: 'Live tracking updated' });
  } catch (err) {
    console.error('updateHomeVisitLiveTracking error:', err);
    return res.status(500).json({ message: 'Failed to update live tracking' });
  }
}

function formatTodayCandidates() {
  const now = new Date();
  const dd = String(now.getDate()).padStart(2, '0');
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const yyyy = String(now.getFullYear());
  return [`${dd}-${mm}-${yyyy}`, `${yyyy}-${mm}-${dd}`];
}

async function stopDoctorHomeVisitDay(req, res) {
  try {
    const columns = await getAppointmentColumnSet();
    const requiredColumns = ['live_tracking_enabled'];
    const missingColumns = requiredColumns.filter((column) => !columns.has(column));
    if (missingColumns.length > 0) {
      return res.status(500).json({
        message: `Missing appointment tracking columns: ${missingColumns.join(', ')}`,
      });
    }

    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [req.user?.firebase_uid || ""]
    );
    if (userRows.length === 0) {
      return res.status(401).json({ message: 'Unauthorized user' });
    }

    const role = String(userRows[0].role || '').toUpperCase();
    const userId = Number(userRows[0].id);
    let doctorId = null;
    if (role === 'DOCTOR') {
      const [doctorRows] = await db.query(
        "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (doctorRows.length === 0) {
        return res.status(404).json({ message: 'Doctor profile not found' });
      }
      doctorId = Number(doctorRows[0].doctor_id);
    }

    const updates = ["live_tracking_enabled = 0"];
    if (columns.has('doctor_live_latitude')) {
      updates.push('doctor_live_latitude = NULL');
    }
    if (columns.has('doctor_live_longitude')) {
      updates.push('doctor_live_longitude = NULL');
    }
    if (columns.has('current_eta_minutes')) {
      updates.push('current_eta_minutes = NULL');
    }
    if (columns.has('last_location_updated_at')) {
      updates.push('last_location_updated_at = NULL');
    }

    const todayCandidates = formatTodayCandidates();
    const [result] = await db.query(
      `UPDATE appointments
       SET ${updates.join(', ')}
       WHERE doctor_id = ?
         AND visit_type = 'HOME'
         AND appointment_date IN (?, ?)
         AND status IN ('APPROVED', 'IN_PROGRESS')`,
      [doctorId, todayCandidates[0], todayCandidates[1]]
    );

    return res.json({
      message: 'Today home visit session stopped',
      affected_rows: result.affectedRows,
    });
  } catch (err) {
    console.error('stopDoctorHomeVisitDay error:', err);
    return res.status(500).json({ message: 'Failed to stop home visit session' });
  }
}

function isToday(rawDate) {
  const now = new Date();
  const value = String(rawDate || '').trim();
  const parts = value.split('-');

  if (parts.length === 3) {
    if (parts[0].length === 2 && parts[2].length === 4) {
      const day = Number(parts[0]);
      const month = Number(parts[1]);
      const year = Number(parts[2]);
      return day === now.getDate() &&
        month === now.getMonth() + 1 &&
        year === now.getFullYear();
    }
    if (parts[0].length === 4) {
      const year = Number(parts[0]);
      const month = Number(parts[1]);
      const day = Number(parts[2]);
      return day === now.getDate() &&
        month === now.getMonth() + 1 &&
        year === now.getFullYear();
    }
  }

  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return false;
  return parsed.getFullYear() === now.getFullYear() &&
    parsed.getMonth() === now.getMonth() &&
    parsed.getDate() === now.getDate();
}

async function getPatientHomeVisitTracking(req, res) {
  const patientId = Number(req.params.patientId);
  if (!Number.isInteger(patientId) || patientId <= 0) {
    return res.status(400).json({ message: 'Invalid patient id' });
  }

  try {
    const columns = await getAppointmentColumnSet();
    const [userRows] = await db.query(
      "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
      [req.user?.firebase_uid || ""]
    );
    if (userRows.length === 0) {
      return res.status(401).json({ message: 'Unauthorized user' });
    }

    const role = String(userRows[0].role || '').toUpperCase();
    const userId = Number(userRows[0].id);
    if (role === 'PATIENT') {
      const [patientRows] = await db.query(
        "SELECT patient_id FROM patients WHERE user_id = ? LIMIT 1",
        [userId]
      );
      if (patientRows.length === 0 || Number(patientRows[0].patient_id) !== patientId) {
        return res.status(403).json({ message: 'Forbidden patient access' });
      }
    }

    const [rows] = await db.query(
      `SELECT
         a.appointment_id,
         a.doctor_id,
         a.patient_id,
         a.appointment_date,
         a.appointment_time,
         a.status,
         a.visit_type,
         ${selectAppointmentColumn(columns, 'actual_start_time')},
         ${selectAppointmentColumn(columns, 'actual_end_time')},
         ${selectAppointmentColumn(columns, 'live_tracking_enabled', '0')},
         ${selectAppointmentColumn(columns, 'doctor_live_latitude')},
         ${selectAppointmentColumn(columns, 'doctor_live_longitude')},
         ${selectAppointmentColumn(columns, 'current_eta_minutes')},
         ${selectAppointmentColumn(columns, 'last_location_updated_at')},
         d.name AS doctor_name,
         p.name AS patient_name,
         p.address AS patient_address,
         p.city AS patient_city,
         p.latitude AS patient_latitude,
         p.longitude AS patient_longitude
       FROM appointments a
       JOIN doctors d ON d.doctor_id = a.doctor_id
       JOIN patients p ON p.patient_id = a.patient_id
       WHERE a.patient_id = ?
         AND a.visit_type = 'HOME'
         AND a.status IN ('APPROVED', 'IN_PROGRESS', 'COMPLETED')
       ORDER BY a.appointment_id DESC`,
      [patientId]
    );

    const todayRows = rows.filter((row) => isToday(row.appointment_date));
    if (todayRows.length === 0) {
      return res.json({ tracking: null });
    }

    todayRows.sort((a, b) => {
      const rank = (row) => {
        const status = String(row.status || '').toUpperCase();
        if (Number(row.live_tracking_enabled) === 1) return 0;
        if (status === 'IN_PROGRESS') return 1;
        if (status === 'APPROVED') return 2;
        if (status === 'COMPLETED') return 3;
        return 4;
      };
      return rank(a) - rank(b);
    });

    return res.json({ tracking: todayRows[0] });
  } catch (err) {
    console.error('getPatientHomeVisitTracking error:', err);
    return res.status(500).json({ message: 'Failed to fetch home visit tracking' });
  }
}

module.exports = {
  getAppointments,
  createAppointment,
  updateAppointmentStatus,
  cancelAppointment,
  confirmSuggestedAppointment,
  rescheduleSuggestedAppointment,
  updateHomeVisitLiveTracking,
  stopDoctorHomeVisitDay,
  getPatientHomeVisitTracking,
};
