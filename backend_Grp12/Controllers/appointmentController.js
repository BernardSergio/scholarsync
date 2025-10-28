// Controllers/appointmentController.js
import Appointment from "../Models/Appointment.js";

// ✅ Create a new appointment
export const createAppointment = async (req, res) => {
  try {
    const { title, provider, type, dateTime, location, notes } = req.body;

    // Validation
    if (!title || !dateTime) {
      return res.status(400).json({ 
        message: "Title and dateTime are required" 
      });
    }

    const newAppointment = new Appointment({
      userId: req.user.id,
      title,
      provider: provider || "",
      type: type || "In-Person",
      dateTime,
      location: location || "",
      notes: notes || "",
    });

    await newAppointment.save();
    
    res.status(201).json({ 
      message: "Appointment created successfully!", 
      appointment: newAppointment 
    });
  } catch (err) {
    console.error("Error creating appointment:", err);
    res.status(500).json({ 
      message: "Error creating appointment", 
      error: err.message 
    });
  }
};

// ✅ Get all appointments for logged-in user
export const getAppointments = async (req, res) => {
  try {
    const appointments = await Appointment.find({ userId: req.user.id })
      .sort({ dateTime: 1 }); // Sort by date, earliest first
    
    res.json(appointments);
  } catch (err) {
    console.error("Error fetching appointments:", err);
    res.status(500).json({ 
      message: "Error fetching appointments", 
      error: err.message 
    });
  }
};

// ✅ Get a single appointment by ID
export const getAppointmentById = async (req, res) => {
  try {
    const appointment = await Appointment.findOne({
      _id: req.params.id,
      userId: req.user.id
    });

    if (!appointment) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json(appointment);
  } catch (err) {
    console.error("Error fetching appointment:", err);
    res.status(500).json({ 
      message: "Error fetching appointment", 
      error: err.message 
    });
  }
};

// ✅ Update an appointment
export const updateAppointment = async (req, res) => {
  try {
    const { title, provider, type, dateTime, location, notes } = req.body;

    const updated = await Appointment.findOneAndUpdate(
      { _id: req.params.id, userId: req.user.id },
      { title, provider, type, dateTime, location, notes },
      { new: true, runValidators: true }
    );

    if (!updated) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ 
      message: "Appointment updated successfully!", 
      appointment: updated 
    });
  } catch (err) {
    console.error("Error updating appointment:", err);
    res.status(500).json({ 
      message: "Error updating appointment", 
      error: err.message 
    });
  }
};

// ✅ Delete an appointment
export const deleteAppointment = async (req, res) => {
  try {
    const deleted = await Appointment.findOneAndDelete({
      _id: req.params.id,
      userId: req.user.id,
    });

    if (!deleted) {
      return res.status(404).json({ message: "Appointment not found" });
    }

    res.json({ message: "Appointment deleted successfully!" });
  } catch (err) {
    console.error("Error deleting appointment:", err);
    res.status(500).json({ 
      message: "Error deleting appointment", 
      error: err.message 
    });
  }
};