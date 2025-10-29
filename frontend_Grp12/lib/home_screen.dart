import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'dashboard.dart';
import 'appointments.dart';
import 'settings_screen.dart';
import 'package:flutter_application_1/journal.dart' as journal_lib;
import 'reminders.dart' as reminders_lib;
import 'package:flutter_application_1/appointments.dart' as appointments_lib;
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'resources.dart';
import 'config.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _medicationsKey = GlobalKey();
  
  final List<Map<String, dynamic>> _todayActivity = [];
  final List<Appointment> _todaysAppointments = [];
  final List<Map<String, dynamic>> _todaysMedReminders = [];
  final List<Map<String, dynamic>> _todaysLoggedMeds = []; // ADD THIS LINE
  int _selectedIndex = 0;
  String? _aiInsight;
  bool _showAIInsight = true;

  static const _storageKey = 'aura_appointments';

  @override
  void initState() {
    super.initState();
    // whether to show the welcome/first-run card; user can dismiss it.
    _showWelcome = true;
    _loadTodaysAppointments();
    // load reminders for today's activity and listen for changes
    _loadTodaysReminders();
    _generateAIInsight();
  try { reminders_lib.remindersNotifier.addListener(_onRemindersChanged); } catch (_) {}
  try { appointments_lib.appointmentsNotifier.addListener(_onAppointmentsChanged); } catch (_) {}
  }

  bool _showWelcome = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If this route is current (e.g., user navigated back to Home), ensure reminders are up-to-date.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _loadTodaysReminders();
        }
      } catch (_) {}
    });
  }

