// Routes/noteRoutes.js
import express from "express";
import { verifyToken } from "../Middleware/authMiddleware.js";
import {
  createNote,
  getNotes,
  getNoteById,
  updateNote,
  deleteNote,
} from "../Controllers/noteController.js";

const router = express.Router();

// ✅ Create a note
router.post("/", verifyToken, createNote);

// ✅ Get all notes for logged-in user
router.get("/", verifyToken, getNotes);

// ✅ Get a single note by ID
router.get("/:id", verifyToken, getNoteById);

// ✅ Update a note
router.put("/:id", verifyToken, updateNote);

// ✅ Delete a note
router.delete("/:id", verifyToken, deleteNote);

export default router;