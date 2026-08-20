require("dotenv").config();
const express = require("express");
const cors = require("cors");
const path = require("path");

const doctorsRoutes = require("./routes/doctors");
const patientsRoutes = require("./routes/patients");
const appointmentsRoutes = require("./routes/appointments");
const verificationRequestsRoutes = require("./routes/verificationRequests");
const authRoutes = require("./routes/auth");
const exercisesRoutes = require("./routes/exercises");
const reviewsRoutes = require("./routes/reviews");
const doctorPatientsRoutes = require("./routes/doctorPatients");
const patientTreatmentRoutes = require("./routes/patientTreatment");
const patientDailyExercisesRoutes = require("./routes/patientDailyExercises");
const paymentsRoutes = require("./routes/payments");
const doctorPortalRoutes = require("./routes/doctorPortal");
const discussionsRoutes = require("./routes/discussions");
const mapsRoutes = require("./routes/maps");
const devicesRoutes = require("./routes/devices");
const reportsRoutes = require("./routes/reports");

const app = express();
app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/", (_req, res) => {
  res.send("PhysioTrack API");
});

app.use("/doctors", doctorsRoutes);
app.use("/patients", patientsRoutes);
app.use("/appointments", appointmentsRoutes);
app.use("/exercises", exercisesRoutes);
app.use("/reviews", reviewsRoutes);
app.use("/", doctorPatientsRoutes);
app.use("/", patientDailyExercisesRoutes);
app.use("/", patientTreatmentRoutes);
app.use("/", paymentsRoutes);
app.use("/", doctorPortalRoutes);
app.use("/", discussionsRoutes);
app.use("/", mapsRoutes);
app.use("/", devicesRoutes);
app.use("/", reportsRoutes);
app.use("/", verificationRequestsRoutes);
app.use("/", authRoutes);

const PORT = 4000;
app.listen(PORT, () => {
  console.log(`Server running at http://localhost:${PORT}`);
});
