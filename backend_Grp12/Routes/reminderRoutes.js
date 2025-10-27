// Routes/reminderRoutes.js
import express from "express";
import { verifyToken } from "../Middleware/authMiddleware.js";
import { 
  createReminder, 
  getReminders, 
  toggleTaken, 
  deleteReminder 
} from "../Controllers/reminderController.js";

const router = express.Router();

router.post("/", verifyToken, createReminder);
router.get("/", verifyToken, getReminders);
router.put("/:id/toggle", verifyToken, toggleTaken);
router.delete("/:id", verifyToken, deleteReminder);

export default router;
