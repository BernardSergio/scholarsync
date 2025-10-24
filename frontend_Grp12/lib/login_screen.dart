
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'forgot_passphrase_screen.dart';
// removed debug settings import


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // State to manage the visibility of the passphrase text
  bool _isPassphraseVisible = false;
  // Controllers for the text fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passphraseController = TextEditingController();

  // Loading state while authenticating 
  bool _isLoading = false;
  // Whether both fields contain text and the form can be submitted
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateCanSubmit);
    _passphraseController.addListener(_updateCanSubmit);
    _updateCanSubmit();
    // Create a single AuthService instance for this screen so login attempts are tracked
    _authService = AuthService();
  }

  late final AuthService _authService;

  // Custom colors based on the new desired purple theme
  final Color _auraPrimaryColor = const Color.fromARGB(255, 0, 146, 110); // A deep teal for buttons/links
  final Color _scaffoldBackgroundColor = const Color(0xFFF3F7FF); // Light pale blue/white background
  final Color _greyTextColor = const Color(0xFF757575); // For secondary text
  final Color _textFieldBorderColor = const Color(0xFFE0E0E0); // For light borders
  final Color _textFieldFillColor = const Color(0xFFFCFCFF); // Very light fill for text fields
  final Color _signInTextColor = Colors.white; // Text color for the Sign In button
  final Color _textLinkColor = const Color.fromARGB(255, 2, 116, 91); // For 'Sign up' and 'Forgot your passphrase?'
  final Color _auraHeaderColor = const Color(0xFF3DAA80); // A green color for the AURA logo

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set the background color to a light color from the image
      backgroundColor: _scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500), // Max width for the login box
            child: Card(
              // The Card widget creates the white, rounded container
              margin: EdgeInsets.zero,
              elevation: 8, // Add some elevation for a shadow effect
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // AURA Header
                    Text(
                      'AURA',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _auraHeaderColor, // Green color for header
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Companion Text
                    Text(
                      'Welcome back to your secure mental health companion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _greyTextColor,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Username Field
                    _buildTextField(
                      label: 'Username',
                      hint: 'Enter your username',
                      controller: _usernameController,
                    ),
                    const SizedBox(height: 20),

                    // Secure Passphrase Field
                    _buildPassphraseField(),
                    const SizedBox(height: 30),

                    // Sign In Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
            onPressed: (_isLoading || !_canSubmit)
              ? null
              : () async {
                                setState(() {
                                  _isLoading = true;
                                });
                                final username = _usernameController.text.trim();
                                final passphrase = _passphraseController.text;

                                final success = await _authService.loginUser(username, passphrase);

                                setState(() {
                                  _isLoading = false;
                                });

                                if (!mounted) return;
                                final ctx = context;

                                if (success) {
                                  // Navigate to home on success
                                  Navigator.of(ctx).pushReplacementNamed('/home');
                                } else {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Authentication failed. Please check your credentials.')),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _auraPrimaryColor, // Dark Teal color
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0, 
                        ),
                        child: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                            : Text(
                                'Sign In',
                                style: TextStyle(fontSize: 18, color: _signInTextColor),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/signup');
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

                    // Forgot your password?
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPassphraseScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot your password?',
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

  // --- Helper Widgets ---

  Widget _buildTextField({
    required String label,
    required String hint,
    TextEditingController? controller,
    // IconData? icon, // Removed unused parameter
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
            // Add padding to the hint text and content
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
            filled: true,
            fillColor: _textFieldFillColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPassphraseField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Secure Password',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _passphraseController,
          obscureText: !_isPassphraseVisible, // Toggle visibility
          decoration: InputDecoration(
            hintText: 'Enter your secure password',
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
            filled: true,
            fillColor: _textFieldFillColor,
            suffixIcon: IconButton(
              icon: Icon(
                _isPassphraseVisible ? Icons.visibility : Icons.visibility_off,
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
    if (can != _canSubmit) {
      setState(() {
        _canSubmit = can;
      });
    }
  }
}