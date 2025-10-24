// ...existing imports...
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'auth_service.dart';
import 'appointments.dart';

// Notifier that indicates reminders storage changed. Pages can listen and reload.
final ValueNotifier<int> remindersNotifier = ValueNotifier<int>(0);

// Shared helper: persist a single reminder map into the user's encrypted reminders list.
Future<void> saveReminderMap(Map<String, dynamic> m) async {
  final u = AuthService().currentUser;
  if (u == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final keyStr = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
    final key = encryptpkg.Key.fromUtf8(keyStr);
    final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
    final iv = encryptpkg.IV.fromLength(16);
    final raw = prefs.getString('aura_reminders_${u.username}');
    List<dynamic> list = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final dec = encrypter.decrypt64(raw, iv: iv);
        list = json.decode(dec) as List<dynamic>;
      } catch (_) {
        try { list = json.decode(raw) as List<dynamic>; } catch (_) { list = []; }
      }
    }
    list.insert(0, m);
    final payload = json.encode(list);
    final encrypted = encrypter.encrypt(payload, iv: iv).base64;
    await prefs.setString('aura_reminders_${u.username}', encrypted);
  // Debug: print what we saved so we can verify Home can load it.
  try { debugPrint('saveReminderMap: saved reminder for ${u.username}: ${m['medication']} @ ${m['dateTime']}'); } catch (_) {}
    try { remindersNotifier.value = remindersNotifier.value + 1; } catch (_) {}
  } catch (_) {}
}

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

  Reminder({required this.id, required this.medication, required this.dosage, required this.dateTime, this.enabled = true, this.notify = true, this.repeatDaily = false, this.takenAt});

  Map<String, dynamic> toJson() => {
        'id': id,
        'medication': medication,
        'dosage': dosage,
        'dateTime': dateTime.toIso8601String(),
        'enabled': enabled,
        'notify': notify,
        'repeatDaily': repeatDaily,
        'takenAt': takenAt?.toIso8601String(),
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
      );

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
  final Set<String> _fading = {}; // ids currently animating out

  String _storageKeyFor(String username) => 'aura_reminders_$username';
  String _historyKeyFor(String username) => 'aura_reminder_history_$username';

  @override
  void initState() {
    super.initState();
    _loadIfAuthenticated();
    // reload when external pages (e.g., Home) save reminders
    remindersNotifier.addListener(_onRemindersChanged);
  }

  @override
  void dispose() {
    try { remindersNotifier.removeListener(_onRemindersChanged); } catch (_) {}
    super.dispose();
  }

  void _onRemindersChanged() {
    _loadIfAuthenticated();
  }

  Future<encryptpkg.Key?> _keyForCurrentUser() async {
    final u = AuthService().currentUser;
    if (u == null) return null;
    // Derive 32-byte key from passphrase (demo only)
    final k = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0, 32);
    return encryptpkg.Key.fromUtf8(k);
  }

  Future<void> _loadIfAuthenticated() async {
    final u = AuthService().currentUser;
    if (u == null) return;
    final prefs = await SharedPreferences.getInstance();
    final enc = prefs.getString(_storageKeyFor(u.username));
    if (enc != null && enc.isNotEmpty) {
      try {
        final key = await _keyForCurrentUser();
        if (key != null) {
          final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
          final iv = encryptpkg.IV.fromLength(16);
          final decrypted = encrypter.decrypt64(enc, iv: iv);
          final list = json.decode(decrypted) as List<dynamic>;
          final tmp = list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
          // Dedupe by id keeping the last occurrence (newest) to ensure a single
          // canonical reminder per id (handles duplicates inserted from other flows)
          final seen = <String>{};
          final dedupedReversed = <Reminder>[];
          for (final r in tmp.reversed) {
            if (!seen.contains(r.id)) {
              dedupedReversed.add(r);
              seen.add(r.id);
            }
          }
          final deduped = dedupedReversed.reversed.toList();
          // Replace only on successful decrypt/parse
          _reminders.clear();
          _reminders.addAll(deduped);
        }
      } catch (_) {
        // decrypt failed — attempt plaintext fallback (in case data was saved without encryption)
        try {
          final list = json.decode(enc) as List<dynamic>;
          final tmp = list.map((e) => Reminder.fromJson(e as Map<String, dynamic>)).toList();
          _reminders.clear();
          _reminders.addAll(tmp);
          // Attempt to migrate to encrypted storage (best-effort)
          try {
            await _saveForCurrentUser();
          } catch (_) {}
        } catch (_) {
          // keep existing in-memory reminders if plaintext parse also fails
        }
      }
    }

    final rawHist = prefs.getString(_historyKeyFor(u.username));
    if (rawHist != null && rawHist.isNotEmpty) {
      try {
        final list = json.decode(rawHist) as List<dynamic>;
        final tmpHist = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _history.clear();
        _history.addAll(tmpHist);
      } catch (_) {
        // keep existing history on parse failure
      }
    }

    setState(() {});
    _loadedOnce = true;
  }

  Future<void> _saveForCurrentUser() async {
    final u = AuthService().currentUser;
    if (u == null) return;
    final prefs = await SharedPreferences.getInstance();
    final key = await _keyForCurrentUser();
    if (key == null) return;
    final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
    final iv = encryptpkg.IV.fromLength(16);
    // Deduplicate reminders by id before saving. Keep the last occurrence
    // (most recent) so that updates to duplicates are preserved.
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
    final encrypted = encrypter.encrypt(payload, iv: iv).base64;
    await prefs.setString(_storageKeyFor(u.username), encrypted);
    await prefs.setString(_historyKeyFor(u.username), json.encode(_history));
  }

  Future<void> _addOrEditReminder({Reminder? existing, int? index}) async {

    final medCtrl = TextEditingController(text: existing?.medication ?? '');
    final doseCtrl = TextEditingController(text: existing?.dosage ?? '');
  DateTime? selectedDate = existing?.dateTime;
  TimeOfDay? selectedTime = existing != null ? TimeOfDay.fromDateTime(existing.dateTime) : null;
    bool notify = existing?.notify ?? true;
    bool repeat = existing?.repeatDaily ?? false;

    final ok = await showDialog<bool?>(context: context, builder: (c) => StatefulBuilder(builder: (ctx, setState) => AlertDialog(
      title: Text(existing == null ? 'Add Reminder' : 'Edit Reminder'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
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
  ]),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () async {
        final med = medCtrl.text.trim();
        final dose = doseCtrl.text.trim();
        if (med.isEmpty || dose.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter medication name and dosage')));
          return;
        }
        // Build a DateTime from selectedDate and selectedTime. If either is missing, default to now+15min.
        DateTime finalDt;
        if (selectedDate != null && selectedTime != null) {
          finalDt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
        } else {
          finalDt = DateTime.now().add(const Duration(minutes: 15));
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No date/time chosen — defaulting reminder to 15 minutes from now')));
        }
        if (finalDt.isBefore(DateTime.now())) {
          if (repeat) {
            // For daily reminders, shift to next day and continue
            finalDt = finalDt.add(const Duration(days: 1));
            setState(() {
              selectedDate = DateTime(finalDt.year, finalDt.month, finalDt.day);
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected time is in the past — scheduling for the next day at the same time')));
          } else {
            // For non-daily reminders, ask user to select a correct time
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a correct time (future) or enable Repeat daily')));
            return;
          }
        }
        final id = existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
        final r = Reminder(id: id, medication: med, dosage: dose, dateTime: finalDt, enabled: true, notify: notify, repeatDaily: repeat, takenAt: existing?.takenAt);
        if (existing != null && index != null) {
          _reminders[index] = r;
        } else {
          _reminders.insert(0, r);
        }
  await _saveForCurrentUser();
        try { remindersNotifier.value = remindersNotifier.value + 1; } catch (_) {}
         Navigator.pop(c, true);
      }, child: const Text('Save'))],
    )));

    if (ok == true) setState(() {});
  }

