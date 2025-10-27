// Routes/appointmentRoutes.js
import express from "express";
import { verifyToken } from "../Middleware/authMiddleware.js";
import {
  createAppointment,
  getAppointments,
  getAppointmentById,
  updateAppointment,
  deleteAppointment,
} from "../Controllers/appointmentController.js";

const router = express.Router();

// ✅ Create an appointment
router.post("/", verifyToken, createAppointment);

// ✅ Get all appointments for logged-in user
router.get("/", verifyToken, getAppointments);

// ✅ Get a single appointment by ID
router.get("/:id", verifyToken, getAppointmentById);

// ✅ Update an appointment
router.put("/:id", verifyToken, updateAppointment);

// ✅ Delete an appointment
router.delete("/:id", verifyToken, deleteAppointment);

export default router;