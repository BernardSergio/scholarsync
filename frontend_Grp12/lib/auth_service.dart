import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final String baseUrl = 'http://localhost:5000/api/auth'; 

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  // --- REGISTER USER ---
Future<bool> registerUser(String username, String email, String password, String number) async {
  try {
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'number': number,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      print('Registration success: ${response.body}');
      return true;
    } else {
      print('Registration failed: ${response.body}');
      return false;
    }
  } catch (e) {
    print('Error registering user: $e');
    return false;
  }
}


  // --- LOGIN USER ---
Future<bool> loginUser(String usernameOrEmail, String password) async {
  try {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': usernameOrEmail, 
        'password': password,
      }),
    );

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

    print('Login failed: ${response.body}');
    return false;
  } catch (e) {
    print('Error logging in: $e');
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
}
