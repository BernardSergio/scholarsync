import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'forgot_passphrase_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isPassphraseVisible = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();
  bool _isLoading = false;
  bool _canSubmit = false;

  // ── ScholarSync Colors ──────────────────────────
  static const Color _primary           = Color(0xFFFFC107); // Amber
  static const Color _background        = Color(0xFFF5F5F5);
  static const Color _surface           = Color(0xFFFFFFFF);
  static const Color _foreground        = Color(0xFF1A1A1A);
  static const Color _muted             = Color(0xFFE8E8E8);
  static const Color _mutedForeground   = Color(0xFF5A5A4D);
  static const Color _border            = Color(0xFFE0E0E0);
  // ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateCanSubmit);
    _passphraseController.addListener(_updateCanSubmit);
    _updateCanSubmit();
    _authService = AuthService();
  }

  late final AuthService _authService;

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: _surface,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Logo / Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _primary.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school, color: _primary, size: 40),
                    ),
                    const SizedBox(height: 16),

                    // App Name
                    const Text(
                      'ScholarSync',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _foreground,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Text(
                      'Welcome back to your wellness companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _mutedForeground, fontSize: 15),
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    _buildTextField(
                      label: 'Username',
                      hint: 'Enter your username',
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 20),

                    // Password Field
                    _buildPassphraseField(),
                    const SizedBox(height: 30),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isLoading || !_canSubmit)
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                final username = _usernameController.text.trim();
                                final passphrase = _passphraseController.text;
                                final success = await _authService.loginUser(username, passphrase);
                                setState(() => _isLoading = false);
                                if (!mounted) return;
                                if (success) {
                                  Navigator.of(context).pushReplacementNamed('/home');
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Authentication failed. Please check your credentials.')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: _foreground,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_foreground),
                                ),
                              )
                            : const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Sign Up Link
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/signup'),
                      child: Text.rich(
                        TextSpan(
                          text: "Don't have an account? ",
                          style: const TextStyle(color: _mutedForeground),
                          children: [
                            TextSpan(
                              text: 'Sign up',
                              style: TextStyle(
                                color: _primary.withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Forgot Password
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPassphraseScreen()),
                        );
                      },
                      child: const Text(
                        'Forgot your password?',
                        style: TextStyle(color: _mutedForeground),
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
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: _foreground, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _mutedForeground),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primary, width: 2)),
            filled: true,
            fillColor: _muted,
          ),
        ),
      ],
    );
  }

  Widget _buildPassphraseField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, color: _foreground, fontSize: 15)),
        const SizedBox(height: 8),
        TextField(
          controller: _passphraseController,
          obscureText: !_isPassphraseVisible,
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: const TextStyle(color: _mutedForeground),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _primary, width: 2)),
            filled: true,
            fillColor: _muted,
            suffixIcon: IconButton(
              icon: Icon(_isPassphraseVisible ? Icons.visibility : Icons.visibility_off, color: _mutedForeground),
              onPressed: () => setState(() => _isPassphraseVisible = !_isPassphraseVisible),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _usernameController.removeListener(_updateCanSubmit);
    _passphraseController.removeListener(_updateCanSubmit);
    _usernameController.dispose();
    _passphraseController.dispose();
    super.dispose();
  }

  void _updateCanSubmit() {
    final can = _usernameController.text.trim().isNotEmpty && _passphraseController.text.isNotEmpty;
    if (can != _canSubmit) setState(() => _canSubmit = can);
  }
}