@override
void dispose() {
  _scrollController.dispose();
  try { reminders_lib.remindersNotifier.removeListener(_onRemindersChanged); } catch (_) {}
  try { appointments_lib.appointmentsNotifier.removeListener(_onAppointmentsChanged); } catch (_) {}
  super.dispose();
}


  void _onRemindersChanged() {
    // reload reminders into today's activity when storage changes
    _loadTodaysReminders();
  }

  void _onAppointmentsChanged() {
    _loadTodaysAppointments();
  }

  Future<void> _generateAIInsight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'aura_mood_entries';
      final raw = prefs.getString(key);
      
      if (raw == null || raw.isEmpty) {
        setState(() => _aiInsight = null);
        return;
      }

      final list = json.decode(raw) as List<dynamic>;
      if (list.isEmpty) {
        setState(() => _aiInsight = null);
        return;
      }

      // Analyze last 7 days of mood data
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      final recentMoods = list.where((entry) {
        try {
          final dt = DateTime.parse(entry['dateTime'] as String);
          return dt.isAfter(sevenDaysAgo);
        } catch (_) {
          return false;
        }
      }).toList();

      if (recentMoods.isEmpty) {
        setState(() => _aiInsight = null);
        return;
      }

      // Calculate average mood intensity
      double totalIntensity = 0;
      int count = 0;
      List<int> intensities = [];
      
      for (final mood in recentMoods) {
        try {
          final value = mood['value'] as int;
          totalIntensity += value;
          intensities.add(value);
          count++;
        } catch (_) {}
      }

      if (count == 0) {
        setState(() => _aiInsight = null);
        return;
      }

      final avgIntensity = totalIntensity / count;
      
      // Analyze trend (improving, declining, stable)
      String? insight;
      
      if (intensities.length >= 3) {
        // Calculate trend by comparing first half vs second half
        final midPoint = intensities.length ~/ 2;
        final firstHalf = intensities.sublist(0, midPoint);
        final secondHalf = intensities.sublist(midPoint);
        
        final firstAvg = firstHalf.reduce((a, b) => a + b) / firstHalf.length;
        final secondAvg = secondHalf.reduce((a, b) => a + b) / secondHalf.length;
        
        final difference = secondAvg - firstAvg;
        
        if (difference > 1.5) {
          // Improving trend
          insight = "🌟 Your mood has been steadily improving over the past week. Consider noting what's been helping you feel better.";
        } else if (difference < -1.5) {
          // Declining trend
          insight = "💙 Your mood has been lower lately. Remember, it's okay to reach out for support. Consider talking to someone you trust.";
        } else if (avgIntensity >= 7) {
          // Stable and positive
          insight = "✨ You've maintained a positive mood this week! Keep up the activities and routines that make you feel good.";
        } else if (avgIntensity <= 4) {
          // Stable but low
          insight = "🌱 Your mood has been challenging. Small steps like going outside, staying hydrated, or talking to a friend can help.";
        } else {
          // Stable and neutral
          insight = "🔄 Your mood has been relatively stable. Consider trying new activities that bring you joy.";
        }
      } else {
        // Not enough data for trend, just give general insight
        if (avgIntensity >= 7) {
          insight = "😊 You're doing well! Keep tracking your mood to discover patterns that help you thrive.";
        } else if (avgIntensity <= 4) {
          insight = "💚 Thank you for tracking your mood. Remember, seeking support is a sign of strength, not weakness.";
        } else {
          insight = "📊 Keep logging your mood to unlock personalized insights about your emotional patterns.";
        }
      }

      // Check for consistency patterns
      if (count >= 5) {
        final hasConsistentHigh = intensities.where((i) => i >= 8).length >= 3;
        final hasConsistentLow = intensities.where((i) => i <= 3).length >= 3;
        
        if (hasConsistentHigh) {
          insight = "🎉 You've had several great days this week! Your consistency shows strong emotional wellness.";
        } else if (hasConsistentLow) {
          insight = "🤗 Multiple low mood days suggest you might benefit from extra self-care or professional support.";
        }
      }

      setState(() => _aiInsight = insight);
    } catch (e) {
      debugPrint('Error generating AI insight: $e');
      setState(() => _aiInsight = null);
    }
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
        // Refresh today's activity entries for appointments
        _todayActivity.removeWhere((a) => a['source'] == 'appointment');
        for (final appt in items.reversed) {
          _todayActivity.insert(0, {
            'title': appt.title,
            'subtitle': DateFormat.jm().format(appt.dateTime) + (appt.provider.isNotEmpty ? ' • ${appt.provider}' : ''),
            'icon': Icons.calendar_today,
            'color': Colors.teal,
            'source': 'appointment',
          });
        }
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
    final remKey = 'aura_reminders_${u['username']}'; 

  final raw = prefs.getString(remKey);
  final now = DateTime.now();
  final List<Map<String, dynamic>> meds = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final keyStr = ('${u['passphrase'] ?? ''}aura_salt_2025') 
            .padRight(32)
            .substring(0, 32);

        final key = encryptpkg.Key.fromUtf8(keyStr);
        final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
        final iv = encryptpkg.IV.fromLength(16);

        try {
          final dec = encrypter.decrypt64(raw, iv: iv);
          debugPrint('home: decrypted reminders payload length=${dec.length}');
          final list = json.decode(dec) as List<dynamic>;
          debugPrint('home: parsed list len=${list.length}');
          for (final e in list) {
            try {
              final m = Map<String, dynamic>.from(e as Map);
              debugPrint('home: found reminder item medication=${m['medication']} dateTime=${m['dateTime']}');
              final dt = DateTime.parse(m['dateTime'] as String);
              if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
                meds.add(m);
              }
            } catch (err) {
              debugPrint('home: item parse error $err');
            }
          }
        } catch (err) {
          debugPrint('home: decrypt failed $err — trying plaintext');
          // try plaintext
          try {
            final list = json.decode(raw) as List<dynamic>;
            debugPrint('home: plaintext parse list len=${list.length}');
            for (final e in list) {
              try {
                final m = Map<String, dynamic>.from(e as Map);
                debugPrint('home: plaintext item medication=${m['medication']} dateTime=${m['dateTime']}');
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
          // Open Settings
          IconButton(
            icon: Icon(Icons.settings, color: Colors.grey[700]),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
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

  // AI Insights Card
  Widget _buildAIInsightsCard() {
    if (_aiInsight == null || !_showAIInsight) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.purple.shade50, Colors.blue.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Insights',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Dismiss',
                    onPressed: () => setState(() => _showAIInsight = false),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _aiInsight!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh Insight'),
                  onPressed: () => _generateAIInsight(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            Row(children: [
              const Expanded(child: Text("Welcome to AURA", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              IconButton(icon: const Icon(Icons.close), tooltip: 'Dismiss', onPressed: () => setState(() => _showWelcome = false))
            ]),
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
 
  Widget _buildTodaysActivityCard() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Today's Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_todayActivity.isEmpty) ...[
            const Center(child: Text('No activity yet. Use quick actions to add something.', style: TextStyle(color: Colors.grey))),
          ] else ...[
            Column(children: _todayActivity.map((a) {
              return ListTile(
                leading: CircleAvatar(backgroundColor: (a['color'] as Color).withOpacity(0.12), child: Icon(a['icon'] as IconData, color: a['color'])),
                title: Text(a['title'] ?? ''),
                subtitle: Text(a['subtitle'] ?? ''),
              );
            }).toList())
          ]
        ]),
      ),
    );
  }

  // Top activity banner removed — activity is shown below today's medications.

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
              onPressed: () async { 
                final saved = await _showLogMoodDialog(); 
                if (saved == true) setState(() {}); 
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent, 
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
          const SizedBox(width: 8),
Expanded(
  child: ElevatedButton.icon(
    icon: const Icon(Icons.medication, color: Colors.white),
    label: const Text('Log Meds', style: TextStyle(color: Colors.white)),
    onPressed: () async {
      // First, scroll to Today's Medications section
      if (_medicationsKey.currentContext != null) {
        await Scrollable.ensureVisible(
          _medicationsKey.currentContext!,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          alignment: 0.0, // Scroll to top of the widget
        );
      }
      
      // Then show the medication dialog
      final saved = await _showLogMedicationDialog();
      if (saved == true) {
        await _loadTodaysReminders();
        await _loadTodaysAppointments();
        setState(() {});
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blueAccent, 
      padding: const EdgeInsets.symmetric(vertical: 12)
    ),
  ),
),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit, color: Colors.white),
              label: const Text('Free Note', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final titleCtrl = TextEditingController();
                final bodyCtrl = TextEditingController();
                await showDialog<bool?>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: const Text('Quick Note'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                            hintText: 'Note title...',
                            filled: true,
                            fillColor: Color(0xFFF3F6F8),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: bodyCtrl,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Content *',
                            hintText: 'Write your note...',
                            filled: true,
                            fillColor: Color(0xFFF3F6F8),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '* Required fields',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final content = bodyCtrl.text.trim();

                          // Validation
                          if (title.isEmpty || content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter both title and content'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // Close dialog first
                          Navigator.pop(c, null);

                          // Show loading
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
                                      Text('Saving note...'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );

                          // Save to backend
                          final success = await saveNoteToBackend(
                            title: title,
                            content: content,
                          );

                          // Close loading
                          if (mounted) Navigator.pop(context);

                          if (success) {
                            // Also save locally as backup (for journal page)
                            try {
                              final prefs = await SharedPreferences.getInstance();
                              const key = 'aura_journal_entries';
                              final raw = prefs.getString(key) ?? '[]';
                              final list = json.decode(raw) as List<dynamic>;
                              final entry = {
                                'id': DateTime.now().toIso8601String(),
                                'type': 3,
                                'dateTime': DateTime.now().toIso8601String(),
                                'title': title,
                                'body': content,
                                'tags': []
                              };
                              list.insert(0, entry);
                              await prefs.setString(key, json.encode(list));
                            } catch (_) {}

                            // Update Today's Activity UI
                            if (mounted) {
                              setState(() {
                                _todayActivity.insert(0, {
                                  'title': title,
                                  'subtitle': content.length > 50 
                                      ? '${content.substring(0, 50)}...' 
                                      : content,
                                  'icon': Icons.note,
                                  'color': Colors.purple,
                                  'source': 'note',
                                });
                              });
                            }
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent, 
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: const Text('Schedule Appointment', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                // Show the dialog to get appointment data
                final titleCtrl = TextEditingController();
                String provider = '';
                String location = '';
                String notes = '';
                String apptType = 'In Person';
                DateTime? selectedDate = DateTime.now();
                TimeOfDay? selectedTime = TimeOfDay.now();

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
                            const Text('Schedule New Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            StatefulBuilder(
                              builder: (dialogContext, setDialogState) {
                                return SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      TextField(
                                        controller: titleCtrl, 
                                        decoration: const InputDecoration(
                                          labelText: 'Appointment Title', 
                                          filled: true, 
                                          fillColor: Color(0xFFF3F6F8), 
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8))
                                          )
                                        )
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () async {
                                                final d = await showDatePicker(
                                                  context: context, 
                                                  initialDate: selectedDate ?? DateTime.now(), 
                                                  firstDate: DateTime(2020), 
                                                  lastDate: DateTime(2100)
                                                );
                                                if (d != null) setDialogState(() => selectedDate = d);
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(0xFFF3F6F8), 
                                                foregroundColor: Colors.black87, 
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8)
                                                )
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft, 
                                                child: Text(
                                                  selectedDate == null 
                                                    ? 'Select date' 
                                                    : DateFormat.yMMMd().format(selectedDate!)
                                                )
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextButton(
                                              onPressed: () async {
                                                final t = await showTimePicker(
                                                  context: context, 
                                                  initialTime: selectedTime ?? TimeOfDay.now()
                                                );
                                                if (t != null) setDialogState(() => selectedTime = t);
                                              },
                                              style: TextButton.styleFrom(
                                                backgroundColor: const Color(0xFFF3F6F8), 
                                                foregroundColor: Colors.black87, 
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8)
                                                )
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft, 
                                                child: Text(
                                                  selectedTime == null 
                                                    ? 'Select time' 
                                                    : selectedTime!.format(context)
                                                )
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: TextEditingController(text: provider), 
                                        onChanged: (v) => provider = v, 
                                        decoration: const InputDecoration(
                                          labelText: 'Healthcare Provider', 
                                          filled: true, 
                                          fillColor: Color(0xFFF3F6F8), 
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8))
                                          )
                                        )
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: TextEditingController(text: location), 
                                        onChanged: (v) => location = v, 
                                        decoration: const InputDecoration(
                                          labelText: 'Location', 
                                          filled: true, 
                                          fillColor: Color(0xFFF3F6F8), 
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8))
                                          )
                                        )
                                      ),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: TextEditingController(text: notes), 
                                        onChanged: (v) => notes = v, 
                                        decoration: const InputDecoration(
                                          labelText: 'Notes (optional)', 
                                          filled: true, 
                                          fillColor: Color(0xFFF3F6F8), 
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(8))
                                          )
                                        )
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.pop(c, false), 
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFF00796B)), 
                                    foregroundColor: const Color(0xFF00796B), 
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)
                                    )
                                  ), 
                                  child: const Text('Cancel')
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () async {
                                    if (selectedDate != null && selectedTime != null && titleCtrl.text.trim().isNotEmpty) {
                                      Navigator.pop(c, true);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00796B), 
                                    foregroundColor: Colors.white, 
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)
                                    )
                                  ),
                                  child: const Text(
                                    'Schedule Appointment', 
                                    style: TextStyle(color: Colors.white)
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                if (result == true && selectedDate != null && selectedTime != null) {
                  // selectedDate and selectedTime were checked above; assert non-null here for the analyzer
                  final dt = DateTime(
                    selectedDate!.year,
                    selectedDate!.month,
                    selectedDate!.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );
                  
                  // Close dialog and show loading
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
                              Text('Saving appointment...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  
                  // Save to backend
                  final success = await saveAppointmentToBackend(
                    title: titleCtrl.text.trim().isEmpty ? 'Appointment' : titleCtrl.text.trim(),
                    provider: provider,
                    type: apptType,
                    dateTime: dt,
                    location: location,
                    notes: notes,
                  );
                  
                  // Close loading
                  if (mounted) Navigator.pop(context);
                  
                  if (success) {
                    // Also save locally as backup
                    try {
                      final appt = Appointment(
                        title: titleCtrl.text.trim().isEmpty ? 'Appointment' : titleCtrl.text.trim(),
                        dateTime: dt,
                        provider: provider,
                        location: location,
                        notes: notes,
                        type: apptType
                      );
                      
                      final prefs = await SharedPreferences.getInstance();
                      const storageKey = 'aura_appointments';
                      final raw = prefs.getString(storageKey) ?? '[]';
                      final list = json.decode(raw) as List<dynamic>;
                      list.insert(0, appt.toJson());
                      await prefs.setString(storageKey, json.encode(list));
                      
                      // Notify listeners
                      try { 
                        appointments_lib.appointmentsNotifier.value = 
                          appointments_lib.appointmentsNotifier.value + 1; 
                      } catch (_) {}
                    } catch (_) {}
                    
                    await _loadTodaysAppointments();
                    setState(() {});
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, 
                padding: const EdgeInsets.symmetric(vertical: 12)
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
Widget _buildTodaysMedicationsCard() {
  // Combine reminders and logged medications
  final allMeds = <Map<String, dynamic>>[];
  allMeds.addAll(_todaysMedReminders);
  allMeds.addAll(_todaysLoggedMeds);
  
  // Sort by time (most recent first)
  allMeds.sort((a, b) {
    final aTime = DateTime.parse(a['dateTime'] as String);
    final bTime = DateTime.parse(b['dateTime'] as String);
    return bTime.compareTo(aTime);
  });

  return Card(
    elevation: 1,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.medication, color: Colors.teal),
              const SizedBox(width: 8),
              const Text(
                "Today's Medications",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allMeds.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'No medications logged or scheduled for today',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Column(
              children: allMeds.map((m) {
                final time = DateFormat.jm().format(DateTime.parse(m['dateTime'] as String));
                final isLogged = m['isLogged'] == true;
                final isReminder = !isLogged;
                final repeat = (m['repeatDaily'] == true);
                final dt = DateTime.parse(m['dateTime'] as String);
                final isPast = dt.isBefore(DateTime.now());
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isLogged 
                        ? Colors.green.shade50 
                        : (isPast && !repeat ? Colors.red.shade50 : null),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isLogged 
                          ? Colors.green.shade300 
                          : (isPast && !repeat ? Colors.red.shade300 : Colors.grey.shade200),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    leading: CircleAvatar(
                      backgroundColor: isLogged 
                          ? Colors.green.shade100 
                          : Colors.teal.shade50,
                      child: Icon(
                        isLogged ? Icons.check_circle : Icons.medication,
                        color: isLogged ? Colors.green : Colors.teal,
                      ),
                    ),
                    title: Text(
                      '${m['medication']} • ${m['dosage']}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isLogged ? Icons.check : Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLogged ? 'Taken at $time' : 'Scheduled at $time',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        if (isReminder && repeat) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.repeat, size: 12, color: Colors.purple.shade400),
                              const SizedBox(width: 6),
                              Text(
                                'Daily',
                                style: TextStyle(fontSize: 11, color: Colors.purple.shade400),
                              ),
                            ],
                          ),
                        ],
                        if (m['notes'] != null && (m['notes'] as String).isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            m['notes'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    trailing: isLogged
                        ? Chip(
                            label: const Text(
                              'Logged',
                              style: TextStyle(fontSize: 10, color: Colors.white),
                            ),
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          )
                        : null,
                    onTap: isReminder
                        ? () => setState(() { _selectedIndex = 4; })
                        : null,
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    ),
  );
}

Future<bool?> _showLogMoodDialog() async {
  final feelings = ['Happy', 'Sad', 'Angry', 'Anxious', 'Calm', 'Excited', 'Tired', 'Motivated'];
  final Set<String> selectedFeelings = {'Happy'};
  int intensity = 7;
  final notesController = TextEditingController();

  String emojiFor(int v, String feeling) {
    if (v >= 9) return '🤩';
    if (v >= 7) return '🙂';
    if (v >= 5) return '😐';
    if (v >= 3) return '☹️';
    return '😭';
  }

  final ok = await showDialog<bool?>(
    context: context,
    barrierDismissible: false, // Prevent accidental dismissal
    builder: (c) => AlertDialog(
      title: const Text('Log Mood'),
      content: StatefulBuilder(
        builder: (ctx, setDialogState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('How do you feel?', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              // Intensity Slider
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: intensity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: '$intensity',
                      onChanged: (d) => setDialogState(() => intensity = d.round()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      emojiFor(intensity, selectedFeelings.isNotEmpty ? selectedFeelings.first : feelings[0]),
                      style: const TextStyle(fontSize: 28),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),
              // Feelings selection
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: feelings.map((f) {
                  final bool sel = selectedFeelings.contains(f);
                  return GestureDetector(
                    onTap: () => setDialogState(() {
                      if (sel) {
                        selectedFeelings.remove(f);
                      } else {
                        selectedFeelings.add(f);
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.purple[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? Colors.purple : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            f == 'Happy' ? '😊' : 
                            f == 'Sad' ? '😢' : 
                            f == 'Angry' ? '😠' : 
                            f == 'Anxious' ? '😰' : 
                            f == 'Calm' ? '😌' : 
                            f == 'Excited' ? '🤩' : 
                            f == 'Tired' ? '😴' : '👍',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            f,
                            style: TextStyle(
                              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? Colors.purple[800] : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Notes field (optional)
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add any additional thoughts...',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                ),
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
            if (selectedFeelings.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select at least one feeling')),
              );
              return;
            }

            // Capture values before async operations
            final primaryMood = selectedFeelings.first;
            final notesText = notesController.text.trim();
            final feelingsText = selectedFeelings.join(', ');
            final currentIntensity = intensity;
            final feelingsList = selectedFeelings.toList();

            // Close dialog FIRST
            Navigator.pop(c, null);

            // Show loading indicator in a separate dialog
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
                        Text('Saving mood...'),
                      ],
                    ),
                  ),
                ),
              ),
            );

            // Prepare combined notes
            final combinedNotes = notesText.isEmpty 
                ? 'Feelings: $feelingsText' 
                : '$notesText (Feelings: $feelingsText)';

            // Save to backend
            final success = await logMoodToBackend(
              mood: primaryMood,
              intensity: currentIntensity,
              notes: combinedNotes,
            );

            // Close loading dialog
            if (mounted) Navigator.pop(context);

            if (success) {
              // Save locally as backup
              try {
                final descriptor = currentIntensity >= 9 ? 'Very positive' :
                                  currentIntensity >= 7 ? 'Positive' :
                                  currentIntensity >= 5 ? 'Neutral' :
                                  currentIntensity >= 3 ? 'Low' : 'Very low';
                
                final entry = {
                  'id': DateTime.now().toIso8601String(),
                  'moodDescriptor': descriptor,
                  'feelings': feelingsList,
                  'value': currentIntensity,
                  'dateTime': DateTime.now().toIso8601String(),
                  'notes': notesText,
                };
                
                final prefs = await SharedPreferences.getInstance();
                const key = 'aura_mood_entries';
                final raw = prefs.getString(key) ?? '[]';
                final list = json.decode(raw) as List<dynamic>;
                list.insert(0, entry);
                await prefs.setString(key, json.encode(list));
              } catch (e) {
                print('Local save error: $e');
              }

              // Update Today's Activity UI and regenerate AI insight
              if (mounted) {
                setState(() {
                  final feelingsStr = feelingsList.isEmpty 
                      ? '' 
                      : ' • ${feelingsList.join(', ')}';
                  final descriptor = currentIntensity >= 9 ? 'Very positive' :
                                    currentIntensity >= 7 ? 'Positive' :
                                    currentIntensity >= 5 ? 'Neutral' :
                                    currentIntensity >= 3 ? 'Low' : 'Very low';
                  
                  // Add to today's activity with 'mood' source tag
                  _todayActivity.insert(0, {
                    'title': '$descriptor$feelingsStr',
                    'subtitle': '$currentIntensity/10 intensity${notesText.isNotEmpty ? " • $notesText" : ""}',
                    'icon': Icons.sentiment_satisfied,
                    'color': Colors.blue,
                    'source': 'mood',
                  });
                });
                
                // Regenerate AI insight with new mood data
                _generateAIInsight();
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return ok;
}

Future<bool?> _showLogMedicationDialog() async {
  final medNameController = TextEditingController();
  final dosageController = TextEditingController();
  final notesController = TextEditingController();
  DateTime selectedDateTime = DateTime.now();

  final ok = await showDialog<bool?>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Log Medication'),
      content: StatefulBuilder(
        builder: (ctx, setDialogState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication Name
              TextField(
                controller: medNameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'e.g., Aspirin',
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 12),
              
              // Dosage
              TextField(
                controller: dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage *',
                  hintText: 'e.g., 500mg',
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: Icon(Icons.science),
                ),
              ),
              const SizedBox(height: 12),
              
              // Date & Time Taken
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text(
                          'Time Taken',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(DateFormat.yMMMd().format(selectedDateTime)),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDateTime,
                                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setDialogState(() {
                                  selectedDateTime = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    selectedDateTime.hour,
                                    selectedDateTime.minute,
                                  );
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.schedule, size: 18),
                            label: Text(DateFormat.jm().format(selectedDateTime)),
                            onPressed: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                              );
                              if (time != null) {
                                setDialogState(() {
                                  selectedDateTime = DateTime(
                                    selectedDateTime.year,
                                    selectedDateTime.month,
                                    selectedDateTime.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              }
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Notes (Optional)
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Any side effects or additional info...',
                  filled: true,
                  fillColor: Color(0xFFF3F6F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  prefixIcon: Icon(Icons.note),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '* Required fields',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
            final medName = medNameController.text.trim();
            final dosage = dosageController.text.trim();
            final notes = notesController.text.trim();

            // Validation
            if (medName.isEmpty || dosage.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter medication name and dosage'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // Close dialog first
            Navigator.pop(c, null);

            // Show loading
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
                        Text('Saving medication...'),
                      ],
                    ),
                  ),
                ),
              ),
            );

            // Save to backend
            final success = await logMedicationToBackend(
              medicationName: medName,
              dosage: dosage,
              timeTaken: selectedDateTime,
              notes: notes,
            );

            // Close loading
            if (mounted) Navigator.pop(context);

            if (success) {
              // Update Today's Activity UI
              if (mounted) {
                setState(() {
                  final timeStr = DateFormat.jm().format(selectedDateTime);
                  final subtitle = '$dosage • Taken at $timeStr${notes.isNotEmpty ? " • $notes" : ""}';
                  
                  _todayActivity.insert(0, {
                    'title': medName,
                    'subtitle': subtitle,
                    'icon': Icons.medication,
                    'color': Colors.green,
                    'source': 'medication',
                  });
                  _todaysLoggedMeds.insert(0, {
                    'medication': medName,
                    'dosage': dosage,
                    'dateTime': selectedDateTime.toIso8601String(),
                    'notes': notes,
                    'isLogged': true, 
                });
              });
            }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  return ok;
}

Widget _buildBodyForIndex(int idx) {
  switch (idx) {
    case 0:
      return SingleChildScrollView(
        controller: _scrollController, // Add this line
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_showWelcome) _buildFirstRunOverviewCard() else (_todayActivity.isEmpty ? _buildEmptyActivityPlaceholder() : _buildTodaysActivityCard()),
            const SizedBox(height: 12),
            _buildAIInsightsCard(),
            const SizedBox(height: 12),
            _buildQuickActions(),
            const SizedBox(height: 12),
            Container(
              key: _medicationsKey, // Add this key
              child: _buildTodaysMedicationsCard(),
            ),
            const SizedBox(height: 12),
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

Future<bool> logMoodToBackend({
  required String mood,
  required int intensity,
  String? notes,
}) async {
  try {
    // Get token from current user (stored by auth_service)
    final user = await AuthService().getCurrentUser();
    if (user == null || user['token'] == null) {
      print("No token found. User might not be logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again')),
        );
      }
      return false;
    }

    final token = user['token'] as String;
    final url = Uri.parse('$baseUrl/moods');

    // Convert mood to lowercase to match backend enum
    final moodLower = mood.toLowerCase();

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'mood': moodLower,
        'intensity': intensity,
        'notes': notes ?? '',
      }),
    );

    if (response.statusCode == 201) {
      print("Mood logged successfully. ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mood saved'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } else {
      print("Failed to log mood: ${response.statusCode} ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${response.statusCode}')),
        );
      }
      return false;
    }
  } catch (e) {
    print("Error sending mood to backend: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}

Future<bool> logMedicationToBackend({
  required String medicationName,
  required String dosage,
  DateTime? timeTaken,
  String? notes,
}) async {
  try {
    // Get token from current user
    final user = await AuthService().getCurrentUser();
    if (user == null || user['token'] == null) {
      print("❌ No token found. User might not be logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again')),
        );
      }
      return false;
    }

    final token = user['token'] as String;
    final url = Uri.parse('$baseUrl/medications');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'medicationName': medicationName,
        'dosage': dosage,
        'timeTaken': (timeTaken ?? DateTime.now()).toIso8601String(),
        'notes': notes ?? '',
      }),
    );

    if (response.statusCode == 201) {
      print("Medication logged successfully ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medication saved '),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } else {
      print("❌ Failed to log medication: ${response.statusCode} ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${response.statusCode}')),
        );
      }
      return false;
    }
  } catch (e) {
    print("❌ Error sending medication to backend: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}

Future<bool> saveNoteToBackend({
  required String title,
  required String content,
  List<String>? tags,
}) async {
  try {
    // Get token from current user
    final user = await AuthService().getCurrentUser();
    if (user == null || user['token'] == null) {
      print("No token found. User might not be logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again')),
        );
      }
      return false;
    }

    final token = user['token'] as String;
    final url = Uri.parse('$baseUrl/notes');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'content': content,
        'tags': tags ?? [],
      }),
    );

    if (response.statusCode == 201) {
      print("Note saved successfully ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } else {
      print("Failed to save note: ${response.statusCode} ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save note: ${response.statusCode}')),
        );
      }
      return false;
    }
  } catch (e) {
    print("❌ Error sending note to backend: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}


Future<bool> saveAppointmentToBackend({
  required String title,
  required String provider,
  required String type,
  required DateTime dateTime,
  String? location,
  String? notes,
}) async {
  try {
    final user = await AuthService().getCurrentUser();
    if (user == null || user['token'] == null) {
      print("❌ No token found. User might not be logged in.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again')),
        );
      }
      return false;
    }

    final token = user['token'] as String;
    final url = Uri.parse('$baseUrl/appointments');

    // 🔥 FIX: Convert Flutter type to backend format
    String backendType = type;
    if (type == 'In Person') {
      backendType = 'In-Person';
    }
    // Video Call and Phone Call already match

    print("Saving appointment...");
    print("  Title: $title");
    print("  Provider: $provider");
    print("  Type: $backendType");
    print("  DateTime: ${dateTime.toIso8601String()}");
    print("  Location: ${location ?? ''}");
    print("  Notes: ${notes ?? ''}");

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'provider': provider,
        'type': backendType,  // 🔥 Use converted type
        'dateTime': dateTime.toIso8601String(),
        'location': location ?? '',
        'notes': notes ?? '',
      }),
    );

    print("📥 Backend response: ${response.statusCode}");
    print("📥 Response body: ${response.body}");

    if (response.statusCode == 201) {
      print("Appointment saved successfully.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return true;
    } else {
      print("❌ Failed to save appointment: ${response.statusCode}");
      print("❌ Error: ${response.body}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: ${response.statusCode}')),
        );
      }
      return false;
    }
  } catch (e) {
    print("❌ Error sending appointment to backend: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    return false;
  }
}
}