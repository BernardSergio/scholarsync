import express from "express";
import mongoose from "mongoose";
import dotenv from "dotenv";
import cors from "cors";
import authRoutes from "./Routes/authRoutes.js";
import moodRoutes from "./Routes/moodRoutes.js";
import medicationRoutes from "./Routes/medicationRoutes.js";
import noteRoutes from "./Routes/noteRoutes.js"; 
import appointmentRoutes from "./Routes/appointmentRoutes.js";
import reminderRoutes from "./Routes/reminderRoutes.js"; 
import { verifyToken } from "./Middleware/authMiddleware.js";

dotenv.config();
const app = express();

app.use(express.json());
app.use(cors());
app.use((req, res, next) => {
  console.log(`📨 ${req.method} ${req.path}`);
  next();
});
// ✅ Connect to MongoDB
mongoose
  .connect(process.env.MONGO_URI)
  .then(() => console.log("✅ Connected to MongoDB"))
  .catch((err) => console.log("❌ MongoDB connection error:", err));

// ✅ Simple public route
app.get("/", (req, res) => {
  res.send("Backend is running...");
});

// ✅ Authentication routes
app.use("/api/auth", authRoutes);

// ✅ MoodLog routes
app.use("/api/moods", moodRoutes);

// ✅ MedicationLog routes
app.use("/api/medications", medicationRoutes);

// ✅ Note routes
app.use("/api/notes", noteRoutes); 

// ✅ Appointment routes 
app.use("/api/appointments", appointmentRoutes);

// ✅ Reminder routes
app.use("/api/reminders", reminderRoutes);

// ✅ Protected test route
app.get("/api/protected", verifyToken, (req, res) => {
  res.json({
    message: `Welcome ${req.user.username}, you accessed a protected route!`,
  });
});

// ✅ Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`🚀 Server running on port ${PORT}`));