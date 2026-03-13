// Routes/authRoutes.js
import express from "express";
import {
  registerUser,
  loginUser,
  forgotPassword,
  resetPassword,
  changePassword  
} from "../Controllers/authController.js";
import { verifyToken } from "../Middleware/authMiddleware.js";  

const router = express.Router();

router.post("/register", registerUser);
router.post("/login", loginUser);
router.post("/forgot-password", forgotPassword);
router.post("/reset-password", resetPassword);
router.post("/change-password", verifyToken, changePassword);  

export default router;