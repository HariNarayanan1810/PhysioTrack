const db = require("../db");
const Razorpay = require("razorpay");
const crypto = require("crypto");

async function resolveUserScope(firebaseUid) {
  const [rows] = await db.query(
    "SELECT id, role FROM users WHERE firebase_uid = ? LIMIT 1",
    [firebaseUid]
  );
  if (rows.length === 0) {
    return null;
  }

  const userId = rows[0].id;
  const role = String(rows[0].role || "").toUpperCase();

  let doctorId = null;
  let patientId = null;
  if (role === "DOCTOR") {
    const [doctorRows] = await db.query(
      "SELECT doctor_id FROM doctors WHERE user_id = ? LIMIT 1",
      [userId]
    );
    if (doctorRows.length > 0) {
      doctorId = doctorRows[0].doctor_id;
    }
  }
  if (role === "PATIENT") {
    const [patientRows] = await db.query(
      "SELECT patient_id FROM patients WHERE user_id = ? LIMIT 1",
      [userId]
    );
    if (patientRows.length > 0) {
      patientId = patientRows[0].patient_id;
    }
  }

  return { userId, role, doctorId, patientId };
}

function parseAmount(value) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount < 0) return null;
  return Math.round(amount * 100) / 100;
}

function allowedPaymentMethods() {
  return new Set(["cash", "online", "credit", "debit", "razorpay"]);
}

function getRazorpayConfig() {
  const keyId = String(process.env.RAZORPAY_KEY_ID || "").trim();
  const keySecret = String(process.env.RAZORPAY_KEY_SECRET || "").trim();
  if (!keyId || !keySecret) return null;
  return { keyId, keySecret };
}

function getRazorpayClient() {
  const config = getRazorpayConfig();
  if (!config) return null;
  return new Razorpay({
    key_id: config.keyId,
    key_secret: config.keySecret,
  });
}

async function getDoctorPayments(req, res) {
  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.doctorId) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [rows] = await db.query(
      `SELECT
         p.id,
         p.appointment_id,
         p.patient_id,
         p.doctor_id,
         p.amount,
         p.payment_method,
         p.payment_status,
         p.payment_date,
         p.created_at,
         a.appointment_date,
         a.appointment_time,
         a.visit_type,
         pt.name AS patient_name,
         d.name AS doctor_name
       FROM payments p
       JOIN appointments a ON a.appointment_id = p.appointment_id
       JOIN patients pt ON pt.patient_id = p.patient_id
       JOIN doctors d ON d.doctor_id = p.doctor_id
       WHERE p.doctor_id = ?
       ORDER BY p.created_at DESC`,
      [scope.doctorId]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getDoctorPayments error:", err);
    return res.status(500).json({ message: "Failed to fetch doctor payments" });
  }
}

async function getPatientPayments(req, res) {
  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.patientId) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT
         p.id,
         p.appointment_id,
         p.patient_id,
         p.doctor_id,
         p.amount,
         p.payment_method,
         p.payment_status,
         p.payment_date,
         p.created_at,
         a.appointment_date,
         a.appointment_time,
         a.visit_type,
         pt.name AS patient_name,
         d.name AS doctor_name
       FROM payments p
       JOIN appointments a ON a.appointment_id = p.appointment_id
       JOIN patients pt ON pt.patient_id = p.patient_id
       JOIN doctors d ON d.doctor_id = p.doctor_id
       WHERE p.patient_id = ?
       ORDER BY p.created_at DESC`,
      [scope.patientId]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getPatientPayments error:", err);
    return res.status(500).json({ message: "Failed to fetch patient payments" });
  }
}

async function getPaymentById(req, res) {
  const paymentId = Number(req.params.id);
  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.patientId) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT
         p.id,
         p.appointment_id,
         p.patient_id,
         p.doctor_id,
         p.amount,
         p.payment_method,
         p.payment_status,
         p.payment_date,
         p.created_at,
         a.appointment_date,
         a.appointment_time,
         a.visit_type,
         pt.name AS patient_name,
         pt.email AS patient_email,
         pt.phone AS patient_phone,
         d.name AS doctor_name
       FROM payments p
       JOIN appointments a ON a.appointment_id = p.appointment_id
       JOIN patients pt ON pt.patient_id = p.patient_id
       JOIN doctors d ON d.doctor_id = p.doctor_id
       WHERE p.id = ? AND p.patient_id = ?
       LIMIT 1`,
      [paymentId, scope.patientId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    return res.json(rows[0]);
  } catch (err) {
    console.error("getPaymentById error:", err);
    return res.status(500).json({ message: "Failed to fetch payment details" });
  }
}

