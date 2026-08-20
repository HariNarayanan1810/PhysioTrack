const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");

const {
  createVerificationRequest,
  getVerificationRequests,
  getVerificationRequestById,
  approveVerificationRequest,
  rejectVerificationRequest,
  uploadVerificationDocument,
} = require("../controllers/verificationRequestsController");

const router = express.Router();

const uploadDir = path.join(__dirname, "..", "uploads", "verification_docs");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${Date.now()}-${Math.round(Math.random() * 1e9)}${ext}`);
  },
});

const allowedExtensions = [".pdf", ".doc", ".docx"];
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (!allowedExtensions.includes(ext)) {
      return cb(new Error("Only PDF/DOC/DOCX files are allowed"));
    }
    cb(null, true);
  },
});

router.post(
  "/verification-request/upload-document",
  upload.single("file"),
  uploadVerificationDocument
);
router.post("/verification-request", createVerificationRequest);
router.get("/verification-requests", getVerificationRequests);
router.get("/verification-request/:id", getVerificationRequestById);
router.put("/verification-request/:id/approve", approveVerificationRequest);
router.put("/verification-request/:id/reject", rejectVerificationRequest);

module.exports = router;
