// Models/MoodLog.js
import mongoose from "mongoose";

const moodLogSchema = new mongoose.Schema(
  {
    userId: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: "User", 
      required: true 
    },
    mood: { 
      type: String, 
      required: true, 
      enum: ["happy", "sad", "angry", "anxious", "neutral", "excited", "tired"] 
    },
    intensity: { 
      type: Number, 
      min: 1, 
      max: 10, 
      required: true 
    },
    notes: { 
      type: String, 
      default: "" 
    },
    date: { 
      type: Date, 
      default: Date.now 
    }
  },
  { timestamps: true }
);

const MoodLog = mongoose.model("MoodLog", moodLogSchema);
export default MoodLog;