async function createPaymentOrder(req, res) {
  const paymentId = Number(req.body.payment_id);
  const amount = parseAmount(req.body.amount);

  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.patientId) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [rows] = await db.query(
      `SELECT id, amount, payment_status
       FROM payments
       WHERE id = ? AND patient_id = ?
       LIMIT 1`,
      [paymentId, scope.patientId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    const row = rows[0];
    if (String(row.payment_status || "").toLowerCase() === "paid") {
      return res.status(400).json({ message: "Payment already completed" });
    }

    const finalAmount = amount == null ? Number(row.amount || 0) : amount;
    const amountInPaise = Math.round(finalAmount * 100);
    const config = getRazorpayConfig();
    const client = getRazorpayClient();

    if (!config || !client) {
      return res.status(503).json({
        message: "Razorpay keys not configured in backend environment",
      });
    }

    const order = await client.orders.create({
      amount: amountInPaise,
      currency: "INR",
      receipt: `pay_${paymentId}_${Date.now()}`,
      notes: {
        payment_id: String(paymentId),
      },
    });

    try {
      await db.query(
        `UPDATE payments
         SET razorpay_order_id = ?, payment_method = 'razorpay'
         WHERE id = ? AND patient_id = ?`,
        [order.id, paymentId, scope.patientId]
      );
    } catch (e) {
      // Backward compatibility if migration not applied yet.
      await db.query(
        `UPDATE payments
         SET payment_method = 'razorpay'
         WHERE id = ? AND patient_id = ?`,
        [paymentId, scope.patientId]
      );
    }

    return res.json({
      payment_id: paymentId,
      razorpay_order_id: order.id,
      amount: amountInPaise,
      currency: "INR",
      key: config.keyId,
    });
  } catch (err) {
    console.error("createPaymentOrder error:", err);
    return res.status(500).json({ message: "Failed to create payment order" });
  }
}

async function confirmPatientPayment(req, res) {
  const paymentId = Number(req.body.payment_id);
  const razorpayOrderId = String(req.body.razorpay_order_id || "").trim();
  const razorpayPaymentId = String(req.body.razorpay_payment_id || "").trim();
  const razorpaySignature = String(req.body.razorpay_signature || "").trim();

  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }
  if (!razorpayOrderId) {
    return res.status(400).json({ message: "razorpay_order_id is required" });
  }
  if (!razorpayPaymentId) {
    return res.status(400).json({ message: "razorpay_payment_id is required" });
  }
  if (!razorpaySignature) {
    return res.status(400).json({ message: "razorpay_signature is required" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.patientId) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [paymentRows] = await db.query(
      `SELECT id, razorpay_order_id
       FROM payments
       WHERE id = ? AND patient_id = ?
       LIMIT 1`,
      [paymentId, scope.patientId]
    );
    if (paymentRows.length === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    const storedOrderId = String(paymentRows[0].razorpay_order_id || "").trim();
    if (!storedOrderId || storedOrderId !== razorpayOrderId) {
      return res.status(400).json({ message: "Invalid Razorpay order id" });
    }

    const config = getRazorpayConfig();
    const client = getRazorpayClient();
    if (!config || !client) {
      return res.status(503).json({
        message: "Razorpay keys not configured in backend environment",
      });
    }

    const expectedSignature = crypto
      .createHmac("sha256", config.keySecret)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest("hex");
    if (expectedSignature !== razorpaySignature) {
      return res.status(400).json({ message: "Invalid payment signature" });
    }

    const razorpayPayment = await client.payments.fetch(razorpayPaymentId);
    const razorpayStatus = String(razorpayPayment?.status || "").toLowerCase();
    if (!["captured", "authorized"].includes(razorpayStatus)) {
      return res.status(400).json({ message: "Payment not completed in Razorpay" });
    }

    let result;
    try {
      [result] = await db.query(
        `UPDATE payments
         SET payment_status = 'paid',
             payment_method = 'razorpay',
             razorpay_order_id = ?,
             razorpay_payment_id = ?,
             payment_date = NOW()
         WHERE id = ? AND patient_id = ?`,
        [razorpayOrderId, razorpayPaymentId, paymentId, scope.patientId]
      );
    } catch (e) {
      // Backward compatibility if migration not applied yet.
      [result] = await db.query(
        `UPDATE payments
         SET payment_status = 'paid',
             payment_method = 'razorpay',
             payment_date = NOW()
         WHERE id = ? AND patient_id = ?`,
        [paymentId, scope.patientId]
      );
    }

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    return res.json({ message: "Payment confirmed successfully" });
  } catch (err) {
    console.error("confirmPatientPayment error:", err);
    return res.status(500).json({ message: "Failed to confirm payment" });
  }
}

async function failPatientPayment(req, res) {
  const paymentId = Number(req.body.payment_id);
  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope || !scope.patientId) {
      return res.status(404).json({ message: "Patient profile not found" });
    }

    const [result] = await db.query(
      `UPDATE payments
       SET payment_status = 'failed'
       WHERE id = ? AND patient_id = ? AND payment_status <> 'paid'`,
      [paymentId, scope.patientId]
    );

    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    return res.json({ message: "Payment marked as failed" });
  } catch (err) {
    console.error("failPatientPayment error:", err);
    return res.status(500).json({ message: "Failed to update failed status" });
  }
}

