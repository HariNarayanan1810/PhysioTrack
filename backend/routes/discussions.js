const express = require("express");
const {
  getDiscussions,
  createQuestion,
  createAnswer,
} = require("../controllers/discussionsController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

router.get(
  "/discussions",
  verifyToken,
  requireRoles("DOCTOR", "PATIENT"),
  getDiscussions
);
router.post(
  "/discussions",
  verifyToken,
  requireRoles("PATIENT"),
  createQuestion
);
router.post(
  "/discussions/:id/answers",
  verifyToken,
  requireRoles("DOCTOR"),
  createAnswer
);

module.exports = router;
