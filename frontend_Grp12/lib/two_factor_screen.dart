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
  String? _message; // To show “link sent” message
  String _randomQrData = '';

  @override
  void initState() {
    super.initState();
    _isSmsSelected = widget.preselectSms;
    _generateRandomQr();
  }

  void _generateRandomQr() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    _randomQrData =
        List.generate(12, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  void _onSendLink() {
    final number = _phoneController.text.trim();
    if (number.isEmpty) {
      setState(() => _message = '⚠️ Please enter your phone number.');
      return;
    }

    setState(() {
      _message = '✅ A link has been sent to $number';
    });
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
        foregroundColor: Colors.teal,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose 2FA Method',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => _isSmsSelected = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isSmsSelected
                          ? Colors.teal
                          : Colors.grey[300],
                      foregroundColor:
                          _isSmsSelected ? Colors.white : Colors.black,
                    ),
                    child: const Text('SMS'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () =>
                        setState(() => _isSmsSelected = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_isSmsSelected
                          ? Colors.teal
                          : Colors.grey[300],
                      foregroundColor:
                          !_isSmsSelected ? Colors.white : Colors.black,
                    ),
                    child: const Text('QR Code'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isSmsSelected) ...[
              const Text(
                'Enter your phone number to receive a link:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: '+63XXXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _onSendLink,
                child: const Text('Send Verification Link'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: const TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.w500),
                ),
              ],
            ] else ...[
              const Text(
                'Scan this QR code using your authenticator app:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: _randomQrData,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'Code: $_randomQrData',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: _onEnable2FA,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 14)),
                child: const Text('Enable 2FA'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
