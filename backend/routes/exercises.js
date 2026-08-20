const express = require("express");
const {
  getExercises,
  getExerciseLibrary,
  getExerciseLibraryById,
} = require("../controllers/exercisesController");

const router = express.Router();
router.get("/master", getExerciseLibrary);
router.get("/master/:id", getExerciseLibraryById);
router.get("/", getExercises);

module.exports = router;
