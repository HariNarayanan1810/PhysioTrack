const express = require("express");
const {
  getPatientTreatment,
  getPatientExercises,
  markExerciseDone,
} = require("../controllers/patientTreatmentController");

const router = express.Router();

router.get("/patients/treatment/:patientId", getPatientTreatment);
router.get("/patients/exercises/:patientId(\\d+)", getPatientExercises);
router.post("/patients/exercises/mark-done", markExerciseDone);

module.exports = router;
