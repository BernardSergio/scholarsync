import 'package:flutter/material.dart';

class TwoFactorScreen extends StatefulWidget {
  final bool preselectSms;
  const TwoFactorScreen({super.key, this.preselectSms = false});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _useAuthenticator = true;
  bool _isLoading = false;

  final TextEditingController _phoneController = TextEditingController();

  final Color _auraPrimaryColor = const Color.fromARGB(255, 0, 146, 110);
  final Color _scaffoldBackgroundColor = const Color(0xFFF3F7FF);
  final Color _greyTextColor = const Color(0xFF757575);
  final Color _textFieldBorderColor = const Color(0xFFE0E0E0);
  final Color _textFieldFillColor = const Color(0xFFFCFCFF);
  final Color _auraHeaderColor = const Color(0xFF3DAA80);

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If caller asked to preselect SMS, set accordingly
    try { _useAuthenticator = !(widget.preselectSms); } catch (_) {}
  }

  Future<void> _enable() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two-factor authentication enabled')));
    Navigator.of(context).pop();
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                      'Enable Two-Factor Authentication',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _greyTextColor, fontSize: 16),
                    ),
                    const SizedBox(height: 20),

                    // Option toggle
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('Authenticator App'),
                            selected: _useAuthenticator,
                            onSelected: (v) => setState(() => _useAuthenticator = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text('SMS / Phone'),
                            selected: !_useAuthenticator,
                            onSelected: (v) => setState(() => _useAuthenticator = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (_useAuthenticator) ...[
                      // QR placeholder and secret
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: _textFieldFillColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _textFieldBorderColor),
                        ),
                        child: const Center(child: Text('QR Code placeholder')),
                      ),
                      const SizedBox(height: 12),
                      const Text('Scan the QR code with your authenticator app and enter the generated code when prompted.'),
                    ] else ...[
                      // SMS
                      Text(
                        'Enter your phone number to receive verification codes via SMS.',
                        style: TextStyle(color: _greyTextColor),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'e.g. +1 555 123 4567',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _textFieldBorderColor)),
                          filled: true,
                          fillColor: _textFieldFillColor,
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _auraPrimaryColor,
                              side: BorderSide(color: _auraPrimaryColor),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _enable,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _auraPrimaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: _isLoading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))) : const Text('Enable', style: TextStyle(color: Colors.white)),
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
