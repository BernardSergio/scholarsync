// Models/MedicationLog.js
import mongoose from "mongoose";

const medicationLogSchema = new mongoose.Schema(
  {
    userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    medicationName: { type: String, required: true },
    dosage: { type: String, required: true },
    timeTaken: { type: Date, default: Date.now },
    notes: { type: String, default: "" },
  },
  { timestamps: true }
);

const MedicationLog = mongoose.model("MedicationLog", medicationLogSchema);
export default MedicationLog;
