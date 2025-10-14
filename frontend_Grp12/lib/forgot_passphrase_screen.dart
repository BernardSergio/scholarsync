import 'package:flutter/material.dart';
import 'auth_service.dart';

class ForgotPassphraseScreen extends StatefulWidget {
  const ForgotPassphraseScreen({super.key});

  @override
  State<ForgotPassphraseScreen> createState() => _ForgotPassphraseScreenState();
}

class _ForgotPassphraseScreenState extends State<ForgotPassphraseScreen> {
  final TextEditingController _emailController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Theme/colors aligned with the login screen
  final Color _auraPrimaryColor = const Color.fromARGB(255, 0, 146, 110);
  final Color _scaffoldBackgroundColor = const Color(0xFFF3F7FF);
  final Color _greyTextColor = const Color(0xFF757575);
  final Color _textFieldBorderColor = const Color(0xFFE0E0E0);
  final Color _textFieldFillColor = const Color(0xFFFCFCFF);
  final Color _auraHeaderColor = const Color(0xFF3DAA80);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your registered email address')),
      );
      return;
    }

    // Basic email validation
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.forgotPassword(email);

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result["message"] ?? "Something went wrong."),
        backgroundColor: result["success"] ? Colors.green : Colors.red,
      ),
    );

    if (result["success"]) {
      Navigator.of(context).pop(); // go back to login screen
    }
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
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
          keyboardType: keyboardType,
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'AURA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _auraHeaderColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your registered email to reset your passphrase',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _greyTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: 'Email Address',
                      hint: 'Enter your email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _auraPrimaryColor,
                              side: BorderSide(color: _auraPrimaryColor),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _auraPrimaryColor,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(color: Colors.white),
                                  ),
                          ),
                        ),
                      ],
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
