// Routes/moodRoutes.js
import express from "express";
import { verifyToken } from "../Middleware/authMiddleware.js";
import { 
  createMood, 
  getMoods, 
  updateMood, 
  deleteMood 
} from "../Controllers/moodController.js";

const router = express.Router();

router.post("/", verifyToken, createMood);
router.get("/", verifyToken, getMoods);
router.put("/:id", verifyToken, updateMood);
router.delete("/:id", verifyToken, deleteMood);

export default router;