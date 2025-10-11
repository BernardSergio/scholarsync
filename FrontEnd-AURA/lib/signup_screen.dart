// lib/signup_screen.dart

import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isPassVisible = false;
  bool _useBiometric = false;

  final Color _auraPrimaryColor = const Color.fromARGB(255, 0, 146, 110);
  final Color _scaffoldBackgroundColor = const Color(0xFFF3F7FF);
  final Color _greyTextColor = const Color(0xFF757575);
  final Color _textFieldBorderColor = const Color(0xFFE0E0E0);
  final Color _textFieldFillColor = const Color(0xFFFCFCFF);

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;

    if (username.isEmpty || pass.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide username and passphrase')),
      );
      return;
    }

    if (pass != conf) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passphrases do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService().signup(username, pass);

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (result['success'] == true) {
        // ✅ Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created — redirecting to login...')),
        );

        // ✅ Navigate after short delay so SnackBar is visible
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed('/login');
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Signup failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred: $e')),
      );
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: _textFieldFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      );

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
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('AURA',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _auraPrimaryColor)),
                    const SizedBox(height: 8),
                    Text('Create your secure account',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _greyTextColor)),
                    const SizedBox(height: 20),
                    TextField(
                        controller: _usernameCtrl,
                        decoration: _inputDecoration('Username')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_isPassVisible,
                      decoration: _inputDecoration('New Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isPassVisible
                              ? Icons.visibility
                              : Icons.visibility_off),
                          onPressed: () =>
                              setState(() => _isPassVisible = !_isPassVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _confirmCtrl,
                        obscureText: !_isPassVisible,
                        decoration: _inputDecoration('Confirm Password')),
                    const SizedBox(height: 12),
                    Row(children: [
                      Switch(
                          value: _useBiometric,
                          onChanged: (v) => setState(() => _useBiometric = v)),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Enable biometric authentication')),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _auraPrimaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8))),
                        child: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(color: Colors.white))
                            : const Text('Create Account',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/login'),
                      child: Text.rich(TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: _greyTextColor),
                          children: [
                            TextSpan(
                                text: 'Sign in',
                                style: TextStyle(
                                    color: _auraPrimaryColor,
                                    fontWeight: FontWeight.bold))
                          ])),
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
}
