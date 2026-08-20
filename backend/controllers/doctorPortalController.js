const db = require("../db");

function parseAppointmentDate(value) {
  const text = String(value || "").trim();
  if (!text) return null;

  // Parse explicit local date formats first to avoid JS Date locale ambiguity.
  const dashParts = text.split("-");
  if (dashParts.length === 3) {
    if (dashParts[0].length === 2 && dashParts[2].length === 4) {
      const day = Number(dashParts[0]);
      const month = Number(dashParts[1]);
      const year = Number(dashParts[2]);
      if (day && month && year) return new Date(year, month - 1, day);
    }
    if (dashParts[0].length === 4) {
      const year = Number(dashParts[0]);
      const month = Number(dashParts[1]);
      const day = Number(dashParts[2]);
      if (day && month && year) return new Date(year, month - 1, day);
    }
  }

  const slashParts = text.split("/");
  if (slashParts.length === 3) {
    if (slashParts[0].length <= 2 && slashParts[2].length === 4) {
      const day = Number(slashParts[0]);
      const month = Number(slashParts[1]);
      const year = Number(slashParts[2]);
      if (day && month && year) return new Date(year, month - 1, day);
    }
    if (slashParts[0].length === 4) {
      const year = Number(slashParts[0]);
      const month = Number(slashParts[1]);
      const day = Number(slashParts[2]);
      if (day && month && year) return new Date(year, month - 1, day);
    }
  }

  const parsed = new Date(text);
  if (!Number.isNaN(parsed.getTime())) return parsed;
  return null;
}

function parseTimeToMinutes(value) {
  const text = String(value || "").trim().toUpperCase();
  const match = text.match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/);
  if (!match) return 0;
  let hour = Number(match[1]);
  const mins = Number(match[2]);
  const suffix = match[3] || "";
  if (suffix === "PM" && hour < 12) hour += 12;
  if (suffix === "AM" && hour === 12) hour = 0;
  return hour * 60 + mins;
}

function sameDate(a, b) {
  return (
    a.getFullYear() === b.getFullYear() &&
    a.getMonth() === b.getMonth() &&
    a.getDate() === b.getDate()
  );
}

async function resolveDoctorByFirebaseUid(firebaseUid) {
  const [rows] = await db.query(
    `SELECT d.doctor_id, d.verification_status, u.email
     FROM users u
     JOIN doctors d ON d.user_id = u.id
     WHERE u.firebase_uid = ?
     LIMIT 1`,
    [firebaseUid]
  );
  if (rows.length === 0) return null;
  return rows[0];
}

async function getDoctorDashboardSummary(req, res) {
  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }
    const doctorId = doctor.doctor_id;
    const today = new Date();

    const [appointments] = await db.query(
      `SELECT appointment_id, appointment_date, visit_type, status
       FROM appointments
       WHERE doctor_id = ?`,
      [doctorId]
    );

    const todaysAppointments = appointments.filter((row) => {
      const dt = parseAppointmentDate(row.appointment_date);
      const status = String(row.status || "").toUpperCase();
      return dt && sameDate(dt, today) && ["APPROVED", "COMPLETED"].includes(status);
    });
    const todaysHomeVisits = todaysAppointments.filter(
      (row) => String(row.visit_type || "").toUpperCase() === "HOME"
    );

    const [payments] = await db.query(
      `SELECT amount, payment_status, payment_date
       FROM payments
       WHERE doctor_id = ?`,
      [doctorId]
    );
    const month = today.getMonth();
    const year = today.getFullYear();
    const monthlyEarnings = payments.reduce((sum, row) => {
      if (String(row.payment_status || "").toLowerCase() !== "paid") return sum;
      if (!row.payment_date) return sum;
      const dt = new Date(row.payment_date);
      if (Number.isNaN(dt.getTime())) return sum;
      if (dt.getMonth() !== month || dt.getFullYear() !== year) return sum;
      return sum + Number(row.amount || 0);
    }, 0);

    return res.json({
      todaysAppointmentsCount: todaysAppointments.length,
      todaysHomeVisitsCount: todaysHomeVisits.length,
      monthlyEarnings,
      verificationStatus: String(doctor.verification_status || "not_applied").toLowerCase(),
      email: doctor.email || "",
    });
  } catch (err) {
    console.error("getDoctorDashboardSummary error:", err);
    return res.status(500).json({ message: "Failed to load dashboard summary" });
  }
}

