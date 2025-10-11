// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  bool _isPassphraseVisible = false;
  final AuthService _authService = AuthService();

  final Color _auraPrimaryColor = const Color.fromARGB(255, 0, 146, 110);
  final Color _scaffoldBackgroundColor = const Color(0xFFF3F7FF);
  final Color _greyTextColor = const Color(0xFF757575);
  final Color _textFieldBorderColor = const Color(0xFFE0E0E0);
  final Color _textFieldFillColor = const Color(0xFFFCFCFF);
  final Color _signInTextColor = Colors.white;
  final Color _textLinkColor = const Color.fromARGB(255, 2, 116, 91);
  final Color _auraHeaderColor = const Color(0xFF3DAA80);

  @override
  void dispose() {
    _usernameController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  // --- LOGIN HANDLER ---
  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final passphrase = _passphraseController.text.trim();

    if (username.isEmpty || passphrase.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final result = await _authService.login(username, passphrase);

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Login failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'AURA',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _auraHeaderColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Welcome back to your secure mental health companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _greyTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildTextField(
                      label: 'Username',
                      hint: 'Enter your username',
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 20),
                    _buildPassphraseField(controller: _passphraseController),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _auraPrimaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 18,
                            color: _signInTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'OR',
                      style: TextStyle(
                        color: Color.fromARGB(153, 117, 117, 117), // replaced deprecated withOpacity(0.6)
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                        },
                        icon: Icon(Icons.fingerprint,
                            size: 24, color: _auraPrimaryColor),
                        label: Text(
                          'Use Biometric Authentication',
                          style: TextStyle(
                              fontSize: 16, color: _auraPrimaryColor),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _auraPrimaryColor),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen()),
                        );
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(color: _greyTextColor),
                          children: <TextSpan>[
                            TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: _textLinkColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                      },
                      child: Text(
                        'Forgot your Password?',
                        style: TextStyle(color: _textLinkColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _textFieldBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _textFieldBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _auraPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: _textFieldFillColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPassphraseField({required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Secure Passphrase',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: !_isPassphraseVisible,
          decoration: InputDecoration(
            hintText: 'Enter your Password',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _textFieldBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _textFieldBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: _auraPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: _textFieldFillColor,
            suffixIcon: IconButton(
              icon: Icon(
                _isPassphraseVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: _greyTextColor,
              ),
              onPressed: () {
                setState(() {
                  _isPassphraseVisible = !_isPassphraseVisible;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