async function getAdminPayments(req, res) {
  try {
    const [rows] = await db.query(
      `SELECT
         p.id,
         p.appointment_id,
         p.patient_id,
         p.doctor_id,
         p.amount,
         p.payment_method,
         p.payment_status,
         p.payment_date,
         p.created_at,
         a.appointment_date,
         a.appointment_time,
         a.visit_type,
         pt.name AS patient_name,
         d.name AS doctor_name
       FROM payments p
       JOIN appointments a ON a.appointment_id = p.appointment_id
       JOIN patients pt ON pt.patient_id = p.patient_id
       JOIN doctors d ON d.doctor_id = p.doctor_id
       ORDER BY p.created_at DESC`
    );

    const [summaryRows] = await db.query(
      `SELECT
         COALESCE(SUM(CASE WHEN payment_status = 'paid' THEN amount ELSE 0 END), 0) AS total_earnings,
         COALESCE(SUM(CASE WHEN payment_status = 'pending' THEN amount ELSE 0 END), 0) AS pending_amount,
         SUM(CASE WHEN payment_status = 'pending' THEN 1 ELSE 0 END) AS pending_count
       FROM payments`
    );

    return res.json({
      summary: summaryRows[0] || {
        total_earnings: 0,
        pending_amount: 0,
        pending_count: 0,
      },
      payments: rows,
    });
  } catch (err) {
    console.error("getAdminPayments error:", err);
    return res.status(500).json({ message: "Failed to fetch payments" });
  }
}

async function markPaymentPaid(req, res) {
  const paymentId = Number(req.params.id);
  const paymentMethod = String(req.body.payment_method || "cash").toLowerCase();
  const allowedMethods = allowedPaymentMethods();

  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }
  if (!allowedMethods.has(paymentMethod)) {
    return res.status(400).json({ message: "Invalid payment method" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope) {
      return res.status(401).json({ message: "Unauthorized user" });
    }

    const whereClause = scope.role === "ADMIN" ? "" : " AND doctor_id = ?";
    const params = scope.role === "ADMIN"
      ? [paymentMethod, paymentId]
      : [paymentMethod, paymentId, scope.doctorId];

    const [result] = await db.query(
      `UPDATE payments
       SET payment_status = 'paid', payment_method = ?, payment_date = NOW()
       WHERE id = ?${whereClause}`,
      params
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }
    return res.json({ message: "Payment marked as paid" });
  } catch (err) {
    console.error("markPaymentPaid error:", err);
    return res.status(500).json({ message: "Failed to mark payment as paid" });
  }
}

async function markPaymentPartial(req, res) {
  const paymentId = Number(req.params.id);
  const amount = parseAmount(req.body.amount);
  const paymentMethod = String(req.body.payment_method || "cash").toLowerCase();
  const allowedMethods = allowedPaymentMethods();

  if (!Number.isInteger(paymentId) || paymentId <= 0) {
    return res.status(400).json({ message: "Invalid payment id" });
  }
  if (amount == null) {
    return res.status(400).json({ message: "Invalid amount" });
  }
  if (!allowedMethods.has(paymentMethod)) {
    return res.status(400).json({ message: "Invalid payment method" });
  }

  try {
    const scope = await resolveUserScope(req.user?.firebase_uid);
    if (!scope) {
      return res.status(401).json({ message: "Unauthorized user" });
    }

    const whereClause = scope.role === "ADMIN" ? "" : " AND doctor_id = ?";
    const selectParams = scope.role === "ADMIN" ? [paymentId] : [paymentId, scope.doctorId];
    const [rows] = await db.query(
      `SELECT id, amount FROM payments WHERE id = ?${whereClause} LIMIT 1`,
      selectParams
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Payment not found" });
    }

    if (amount >= Number(rows[0].amount)) {
      return res.status(400).json({ message: "Partial amount should be less than full amount" });
    }

    const updateParams = scope.role === "ADMIN"
      ? [amount, paymentMethod, paymentId]
      : [amount, paymentMethod, paymentId, scope.doctorId];
    await db.query(
      `UPDATE payments
       SET amount = ?, payment_status = 'partial', payment_method = ?, payment_date = NOW()
       WHERE id = ?${whereClause}`,
      updateParams
    );
    return res.json({ message: "Payment marked as partial" });
  } catch (err) {
    console.error("markPaymentPartial error:", err);
    return res.status(500).json({ message: "Failed to mark partial payment" });
  }
}

module.exports = {
  getDoctorPayments,
  getPatientPayments,
  getAdminPayments,
  getPaymentById,
  createPaymentOrder,
  confirmPatientPayment,
  failPatientPayment,
  markPaymentPaid,
  markPaymentPartial,
};
