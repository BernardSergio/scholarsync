// Models/Reminder.js
import mongoose from "mongoose";

const reminderSchema = new mongoose.Schema(
  {
    userId: { 
      type: mongoose.Schema.Types.ObjectId, 
      ref: "User", 
      required: true 
    },
    medicationName: { 
      type: String, 
      required: true 
    },
    dosage: { 
      type: String, 
      required: true 
    },
    time: { 
      type: String, // e.g., "8:00 AM"
      required: true 
    },
    taken: { 
      type: Boolean, 
      default: false 
    },
    notified: { 
      type: Boolean, 
      default: false 
    },
  },
  { timestamps: true }
);

const Reminder = mongoose.model("Reminder", reminderSchema);
export default Reminder;
