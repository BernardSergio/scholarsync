// Models/Appointment.js
import mongoose from "mongoose";

const appointmentSchema = new mongoose.Schema({
  userId: { 
    type: mongoose.Schema.Types.ObjectId, 
    ref: "User", 
    required: true 
  },
  title: { 
    type: String, 
    required: true 
  },
  provider: { 
    type: String, 
    default: "" 
  },
  type: { 
    type: String, 
    enum: ["In-Person", "Video Call", "Phone Call"],
    default: "In-Person"
  },
  dateTime: { 
    type: Date, 
    required: true 
  },
  location: { 
    type: String, 
    default: "" 
  },
  notes: { 
    type: String, 
    default: "" 
  }
}, { timestamps: true });

const Appointment = mongoose.model("Appointment", appointmentSchema);
export default Appointment;