// Public helper to show Add Reminder dialog from other pages (e.g. Home quick action)
Future<bool?> showAddReminderDialog(BuildContext context) async {
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
      // Build a DateTime from selectedDate and selectedTime. If either is missing, default to now+15min.
      DateTime finalDt;
      if (selectedDate != null && selectedTime != null) {
        finalDt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
      } else {
        finalDt = DateTime.now().add(const Duration(minutes: 15));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No date/time chosen — defaulting reminder to 15 minutes from now')));
      }
      if (finalDt.isBefore(DateTime.now())) return; // validation: not in past
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final r = Reminder(id: id, medication: med, dosage: dose, dateTime: finalDt, enabled: true, notify: notify, repeatDaily: repeat);
      try { await saveReminderMap(r.toJson()); } catch (_) {}
      Navigator.pop(c, true);
    }, child: const Text('Save'))],
  ));

  if (ok == true) {
    // nothing extra needed here; callers listen to remindersNotifier or reload
  }
  return ok;
}

  Future<void> _toggleTaken(int index) async {
    final r = _reminders[index];
    if (r.takenAt != null) return; // already taken

    // mark taken time immediately for UI state
    r.takenAt = DateTime.now();

    if (!r.repeatDaily) {
      // For non-daily reminders: animate out then move to history and remove
      _fading.add(r.id);
      setState(() {});
      // wait for fade animation to complete then remove and record history
      await Future.delayed(const Duration(milliseconds: 600));
      // insert history entry (avoid duplicates)
      final exists = _history.any((h) => h['id'] == r.id && h['status'] == 'taken');
      if (!exists) {
        _history.insert(0, {'id': r.id, 'medication': r.medication, 'when': r.takenAt!.toIso8601String(), 'status': 'taken'});
      }
      _reminders.removeWhere((x) => x.id == r.id);
      _fading.remove(r.id);
      await _saveForCurrentUser();
      try {
        remindersNotifier.value = remindersNotifier.value + 1;
      } catch (_) {}
      setState(() {});
    } else {
      // Daily reminders stay in schedule; record history immediately (no remove)
      final exists = _history.any((h) => h['id'] == r.id && h['status'] == 'taken');
      if (!exists) {
        _history.insert(0, {'id': r.id, 'medication': r.medication, 'when': r.takenAt!.toIso8601String(), 'status': 'taken'});
      }
      await _saveForCurrentUser();
      try { remindersNotifier.value = remindersNotifier.value + 1; } catch (_) {}
      setState(() {});
    }
  }

  Future<void> _toggleNotify(int index) async {
    _reminders[index].notify = !_reminders[index].notify;
    await _saveForCurrentUser();
    try { remindersNotifier.value = remindersNotifier.value + 1; } catch (_) {}
    setState(() {});
  }

  // Deletion handled inline where needed. (Removed unused helper to satisfy analyzer.)

  List<Reminder> _todaysMeds() {
    final now = DateTime.now();
    return _reminders.where((r) => r.dateTime.year == now.year && r.dateTime.month == now.month && r.dateTime.day == now.day).toList();
  }

  Future<List<Appointment>> _loadTodaysAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aura_appointments');
    final List<Appointment> out = [];
    if (raw == null || raw.isEmpty) return out;
    try {
      final list = json.decode(raw) as List<dynamic>;
      final now = DateTime.now();
      for (final e in list) {
        try {
          final a = Appointment.fromJson(e as Map<String, dynamic>);
          final dt = a.dateTime;
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) out.add(a);
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  Widget _statusBadge(ReminderStatus s) {
    switch (s) {
      case ReminderStatus.taken:
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)), child: const Text('Taken', style: TextStyle(color: Colors.white, fontSize: 12)));
      case ReminderStatus.pending:
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)), child: const Text('Pending', style: TextStyle(color: Colors.black, fontSize: 12)));
      case ReminderStatus.missed:
        return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(6)), child: const Text('Missed', style: TextStyle(color: Colors.red, fontSize: 12)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensure we have loaded reminders at least once. This guards against the
    // case where the widget is rebuilt (e.g., tab switch) before initState's
    // async load completes — call load once from build if needed.
    if (!_loadedOnce) {
      _loadedOnce = true; // mark immediately to avoid repeated calls
      // schedule async load after build
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadIfAuthenticated());
    }
    final user = AuthService().currentUser;
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 24.0;
    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: bottomPad),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Smart Reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.edit, color: Colors.teal), SizedBox(width:8), Text("Today's Medication Schedule", style: TextStyle(fontWeight: FontWeight.bold))]),
          const SizedBox(height:8),
          const Text('Track your daily medication routine', style: TextStyle(color: Colors.grey)),
          const SizedBox(height:12),
          // Today's meds list
          FutureBuilder<void>(future: Future.value(), builder: (context, snap) {
            final meds = _todaysMeds();
            if (meds.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical:24), child: Center(child: Text('No medication reminders for today')));
            // build today's reminder widgets using a for-loop for clarity
            final widgets = <Widget>[];
            for (final r in meds) {
              final s = r.status();
              final bg = s == ReminderStatus.taken ? Colors.green.shade50 : Colors.white;
              widgets.add(
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _fading.contains(r.id) ? 0.0 : 1.0,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical:6),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                    child: ListTile(
                      leading: Icon(s==ReminderStatus.taken?Icons.check_circle:Icons.circle_outlined, color: s==ReminderStatus.taken?Colors.green:Colors.grey),
                      title: Row(children: [
                        Expanded(child: Text('${r.medication} • ${r.dosage}', style: const TextStyle(fontWeight: FontWeight.bold))),
                      ]),
                      subtitle: Row(children: [
                        Text(TimeOfDay.fromDateTime(r.dateTime).format(context)),
                        const SizedBox(width: 8),
                        if (r.repeatDaily)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.purple.shade200)),
                            child: Row(children: const [Icon(Icons.repeat, size: 12, color: Colors.purple), SizedBox(width: 6), Text('Daily', style: TextStyle(fontSize: 11, color: Colors.purple))]),
                          ),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (s != ReminderStatus.pending) ...[ _statusBadge(s), const SizedBox(width:8) ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {},
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                !r.enabled ? Icons.notifications_off : (r.notify ? Icons.notifications_active : Icons.notifications_off),
                                key: ValueKey('${r.enabled}-${r.notify}'),
                                color: !r.enabled ? Colors.grey.shade400 : (r.notify ? Colors.teal : Colors.grey),
                              ),
                            ),
                          ),
                        ),
                        Switch(value: r.notify, onChanged: (v) { final orig = _reminders.indexWhere((x)=>x.id==r.id); if (orig!=-1) _toggleNotify(orig); }),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove reminder',
                          onPressed: () async {
                            final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Remove reminder?'), content: const Text('Remove this reminder from your schedule?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove'))]));
                            if (ok == true) {
                              _reminders.removeWhere((x) => x.id == r.id);
                              await _saveForCurrentUser();
                              try { remindersNotifier.value = remindersNotifier.value + 1; } catch (_) {}
                              setState(() {});
                            }
                          },
                        ),
                      ]),
                      onTap: () { if (r.takenAt == null) { final orig = _reminders.indexWhere((x)=>x.id==r.id); if (orig!=-1) _toggleTaken(orig); } },
                    ),
                  ),
                ),
              );
            }
            return Column(children: widgets);
          }),
          const SizedBox(height:12),
          // Add reminder button
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            ElevatedButton.icon(
              onPressed: () {
                if (user == null) {
                  showDialog(context: context, builder: (ctx) => AlertDialog(
                    title: const Text('Sign in required'),
                    content: const Text('You need to sign in to manage reminders. Would you like to sign in now?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pushNamed(context, '/login');
                      }, child: const Text('Sign in'))
                    ],
                  ));
                  return;
                }
                _addOrEditReminder();
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Reminder'),
            )
          ])
        ]))),
        const SizedBox(height:12),
        // Reminder history
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.history, color: Colors.teal), SizedBox(width: 8), Text('Reminder History', style: TextStyle(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              // Reminder history (single instance)
              _history.isEmpty
                  ? const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Text('No recent activity'))
                  : SizedBox(
                      height: (_history.length < 5 ? _history.length : 5) * 64.0,
                      child: ListView.builder(
                        itemCount: _history.length,
                        itemBuilder: (context, i) {
                          final h = _history[i];
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('${h['medication']}'), Text(h['status'], style: const TextStyle(color: Colors.black))]),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: _history.isEmpty
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Clear history?'), content: const Text('This will permanently remove your reminder history. Continue?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear'))]));
                          if (ok == true) {
                            _history.clear();
                            await _saveForCurrentUser();
                            setState(() {});
                          }
                        },
                  child: const Text('Clear History'),
                ),
              ])
            ]),
          ),
        ),
        const SizedBox(height:12),
        // Appointments section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [Icon(Icons.calendar_today, color: Colors.purple), SizedBox(width: 8), Text('Upcoming Appointments', style: TextStyle(fontWeight: FontWeight.bold))]),
              const SizedBox(height: 8),
              FutureBuilder<List<Appointment>>(
                future: _loadTodaysAppointments(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
                  final list = snap.data ?? [];
                  if (list.isEmpty) return const Text('No appointments scheduled for today');
                  return Column(
                    children: list.map((a) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(a.provider),
                          const SizedBox(height: 6),
                          Row(children: [const Icon(Icons.access_time, size: 16, color: Colors.grey), const SizedBox(width: 6), Text(TimeOfDay.fromDateTime(a.dateTime).format(context))]),
                          const SizedBox(height: 6),
                          Row(children: [const Icon(Icons.location_on, size: 16, color: Colors.grey), const SizedBox(width: 6), Text(a.location)]),
                          const SizedBox(height: 8),
                          Row(children: [TextButton.icon(onPressed: () {}, icon: const Icon(Icons.place), label: const Text('Directions')), const SizedBox(width: 8), TextButton.icon(onPressed: () {}, icon: const Icon(Icons.edit), label: const Text('Edit Reminder'))])
                        ]),
                      );
                    }).toList(),
                  );
                },
              ),
            ]),
          ),
        ),
        const SizedBox(height:12),
        // AI preferences placeholder
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AI Learning Preferences', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Expanded(child: Text('Context Learning\nLearn from your daily routines and patterns')),
                Switch(value: true, onChanged: (_) {}),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Expanded(child: Text('Pattern Recognition\nIdentify trends in your medication adherence')),
                Switch(value: true, onChanged: (_) {}),
              ]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Expanded(child: Text('Personalized Timing\nAdjust reminder times based on your schedule')),
                Switch(value: false, onChanged: (_) {}),
              ]),
            ]),
          ),
        ),
      ],
      ),
    ),
  ),
);
}

}

