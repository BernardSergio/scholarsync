// Controllers/noteController.js
import Note from "../Models/Note.js";

// ✅ Create a new note
export const createNote = async (req, res) => {
  try {
    const { title, content, tags } = req.body;

    // Validation
    if (!title || !content) {
      return res.status(400).json({ 
        message: "Title and content are required" 
      });
    }

    const newNote = new Note({
      userId: req.user.id,
      title,
      content,
      tags: tags || [],
    });

    await newNote.save();
    
    res.status(201).json({ 
      message: "Note created successfully!", 
      note: newNote 
    });
  } catch (err) {
    console.error("Error creating note:", err);
    res.status(500).json({ 
      message: "Error creating note", 
      error: err.message 
    });
  }
};

// ✅ Get all notes for logged-in user
export const getNotes = async (req, res) => {
  try {
    const notes = await Note.find({ userId: req.user.id })
      .sort({ createdAt: -1 }); // Most recent first
    
    res.json(notes);
  } catch (err) {
    console.error("Error fetching notes:", err);
    res.status(500).json({ 
      message: "Error fetching notes", 
      error: err.message 
    });
  }
};

// ✅ Get a single note by ID
export const getNoteById = async (req, res) => {
  try {
    const note = await Note.findOne({
      _id: req.params.id,
      userId: req.user.id
    });

    if (!note) {
      return res.status(404).json({ message: "Note not found" });
    }

    res.json(note);
  } catch (err) {
    console.error("Error fetching note:", err);
    res.status(500).json({ 
      message: "Error fetching note", 
      error: err.message 
    });
  }
};

// ✅ Update a note
export const updateNote = async (req, res) => {
  try {
    const { title, content, tags } = req.body;

    const updated = await Note.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { title, content, tags },
      { new: true, runValidators: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Note not found" });
    }

    res.json({ 
      message: "Note updated successfully!", 
      note: updated 
    });
  } catch (err) {
    console.error("Error updating note:", err);
    res.status(500).json({ 
      message: "Error updating note", 
      error: err.message 
    });
  }
};

// ✅ Delete a note
export const deleteNote = async (req, res) => {
  try {
    const deleted = await Note.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!deleted) {
      return res.status(404).json({ message: "Note not found" });
    }

    res.json({ message: "Note deleted successfully!" });
  } catch (err) {
    console.error("Error deleting note:", err);
    res.status(500).json({ 
      message: "Error deleting note", 
      error: err.message 
    });
  }
};