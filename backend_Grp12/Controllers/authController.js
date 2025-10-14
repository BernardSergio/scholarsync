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
    const { username, password } = req.body;

    if (!username || !password) {
      return res
        .status(400)
        .json({ message: "Please provide both username and password." });
    }

    const user = await User.findOne({ username });
    if (!user) return res.status(404).json({ message: "User not found." });

    if (user.isLocked && user.isLocked()) {
      const minutesLeft = Math.ceil((user.lockUntil - Date.now()) / 60000);
      return res
        .status(403)
        .json({
          message: `Account locked. Try again in ${minutesLeft} minute(s).`,
        });
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
    console.error("❌ Login error:", err);
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
    const FRONTEND_URL = process.env.FRONTEND_URL || "http://localhost:3000";

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

    await transporter.sendMail(mailOptions);
    console.log("✅ Reset email sent to:", user.email);
    console.log("🧩 Plain token for testing:", resetToken);

    return res.status(200).json(genericSuccess);
  } catch (err) {
    console.error("❌ Forgot Password Error:", err);
    return res
      .status(500)
      .json({
        success: false,
        message: "Error processing forgot password request.",
      });
  }
};

// ---------------------- Reset Password ----------------------
export const resetPassword = async (req, res) => {
  try {
    const { token, newPassword } = req.body;

    console.log("🔹 Received token:", token);

    if (!token || !newPassword) {
      return res
        .status(400)
        .json({ success: false, message: "Token and newPassword are required." });
    }

    const hashedToken = crypto.createHash("sha256").update(token).digest("hex");
    console.log("🔹 Hashed token:", hashedToken);

    const user = await User.findOne({
      resetPasswordToken: hashedToken,
      resetPasswordExpires: { $gt: Date.now() },
    });

    console.log("🔹 Found user:", user);

    if (!user) {
      return res
        .status(400)
        .json({ success: false, message: "Invalid or expired token." });
    }

    const saltRounds = 10;
    const hashedPassword = await bcrypt.hash(newPassword, saltRounds);
    user.password = hashedPassword;

    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;

    await user.save();

    return res
      .status(200)
      .json({ success: true, message: "Password has been reset successfully." });
  } catch (err) {
    console.error("❌ Reset Password Error:", err);
    return res
      .status(500)
      .json({ success: false, message: "Server error while resetting password." });
  }
};
