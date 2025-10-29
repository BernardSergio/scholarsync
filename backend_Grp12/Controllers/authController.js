// Controllers/authController.js
import crypto from "crypto";
import nodemailer from "nodemailer";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import User from "../Models/User.js";
import dotenv from "dotenv";

dotenv.config();
const JWT_SECRET = process.env.JWT_SECRET;

// ---------------------- Register ----------------------
export const registerUser = async (req, res) => {
  try {
    const { username, password, email, number } = req.body;

    if (!username || !password || !email || !number) {
      return res.status(400).json({
        message: "All fields (username, password, email, number) are required.",
      });
    }

    const existingUser = await User.findOne({
      $or: [{ username }, { email }],
    });
    if (existingUser) {
      return res
        .status(400)
        .json({ message: "Username or email already taken." });
    }

    const newUser = new User({ username, password, email, number });
    await newUser.save();

    res.status(201).json({
      message: "User registered successfully!",
      user: {
        id: newUser._id,
        username: newUser.username,
        email: newUser.email,
        number: newUser.number,
        role: newUser.role,
      },
    });
  } catch (err) {
    console.error("❌ Registration error:", err);
    res.status(500).json({ error: "Server error during registration." });
  }
};

// ---------------------- Login ----------------------
export const loginUser = async (req, res) => {
  try {
    const { username, email, password } = req.body;

    if ((!username && !email) || !password) {
      return res
        .status(400)
        .json({ message: "Please provide a username/email and password." });
    }

    const user = await User.findOne({
      $or: [{ username }, { email }],
    });
    if (!user) return res.status(404).json({ message: "User not found." });

    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({ message: "Invalid password." });
    }

    const token = jwt.sign(
      { id: user._id, username: user.username },
      JWT_SECRET,
      { expiresIn: "1h" }
    );

    res.json({
      message: "Login successful!",
      token,
      user: {
        id: user._id,
        username: user.username,
        email: user.email,
        number: user.number,
        role: user.role,
      },
    });
  } catch (err) {
    console.error("Login error:", err);
    res.status(500).json({ error: "Server error during login." });
  }
};


// ---------------------- Forgot Password ----------------------
export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;
    if (!email)
      return res
        .status(400)
        .json({ success: false, message: "Email is required." });

    const user = await User.findOne({ email });

    const genericSuccess = {
      success: true,
      message:
        "If an account with that email exists, reset instructions have been sent.",
    };

    if (!user) return res.status(200).json(genericSuccess);

    // Generate and hash reset token
    const resetToken = crypto.randomBytes(32).toString("hex");
    const hashedToken = crypto.createHash("sha256").update(resetToken).digest("hex");

    user.resetPasswordToken = hashedToken;
    user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 minutes
    await user.save();

    // ✅ Automatically choose frontend URL
    const FRONTEND_URL = process.env.FRONTEND_URL;

    // ✅ Flutter web uses hash routing (#/)
    const resetUrl = `${FRONTEND_URL}/#/reset-password?token=${resetToken}`;

    // Configure email
    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
      tls: {
        rejectUnauthorized: false,
      },
    });

    const mailOptions = {
      from: `"AURA Support" <${process.env.EMAIL_USER}>`,
      to: user.email,
      subject: "AURA Password Reset Request",
      html: `
        <p>Hello ${user.username},</p>
        <p>You (or someone else) requested to reset your AURA password. Click the link below to reset it:</p>
        <p><a href="${resetUrl}" target="_blank">${resetUrl}</a></p>
        <p>This link will expire in 15 minutes.</p>
        <p>If you didn't request this, you can ignore this email.</p>
      `,
    };

      try {
        const info = await transporter.sendMail(mailOptions);
        console.log("Reset email sent to:", user.email);
        console.log("Message ID:", info.messageId);
        console.log("Plain token for testing:", resetToken);
      } catch (emailErr) {
        console.error("❌ Error sending email:", emailErr);
        return res.status(500).json({ success: false, message: "Failed to send reset email. Check server logs for details." });
      }

    return res.status(200).json(genericSuccess);
  } catch (err) {
    console.error("Forgot Password Error:", err);
    return res
      .status(500)
      .json({
        success: false,
        message: "Error processing forgot password request.",
      });
  }
};
// ---------------------- Change Password ----------------------
export const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const userId = req.user.id; // From JWT token via middleware

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Current password and new password are required."
      });
    }

    // Find user
    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found."
      });
    }

    // Verify current password
    const isMatch = await user.matchPassword(currentPassword);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Current password is incorrect."
      });
    }

    // Update to new password (pre-save hook will hash it)
    user.password = newPassword;
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Password changed successfully."
    });
  } catch (err) {
    console.error("❌ Change Password Error:", err);
    return res.status(500).json({
      success: false,
      message: "Server error while changing password."
    });
  }
};
// ---------------------- Reset Password ----------------------
export const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    console.log("🔹 Received token:", token);

    if (!token || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Token and newPassword are required."
      });
    }

    // Hash the incoming token to compare with stored token
    const hashedToken = crypto.createHash("sha256").update(token).digest("hex");
    console.log("🔹 Hashed token:", hashedToken);

    // Find user with valid token
    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpires: { $gt: Date.now() },
    });

    console.log("🔹 Found user:", user ? user.email : "No user found");

    if (!user) {
      return res.status(400).json({
        success: false,
        message: "Invalid or expired token."
      });
    }

    // Assign the new password (pre-save hook will hash it)
    user.password = newPassword;

    // Clear reset token fields
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save(); // pre-save hook handles hashing
    console.log(`🔹 Password successfully updated for ${user.email}`);

    return res.status(200).json({
      success: true,
      message: "Password has been reset successfully."
    });
  } catch (err) {
    console.error("❌ Reset Password Error:", err);
    return res.status(500).json({
      success: false,
      message: "Server error while resetting password."
    });
  }
};

