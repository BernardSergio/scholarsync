// reminders.dart 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'auth_service.dart';
import 'appointments.dart';
import 'config.dart';

final _fixedIV = encryptpkg.IV.fromUtf8('ss_fixed_iv_2025__'.padRight(16).substring(0, 16));
final ValueNotifier<int> remindersNotifier = ValueNotifier<int>(0);

enum ReminderStatus { pending, taken, missed }

class Reminder {
  String id;
  String medication;
  String dosage;
  DateTime dateTime;
  bool enabled;
  bool notify;
  bool repeatDaily;
  DateTime? takenAt;
  String? backendId;

  Reminder({
    required this.id,
    required this.medication,
    required this.dosage,
    required this.dateTime,
    this.enabled = true,
    this.notify = true,
    this.repeatDaily = false,
    this.takenAt,
    this.backendId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'medication': medication,
        'dosage': dosage,
        'dateTime': dateTime.toIso8601String(),
        'enabled': enabled,
        'notify': notify,
        'repeatDaily': repeatDaily,
        'takenAt': takenAt?.toIso8601String(),
        'backendId': backendId,
      };

  static Reminder fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        medication: j['medication'] ?? '',
        dosage: j['dosage'] ?? '',
        dateTime: DateTime.parse(j['dateTime']),
        enabled: j['enabled'] ?? true,
        notify: j['notify'] ?? true,
        repeatDaily: j['repeatDaily'] ?? false,
        takenAt: j['takenAt'] != null ? DateTime.parse(j['takenAt']) : null,
        backendId: j['backendId'],
      );

  // FIXED: Better backend JSON parsing
  static Reminder fromBackendJson(Map<String, dynamic> j) {
    debugPrint('📝 Parsing backend reminder: $j');
    
    final timeStr = j['time'] as String? ?? '12:00 PM';
    final now = DateTime.now();
    
    DateTime parsedDateTime;
    try {
      // Clean and parse time string
      final cleaned = timeStr.trim().replaceAll(RegExp(r'\s+'), ' ');
      final parts = cleaned.split(' ');
      
      final timePart = parts[0];
      final meridiem = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      
      final hourMin = timePart.split(':');
      int hour = int.parse(hourMin[0]);
      final minute = hourMin.length > 1 ? int.parse(hourMin[1]) : 0;
      
      // Convert to 24-hour format
      if (meridiem == 'PM' && hour != 12) {
        hour += 12;
      } else if (meridiem == 'AM' && hour == 12) {
        hour = 0;
      }
      
      parsedDateTime = DateTime(now.year, now.month, now.day, hour, minute);
      debugPrint('✅ Parsed: "$timeStr" -> $parsedDateTime (${hour}:${minute.toString().padLeft(2, '0')})');
    } catch (e) {
      debugPrint('❌ Parse error: $e');
      parsedDateTime = now;
    }

    final backendId = j['_id'] as String?;
    final taken = j['taken'] == true;
    
    final reminder = Reminder(
      id: backendId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      medication: j['medicationName'] ?? 'Unknown',
      dosage: j['dosage'] ?? 'Unknown',
      dateTime: parsedDateTime,
      enabled: true,
      notify: !(j['notified'] ?? false),
      repeatDaily: false,
      takenAt: taken ? parsedDateTime : null,
      backendId: backendId,
    );
    
    debugPrint('✅ Reminder created: ${reminder.medication} @ ${DateFormat.jm().format(reminder.dateTime)}');
    return reminder;
  }

  ReminderStatus status() {
    final now = DateTime.now();
    if (takenAt != null) return ReminderStatus.taken;
    if (now.isBefore(dateTime.add(const Duration(minutes: 60)))) return ReminderStatus.pending;
    return ReminderStatus.missed;
  }
}

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  final List<Reminder> _reminders = [];
  final List<Map<String, dynamic>> _history = [];
  bool _loadedOnce = false;
  final Set<String> _fading = {};
  bool _isLoading = false;

