// Routes/medicationRoutes.js
import express from "express";
import MedicationLog from "../Models/MedicationLog.js";
import { verifyToken } from "../Middleware/authMiddleware.js";

const router = express.Router();

// ✅ Create a new medication log
router.post("/", verifyToken, async (req, res) => {
  try {
    const { medicationName, dosage, notes } = req.body;
    const newLog = new MedicationLog({
      userId: req.user.id,
      medicationName,
      dosage,
      notes,
    });
    await newLog.save();
    res.status(201).json({ message: "Medication logged successfully!", newLog });
  } catch (error) {
    res.status(500).json({ message: "Error logging medication", error: error.message });
  }
});

export default router;
