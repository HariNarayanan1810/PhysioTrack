const express = require("express");
const fs = require("fs");
const path = require("path");
const multer = require("multer");
const {
  getDoctorDashboardSummary,
  getDoctorTodaySchedule,
  getRecentDoctorBlogs,
  getDoctorBlogFeed,
  getMyDoctorBlogs,
  getDoctorBlogById,
  createDoctorBlog,
  updateDoctorBlog,
} = require("../controllers/doctorPortalController");
const { verifyToken, requireRoles } = require("../middleware/auth");

const router = express.Router();

const blogsUploadDir = path.join(__dirname, "..", "uploads", "blogs");
if (!fs.existsSync(blogsUploadDir)) {
  fs.mkdirSync(blogsUploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, blogsUploadDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname || "").toLowerCase();
    const safeExt = ext || ".jpg";
    cb(null, `blog-${Date.now()}${safeExt}`);
  },
});
const upload = multer({ storage });

router.get(
  "/doctor/dashboard-summary",
  verifyToken,
  requireRoles("DOCTOR"),
  getDoctorDashboardSummary
);
router.get(
  "/doctor/today-schedule",
  verifyToken,
  requireRoles("DOCTOR"),
  getDoctorTodaySchedule
);
router.get(
  "/doctor/blogs/recent",
  verifyToken,
  requireRoles("DOCTOR"),
  getRecentDoctorBlogs
);
router.get(
  "/doctor/blogs/feed",
  verifyToken,
  requireRoles("DOCTOR", "PATIENT"),
  getDoctorBlogFeed
);
router.get(
  "/doctor/blogs/mine",
  verifyToken,
  requireRoles("DOCTOR"),
  getMyDoctorBlogs
);
router.get(
  "/doctor/blogs/:id",
  verifyToken,
  requireRoles("DOCTOR", "PATIENT"),
  getDoctorBlogById
);
router.post(
  "/doctor/blogs",
  verifyToken,
  requireRoles("DOCTOR"),
  createDoctorBlog
);
router.put(
  "/doctor/blogs/:id",
  verifyToken,
  requireRoles("DOCTOR"),
  updateDoctorBlog
);
router.post(
  "/doctor/blogs/upload-image",
  verifyToken,
  requireRoles("DOCTOR"),
  upload.single("image"),
  (req, res) => {
    if (!req.file) {
      return res.status(400).json({ message: "No image uploaded" });
    }
    return res.status(201).json({
      media_url: `/uploads/blogs/${req.file.filename}`,
    });
  }
);

module.exports = router;
