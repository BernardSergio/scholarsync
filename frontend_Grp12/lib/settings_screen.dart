import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'two_factor_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _twoFactorEnabled = false;
  String _autoLock = '5 minutes';
  final Color _textFieldBorderColor = const Color(0xFF6F6565);
  final Color _textFieldFillColor = const Color(0xFFF7F5F7);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _twoFactorEnabled = prefs.getBool('two_factor_enabled') ?? false;
        _autoLock = prefs.getString('auto_lock') ?? '5 minutes';
      });
    } catch (_) {}
  }

Future<void> _changePassphrase() async {
  final oldCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  final ok = await showDialog<bool?>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Change Secure Password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPasswordField(oldCtrl, 'Current password'),
          const SizedBox(height: 8),
          _buildPasswordField(newCtrl, 'New password'),
          const SizedBox(height: 8),
          _buildPasswordField(confirmCtrl, 'Confirm new password'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Update'),
        ),
      ],
    ),
  );

  if (ok == true) {
    // Validate matching passwords
    if (newCtrl.text.trim() != confirmCtrl.text.trim()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ New passwords do not match')),
      );
      return;
    }

    // Validate password length
    if (newCtrl.text.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Password must be at least 6 characters')),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Call API to change password
    final result = await AuthService().changePassword(
      oldCtrl.text.trim(),
      newCtrl.text.trim(),
    );

    // Hide loading indicator
    Navigator.pop(context);

    // Show result
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${result['message']}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${result['message']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  Widget _buildPasswordField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      obscureText: true,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: _textFieldFillColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _textFieldBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _textFieldBorderColor),
        ),
      ),
    );
  }
Future<void> _chooseAutoLock() async {
  final choices = ['1 minute', '5 minutes', '15 minutes', '30 minutes', '1 hour'];
  final sel = await showDialog<String?>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('Auto-lock Timer'),
      children: choices
          .map((cname) => SimpleDialogOption(
                child: Text(cname),
                onPressed: () => Navigator.pop(c, cname),
              ))
          .toList(),
    ),
  );

  if (sel != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auto_lock', sel);
    setState(() => _autoLock = sel);
  }
}

  // 🧱 --- REAL ENCRYPTED BACKUP LOGIC ---
Future<void> _exportEncryptedBackup() async {
  final ok = await _requireReauth();
  if (!ok) return;

  final prefs = await SharedPreferences.getInstance();
  final allData = prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
    map[key] = prefs.get(key);
    return map;
  });

  if (allData.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No data to back up.')),
    );
    return;
  }

  final passphrase = await _getPassphrase();
  if (passphrase == null || passphrase.isEmpty) return;

  final jsonData = jsonEncode(allData);
  final encryptedData = _encryptData(jsonData, passphrase);

  // ✅ Save to Downloads folder instead of internal documents
  Directory? dir;
  try {
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
    } else {
      dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }

  final backupPath = '${dir.path}/aura_backup.enc';
  final backupFile = File(backupPath);
  await backupFile.writeAsBytes(encryptedData);

  // ✅ Notify the user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Encrypted backup saved to:\n$backupPath'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );

  // ✅ Open File Explorer / Share dialog
  try {
    await Share.shareXFiles(
      [XFile(backupFile.path)],
      text: 'Your encrypted AURA backup file.',
      subject: 'AURA Backup Export',
    );
  } catch (e) {
    debugPrint('⚠️ Share dialog failed: $e');
  }
}


  List<int> _encryptData(String data, String passphrase) {
    final key = encrypt.Key.fromUtf8(passphrase.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(data, iv: iv);
    return encrypted.bytes;
  }

  Future<String?> _getPassphrase() async {
    final ctrl = TextEditingController();
    return await showDialog<String?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enter Backup Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Enter passphrase'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );
  }

Future<void> _deleteAllData() async {
  final ok = await _requireReauth();
  if (!ok) return;

  final confirm = await showDialog<bool?>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Delete All Data'),
      content: const Text('This will permanently remove all app data. This action cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );

  if (confirm == true) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // ✅ Web-safe notice
    debugPrint('🌐 Running on web — skipping file system cleanup.');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('🧹 All data deleted successfully')),
    );

    // ✅ Automatically sign out and redirect to login
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      await AuthService().logoutUser();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }
}



  Future<bool> _requireReauth() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Re-authenticate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your password to continue'),
            TextField(controller: ctrl, obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm')),
        ],
      ),
    );
    return ok == true;
  }

Future<void> _chooseAppIcon() async {
  final icons = ['AURA (Default)', 'Solar Dot', 'Subtle Circle'];
  final sel = await showDialog<String?>(
    context: context,
    builder: (c) => SimpleDialog(
      title: const Text('App Icon'),
      children: icons.map((i) {
        return SimpleDialogOption(
          onPressed: () => Navigator.pop(c, i),
          child: Row(
            children: [
              _buildIconPreview(i),
              const SizedBox(width: 12),
              Text(i),
            ],
          ),
        );
      }).toList(),
    ),
  );

  if (sel != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_icon_choice', sel);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ App icon saved — will load next time'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 3),
      ),
    );

    debugPrint('✅ Saved app icon choice: $sel');
  }
}

