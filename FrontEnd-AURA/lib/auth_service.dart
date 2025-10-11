import 'dart:convert';
import 'package:flutter/foundation.dart'; 
import 'package:http/http.dart' as http;

class AuthService {
  static final String baseUrl = kIsWeb
      ? "http://localhost:5000/api/auth"
      : "http://10.0.2.2:5000/api/auth"; 

  Future<Map<String, dynamic>> login(String username, String password) async {
    final url = Uri.parse("$baseUrl/login");
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"username": username, "password": password}),
    );

    if (response.statusCode == 200) {
      return {"success": true, "data": jsonDecode(response.body)};
    } else {
      return {
        "success": false,
        "message": jsonDecode(response.body)["message"] ?? "Login failed"
      };
    }
  }

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
}
