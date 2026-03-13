import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _isPassVisible = false;

  // ── ScholarSync Colors ──────────────────────────
  static const Color _primary         = Color(0xFFFFC107);
  static const Color _background      = Color(0xFFF5F5F5);
  static const Color _surface         = Color(0xFFFFFFFF);
  static const Color _foreground      = Color(0xFF1A1A1A);
  static const Color _muted           = Color(0xFFE8E8E8);
  static const Color _mutedForeground = Color(0xFF5A5A4D);
  static const Color _border          = Color(0xFFE0E0E0);
  // ───────────────────────────────────────────────

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _numberCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final number = _numberCtrl.text.trim();
    final pass = _passCtrl.text;
    final conf = _confirmCtrl.text;

    if (username.isEmpty || email.isEmpty || pass.isEmpty || conf.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email address')));
      return;
    }
    if (pass != conf) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    final created = await AuthService().registerUser(username, email, pass, number);
    setState(() => _isLoading = false);
    if (!created) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed or user already exists')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created — you can now sign in')));
    Navigator.of(context).pushReplacementNamed('/login');
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _mutedForeground),
        filled: true,
        fillColor: _muted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primary, width: 2)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              margin: EdgeInsets.zero,
              elevation: 8,
              color: _surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: const Icon(Icons.school, color: _primary, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text('ScholarSync', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _foreground)),
                    const SizedBox(height: 8),
                    const Text('Create your secure account', textAlign: TextAlign.center, style: TextStyle(color: _mutedForeground)),
                    const SizedBox(height: 20),

                    TextField(controller: _usernameCtrl, decoration: _inputDecoration('Username')),
                    const SizedBox(height: 16),
                    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration('Email Address')),
                    const SizedBox(height: 16),
                    TextField(controller: _numberCtrl, keyboardType: TextInputType.phone, decoration: _inputDecoration('Phone Number')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !_isPassVisible,
                      decoration: _inputDecoration('Password').copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_isPassVisible ? Icons.visibility : Icons.visibility_off, color: _mutedForeground),
                          onPressed: () => setState(() => _isPassVisible = !_isPassVisible),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: _confirmCtrl, obscureText: !_isPassVisible, decoration: _inputDecoration('Confirm Password')),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: _foreground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2))
                            : const Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
                      child: Text.rich(TextSpan(
                        text: 'Already have an account? ',
                        style: const TextStyle(color: _mutedForeground),
                        children: [
                          TextSpan(text: 'Sign in', style: TextStyle(color: _primary.withOpacity(0.9), fontWeight: FontWeight.bold)),
                        ],
                      )),
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