async function getDoctorTodaySchedule(req, res) {
  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }
    const today = new Date();
    const [rows] = await db.query(
      `SELECT
         a.appointment_id,
         a.appointment_date,
         a.appointment_time,
         a.visit_type,
         a.status,
         p.patient_id,
         p.name AS patient_name
       FROM appointments a
       JOIN patients p ON p.patient_id = a.patient_id
       WHERE a.doctor_id = ?
         AND a.status IN ('APPROVED', 'COMPLETED')`,
      [doctor.doctor_id]
    );

    const schedule = rows
      .filter((row) => {
        const dt = parseAppointmentDate(row.appointment_date);
        return dt && sameDate(dt, today);
      })
      .sort(
        (a, b) =>
          parseTimeToMinutes(a.appointment_time) -
          parseTimeToMinutes(b.appointment_time)
      );

    return res.json(schedule);
  } catch (err) {
    console.error("getDoctorTodaySchedule error:", err);
    return res.status(500).json({ message: "Failed to load today's schedule" });
  }
}

async function getRecentDoctorBlogs(req, res) {
  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [rows] = await db.query(
      `SELECT id, doctor_id, title, short_description, content, media_url, status, created_at
       FROM doctor_blogs
       WHERE doctor_id = ? AND status = 'published'
       ORDER BY created_at DESC
       LIMIT 3`,
      [doctor.doctor_id]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getRecentDoctorBlogs error:", err);
    return res.status(500).json({ message: "Failed to load blogs" });
  }
}

async function getDoctorBlogFeed(req, res) {
  const limit = Math.min(Number(req.query.limit) || 3, 20);
  try {
    const [rows] = await db.query(
      `SELECT
         b.id,
         b.doctor_id,
         b.title,
         b.short_description,
         b.content,
         b.media_url,
         b.status,
         b.created_at,
         b.updated_at,
         d.name AS doctor_name
       FROM doctor_blogs b
       JOIN doctors d ON d.doctor_id = b.doctor_id
       WHERE b.status = 'published' AND d.is_removed = 0
       ORDER BY b.created_at DESC
       LIMIT ?`,
      [limit]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getDoctorBlogFeed error:", err);
    return res.status(500).json({ message: "Failed to load blog feed" });
  }
}

async function getMyDoctorBlogs(req, res) {
  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [rows] = await db.query(
      `SELECT
         b.id,
         b.doctor_id,
         b.title,
         b.short_description,
         b.content,
         b.media_url,
         b.status,
         b.created_at,
         b.updated_at,
         d.name AS doctor_name
       FROM doctor_blogs b
       JOIN doctors d ON d.doctor_id = b.doctor_id
       WHERE b.doctor_id = ?
       ORDER BY b.created_at DESC`,
      [doctor.doctor_id]
    );
    return res.json(rows);
  } catch (err) {
    console.error("getMyDoctorBlogs error:", err);
    return res.status(500).json({ message: "Failed to load my blogs" });
  }
}

