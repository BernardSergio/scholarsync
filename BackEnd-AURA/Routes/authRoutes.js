// Routes/authRoutes.js
import express from "express";
import {
  registerUser,
  loginUser,
  forgotPassword,
  resetPassword
} from "../Controllers/authController.js";

const router = express.Router();

router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword); // accepts { token, newPassword } in body

export default router;
