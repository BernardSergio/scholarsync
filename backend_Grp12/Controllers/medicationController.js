// Controllers/medicationController.js
import MedicationLog from "../Models/MedicationLog.js";

// ✅ Create a new medication log
export const createMedication = async (req, res) => {
  try {
    const { medicationName, dosage, timeTaken, notes } = req.body;
    const userId = req.user.id; // comes from JWT middleware

    const newMedication = new MedicationLog({ 
      userId, 
      medicationName, 
      dosage, 
      timeTaken: timeTaken || Date.now(),
      notes 
    });
    await newMedication.save();

    res.status(201).json({ 
      message: "Medication logged successfully!", 
      medication: newMedication 
    });
  } catch (error) {
    res.status(500).json({ 
      message: "Error creating medication log", 
      error: error.message 
    });
  }
};

// ✅ Get all medication logs for logged-in user
export const getMedications = async (req, res) => {
  try {
    const userId = req.user.id;
    const medications = await MedicationLog.find({ userId }).sort({ timeTaken: -1 });
    res.status(200).json(medications);
  } catch (error) {
    res.status(500).json({ 
      message: "Error fetching medications", 
      error: error.message 
    });
  }
};

// ✅ Get medications for a specific date range
export const getMedicationsByDateRange = async (req, res) => {
  try {
    const userId = req.user.id;
    const { startDate, endDate } = req.query;

    const query = { userId };
    if (startDate && endDate) {
      query.timeTaken = {
        $gte: new Date(startDate),
        $lte: new Date(endDate)
      };
    }

    const medications = await MedicationLog.find(query).sort({ timeTaken: -1 });
    res.status(200).json(medications);
  } catch (error) {
    res.status(500).json({ 
      message: "Error fetching medications by date", 
      error: error.message 
    });
  }
};

// ✅ Update a medication log
export const updateMedication = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { medicationName, dosage, timeTaken, notes } = req.body;

    const updatedMedication = await MedicationLog.findOneAndUpdate(
      { _id: id, userId },
      { medicationName, dosage, timeTaken, notes },
      { new: true }
    );

    if (!updatedMedication) {
      return res.status(404).json({ message: "Medication log not found" });
    }

    res.status(200).json({ 
      message: "Medication log updated successfully", 
      medication: updatedMedication 
    });
  } catch (error) {
    res.status(500).json({ 
      message: "Error updating medication", 
      error: error.message 
    });
  }
};

// ✅ Delete a medication log
export const deleteMedication = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const deletedMedication = await MedicationLog.findOneAndDelete({ _id: id, userId });

    if (!deletedMedication) {
      return res.status(404).json({ message: "Medication log not found" });
    }

    res.status(200).json({ message: "Medication log deleted successfully" });
  } catch (error) {
    res.status(500).json({ 
      message: "Error deleting medication", 
      error: error.message 
    });
  }
};