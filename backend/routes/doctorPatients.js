const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const {
  getDoctorPatients,
  getDoctorPatientDetail,
  getDoctorPatientCompletedDays,
  createProblem,
  updateProblem,
  createMedia,
  deleteMedia,
  createExercise,
  deleteExercise,
  createAdvice,
  deleteAdvice,
} = require("../controllers/doctorPatientsController");

const router = express.Router();

const uploadDir = path.join(__dirname, "..", "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase();
    const safeExt = ext || ".bin";
    cb(null, `doctor-patient-${Date.now()}${safeExt}`);
  },
});
const upload = multer({ storage });

router.get("/doctor/patients/:doctorId", getDoctorPatients);
router.get("/doctor/patient/:doctorId/:patientId", getDoctorPatientDetail);
router.get(
  "/doctor/patient/:doctorId/:patientId/completed-days",
  getDoctorPatientCompletedDays
);
router.post("/doctor/patient/problem", createProblem);
router.put("/doctor/patient/problem", updateProblem);
router.post("/doctor/patient/media", upload.single("file"), createMedia);
router.delete("/doctor/patient/media/:id", deleteMedia);
router.post("/doctor/patient/exercise", createExercise);
router.delete("/doctor/patient/exercise/:id", deleteExercise);
router.post("/doctor/patient/advice", createAdvice);
router.delete("/doctor/patient/advice/:id", deleteAdvice);

module.exports = router;
