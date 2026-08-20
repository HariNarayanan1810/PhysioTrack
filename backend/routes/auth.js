const express = require("express");
const { register, login, getUserById } = require("../controllers/authController");
const { verifyToken } = require("../middleware/auth");

const router = express.Router();

router.post("/register", verifyToken, register);
router.post("/login", verifyToken, login);
router.get("/users/:id", getUserById);

module.exports = router;