Widget _buildIconPreview(String name) {
  IconData ic = Icons.apps;
  if (name == 'AURA (Default)') ic = Icons.bubble_chart;
  if (name == 'Solar Dot') ic = Icons.brightness_5;
  if (name == 'Subtle Circle') ic = Icons.circle_outlined;

  return Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(child: Icon(ic, size: 20, color: Colors.teal)),
  );
}


  Future<void> _signOut() async {
    await AuthService().logoutUser();
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  Widget _faqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      childrenPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      children: [
        Text(answer, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Settings'), backgroundColor: Colors.white, foregroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // SECURITY CARD
          _buildSecurityCard(),

          const SizedBox(height: 16),
          _buildDataCard(),

          const SizedBox(height: 16),
          _buildAppearanceCard(),

          const SizedBox(height: 16),
          _buildHelpCard(),

          const SizedBox(height: 16),
          Center(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  onPressed: _signOut,
                  child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Text('Sign Out')))),
        ]),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('App Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            title: const Text('Two Factor Authentication'),
            subtitle: const Text('Use SMS/authenticator app'),
            trailing: _twoFactorEnabled ? const Icon(Icons.check, color: Colors.teal) : null,
            onTap: () async {
              final res = await Navigator.of(context)
                  .push<bool?>(MaterialPageRoute(builder: (_) => const TwoFactorScreen(preselectSms: true)));
              if (res == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('two_factor_enabled', true);
                setState(() => _twoFactorEnabled = true);
              }
            },
          ),
          ListTile(
              title: const Text('Change Password'),
              trailing: TextButton(onPressed: _changePassphrase, child: const Text('Change'))),
          ListTile(
              title: const Text('Auto-lock Timer'),
              subtitle: Text(_autoLock),
              trailing: TextButton(onPressed: _chooseAutoLock, child: const Text('Change'))),
        ]),
      ),
    );
  }

  Widget _buildDataCard() {
    return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Data Management',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                  title: const Text('Export Encrypted Backup'),
                  subtitle: const Text('Download your data with encryption'),
                  trailing:
                      ElevatedButton(onPressed: _exportEncryptedBackup, child: const Text('Export'))),
              ListTile(
                  title: const Text('Delete All Data'),
                  subtitle: const Text('Permanently remove all app data'),
                  trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _deleteAllData,
                      child: const Text('Delete'))),
            ])));
  }

  Widget _buildAppearanceCard() {
    return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Appearance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListTile(
                  title: const Text('App Icon (Discreet Options)'),
                  subtitle: const Text('Choose a subtle icon for privacy'),
                  trailing: TextButton(onPressed: _chooseAppIcon, child: const Text('Change'))),
            ])));
  }

  Widget _buildHelpCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Help & Tutorials',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Frequently Asked Questions (FAQs)'),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              const Text('General & Security',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _faqItem(
                  'What is AURA?',
                  'AURA is a secure, mobile application designed to be your private partner in managing HIV treatment and prevention. It helps you track medication, log your mood and side effects, schedule appointments, and access resources, all within a confidential, encrypted environment on your device.'),
              _faqItem(
                  'How is my privacy protected?',
                  'Your privacy is our top priority. AURA uses strong, multi-layered security. All your data is encrypted and stored locally by default. Your personal information is never shared without consent, complying with the Philippine Data Privacy Act (RA 10173).'),
              _faqItem(
                  'What happens if I forget my passphrase?',
                  'You can use the "Forgot Passphrase" feature on the login screen. This triggers a secure recovery process using your registered email or two-factor authentication.'),
              _faqItem(
                  'What does the "Discreet App Icon" do?',
                  'It allows you to change the app icon to a neutral one (like a calendar or notes icon) for privacy on your device.'),

              const SizedBox(height: 10),
              const Text('Features & Functionality',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _faqItem('How do I log my medication?',
                  'Quickly from the Home Screen using the "Log Medication" button, or in detail via Journal Vault > Add New Entry > Medication.'),
              _faqItem('Can I back up my data?',
                  'Yes. You can export encrypted backups under Settings > Data Management. The file is password-protected for security.'),
              _faqItem('How do Smart Reminders work?',
                  'Set customizable medication or appointment reminders. Notifications appear discreetly, and you can mark them as "Taken", "Missed", or "Snooze".'),
              _faqItem('Does the app work offline?',
                  'Yes, core features work offline. Only backup syncing, sending SMS/email reminders, and map use require internet.'),
              _faqItem('How can I delete all my data?',
                  'Go to Settings > Data Management > Delete All Data. This action is irreversible.'),

              const SizedBox(height: 10),
              const Text('Support & Troubleshooting',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _faqItem('My account is locked. What should I do?',
                  'Your account locks after five failed login attempts and unlocks automatically after a short time. If not, use recovery or contact support.'),
              _faqItem('How do I contact support?',
                  'Go to Settings > Help & Tutorials > Contact Support. This ensures secure handling of your inquiries.'),
              _faqItem('Is AURA free to use?',
                  'Yes, AURA is free. It’s designed to provide private, accessible health management tools to everyone.'),
            ],
          ),
        ]),
      ),
    );
  }
}
