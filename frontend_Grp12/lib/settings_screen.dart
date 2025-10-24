import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'two_factor_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _twoFactorEnabled = false;
  String _autoLock = '5 minutes';
  // input styling for password fields
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

  // Two-factor is configured via the TwoFactorScreen; persistence happens after configuration.

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
            TextField(
              controller: oldCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Current password',
                filled: true,
                fillColor: _textFieldFillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'New password',
                filled: true,
                fillColor: _textFieldFillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Confirm new password',
                filled: true,
                fillColor: _textFieldFillColor,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _textFieldBorderColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Update')),
        ],
      ),
    );

    if (ok == true) {
      // TODO: securely update credentials via AuthService
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated (placeholder)')));
    }
  }

  Future<void> _chooseAutoLock() async {
    final choices = ['1 minute','5 minutes','15 minutes','30 minutes','1 hour'];
    final sel = await showDialog<String?>(context: context, builder: (c) => SimpleDialog(
      title: const Text('Auto-lock Timer'),
      children: choices.map((cname) => SimpleDialogOption(child: Text(cname), onPressed: () => Navigator.pop(c, cname))).toList(),
    ));
    if (sel != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auto_lock', sel);
      } catch (_) {}
      setState(() => _autoLock = sel);
    }
  }

  Future<void> _exportEncryptedBackup() async {
    // Require re-auth
    final ok = await _requireReauth();
    if (!ok) return;
    // TODO: gather data, encrypt with user's passphrase/key, and trigger file save/share
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exported encrypted backup (placeholder)')));
  }

  Future<void> _deleteAllData() async {
    final ok = await _requireReauth();
    if (!ok) return;
    final confirm = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete All Data'),
      content: const Text('This will permanently remove all app data. This action cannot be undone.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
    ));

    if (confirm == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All data deleted (placeholder)')));
    }
  }

  Future<bool> _requireReauth() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
      title: const Text('Re-authenticate'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Enter your secure passphrase to continue'), TextField(controller: ctrl, obscureText: true)]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirm'))],
    ));
    if (ok == true) {
      // TODO: verify passphrase with AuthService
      return true;
    }
    return false;
  }

  Future<void> _chooseAppIcon() async {
    // placeholder options (Plain Text removed)
    final icons = ['AURA (Default)', 'Solar Dot', 'Subtle Circle'];
    final sel = await showDialog<String?>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('App Icon'),
        children: icons.map((i) {
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(c, i),
            child: Row(children: [
              _buildIconPreview(i),
              const SizedBox(width: 12),
              Text(i),
            ]),
          );
        }).toList(),
      ),
    );
    if (sel != null) {
      try { final prefs = await SharedPreferences.getInstance(); await prefs.setString('app_icon_choice', sel); } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('App icon changed (placeholder)')));
    }
  }

  Future<void> _openHelp(String which) async {
    // Placeholder: navigate to pages or show dialogs
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open $which (placeholder)')));
  }

  Widget _buildIconPreview(String name) {
    // Simple preview: use the Solar Dot asset for 'Solar Dot', otherwise use an Icon.
    if (name == 'Solar Dot') {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: SvgPicture.asset('assets/icons/solar_dot.svg', width: 28, height: 28),
        ),
      );
    }
    // default small circular icon preview
    IconData ic = Icons.apps;
    if (name == 'AURA (Default)') ic = Icons.bubble_chart;
    if (name == 'Subtle Circle') ic = Icons.circle;
    return Container(width:36, height:36, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)), child: Center(child: Icon(ic, size:18, color: Colors.teal)));
  }

Future<void> _signOut() async {
  await AuthService().logoutUser();
  Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), backgroundColor: Colors.white, foregroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Card(elevation:1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('App Security', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height:12),
            // Open the Two-Factor configuration screen when tapped
            ListTile(
              title: const Text('Two Factor Authentication'),
              subtitle: const Text('Use SMS/authenticator app'),
              trailing: _twoFactorEnabled ? const Icon(Icons.check, color: Colors.teal) : null,
              onTap: () async {
                // open the two-factor screen and preselect SMS
                final res = await Navigator.of(context).push<bool?>(MaterialPageRoute(builder: (_) => const TwoFactorScreen(preselectSms: true)));
                if (res == true) {
                  // persisted as enabled via TwoFactorScreen; save a simple flag
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('two_factor_enabled', true);
                  } catch (_) {}
                  setState(() => _twoFactorEnabled = true);
                }
              },
            ),
            ListTile(title: const Text('Change Secure Passphrase'), trailing: TextButton(onPressed: _changePassphrase, child: const Text('Change'))),
            ListTile(title: const Text('Auto-lock Timer'), subtitle: Text(_autoLock), trailing: TextButton(onPressed: _chooseAutoLock, child: const Text('Change'))),
          ]))),

          const SizedBox(height:16),
          Card(elevation:1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height:12),
            ListTile(title: const Text('Export Encrypted Backup'), subtitle: const Text('Download your data with encryption'), trailing: ElevatedButton(onPressed: _exportEncryptedBackup, child: const Text('Export'))),
            ListTile(title: const Text('Delete All Data'), subtitle: const Text('Permanently remove all app data'), trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: _deleteAllData, child: const Text('Delete'))),
          ]))),

          const SizedBox(height:16),
          Card(elevation:1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Appearance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height:12),
            ListTile(title: const Text('App Icon (Discreet Options)'), subtitle: const Text('Choose a subtle icon for privacy'), trailing: TextButton(onPressed: _chooseAppIcon, child: const Text('Change'))),
          ]))),

          const SizedBox(height:16),
          Card(elevation:1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Help & Tutorials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height:12),
            ListTile(title: const Text('Frequently Asked Questions'), onTap: () => _openHelp('FAQ')),
            ListTile(title: const Text('App Tutorial & Walkthrough'), onTap: () => _openHelp('Tutorial')),
            ListTile(title: const Text('Privacy & Security Guide'), onTap: () => _openHelp('Privacy')),
            ListTile(title: const Text('Contact Support'), onTap: () => _openHelp('Support')),
          ]))),

          const SizedBox(height:16),
          Center(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)), onPressed: _signOut, child: const Padding(padding: EdgeInsets.symmetric(horizontal:24, vertical:12), child: Text('Sign Out')))),

        ]),
      ),
    );
  }
}
