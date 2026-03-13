// Controllers/reminderController.js
import Reminder from "../Models/Reminders.js";

// ✅ Create a new reminder
export const createReminder = async (req, res) => {
  try {
    console.log('\n📨 === CREATE REMINDER REQUEST ===');
    console.log('User ID:', req.user.id);
    console.log('User:', req.user.username);
    console.log('Body:', req.body);
    
    const userId = req.user.id;
    const { medicationName, dosage, time } = req.body;

    // Validate input
    if (!medicationName || !dosage || !time) {
      console.log('❌ Missing fields');
      return res.status(400).json({ message: "Missing required fields" });
    }

    const newReminder = new Reminder({ userId, medicationName, dosage, time });
    await newReminder.save();

    console.log('✅ Reminder saved successfully:', newReminder._id);
    console.log('===================================\n');
    
    res.status(201).json({ message: "Reminder added successfully!", reminder: newReminder });
  } catch (error) {
    console.error('❌ Error creating reminder:', error.message);
    console.log('===================================\n');
    res.status(500).json({ message: "Error creating reminder", error: error.message });
  }
};

// ✅ Get all reminders for logged-in user
export const getReminders = async (req, res) => {
  try {
    console.log('\n📥 === GET REMINDERS REQUEST ===');
    console.log('User ID:', req.user.id);
    
    const userId = req.user.id;
    const reminders = await Reminder.find({ userId }).sort({ createdAt: -1 });
    
    console.log(`✅ Found ${reminders.length} reminders`);
    console.log('===================================\n');
    
    res.status(200).json(reminders);
  } catch (error) {
    console.error('❌ Error fetching reminders:', error.message);
    res.status(500).json({ message: "Error fetching reminders", error: error.message });
  }
};

// ✅ Toggle "taken" status
export const toggleTaken = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const reminder = await Reminder.findOne({ _id: id, userId });
    if (!reminder) return res.status(404).json({ message: "Reminder not found" });

    reminder.taken = !reminder.taken;
    await reminder.save();

    res.status(200).json({ message: "Reminder updated", reminder });
  } catch (error) {
    res.status(500).json({ message: "Error updating reminder", error: error.message });
  }
};

// ✅ Delete reminder
export const deleteReminder = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const deleted = await Reminder.findOneAndDelete({ _id: id, userId });
    if (!deleted) return res.status(404).json({ message: "Reminder not found" });

    res.status(200).json({ message: "Reminder deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error deleting reminder", error: error.message });
  }
};