String _storageKeyFor(String username) => 'scholarsync_reminders_$username';
String _historyKeyFor(String username) => 'scholarsync_reminder_history_$username';

  @override
  void initState() {
    super.initState();
    _loadReminders();
    remindersNotifier.addListener(_onRemindersChanged);
  }

  @override
  void dispose() {
    try {
      remindersNotifier.removeListener(_onRemindersChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onRemindersChanged() {
    debugPrint('🔔 Reminder changed - reloading...');
    _loadReminders();
  }

  Future<encryptpkg.Key?> _keyForCurrentUser() async {
    final u = AuthService().currentUser;
    if (u == null) return null;
    final passphrase = u['passphrase'] ?? '';
    final k = ('${passphrase}ss_salt_2025____').padRight(32).substring(0, 32);
    return encryptpkg.Key.fromUtf8(k);
  }

Future<void> _loadReminders() async {
  await AuthService().getCurrentUser();
  final u = AuthService().currentUser;

  if (u == null || u['token'] == null) {
    debugPrint('❌ No user logged in (token missing)');
    if (mounted) setState(() => _isLoading = false);
    return;
  }

  if (mounted) setState(() => _isLoading = true);

  debugPrint('\n🔄 === LOADING REMINDERS ===');
  debugPrint('User: ${u['username']}');
  debugPrint('Token (first 20): ${u['token'].toString().substring(0, 20)}...');

  try {
    // ✅ Backend first
    final backendReminders = await _loadFromBackend();
    debugPrint('📦 Backend: ${backendReminders.length} reminders');

    // ✅ Then local
    final localReminders = await _loadFromLocal();
    debugPrint('💾 Local: ${localReminders.length} reminders');

    // ✅ Merge logic
    final Map<String, Reminder> merged = {};

    for (final r in backendReminders) {
      merged[r.id] = r;
    }
    for (final r in localReminders) {
      if (!merged.containsKey(r.id) && r.backendId == null) {
        merged[r.id] = r;
      }
    }

    if (mounted) {
      setState(() {
        _reminders
          ..clear()
          ..addAll(merged.values)
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
        _isLoading = false;
      });
    }
  } catch (e) {
    debugPrint('❌ Error loading reminders: $e');
    if (mounted) setState(() => _isLoading = false);
  }
}


  Future<List<Reminder>> _loadFromBackend() async {
    final u = AuthService().currentUser;
    if (u == null || u['token'] == null) {
      debugPrint('  ❌ No token available');
      return [];
    }

    try {
      debugPrint('  📡 GET $baseUrl/reminders');
      final response = await http.get(
        Uri.parse('$baseUrl/reminders'),
        headers: {
          'Authorization': 'Bearer ${u['token']}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      debugPrint('  📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        debugPrint('  📥 Body: ${response.body}');
        
        final reminders = <Reminder>[];
        for (var item in data) {
          try {
            reminders.add(Reminder.fromBackendJson(item));
          } catch (e) {
            debugPrint('  ⚠️ Skip invalid reminder: $e');
          }
        }
        
        return reminders;
      } else {
        debugPrint('  ❌ Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Exception: $e');
    }
    return [];
  }

  Future<List<Reminder>> _loadFromLocal() async {
    final u = AuthService().currentUser;
    if (u == null) return [];

    final prefs = await SharedPreferences.getInstance();
    final enc = prefs.getString(_storageKeyFor(u['username']));
    
    if (enc != null && enc.isNotEmpty) {
      try {
        final key = await _keyForCurrentUser();
        if (key != null) {
          final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
          final dec = encrypter.decrypt64(enc, iv: _fixedIV);
          final list = json.decode(dec) as List<dynamic>;
          return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {
        try {
          final list = json.decode(enc) as List<dynamic>;
          return list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
    }
    return [];
  }

  Future<void> _saveForCurrentUser() async {
    final u = AuthService().currentUser;
    if (u == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyForCurrentUser();
    if (key == null) return;
    
    final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
    final seen = <String>{};
    final dedupedReversed = <Map<String, dynamic>>[];
    
    for (final r in _reminders.reversed) {
      if (!seen.contains(r.id)) {
        dedupedReversed.add(r.toJson());
        seen.add(r.id);
      }
    }
    
    final deduped = dedupedReversed.reversed.toList();
    final payload = json.encode(deduped);
    final encrypted = encrypter.encrypt(payload, iv: _fixedIV).base64;
    await prefs.setString(_storageKeyFor(u['username']), encrypted);
    await prefs.setString(_historyKeyFor(u['username']), json.encode(_history));
  }

  // FIXED: Better backend saving with logging
  Future<String?> _saveToBackend(Reminder reminder) async {
    // IMPORTANT: Load user from storage first!
    await AuthService().getCurrentUser();
    
    final u = AuthService().currentUser;
    
    debugPrint('\n📤 === ATTEMPTING SAVE TO BACKEND ===');
    debugPrint('User: ${u != null ? u['username'] : 'NULL'}');
    debugPrint('Token exists: ${u?['token'] != null}');
    
    if (u == null || u['token'] == null) {
      debugPrint('❌ Cannot save: no token');
      debugPrint('===========================\n');
      return null;
    }

    try {
      final timeStr = DateFormat.jm().format(reminder.dateTime);
      debugPrint('Medication: ${reminder.medication}');
      debugPrint('Dosage: ${reminder.dosage}');
      debugPrint('Time: $timeStr');
      debugPrint('URL: $baseUrl/reminders');
      debugPrint('Token (first 30 chars): ${u['token'].toString().substring(0, 30)}...');
      
      debugPrint('🌐 Sending HTTP POST request...');
      
      final response = await http.post(
          Uri.parse('$baseUrl/reminders'),
        headers: {
          'Authorization': 'Bearer ${u['token']}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'medicationName': reminder.medication,
          'dosage': reminder.dosage,
          'time': timeStr,
        }),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('⏰ Request timeout!');
          throw Exception('Request timeout');
        },
      );

      debugPrint('📥 Response received!');
      debugPrint('📥 Status: ${response.statusCode}');
      debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final backendId = data['reminder']['_id'] as String?;
        debugPrint('✅ Saved with ID: $backendId');
        debugPrint('===========================\n');
        return backendId;
      } else {
        debugPrint('❌ Save failed: ${response.statusCode}');
        debugPrint('===========================\n');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Exception caught: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('===========================\n');
    }
    return null;
  }

  Future<void> _toggleTakenBackend(String backendId) async {
    final u = AuthService().currentUser;
    if (u == null || u['token'] == null) return;

    try {
      await http.put(
        Uri.parse('$baseUrl/reminders/$backendId/toggle'),
        headers: {
          'Authorization': 'Bearer ${u['token']}',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      debugPrint('Error toggling: $e');
    }
  }

  Future<void> _deleteFromBackend(String backendId) async {
    final u = AuthService().currentUser;
    if (u == null || u['token'] == null) return;

    try {
      await http.delete(
          Uri.parse('$baseUrl/reminders/$backendId'),
        headers: {
          'Authorization': 'Bearer ${u['token']}',
          'Content-Type': 'application/json',
        },
      );
    } catch (e) {
      debugPrint('Error deleting: $e');
    }
  }

  Future<void> _addOrEditReminder({Reminder? existing, int? index}) async {
    final medCtrl = TextEditingController(text: existing?.medication ?? '');
    final doseCtrl = TextEditingController(text: existing?.dosage ?? '');
    DateTime? selectedDate = existing?.dateTime;
    TimeOfDay? selectedTime = existing != null ? TimeOfDay.fromDateTime(existing.dateTime) : null;
    bool notify = existing?.notify ?? true;
    bool repeat = existing?.repeatDaily ?? false;

    await showDialog<bool?>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Reminder' : 'Edit Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: medCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medication name',
                    filled: true,
                    fillColor: Color(0xFFF3F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: doseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    filled: true,
                    fillColor: Color(0xFFF3F6F8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: selectedDate ?? now,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (d != null) setDialogState(() => selectedDate = d);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F6F8),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedDate == null
                                ? 'Select date'
                                : DateFormat.yMMMd().format(selectedDate!),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                            context: context,
                            initialTime: selectedTime ?? TimeOfDay.now(),
                          );
                          if (t != null) setDialogState(() => selectedTime = t);
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFF3F6F8),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            selectedTime == null
                                ? 'Select time'
                                : selectedTime!.format(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: Icon(
                        notify ? Icons.notifications_active : Icons.notifications_off,
                        key: ValueKey<bool>(notify),
                      color: notify ? const Color(0xFFFFC107) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Checkbox(
                      value: notify,
                      onChanged: (v) => setDialogState(() => notify = v ?? true),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Enable notification')),
                  ],
                ),
                Row(
                  children: [
                    Checkbox(
                      value: repeat,
                      onChanged: (v) => setDialogState(() => repeat = v ?? false),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Repeat daily')),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final med = medCtrl.text.trim();
                final dose = doseCtrl.text.trim();
                
                if (med.isEmpty || dose.isEmpty) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter medication name and dosage'),
                      ),
                    );
                  }
                  return;
                }

                DateTime finalDt;
                if (selectedDate != null && selectedTime != null) {
                  finalDt = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                } else {
                  finalDt = DateTime.now().add(const Duration(hours: 1));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No date/time chosen – defaulting to 1 hour from now'),
                      ),
                    );
                  }
                }

                if (finalDt.isBefore(DateTime.now())) {
                  if (repeat) {
                    while (finalDt.isBefore(DateTime.now())) {
                      finalDt = finalDt.add(const Duration(days: 1));
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select future time or enable Repeat daily'),
                        ),
                      );
                    }
                    return;
                  }
                }

                Navigator.pop(c, null);

                debugPrint('\n🔵 === STARTING SAVE PROCESS ===');

                // Show loading
                if (mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (loadingCtx) => const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Saving reminder...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
                final r = Reminder(
                  id: id,
                  medication: med,
                  dosage: dose,
                  dateTime: finalDt,
                  enabled: true,
                  notify: notify,
                  repeatDaily: repeat,
                  takenAt: existing?.takenAt,
                  backendId: existing?.backendId,
                );

                debugPrint('🔵 Created reminder object: ${r.medication}');
                debugPrint('🔵 Calling _saveToBackend...');

                // Save to backend FIRST
                final backendId = await _saveToBackend(r);
                
                debugPrint('🔵 _saveToBackend returned: $backendId');
                
                if (backendId != null) {
                  r.backendId = backendId;
                  r.id = backendId; // Use backend ID
                  debugPrint('✅ Backend save successful');
                } else {
                  debugPrint('⚠️ Backend save failed or unavailable');
                }

                // Update local list
                if (existing != null && index != null) {
                  _reminders[index] = r;
                } else {
                  _reminders.insert(0, r);
                }

                await _saveForCurrentUser();
                remindersNotifier.value = remindersNotifier.value + 1;

                // Close loading
                if (mounted) Navigator.pop(context);

                // Reload from backend
                await _loadReminders();
                
                debugPrint('🔵 === SAVE PROCESS COMPLETE ===\n');

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(backendId != null 
                        ? 'Reminder saved successfully!' 
                        : 'Reminder Saved!'),
                      backgroundColor: backendId != null ? Colors.green : Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTaken(int index) async {
    final r = _reminders[index];
    if (r.takenAt != null) return;

    r.takenAt = DateTime.now();

    if (r.backendId != null) {
      await _toggleTakenBackend(r.backendId!);
    }

    if (!r.repeatDaily) {
      _fading.add(r.id);
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 600));
      
      final exists = _history.any((h) => h['id'] == r.id && h['status'] == 'taken');
      if (!exists) {
        _history.insert(0, {
          'id': r.id,
          'medication': r.medication,
          'when': r.takenAt!.toIso8601String(),
          'status': 'taken',
        });
      }
      
      _reminders.removeWhere((x) => x.id == r.id);
      _fading.remove(r.id);
      await _saveForCurrentUser();
      remindersNotifier.value = remindersNotifier.value + 1;
      
      setState(() {});
    } else {
      final exists = _history.any((h) => h['id'] == r.id && h['status'] == 'taken');
      if (!exists) {
        _history.insert(0, {
          'id': r.id,
          'medication': r.medication,
          'when': r.takenAt!.toIso8601String(),
          'status': 'taken',
        });
      }
      
      await _saveForCurrentUser();
      remindersNotifier.value = remindersNotifier.value + 1;
      
      setState(() {});
    }
  }

  List<Reminder> _todaysMeds() {
    final now = DateTime.now();
    return _reminders.where((r) {
      return r.dateTime.year == now.year &&
          r.dateTime.month == now.month &&
          r.dateTime.day == now.day;
    }).toList();
  }

  Future<List<Appointment>> _loadTodaysAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('scholarsync_sessions');
    final List<Appointment> out = [];
    if (raw == null || raw.isEmpty) return out;
    
    try {
      final list = json.decode(raw) as List<dynamic>;
      final now = DateTime.now();
      for (final e in list) {
        try {
          final a = Appointment.fromJson(e as Map<String, dynamic>);
          final dt = a.dateTime;
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
            out.add(a);
          }
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  Widget _statusBadge(ReminderStatus s) {
    switch (s) {
      case ReminderStatus.taken:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Taken',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
      case ReminderStatus.pending:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Pending',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
      case ReminderStatus.missed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'Missed',
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loadedOnce) {
      _loadedOnce = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReminders());
    }

    final bottomPad = MediaQuery.of(context).viewPadding.bottom +
        kBottomNavigationBarHeight +
        24.0;

    final todays = _todaysMeds();
    
    return SafeArea(
      bottom: true,
      child: RefreshIndicator(
        onRefresh: _loadReminders,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Smart Reminders',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadReminders,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Today's meds
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            const Icon(Icons.assignment, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text(
                                "Today's Assignment Schedule",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (todays.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('No assignment reminders for today'),
                            ),
                          )
                        else
                          ...todays.map((r) {
                            final s = r.status();
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: s == ReminderStatus.taken 
                                ? Colors.green.shade50 
                                : Colors.white,
                              child: ListTile(
                                leading: Icon(
                                  s == ReminderStatus.taken
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: s == ReminderStatus.taken
                                      ? Colors.green
                                      : s == ReminderStatus.pending
                                      ? Colors.orange
                                      : Colors.red,
                                  size: 32,
                                ),
                                title: Text(
                                  '${r.medication} • ${r.dosage}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    decoration: s == ReminderStatus.taken
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                subtitle: Text(
                                  TimeOfDay.fromDateTime(r.dateTime).format(context),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _statusBadge(s),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Reminder?'),
                                            content: const Text('Are you sure?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          if (r.backendId != null) {
                                            await _deleteFromBackend(r.backendId!);
                                          }
                                          _reminders.removeWhere((x) => x.id == r.id);
                                          await _saveForCurrentUser();
                                          remindersNotifier.value = remindersNotifier.value + 1;
                                          await _loadReminders();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  if (r.takenAt == null) {
                                    final orig = _reminders.indexWhere((x) => x.id == r.id);
                                    if (orig != -1) _toggleTaken(orig);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _addOrEditReminder(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Reminder'),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Reminder history
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            const Icon(Icons.history, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text(
                              'Reminder History',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_history.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: Text('No recent activity')),
                          )
                        else
                          ...(_history.take(5).map((h) {
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      h['medication'] ?? 'Unknown',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      h['status'] ?? 'taken',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList()),
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () async {
                                  final ok = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear history?'),
                                      content: const Text(
                                        'This will permanently remove your reminder history. Continue?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Clear', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (ok == true) {
                                    _history.clear();
                                    await _saveForCurrentUser();
                                    setState(() {});
                                  }
                                },
                                child: const Text('Clear History'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Appointments section (KEPT AS IS)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFFFFC107)),
                            SizedBox(width: 8),
                            Text(
                            'Upcoming Study Sessions',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FutureBuilder<List<Appointment>>(
                          future: _loadTodaysAppointments(),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const SizedBox.shrink();
                            }
                            final list = snap.data ?? [];
                            if (list.isEmpty) {
                            return const Text('No study sessions scheduled for today');
                            }
                            return Column(
                              children: list.map((a) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(a.provider),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            TimeOfDay.fromDateTime(a.dateTime).format(context),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(a.location),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          TextButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(Icons.place),
                                            label: const Text('Directions'),
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit Reminder'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for other pages
  Future<List<Map<String, dynamic>>> loadTodaysReminderMaps() async {
    final out = <Map<String, dynamic>>[];
    final u = AuthService().currentUser;
    if (u == null) return out;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('scholarsync_reminders_${u['username']}');
      if (raw == null || raw.isEmpty) return out;

      final passphrase = u['passphrase'] ?? 'default_pass';
      final keyStr = ('${passphrase}ss_salt_2025____').padRight(32).substring(0, 32);
      final key = encryptpkg.Key.fromUtf8(keyStr);
      final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));

      try {
        final dec = encrypter.decrypt64(raw, iv: _fixedIV);
        final list = json.decode(dec) as List<dynamic>;
        final now = DateTime.now();
        for (final e in list) {
          try {
            final m = Map<String, dynamic>.from(e as Map);
            final dt = DateTime.parse(m['dateTime'] as String);
            if (dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day) {
              out.add(m);
            }
          } catch (_) {}
        }
        return out;
      } catch (_) {
        try {
          final list = json.decode(raw) as List<dynamic>;
          final now = DateTime.now();
          for (final e in list) {
            try {
              final m = Map<String, dynamic>.from(e as Map);
              final dt = DateTime.parse(m['dateTime'] as String);
              if (dt.year == now.year &&
                  dt.month == now.month &&
                  dt.day == now.day) {
                out.add(m);
              }
            } catch (_) {}
          }
        } catch (_) {}
      }
    } catch (_) {}

    return out;
  }
}

// Helper function for other pages to add reminders
Future<bool?> showAddReminderDialog(BuildContext context) async {
  final medCtrl = TextEditingController();
  final doseCtrl = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool notify = true;
  bool repeat = false;

  final u = AuthService().currentUser;
  if (u == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first')),
      );
    }
    return null;
  }

  final result = await showDialog<bool?>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Add Reminder'),
      content: StatefulBuilder(
        builder: (ctx, setState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: medCtrl,
                decoration: const InputDecoration(
                    labelText: 'Assignment name',
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: doseCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject / Course',
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final d = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? now,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (d != null) setState(() => selectedDate = d);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F6F8),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedDate == null
                              ? 'Select date'
                              : DateFormat.yMMMd().format(selectedDate!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (t != null) setState(() => selectedTime = t);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F6F8),
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          selectedTime == null
                              ? 'Select time'
                              : selectedTime!.format(context),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: notify,
                    onChanged: (v) => setState(() => notify = v ?? true),
                  ),
                  const Expanded(child: Text('Enable notification')),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: repeat,
                    onChanged: (v) => setState(() => repeat = v ?? false),
                  ),
                  const Expanded(child: Text('Repeat daily')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            final med = medCtrl.text.trim();
            final dose = doseCtrl.text.trim();
            
            if (med.isEmpty || dose.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                content: Text('Please enter assignment name and subject'),
                  ),
                );
              }
              return;
            }
            
            DateTime finalDt;
            if (selectedDate != null && selectedTime != null) {
              finalDt = DateTime(
                selectedDate!.year,
                selectedDate!.month,
                selectedDate!.day,
                selectedTime!.hour,
                selectedTime!.minute,
              );
            } else {
              finalDt = DateTime.now().add(const Duration(hours: 1));
            }
            
            if (finalDt.isBefore(DateTime.now())) {
              if (repeat) {
                while (finalDt.isBefore(DateTime.now())) {
                  finalDt = finalDt.add(const Duration(days: 1));
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a future time')),
                  );
                }
                return;
              }
            }

            Navigator.pop(c, true);

            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (loadingCtx) => const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Saving reminder...'),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            try {
              final token = u['token'] as String?;
              if (token != null) {
                final timeStr = DateFormat.jm().format(finalDt);
                
                final response = await http.post(
                  Uri.parse('$baseUrl/reminders'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                  body: json.encode({
                    'medicationName': med,
                    'dosage': dose,
                    'time': timeStr,
                  }),
                ).timeout(const Duration(seconds: 10));

                if (context.mounted) Navigator.pop(context);

                if (response.statusCode == 201) {
                  remindersNotifier.value = remindersNotifier.value + 1;
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Reminder saved successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  return;
                }
              }
            } catch (e) {
              debugPrint('❌ Error: $e');
            }

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Failed to save reminder'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return result;
}