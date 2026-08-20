const express = require("express");
const {
  getDoctorPayments,
  getPatientPayments,
  getAdminPayments,
  getPaymentById,
  createPaymentOrder,
  confirmPatientPayment,
  failPatientPayment,
  markPaymentPaid,
  markPaymentPartial,
} = require("../controllers/paymentsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.get(
  "/doctor/payments",
  verifyToken,
  requireRoles("DOCTOR"),
  getDoctorPayments
);
router.get(
  "/patient/payments",
  verifyToken,
  requireRoles("PATIENT"),
  getPatientPayments
);
router.get(
  "/patient/payment/:id",
  verifyToken,
  requireRoles("PATIENT"),
  getPaymentById
);
router.post(
  "/payments/create-order",
  verifyToken,
  requireRoles("PATIENT"),
  createPaymentOrder
);
router.post(
  "/payments/confirm",
  verifyToken,
  requireRoles("PATIENT"),
  confirmPatientPayment
);
router.post(
  "/payments/fail",
  verifyToken,
  requireRoles("PATIENT"),
  failPatientPayment
);
router.get(
  "/admin/payments",
  verifyToken,
  requireRoles("ADMIN"),
  getAdminPayments
);
router.put(
  "/payments/:id/mark-paid",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  markPaymentPaid
);
router.put(
  "/payments/:id/mark-partial",
  verifyToken,
  requireRoles("DOCTOR", "ADMIN"),
  markPaymentPartial
);

module.exports = router;
