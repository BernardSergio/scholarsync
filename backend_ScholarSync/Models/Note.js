// Models/Note.js
import mongoose from "mongoose";

const noteSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  title: { type: String, required: true },
  content: { type: String, required: true },
  tags: { type: [String], default: [] },
  date: { type: Date, default: Date.now }
}, { timestamps: true });

const Note = mongoose.model("Note", noteSchema);
export default Note;
