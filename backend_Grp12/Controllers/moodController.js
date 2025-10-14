// Controllers/moodController.js
import MoodLog from "../Models/MoodLog.js";

// ✅ Create a new mood log
export const createMood = async (req, res) => {
  try {
    const { mood, intensity, notes } = req.body;
    const userId = req.user.id; // comes from JWT middleware

    const newMood = new MoodLog({ userId, mood, intensity, notes });
    await newMood.save();

    res.status(201).json({ message: "Mood logged successfully!", mood: newMood });
  } catch (error) {
    res.status(500).json({ message: "Error creating mood log", error: error.message });
  }
};

// ✅ Get all mood logs for logged-in user
export const getMoods = async (req, res) => {
  try {
    const userId = req.user.id;
    const moods = await MoodLog.find({ userId }).sort({ createdAt: -1 });
    res.status(200).json(moods);
  } catch (error) {
    res.status(500).json({ message: "Error fetching moods", error: error.message });
  }
};

// ✅ Update a mood log
export const updateMood = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;
    const { mood, intensity, notes } = req.body;

    const updatedMood = await MoodLog.findOneAndUpdate(
      { _id: id, userId },
      { mood, intensity, notes },
      { new: true }
    );

    if (!updatedMood) {
      return res.status(404).json({ message: "Mood log not found" });
    }

    res.status(200).json({ message: "Mood log updated successfully", mood: updatedMood });
  } catch (error) {
    res.status(500).json({ message: "Error updating mood", error: error.message });
  }
};

// ✅ Delete a mood log
export const deleteMood = async (req, res) => {
  try {
    const userId = req.user.id;
    const { id } = req.params;

    const deletedMood = await MoodLog.findOneAndDelete({ _id: id, userId });

    if (!deletedMood) {
      return res.status(404).json({ message: "Mood log not found" });
    }

    res.status(200).json({ message: "Mood log deleted successfully" });
  } catch (error) {
    res.status(500).json({ message: "Error deleting mood", error: error.message });
  }
};