// Helper: load today's reminder maps for the current user (decrypted if needed).
Future<List<Map<String, dynamic>>> loadTodaysReminderMaps() async {
  final out = <Map<String, dynamic>>[];
  final u = AuthService().currentUser;
  if (u == null) return out;
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aura_reminders_${u.username}');
    if (raw == null || raw.isEmpty) return out;
    final keyStr = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
    final key = encryptpkg.Key.fromUtf8(keyStr);
    final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
    final iv = encryptpkg.IV.fromLength(16);
    try {
      final dec = encrypter.decrypt64(raw, iv: iv);
      final list = json.decode(dec) as List<dynamic>;
      final now = DateTime.now();
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final dt = DateTime.parse(m['dateTime'] as String);
          if (dt.year == now.year && dt.month == now.month && dt.day == now.day) out.add(m);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      // try plaintext
      try {
        final list = json.decode(raw) as List<dynamic>;
        final now = DateTime.now();
        for (final e in list) {
          try {
            final m = Map<String, dynamic>.from(e as Map);
            final dt = DateTime.parse(m['dateTime'] as String);
            if (dt.year == now.year && dt.month == now.month && dt.day == now.day) out.add(m);
          } catch (_) {}
        }
      } catch (_) {}
    }
  } catch (_) {}
  return out;
}