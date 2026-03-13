import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TwoFactorScreen extends StatefulWidget {
  final bool preselectSms;
  const TwoFactorScreen({super.key, this.preselectSms = false});

  @override
  State<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends State<TwoFactorScreen> {
  bool _isSmsSelected = false;
  final TextEditingController _phoneController = TextEditingController();
  String? _message;
  String _randomQrData = '';

  // ── ScholarSync Colors ──────────────────────────
  static const Color _primary     = Color(0xFFFFC107);
  static const Color _foreground  = Color(0xFF1A1A1A);
  static const Color _muted       = Color(0xFFE8E8E8);
  // ───────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _isSmsSelected = widget.preselectSms;
    _generateRandomQr();
  }

  void _generateRandomQr() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    _randomQrData = List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _onSendLink() {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      setState(() => _message = '⚠️ Please enter your phone number.');
      return;
    }
    setState(() => _message = '✅ A link has been sent to $number');
  }

  void _onEnable2FA() {
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Two-Factor Authentication Enabled')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Two-Factor Authentication'),
        backgroundColor: Colors.white,
        foregroundColor: _foreground,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose 2FA Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isSmsSelected = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSmsSelected ? _primary : _muted,
                      foregroundColor: _foreground,
                    ),
                    child: const Text('SMS'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _isSmsSelected = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isSmsSelected ? _primary : _muted,
                      foregroundColor: _foreground,
                    ),
                    child: const Text('QR Code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isSmsSelected) ...[
              const Text('Enter your phone number to receive a link:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+63XXXXXXXXXX',
                  filled: true,
                  fillColor: _muted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _onSendLink,
                style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: _foreground),
                child: const Text('Send Verification Link'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(_message!, style: const TextStyle(color: Color(0xFF5A5A4D), fontWeight: FontWeight.w500)),
              ],
            ] else ...[
              const Text('Scan this QR code using your authenticator app:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              Center(child: QrImageView(data: _randomQrData, size: 200, backgroundColor: Colors.white)),
              const SizedBox(height: 10),
              Center(child: Text('Code: $_randomQrData', style: const TextStyle(fontSize: 14, color: Colors.grey))),
            ],
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _onEnable2FA,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: _foreground,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                ),
                child: const Text('Enable 2FA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}