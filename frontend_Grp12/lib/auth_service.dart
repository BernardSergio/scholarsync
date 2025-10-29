import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class AuthService {
  final String authUrl = '$baseUrl/auth';  // ✅ Fixed: added /auth

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // --- REGISTER USER ---
  Future<bool> registerUser(String username, String email, String password, String number) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');  // ✅ Fixed: was just /register
      print('🔵 Registering to: $url');
      print('🔵 Data: username=$username, email=$email');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'number': number,
        }),
      ).timeout(const Duration(seconds: 10));  // ✅ Added timeout

      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Registration success: ${response.body}');
        return true;
      } else {
        print('❌ Registration failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error registering user: $e');
      return false;
    }
  }

  // --- LOGIN USER ---
Future<bool> loginUser(String usernameOrEmail, String password) async {
  try {
    final url = Uri.parse('$baseUrl/auth/login');
    print('🔵 Logging in to: $url');

    // Send BOTH username and email fields
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': usernameOrEmail,
        'email': usernameOrEmail,   // <-- send email too
        'password': password,
      }),
    ).timeout(const Duration(seconds: 10));

    print('🔹 Login response: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['token'] != null) {
        _currentUser = {
          'email': data['user']['email'],
          'username': data['user']['username'],
          'token': data['token'],
        };

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(_currentUser));

        return true;
      }
    }

    print('❌ Login failed: ${response.body}');
    return false;
  } catch (e) {
    print('❌ Error logging in: $e');
    return false;
  }
}


  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson == null) return null;

      _currentUser = jsonDecode(userJson);
      return _currentUser;
    } catch (e) {
      print('Error loading current user: $e');
      return null;
    }
  }

  Future<void> logoutUser() async {
    try {
      _currentUser = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
    } catch (e) {
      print('Error during logout: $e');
    }
  }

  // --- CHANGE PASSWORD ---
  Future<Map<String, dynamic>> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      final user = await getCurrentUser();
      if (user == null || user['token'] == null) {
        return {
          'success': false,
          'message': 'No user logged in'
        };
      }

      final url = Uri.parse('$baseUrl/auth/change-password');  // ✅ Fixed
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${user['token']}',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      print('🔹 Change password response: ${response.body}');

      final data = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Password changed successfully'
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to change password'
        };
      }
    } catch (e) {
      print('❌ Error changing password: $e');
      return {
        'success': false,
        'message': 'Network error: $e'
      };
    }
  }
}