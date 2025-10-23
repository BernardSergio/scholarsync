import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'dashboard.dart';
import 'appointments.dart';
import 'journal.dart' as journal_lib;
import 'reminders.dart' as reminders_lib;
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'resources.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> _todayActivity = [];
  final List<Appointment> _todaysAppointments = [];
  final List<Map<String, dynamic>> _todaysMedReminders = [];
  int _selectedIndex = 0;

  static const _storageKey = 'aura_appointments';

  @override
  void initState() {
    super.initState();
    _loadTodaysAppointments();
    // load reminders for today's activity and listen for changes
    _loadTodaysReminders();
  try { reminders_lib.remindersNotifier.addListener(_onRemindersChanged); } catch (_) {}
  }

  @override
  void dispose() {
  try { reminders_lib.remindersNotifier.removeListener(_onRemindersChanged); } catch (_) {}
    super.dispose();
  }

  void _onRemindersChanged() {
    // reload reminders into today's activity when storage changes
    _loadTodaysReminders();
  }

  Future<void> _loadTodaysAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      final now = DateTime.now();
      final List<Appointment> items = [];
      if (raw != null && raw.isNotEmpty) {
        final list = json.decode(raw) as List<dynamic>;
        for (final e in list) {
          try {
            final appt = Appointment.fromJson(e as Map<String, dynamic>);
            final dt = appt.dateTime;
            if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
              items.add(appt);
            }
          } catch (_) {
            // ignore malformed entry
          }
        }
      }
      setState(() {
        _todaysAppointments.clear();
        _todaysAppointments.addAll(items);
      });
    } catch (_) {
      // ignore load errors
    }
  }

  Future<void> _loadTodaysReminders() async {
    try {
      final u = AuthService().currentUser;
      if (u == null) return;
      final prefs = await SharedPreferences.getInstance();
      final remKey = 'aura_reminders_${u.username}';
      final raw = prefs.getString(remKey);
      final now = DateTime.now();
      final List<Map<String, dynamic>> meds = [];
      if (raw != null && raw.isNotEmpty) {
        try {
          final keyStr = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
          final key = encryptpkg.Key.fromUtf8(keyStr);
          final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
          final iv = encryptpkg.IV.fromLength(16);
          try {
            final dec = encrypter.decrypt64(raw, iv: iv);
            final list = json.decode(dec) as List<dynamic>;
            for (final e in list) {
              try {
                final m = Map<String, dynamic>.from(e as Map);
                final dt = DateTime.parse(m['dateTime'] as String);
                if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                  meds.add(m);
                }
              } catch (_) {}
            }
          } catch (_) {
            // try plaintext
            try {
              final list = json.decode(raw) as List<dynamic>;
              for (final e in list) {
                try {
                  final m = Map<String, dynamic>.from(e as Map);
                  final dt = DateTime.parse(m['dateTime'] as String);
                  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                    meds.add(m);
                  }
                } catch (_) {}
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      // store meds for today's medications card and also merge into today's activity
      setState(() {
        // remove previous medication entries we added earlier (match by a tag)
        _todayActivity.removeWhere((a) => a['source'] == 'reminder');
        _todaysMedReminders.clear();
        _todaysMedReminders.addAll(meds);
        for (final m in meds.reversed) {
          _todayActivity.insert(0, {
            'title': '${m['medication']} • ${m['dosage']}',
            'subtitle': DateFormat.jm().format(DateTime.parse(m['dateTime'] as String)),
            'icon': Icons.medication,
            'color': Colors.green,
            'source': 'reminder',
          });
        }
      });
    } catch (_) {}
  }

  void _logActivity(String title, String subtitle, IconData icon, Color color) {
    setState(() {
      _todayActivity.insert(0, {
        'title': title,
        'subtitle': subtitle,
        'icon': icon,
        'color': color,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AURA', style: TextStyle(color: Colors.teal[600], fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          // Debug: reset auth attempts
          IconButton(
            icon: Icon(Icons.restore, color: Colors.grey[700]),
            tooltip: 'Reset login attempts',
            onPressed: () async {
              final choice = await showDialog<String?>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Reset login attempts'),
                  children: [
                    SimpleDialogOption(
                      child: const Text('Reset all attempts'),
                      onPressed: () => Navigator.pop(context, 'all'),
                    ),
                    SimpleDialogOption(
                      child: const Text('Reset specific username'),
                      onPressed: () => Navigator.pop(context, 'one'),
                    ),
                    SimpleDialogOption(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ],
                ),
              );

              if (choice == 'all') {
                final ok = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
                  title: const Text('Confirm'),
                  content: const Text('Clear all login attempt counters?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes')),
                  ],
                ));
                if (ok == true) {
                  AuthService().resetAllAttempts();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All login attempts cleared')));
                }
              } else if (choice == 'one') {
                final username = await showDialog<String?>(context: context, builder: (c) {
                  final ctrl = TextEditingController();
                  return AlertDialog(
                    title: const Text('Reset attempts for user'),
                    content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'username')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('Reset')),
                    ],
                  );
                });

                if (username != null && username.isNotEmpty) {
                AuthService().resetAttemptsForUser(username);
                ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Attempts cleared for $username')));
                }
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.grey[700]),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _buildBodyForIndex(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey[700],
        type: BottomNavigationBarType.fixed,
        onTap: (i) {
          setState(() => _selectedIndex = i);
          if (i == 0) {
            _loadTodaysAppointments();
            _loadTodaysReminders();
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Journal'),
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Reminders'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Resources'),
        ],
      ),
    );
  }

  // ...first-run overview is built by _buildFirstRunOverviewCard

  // First-run overview for new users (no data yet)
  Widget _buildFirstRunOverviewCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Welcome to AURA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('This looks like your first time here. Let\'s get you set up.'),
            const SizedBox(height: 12),
            const Text('Start by logging your mood, medication, or a quick note using the buttons below.'),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.sentiment_satisfied),
                  label: const Text('Log Mood'),
                  onPressed: () => _logActivity('Mood logged', 'You wrote your first mood entry', Icons.sentiment_satisfied, Colors.blue),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.medication),
                  label: const Text('Log Medication'),
                  onPressed: () => _logActivity('Medication logged', 'You logged your first medication', Icons.check_circle, Colors.green),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: const Text('Schedule Appointment'),
                    onPressed: () => _logActivity('Appointment scheduled', 'You scheduled your first appointment', Icons.calendar_today, Colors.teal),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[400]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivityPlaceholder() {
    // Show today's appointments if we have any, otherwise fall back to placeholder text
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_todaysAppointments.isEmpty) ...[
              const Center(
                child: Text('No entries yet. Use the quick actions to add your first mood or medication.' , style: TextStyle(color: Colors.grey)),
              ),
            ] else ...[
              Column(
                children: _todaysAppointments.map((a) {
                  IconData icon = Icons.location_on;
                  if (a.type == 'Video Call') {
                    icon = Icons.videocam;
                  } else if (a.type == 'Phone Call') icon = Icons.phone;
                  return ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.teal[50], child: Icon(icon, color: Colors.teal)),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${DateFormat.jm().format(a.dateTime)} • ${a.provider}'),
                    trailing: Text(a.type, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    // AC B: Quick Action buttons
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sentiment_satisfied, color: Colors.white),
                label: const Text('Log Mood', style: TextStyle(color: Colors.white)),
                onPressed: () => _logActivity('Mood logged', 'Feeling optimistic - 7/10', Icons.sentiment_satisfied, Colors.blue),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.medication, color: Colors.white),
                label: const Text('Log Meds', style: TextStyle(color: Colors.white)),
                  onPressed: () async {
                    final saved = await _showAddReminderFromHome();
                  if (saved == true) {
                    await _loadTodaysReminders();
                    await _loadTodaysAppointments();
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('Free Note', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  // Inline quick-note dialog: persist directly to journal storage so Home
                  // doesn't depend on the journal helper. This keeps the quick-action working.
                  final titleCtrl = TextEditingController();
                  final bodyCtrl = TextEditingController();
                  final res = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
                    title: const Text('Quick Note'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title (optional)')), const SizedBox(height:8), TextField(controller: bodyCtrl, maxLines:4, decoration: const InputDecoration(hintText: 'Write a quick note...'))]),
                    actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save'))],
                  ));

                  if (res == true) {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      const key = 'aura_journal_entries';
                      final raw = prefs.getString(key) ?? '[]';
                      final list = json.decode(raw) as List<dynamic>;
                      final entry = {'id': DateTime.now().toIso8601String(), 'type': 3, 'dateTime': DateTime.now().toIso8601String(), 'title': titleCtrl.text.trim(), 'body': bodyCtrl.text.trim(), 'tags': []};
                      list.insert(0, entry);
                      await prefs.setString(key, json.encode(list));
                    } catch (_) {}
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today, color: Colors.white),
                label: const Text('Schedule Appointment', style: TextStyle(color: Colors.white)),
                onPressed: () async {
                  final res = await showScheduleAppointmentDialog(context);
                  if (res == true) {
                    await _loadTodaysAppointments();
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTodaysMedicationsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.medication, color: Colors.teal), SizedBox(width:8), Text("Today's Medications", style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height:8),
          _todaysMedReminders.isEmpty
            ? const Padding(padding: EdgeInsets.symmetric(vertical:16), child: Text('No medication reminders for today'))
            : Column(children: _todaysMedReminders.map((m) {
                final time = DateFormat.jm().format(DateTime.parse(m['dateTime'] as String));
                final repeat = (m['repeatDaily'] == true);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical:6),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.green.shade50, child: const Icon(Icons.medication, color: Colors.green)),
                    title: Text('${m['medication']} • ${m['dosage']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Row(children: [Text(time), const SizedBox(width:8), if (repeat) Container(padding: const EdgeInsets.symmetric(horizontal:6, vertical:2), decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200)), child: Row(children: const [Icon(Icons.repeat, size:12, color: Colors.purple), SizedBox(width:6), Text('Daily', style: TextStyle(fontSize:11, color: Colors.purple))]))]),
                    onTap: () {
                      // switch to full Reminders page to interact with the item
                      setState(() { _selectedIndex = 4; });
                    },
                  ),
                );
              }).toList()),
        ]),
      ),
    );
  }

  // Using shared reminders dialog. UI code moved to `reminders.dart`.

  Future<bool?> _showAddReminderFromHome() async {
    final u = AuthService().currentUser;
    if (u == null) return null;

    final medCtrl = TextEditingController();
    final doseCtrl = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool notify = true;
    bool repeat = false;

    final ok = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
      title: const Text('Add Reminder'),
      content: StatefulBuilder(builder: (ctx, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: medCtrl, decoration: const InputDecoration(labelText: 'Medication name', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 8),
        TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: 'Dosage', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final d = await showDatePicker(context: context, initialDate: selectedDate ?? now, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)));
                  if (d != null) setState(() => selectedDate = d);
                },
                style: TextButton.styleFrom(backgroundColor: const Color(0xFFF3F6F8), foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Align(alignment: Alignment.centerLeft, child: Text(selectedDate == null ? 'Select date' : DateFormat.yMMMd().format(selectedDate!))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                onPressed: () async {
                  final t = await showTimePicker(context: context, initialTime: selectedTime ?? TimeOfDay.now());
                  if (t != null) setState(() => selectedTime = t);
                },
                style: TextButton.styleFrom(backgroundColor: const Color(0xFFF3F6F8), foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: Align(alignment: Alignment.centerLeft, child: Text(selectedTime == null ? 'Select time' : selectedTime!.format(context))),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Icon(notify ? Icons.notifications_active : Icons.notifications_off, key: ValueKey<bool>(notify), color: notify ? Colors.teal : Colors.grey),
          ),
          const SizedBox(width: 8),
          Checkbox(value: notify, onChanged: (v) => setState(() => notify = v ?? true)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Enable notification'))
        ]),
        Row(children: [Checkbox(value: repeat, onChanged: (v) => setState(() => repeat = v ?? false)), const SizedBox(width: 8), const Expanded(child: Text('Repeat daily'))]),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () async {
        final med = medCtrl.text.trim();
        final dose = doseCtrl.text.trim();
        if (med.isEmpty || dose.isEmpty) return; // validation: non-empty
        DateTime finalDt;
        if (selectedDate != null && selectedTime != null) {
          finalDt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
        } else {
          finalDt = DateTime.now().add(const Duration(minutes: 15));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No date/time chosen — defaulting reminder to 15 minutes from now')));
        }
        if (finalDt.isBefore(DateTime.now())) return; // validation: not in past
        final id = DateTime.now().millisecondsSinceEpoch.toString();
        final r = {'id': id, 'medication': med, 'dosage': dose, 'dateTime': finalDt.toIso8601String(), 'enabled': true, 'notify': notify, 'repeatDaily': repeat};
  try { await reminders_lib.saveReminderMap(r); } catch (_) {}
        Navigator.pop(c, true);
      }, child: const Text('Save'))],
    ));

    return ok;
  }

  Widget _buildBodyForIndex(int idx) {
    switch (idx) {
      case 0:
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_todayActivity.isEmpty) _buildFirstRunOverviewCard() else _buildEmptyActivityPlaceholder(),
              const SizedBox(height: 12),
              _buildQuickActions(),
              const SizedBox(height: 12),
              _buildTodaysMedicationsCard(),
            ],
          ),
        );
      case 1:
        return const DashboardPage();
      case 2:
        return FutureBuilder(
          future: Future.value(null),
          builder: (c, s) => const AppointmentsPage(),
        );
      case 3:
        return const journal_lib.JournalPage();
      case 4:
        return const reminders_lib.RemindersPage();
      case 5:
        return const ResourcesPage();
      default:
        return const SizedBox.shrink();
    }
  }
}