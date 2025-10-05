// Routes/noteRoutes.js
import express from "express";
import Note from "../Models/Note.js";
import { verifyToken } from "../Middleware/authMiddleware.js";

const router = express.Router();

// ✅ Create a note
router.post("/", verifyToken, async (req, res) => {
  try {
    const { title, content, tags } = req.body;
    const newNote = new Note({
      userId: req.user.id,
      title,
      content,
      tags,
    });
    await newNote.save();
    res.status(201).json({ message: "Note created successfully!", note: newNote });
  } catch (err) {
    res.status(500).json({ message: "Error creating note", error: err.message });
  }
});

// ✅ Get all notes for logged-in user
router.get("/", verifyToken, async (req, res) => {
  try {
    const notes = await Note.find({ userId: req.user.id });
    res.json(notes);
  } catch (err) {
    res.status(500).json({ message: "Error fetching notes", error: err.message });
  }
});

// ✅ Update a note
router.put("/:id", verifyToken, async (req, res) => {
  try {
    const updated = await Note.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      req.body,
      { new: true }
    );
    if (!updated) return res.status(404).json({ message: "Note not found" });
    res.json({ message: "Note updated successfully!", note: updated });
  } catch (err) {
    res.status(500).json({ message: "Error updating note", error: err.message });
  }
});

// ✅ Delete a note
router.delete("/:id", verifyToken, async (req, res) => {
  try {
    const deleted = await Note.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });
    if (!deleted) return res.status(404).json({ message: "Note not found" });
    res.json({ message: "Note deleted successfully!" });
  } catch (err) {
    res.status(500).json({ message: "Error deleting note", error: err.message });
  }
});

export default router;
