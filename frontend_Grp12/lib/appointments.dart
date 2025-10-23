import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Appointment {
  String title;
  DateTime dateTime;
  String provider;
  String location;
  String notes;
  String type;

  Appointment({
    required this.title,
    required this.dateTime,
    required this.provider,
    required this.location,
    this.notes = '',
    this.type = 'In Person',
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'dateTime': dateTime.toIso8601String(),
        'provider': provider,
        'location': location,
        'notes': notes,
        'type': type,
      };

  static Appointment fromJson(Map<String, dynamic> j) => Appointment(
        title: j['title'] ?? 'Appointment',
        dateTime: DateTime.parse(j['dateTime']),
        provider: j['provider'] ?? '',
        location: j['location'] ?? '',
        notes: j['notes'] ?? '',
        type: j['type'] ?? 'In Person',
      );
}

// Shared storage key for appointments (used by helper dialog and page)
const String _appointmentsStorageKey = 'aura_appointments';

// ...existing file continues (keep the in-file AppointmentsPage and its local dialog) ...

// Public helper that shows the same scheduling dialog used in AppointmentsPage
// and persists the new appointment into SharedPreferences so other pages (Home)
// can reload and display it immediately.
Future<bool?> showScheduleAppointmentDialog(BuildContext context, {Appointment? existing, int? index}) async {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  DateTime? selectedDate = existing?.dateTime ?? DateTime.now();
  TimeOfDay? selectedTime = existing != null ? TimeOfDay.fromDateTime(existing.dateTime) : TimeOfDay.now();
  String provider = existing?.provider ?? '';
  String location = existing?.location ?? '';
  String notes = existing?.notes ?? '';
  String apptType = existing?.type ?? 'In Person';

  final result = await showDialog<bool?>(
    context: context,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Schedule New Appointment' : 'Edit Appointment', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (dialogContext, setDialogState) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Appointment Title', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () async {
                                  final d = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                                  if (d != null) setDialogState(() => selectedDate = d);
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
                                  if (t != null) setDialogState(() => selectedTime = t);
                                },
                                style: TextButton.styleFrom(backgroundColor: const Color(0xFFF3F6F8), foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                child: Align(alignment: Alignment.centerLeft, child: Text(selectedTime == null ? 'Select time' : selectedTime!.format(context))),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('Appointment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        Builder(builder: (fieldContext) {
                          final fieldKey = GlobalKey();
                          return SizedBox(
                            key: fieldKey,
                            width: double.infinity,
                            child: InkWell(
                              onTap: () async {
                                final renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
                                final overlay = Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
                                final screenW = MediaQuery.of(fieldContext).size.width;
                                final dialogMax = 520.0;
                                final dialogEffective = math.min(screenW - 48.0, dialogMax);
                                final extra = 48.0;
                                final w = math.min(dialogEffective, dialogEffective - 40.0 + extra);

                                RelativeRect position = const RelativeRect.fromLTRB(0, 0, 0, 0);
                                if (renderBox != null) {
                                  final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
                                  position = RelativeRect.fromLTRB(offset.dx, offset.dy + renderBox.size.height, offset.dx + w, offset.dy);
                                }

                                final selected = await showMenu<String>(
                                  context: fieldContext,
                                  position: position,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  color: Colors.white,
                                  items: [
                                    PopupMenuItem(value: 'In Person', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.location_on, size: 18), const SizedBox(width: 8), const Expanded(child: Text('In-Person')), if (apptType == 'In Person') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                    PopupMenuItem(value: 'Video Call', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.videocam, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Video Call')), if (apptType == 'Video Call') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                    PopupMenuItem(value: 'Phone Call', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.phone, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Phone Call')), if (apptType == 'Phone Call') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                  ],
                                );

                                if (selected != null) setDialogState(() => apptType = selected);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F6F8),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(children: [if (apptType == 'In Person') const Icon(Icons.location_on, size: 18) else if (apptType == 'Video Call') const Icon(Icons.videocam, size: 18) else const Icon(Icons.phone, size: 18), const SizedBox(width: 8), Text(apptType == 'In Person' ? 'In-Person' : apptType)]),
                                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        TextField(controller: TextEditingController(text: provider), onChanged: (v) => provider = v, decoration: const InputDecoration(labelText: 'Healthcare Provider', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                        const SizedBox(height: 12),
                        TextField(controller: TextEditingController(text: location), onChanged: (v) => location = v, decoration: const InputDecoration(labelText: 'Location', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                        const SizedBox(height: 12),
                        TextField(controller: TextEditingController(text: notes), onChanged: (v) => notes = v, decoration: const InputDecoration(labelText: 'Notes (optional)', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(onPressed: () => Navigator.pop(c, false), style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF00796B)), foregroundColor: const Color(0xFF00796B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedDate != null && selectedTime != null) {
                        final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                        final appt = Appointment(title: titleCtrl.text.trim().isEmpty ? 'Appointment' : titleCtrl.text.trim(), dateTime: dt, provider: provider, location: location, notes: notes, type: apptType);
                        // persist to SharedPreferences (append to existing list)
                        try {
                          final prefs = await SharedPreferences.getInstance();
                          final raw = prefs.getString(_appointmentsStorageKey) ?? '[]';
                          final list = json.decode(raw) as List<dynamic>;
                          list.insert(0, appt.toJson());
                          await prefs.setString(_appointmentsStorageKey, json.encode(list));
                        } catch (_) {}
                        Navigator.pop(c, true);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: Text(existing == null ? 'Schedule Appointment' : 'Update Appointment', style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  return result;
}

class AppointmentsPage extends StatefulWidget {
  const AppointmentsPage({super.key});

  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  // Start empty for a fresh install — user hasn't scheduled anything yet.
  final List<Appointment> _appointments = [];

  final DateFormat _dateFmt = DateFormat.yMMMd();
  final DateFormat _timeFmt = DateFormat.jm();

  static const _storageKey = 'aura_appointments';

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        setState(() {
          _appointments.clear();
          _appointments.addAll(list.map((e) => Appointment.fromJson(e as Map<String, dynamic>)));
        });
      } catch (_) {
        // ignore parse errors
      }
    }
  }

  Future<void> _saveAppointments() async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(_appointments.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  void _showScheduleDialog({Appointment? existing, int? index}) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
  DateTime? selectedDate = existing?.dateTime ?? DateTime.now();
  TimeOfDay? selectedTime = existing != null ? TimeOfDay.fromDateTime(existing.dateTime) : TimeOfDay.now();
  String provider = existing?.provider ?? '';
  String location = existing?.location ?? '';
  String notes = existing?.notes ?? '';
  // track appointment type locally (UI only for now)
  String apptType = existing?.type ?? 'In Person';

    final result = await showDialog<bool?>(
      context: context,
      builder: (c) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Schedule New Appointment' : 'Edit Appointment', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                StatefulBuilder(
                  builder: (dialogContext, setDialogState) {
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Appointment Title', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () async {
                                    final d = await showDatePicker(context: context, initialDate: selectedDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                                    if (d != null) setState(() => selectedDate = d);
                                  },
                                  style: TextButton.styleFrom(backgroundColor: const Color(0xFFF3F6F8), foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  child: Align(alignment: Alignment.centerLeft, child: Text(selectedDate == null ? 'Select date' : _dateFmt.format(selectedDate!))),
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
                          const SizedBox(height: 12),
                          // Label for the custom field to match other inputs
                          const Text('Appointment Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          // Custom InkWell + showMenu so we can position the popup left-aligned and match dialog width
                          Builder(builder: (fieldContext) {
                            final fieldKey = GlobalKey();
                            return SizedBox(
                              key: fieldKey,
                              width: double.infinity,
                              child: InkWell(
                                onTap: () async {
                                  final renderBox = fieldKey.currentContext?.findRenderObject() as RenderBox?;
                                  final overlay = Overlay.of(fieldContext).context.findRenderObject() as RenderBox;
                                  final screenW = MediaQuery.of(fieldContext).size.width;
                                  final dialogMax = 520.0;
                                  final dialogEffective = math.min(screenW - 48.0, dialogMax);
                                  final extra = 48.0; // extend rows further to the right
                                  final w = math.min(dialogEffective, dialogEffective - 40.0 + extra);

                                  // compute left/top for menu so it lines up with the field (left aligned)
                                  RelativeRect position = const RelativeRect.fromLTRB(0, 0, 0, 0);
                                  if (renderBox != null) {
                                    final offset = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
                                    position = RelativeRect.fromLTRB(offset.dx, offset.dy + renderBox.size.height, offset.dx + w, offset.dy);
                                  }

                                  final selected = await showMenu<String>(
                                    context: fieldContext,
                                    position: position,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    color: Colors.white,
                                    items: [
                                                  PopupMenuItem(value: 'In Person', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.location_on, size: 18), const SizedBox(width: 8), const Expanded(child: Text('In-Person')), if (apptType == 'In Person') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                                  PopupMenuItem(value: 'Video Call', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.videocam, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Video Call')), if (apptType == 'Video Call') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                                  PopupMenuItem(value: 'Phone Call', child: SizedBox(width: w, child: Row(children: [const Icon(Icons.phone, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Phone Call')), if (apptType == 'Phone Call') const Icon(Icons.check, color: Color(0xFF00796B))]))),
                                    ],
                                  );

                                  if (selected != null) setDialogState(() => apptType = selected);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F6F8),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(children: [
                                        if (apptType == 'In Person') const Icon(Icons.location_on, size: 18) else if (apptType == 'Video Call') const Icon(Icons.videocam, size: 18) else const Icon(Icons.phone, size: 18),
                                        const SizedBox(width: 8),
                                        Text(apptType == 'In Person' ? 'In-Person' : apptType),
                                      ]),
                                      const Icon(Icons.arrow_drop_down, color: Colors.grey),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 12),
                          TextField(controller: TextEditingController(text: provider), onChanged: (v) => provider = v, decoration: const InputDecoration(labelText: 'Healthcare Provider', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                          const SizedBox(height: 12),
                          TextField(controller: TextEditingController(text: location), onChanged: (v) => location = v, decoration: const InputDecoration(labelText: 'Location', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                          const SizedBox(height: 12),
                          TextField(controller: TextEditingController(text: notes), onChanged: (v) => notes = v, decoration: const InputDecoration(labelText: 'Notes (optional)', filled: true, fillColor: Color(0xFFF3F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))))),
                          const SizedBox(height: 12),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                // single action row (styled)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(c, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00796B)),
                        foregroundColor: const Color(0xFF00796B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
              ElevatedButton(
            onPressed: () async {
                        if (selectedDate != null && selectedTime != null) {
                          final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
                          final appt = Appointment(title: titleCtrl.text.trim().isEmpty ? 'Appointment' : titleCtrl.text.trim(), dateTime: dt, provider: provider, location: location, notes: notes, type: apptType);
                          if (existing != null && index != null) {
                            setState(() => _appointments[index] = appt);
                          } else {
                            setState(() => _appointments.insert(0, appt));
                          }
                          await _saveAppointments();
                          Navigator.pop(c, true);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: Text(existing == null ? 'Schedule Appointment' : 'Update Appointment', style: const TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true) {
      // optional: show confirmation
    }
  }

  void _confirmDelete(int index) async {
    final ok = await showDialog<bool?>(context: context, builder: (c) => AlertDialog(
      title: const Text('Delete appointment'),
      content: const Text('Are you sure you want to delete this appointment?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
      ],
    ));

    if (ok == true) {
      setState(() => _appointments.removeAt(index));
      await _saveAppointments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Appointments', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Manage your healthcare appointments', style: TextStyle(color: Colors.grey[700])),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showScheduleDialog(),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Schedule Appointment', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note, color: Colors.teal),
                      const SizedBox(width: 8),
                      const Text('Upcoming Appointments', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Text('${_appointments.length} appointments scheduled', style: TextStyle(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _appointments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 48, color: Colors.teal[300]),
                                const SizedBox(height: 12),
                                const Text('No upcoming appointments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text('You don\'t have any appointments yet. Tap "Schedule Appointment" to create your first one.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _appointments.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final a = _appointments[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                                      child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                                Row(
                                                  children: [
                                                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                                    const SizedBox(width: 8),
                                                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)), child: const Text('Upcoming', style: TextStyle(color: Colors.blue))),
                                                  ],
                                                ),
                                        Row(
                                          children: [
                                            IconButton(onPressed: () => _showScheduleDialog(existing: a, index: index), icon: const Icon(Icons.edit)),
                                            IconButton(onPressed: () => _confirmDelete(index), icon: const Icon(Icons.delete, color: Colors.red)),
                                          ],
                                        ),
                                      ],
                                    ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(_dateFmt.format(a.dateTime)),
                                                const SizedBox(width: 12),
                                                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(_timeFmt.format(a.dateTime)),
                                              ],
                                            ),
                                    const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                const Icon(Icons.person, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(a.provider),
                                                const SizedBox(width: 12),
                                                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(a.location),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // show appointment type with icon
                                            Row(
                                              children: [
                                                if (a.type == 'In Person') const Icon(Icons.location_on, size: 16, color: Colors.grey) else if (a.type == 'Video Call') const Icon(Icons.videocam, size: 16, color: Colors.grey) else const Icon(Icons.phone, size: 16, color: Colors.grey),
                                                const SizedBox(width: 6),
                                                Text(a.type, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                              ],
                                            ),
                                    const SizedBox(height: 8),
                                    Text(a.notes, style: const TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
