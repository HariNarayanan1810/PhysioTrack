const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const {
  getPatients,
  getPatientById,
  getPatientProfile,
  createPatientProfile,
  updatePatientProfile,
  uploadPatientProfileImage,
  removePatient,
} = require("../controllers/patientsController");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase();
    const safeExt = ext || ".jpg";
    cb(null, `patient-${Date.now()}${safeExt}`);
  },
});

const upload = multer({ storage });

router.get("/", getPatients);
router.get("/profile", verifyToken, getPatientProfile);
router.post("/profile", verifyToken, createPatientProfile);
router.put("/profile", verifyToken, updatePatientProfile);
router.post(
  "/profile-image",
  verifyToken,
  upload.single("profile_image"),
  uploadPatientProfileImage
);
router.get("/:id", getPatientById);
router.put("/:id/remove", removePatient);

module.exports = router;
