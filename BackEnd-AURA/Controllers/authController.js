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
      return res.status(400).json({ message: "Username or email already taken." });
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
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({ message: "Please provide both username and password." });
    }

    const user = await User.findOne({ username });
    if (!user) return res.status(404).json({ message: "User not found." });

    if (user.isLocked && user.isLocked()) {
      const minutesLeft = Math.ceil((user.lockUntil - Date.now()) / 60000);
      return res.status(403).json({ message: `Account locked. Try again in ${minutesLeft} minute(s).` });
    }

    const isMatch = await user.matchPassword(password);

    if (!isMatch) {
      user.failedLoginAttempts += 1;
      if (user.failedLoginAttempts >= 5) {
        user.lockUntil = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes
      }
      await user.save();
      return res.status(401).json({ message: "Invalid password." });
    }

    // reset failed attempts
    user.failedLoginAttempts = 0;
    user.lockUntil = null;
    user.lastActive = new Date();
    await user.save();

    const token = jwt.sign({ id: user._id, username: user.username }, JWT_SECRET, { expiresIn: "1h" });

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
    console.error("❌ Login error:", err);
    res.status(500).json({ error: "Server error during login." });
  }
};

// ---------------------- Forgot Password (generate token + send email) ----------------------
export const forgotPassword = async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) return res.status(400).json({ success: false, message: "Email is required." });

    const user = await User.findOne({ email });

    // Always respond with generic message to avoid exposing which emails exist
    const genericSuccess = {
      success: true,
      message: "If an account with that email exists, reset instructions have been sent."
    };

    if (!user) {
      // Still return generic success
      return res.status(200).json(genericSuccess);
    }

    // Generate a secure token (plain token to send to user)
    const resetToken = crypto.randomBytes(32).toString("hex");
    // Hash token for storage
    const hashedToken = crypto.createHash("sha256").update(resetToken).digest("hex");

    // Save hashed token and expiry
    user.resetPasswordToken = hashedToken;
    user.resetPasswordExpires = Date.now() + 15 * 60 * 1000; // 15 minutes
    await user.save();

    // Build reset URL (frontend should capture token and present reset UI)
    const resetUrl = `${process.env.CLIENT_URL}/reset-password?token=${resetToken}`;

    // Configure nodemailer transporter
      const transporter = nodemailer.createTransport({
        service: 'gmail',
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

    // Send the email
    await transporter.sendMail(mailOptions);

    // For development/testing only: log plain token (remove in production)
    console.log("Password reset token (plain) for testing:", resetToken);

    return res.status(200).json(genericSuccess);
  } catch (err) {
    console.error("❌ Forgot Password Error:", err);
    return res.status(500).json({ success: false, message: "Error processing forgot password request." });
  }
};

// ---------------------- Reset Password ----------------------
// Accepts { token, newPassword } in body
export const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      return res.status(400).json({ success: false, message: "Token and newPassword are required." });
    }

    // Hash the provided token to compare with stored hash
    const hashedToken = crypto.createHash("sha256").update(token).digest("hex");

    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpires: { $gt: Date.now() }
    });

    if (!user) {
      return res.status(400).json({ success: false, message: "Invalid or expired token." });
    }

    // Hash the new password (if your User model doesn't already hash in pre-save)
    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
    user.password = hashedPassword;

    // Clear reset fields
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();

    return res.status(200).json({ success: true, message: "Password has been reset successfully." });
  } catch (err) {
    console.error("❌ Reset Password Error:", err);
    return res.status(500).json({ success: false, message: "Server error while resetting password." });
  }
};