async function getDoctorBlogById(req, res) {
  const blogId = Number(req.params.id);
  if (!Number.isInteger(blogId) || blogId <= 0) {
    return res.status(400).json({ message: "Invalid blog id" });
  }

  try {
    const [rows] = await db.query(
      `SELECT
         b.id,
         b.doctor_id,
         b.title,
         b.short_description,
         b.content,
         b.media_url,
         b.status,
         b.created_at,
         b.updated_at,
         d.name AS doctor_name
       FROM doctor_blogs b
       JOIN doctors d ON d.doctor_id = b.doctor_id
       WHERE b.id = ?
       LIMIT 1`,
      [blogId]
    );
    if (rows.length === 0) {
      return res.status(404).json({ message: "Blog not found" });
    }
    const blog = rows[0];
    const isPublished = String(blog.status || "").toLowerCase() === "published";
    const role = String(req.user?.role || "").toUpperCase();

    if (role === "DOCTOR") {
      const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
      if (!doctor) {
        return res.status(404).json({ message: "Doctor profile not found" });
      }

      const isOwnBlog = Number(blog.doctor_id) === Number(doctor.doctor_id);
      if (!isOwnBlog && !isPublished) {
        return res.status(403).json({ message: "Access denied" });
      }
    } else if (!isPublished) {
      return res.status(403).json({ message: "Access denied" });
    }

    return res.json(blog);
  } catch (err) {
    console.error("getDoctorBlogById error:", err);
    return res.status(500).json({ message: "Failed to load blog" });
  }
}

async function createDoctorBlog(req, res) {
  const title = String(req.body.title || "").trim();
  const shortDescription = String(req.body.short_description || "").trim();
  const content = String(req.body.content || "").trim();
  const mediaUrl = String(req.body.media_url || "").trim();
  const status = String(req.body.status || "published").toLowerCase();

  if (!title || !shortDescription || !content) {
    return res.status(400).json({ message: "title, short_description and content are required" });
  }
  if (!["draft", "published"].includes(status)) {
    return res.status(400).json({ message: "Invalid blog status" });
  }

  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [result] = await db.query(
      `INSERT INTO doctor_blogs
        (doctor_id, title, short_description, content, media_url, status)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [doctor.doctor_id, title, shortDescription, content, mediaUrl || null, status]
    );

    return res.status(201).json({ id: result.insertId });
  } catch (err) {
    console.error("createDoctorBlog error:", err);
    return res.status(500).json({ message: "Failed to create blog" });
  }
}

async function updateDoctorBlog(req, res) {
  const blogId = Number(req.params.id);
  const title = String(req.body.title || "").trim();
  const shortDescription = String(req.body.short_description || "").trim();
  const content = String(req.body.content || "").trim();
  const mediaUrl = String(req.body.media_url || "").trim();
  const status = String(req.body.status || "published").toLowerCase();

  if (!Number.isInteger(blogId) || blogId <= 0) {
    return res.status(400).json({ message: "Invalid blog id" });
  }
  if (!title || !shortDescription || !content) {
    return res.status(400).json({ message: "title, short_description and content are required" });
  }
  if (!["draft", "published"].includes(status)) {
    return res.status(400).json({ message: "Invalid blog status" });
  }

  try {
    const doctor = await resolveDoctorByFirebaseUid(req.user?.firebase_uid);
    if (!doctor) {
      return res.status(404).json({ message: "Doctor profile not found" });
    }

    const [result] = await db.query(
      `UPDATE doctor_blogs
       SET title = ?, short_description = ?, content = ?, media_url = ?, status = ?, updated_at = CURRENT_TIMESTAMP
       WHERE id = ? AND doctor_id = ?`,
      [
        title,
        shortDescription,
        content,
        mediaUrl || null,
        status,
        blogId,
        doctor.doctor_id,
      ]
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ message: "Blog not found" });
    }
    return res.json({ message: "Blog updated successfully" });
  } catch (err) {
    console.error("updateDoctorBlog error:", err);
    return res.status(500).json({ message: "Failed to update blog" });
  }
}

module.exports = {
  getDoctorDashboardSummary,
  getDoctorTodaySchedule,
  getRecentDoctorBlogs,
  getDoctorBlogFeed,
  getMyDoctorBlogs,
  getDoctorBlogById,
  createDoctorBlog,
  updateDoctorBlog,
};
