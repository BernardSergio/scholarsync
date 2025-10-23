// lib/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class User {
  final String username;
  final String passphrase;

  User({required this.username, required this.passphrase});

  factory User.fromJson(Map<String, dynamic> json) => User(
        username: json['username'] ?? '',
        passphrase: json['passphrase'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'username': username,
        'passphrase': passphrase,
      };
}

class AuthService {
  static final String baseUrl = kIsWeb
      ? "http://localhost:5000/api/auth"
      : "http://10.0.2.2:5000/api/auth";

  // 🧍‍♂️ Holds the currently logged-in user data
  User? currentUser;

  // 🧮 Track reset password attempts (memory-based)
  int resetAttempts = 0;
  final int maxResetAttempts = 3;

  // Optional: Track attempts per username
  final Map<String, int> _userAttempts = {};

  // 🔐 LOGIN
  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse("$baseUrl/login");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final userData = body["user"] ?? body;
        currentUser = User.fromJson(userData);
        return {"success": true, "data": body};
      } else {
        return {
          "success": false,
          "message": body["message"] ?? "Login failed (${response.statusCode})"
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network or server error: $e"};
    }
  }

  // 📝 SIGNUP
  Future<Map<String, dynamic>> signup(
      String username, String email, String number, String password) async {
    final url = Uri.parse("$baseUrl/register");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "email": email,
          "number": number,
          "password": password,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"success": true, "data": body};
      } else {
        return {
          "success": false,
          "message":
              body["message"] ?? "Signup failed (${response.statusCode})"
        };
      }
    } catch (e) {
      return {"success": false, "message": "Server error: $e"};
    }
  }

  // 🔄 FORGOT PASSWORD
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final url = Uri.parse("$baseUrl/forgot-password");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          "success": body["success"] ?? true,
          "message": body["message"] ??
              "If an account exists, reset instructions were sent."
        };
      } else {
        return {
          "success": false,
          "message": body["message"] ??
              "Error processing request (${response.statusCode})"
        };
      }
    } catch (e) {
      return {"success": false, "message": "Network error: $e"};
    }
  }

  // 🔐 RESET PASSWORD (with attempt tracking)
  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final url = Uri.parse("$baseUrl/reset-password");

    if (resetAttempts >= maxResetAttempts) {
      return {
        "success": false,
        "message":
            "Too many failed reset attempts. Please try again later or request a new reset link."
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "token": token,
          "newPassword": newPassword,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        resetAttempts = 0;
        return {
          "success": body["success"] ?? true,
          "message":
              body["message"] ?? "Password has been reset successfully."
        };
      } else {
        resetAttempts++;
        return {
          "success": false,
          "message": body["message"] ??
              "Reset failed (${response.statusCode}). Attempt $resetAttempts/$maxResetAttempts."
        };
      }
    } catch (e) {
      resetAttempts++;
      return {
        "success": false,
        "message":
            "Error resetting password: $e (Attempt $resetAttempts/$maxResetAttempts)"
      };
    }
  }

  // 🚪 LOGOUT
  void logout() {
    currentUser = null;
    resetAttempts = 0;
    _userAttempts.clear();
  }

  // ✅ RESET all attempts
  void resetAllAttempts() {
    resetAttempts = 0;
    _userAttempts.clear();
  }

  // ✅ RESET attempts for a specific username
  void resetAttemptsForUser(String username) {
    _userAttempts[username] = 0;
  }
}
