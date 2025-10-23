import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'auth_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DayStatus { taken, missed, nodata }

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  final DateTime _visibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  final Map<String, DayStatus> _dayStatus = {}; // yyyy-MM-dd -> status
  final Map<String, List<Map<String, dynamic>>> _dayDetails =
      {}; // yyyy-MM-dd -> list of reminders/history entries
  double _monthAdherencePercent = 0.0;
  final Map<int, double> _weeklyAdherencePct = {}; // week index -> percent (0-100)
  final Map<String, double> _moodByDate = {}; // yyyy-MM-dd -> avg mood (0-10)

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDataForMonth(_visibleMonth);
  }

  Future<encryptpkg.Key?> _keyForUser() async {
    final u = AuthService().currentUser;
    if (u == null) return null;
    final passphrase = (u as Map<String, dynamic>)['passphrase'] ?? '';
    final k = ('$passphrase' 'aura_salt_2025').padRight(32).substring(0, 32);
    return encryptpkg.Key.fromUtf8(k);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    _dayStatus.clear();
    _dayDetails.clear();
    final u = AuthService().currentUser;
    if (u == null) {
      setState(() {});
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aura_reminders_${(u as Map<String, dynamic>)['username']}');
    if (raw == null || raw.isEmpty) {
      setState(() {});
      return;
    }

    String decoded = raw;
    try {
      final key = await _keyForUser();
      if (key != null) {
        final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
        final iv = encryptpkg.IV.fromLength(16);
        decoded = encrypter.decrypt64(raw, iv: iv);
      }
    } catch (_) {
      // fallback: treat raw as plaintext JSON
      decoded = raw;
    }

    int totalForMonth = 0;
    int takenForMonth = 0;
    try {
      final list = json.decode(decoded) as List<dynamic>;
      final now = DateTime.now();
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final key = DateFormat('yyyy-MM-dd').format(dt);
          final taken = m['takenAt'] != null;
          _dayDetails.putIfAbsent(key, () => []).add(m);
          final dayStart = DateTime(dt.year, dt.month, dt.day);
          final nowDayStart = DateTime(now.year, now.month, now.day);
          if (taken) {
            _dayStatus[key] = DayStatus.taken;
            if (dayStart.month == month.month && dayStart.year == month.year) {
              takenForMonth++;
              totalForMonth++;
            }
          } else if (dayStart.isBefore(nowDayStart) &&
              dayStart.month == month.month &&
              dayStart.year == month.year) {
            _dayStatus.putIfAbsent(key, () => DayStatus.missed);
            totalForMonth++;
          } else {
            _dayStatus.putIfAbsent(key, () => DayStatus.nodata);
          }
        } catch (_) {}
      }
    } catch (_) {}

    if (totalForMonth > 0) {
      _monthAdherencePercent = (takenForMonth / totalForMonth) * 100.0;
    } else {
      _monthAdherencePercent = 0.0;
    }

    _weeklyAdherencePct.clear();
    final days = DateTime(month.year, month.month + 1, 0).day;
    for (int w = 0; w < 4; w++) {
      int wkTotal = 0;
      int wkTaken = 0;
      final start = w * 7 + 1;
      for (int d = start;
          d <= (start + 6) && d <= days;
          d++) {
        final key =
            DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, d));
        final s = _dayStatus[key];
        if (s != null && s != DayStatus.nodata) {
          wkTotal++;
          if (s == DayStatus.taken) wkTaken++;
        }
      }
      final pct = wkTotal == 0 ? 0.0 : (wkTaken / wkTotal) * 100.0;
      _weeklyAdherencePct[w + 1] = pct;
    }

    await _loadMoodData();

    setState(() {});
  }

  Future<void> _loadMoodData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'aura_journal_entries';
      final raw = prefs.getString(key) ?? '[]';
      final list = json.decode(raw) as List<dynamic>;
      final Map<String, List<double>> sums = {};
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final type = (m['type'] ?? 0) as int;
          if (type != 0) continue;
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final keyDate = DateFormat('yyyy-MM-dd').format(dt);
          double? val;
          final title = (m['title'] ?? '').toString();
          final body = (m['body'] ?? '').toString();
          final RegExp r1 = RegExp(r"(\b[0-9](?:\.[0-9])?)/?10\b");
          final RegExp r2 = RegExp(r"\b([0-9](?:\.[0-9])?)\b");
          final match1 = r1.firstMatch(title) ?? r1.firstMatch(body);
          if (match1 != null) {
            val = double.tryParse(match1.group(1)!);
          } else {
            final match2 = r2.firstMatch(title) ?? r2.firstMatch(body);
            if (match2 != null) val = double.tryParse(match2.group(1)!);
          }
          if (val == null) continue;
          if (val < 0) val = 0;
          if (val > 10) val = 10;
          sums.putIfAbsent(keyDate, () => []).add(val);
        } catch (_) {}
      }
      _moodByDate.clear();
      sums.forEach((k, vals) {
        if (vals.isNotEmpty) {
          _moodByDate[k] = vals.reduce((a, b) => a + b) / vals.length;
        }
      });
    } catch (_) {}
  }

  // --- ADD THE BUILD METHOD HERE ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDetailsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Month Adherence: ${_monthAdherencePercent.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 20),
          Text(
            'Mood Entries: ${_moodByDate.length}',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Weekly adherence breakdown:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        ..._weeklyAdherencePct.entries.map((e) => Text('Week ${e.key}: ${e.value.toStringAsFixed(1)}%')),
      ],
    );
  }
}
