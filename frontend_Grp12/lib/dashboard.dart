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

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  final Map<String, DayStatus> _dayStatus = {}; 
  final Map<String, List<Map<String,dynamic>>> _dayDetails = {}; 
  double _monthAdherencePercent = 0.0;
  final Map<int,double> _weeklyAdherencePct = {}; 
  final Map<String,double> _moodByDate = {}; 
  final Map<String,List<String>> _sideEffectsByDate = {}; // NEW: side effects

  late TabController _tabController;
  String? _username; // store the current logged-in user's username

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserAndData();
  }

  Future<void> _loadCurrentUserAndData() async {
    final user = await AuthService().getCurrentUser();
    if (user == null) return;
    setState(() {
      _username = user['username'];
    });
    await _loadDataForMonth(_visibleMonth);
  }

  Future<encryptpkg.Key?> _keyForUser() async {
    if (_username == null) return null;
    final k = ('${_username}_aura_salt_2025').padRight(32).substring(0, 32);
    return encryptpkg.Key.fromUtf8(k);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    _dayStatus.clear();
    _dayDetails.clear();

    if (_username == null) { setState(() {}); return; }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aura_reminders_$_username');
    if (raw == null || raw.isEmpty) { setState(() {}); return; }

    String decoded = raw;
    try {
      final key = await _keyForUser();
      if (key != null) {
        final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
        final iv = encryptpkg.IV.fromLength(16);
        decoded = encrypter.decrypt64(raw, iv: iv);
      }
    } catch (_) {
      decoded = raw;
    }

    int totalForMonth = 0;
    int takenForMonth = 0;
    try {
      final list = json.decode(decoded) as List<dynamic>;
      final now = DateTime.now();

      for (final e in list) {
        try {
          final m = Map<String,dynamic>.from(e as Map);
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final key = DateFormat('yyyy-MM-dd').format(dt);
          final taken = m['takenAt'] != null;
          _dayDetails.putIfAbsent(key, () => []).add(m);

          final dayStart = DateTime(dt.year, dt.month, dt.day);
          final nowDayStart = DateTime(now.year, now.month, now.day);
          if (taken) {
            _dayStatus[key] = DayStatus.taken;
            if (dayStart.month == month.month && dayStart.year == month.year) { takenForMonth++; totalForMonth++; }
          } else if (dayStart.isBefore(nowDayStart) && dayStart.month == month.month && dayStart.year == month.year) {
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
      for (int d = start; d <= (start + 6) && d <= days; d++) {
        final key = DateFormat('yyyy-MM-dd').format(DateTime(month.year, month.month, d));
        final s = _dayStatus[key];
        if (s != null && s != DayStatus.nodata) {
          wkTotal++;
          if (s == DayStatus.taken) wkTaken++;
        }
      }
      final pct = wkTotal == 0 ? 0.0 : (wkTaken / wkTotal) * 100.0;
      _weeklyAdherencePct[w+1] = pct;
    }

    await _loadMoodData();
    await _loadSideEffectsData(); // NEW
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
          if (val < 0) val = 0; if (val > 10) val = 10;
          sums.putIfAbsent(keyDate, () => []).add(val);
        } catch (_) {}
      }
      _moodByDate.clear();
      sums.forEach((k, vals) {
        if (vals.isNotEmpty) _moodByDate[k] = vals.reduce((a,b)=>a+b)/vals.length;
      });
    } catch (_) {}
  }

  // NEW: Load side effects
  Future<void> _loadSideEffectsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const key = 'aura_journal_entries';
      final raw = prefs.getString(key) ?? '[]';
      final list = json.decode(raw) as List<dynamic>;
      _sideEffectsByDate.clear();
      for (final e in list) {
        try {
          final m = Map<String, dynamic>.from(e as Map);
          final type = (m['type'] ?? 0) as int;
          if (type != 1) continue; // 1 = side effect
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final keyDate = DateFormat('yyyy-MM-dd').format(dt);
          final description = (m['body'] ?? '').toString();
          _sideEffectsByDate.putIfAbsent(keyDate, () => []).add(description);
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _prevMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
      _loadDataForMonth(_visibleMonth);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
      _loadDataForMonth(_visibleMonth);
    });
  }

  Color _colorForStatus(DayStatus? s) {
    switch (s) {
      case DayStatus.taken: return Colors.green.shade300;
      case DayStatus.missed: return Colors.red.shade200;
      case DayStatus.nodata: return Colors.grey.shade300;
      default: return Colors.grey.shade200;
    }
  }

  void _showDayDetails(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final items = _dayDetails[key] ?? [];
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(DateFormat.yMMMMd().format(date)),
      content: items.isEmpty && (_sideEffectsByDate[key]?.isEmpty ?? true)
          ? const Text('No reminders, logs, or side effects for this day.')
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...items.map((m) {
                    final taken = m['takenAt'] != null;
                    final time = DateFormat.jm().format(DateTime.parse(m['dateTime']));
                    return ListTile(
                      title: Text('${m['medication']} • ${m['dosage']}'),
                      subtitle: Text(time),
                      trailing: Text(taken ? 'Taken' : 'Scheduled'),
                    );
                  }),
                  if (_sideEffectsByDate[key]?.isNotEmpty ?? false) ...[
                    const Divider(),
                    const Text('Side Effects:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ..._sideEffectsByDate[key]!.map((s) => Text('- $s')),
                  ],
                  if (_moodByDate[key] != null) ...[
                    const Divider(),
                    Text('Mood: ${_moodByDate[key]!.toStringAsFixed(1)}/10', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ));
  }

  Widget _buildCalendar() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final startWeekday = firstOfMonth.weekday % 7; // 0=Sun..6=Sat
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final rows = <Widget>[];

    for (int r = 0; r < 6; r++) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < 7; c++) {
        final cellIndex = r * 7 + c;
        final cellDay = cellIndex - startWeekday + 1;
        Widget child;
        if (cellDay < 1 || cellDay > daysInMonth) {
          child = const SizedBox.shrink();
        } else {
          final date = DateTime(_visibleMonth.year, _visibleMonth.month, cellDay);
          final key = DateFormat('yyyy-MM-dd').format(date);
          final status = _dayStatus[key];
          child = GestureDetector(
            onTap: () => _showDayDetails(date),
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _colorForStatus(status), borderRadius: BorderRadius.circular(8)),
              height: 84,
              child: Center(child: Text('$cellDay', style: const TextStyle(fontWeight: FontWeight.bold))),
            ),
          );
        }
        rowChildren.add(Expanded(child: child));
      }
      rows.add(Row(children: rowChildren));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)), Text(DateFormat.yMMMM().format(_visibleMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right))]),
        Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: const Text('Taken')),
          const SizedBox(width:8),
          Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)), child: const Text('Missed')),
          const SizedBox(width:8),
          Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), child: const Text('No data')),
          const SizedBox(width:12),
          Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)), child: Text(_monthAdherencePercent > 0 ? '${_monthAdherencePercent.toStringAsFixed(0)}% adherence' : 'No adherence data'))
        ]),
      ]),
      const SizedBox(height: 8),
      Row(children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'].map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.w600))))).toList()),
      const SizedBox(height: 8),
      ...rows,
    ]);
  }

  Widget _buildTrends() {
    final Map<int, List<String>> weekToDates = {};
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    DateTime start = firstOfMonth.subtract(Duration(days: (firstOfMonth.weekday % 7)));
    int weekIndex = 0;
    while (start.month <= _visibleMonth.month || start.isBefore(firstOfMonth.add(const Duration(days: 35)))) {
      final weekDates = <String>[];
      for (int i = 0; i < 7; i++) {
        final d = start.add(Duration(days: i));
        if (d.month == _visibleMonth.month) {
          weekDates.add(DateFormat('yyyy-MM-dd').format(d));
        }
      }
      if (weekDates.isNotEmpty) weekToDates[++weekIndex] = weekDates;
      start = start.add(const Duration(days: 7));
      if (start.isAfter(DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1).subtract(const Duration(days:1)))) break;
    }

    final List<double> weekPcts = [];
    final bars = <Widget>[];
    for (final e in weekToDates.entries) {
      final wk = e.key;
      final dates = e.value;
      int wkTotal = 0;
      int wkTaken = 0;
      for (final k in dates) {
        final s = _dayStatus[k];
        if (s != null && s != DayStatus.nodata) {
          wkTotal++;
          if (s == DayStatus.taken) wkTaken++;
        }
      }
      final pct = wkTotal == 0 ? 0.0 : (wkTaken / wkTotal) * 100.0;
      weekPcts.add(pct);
      final double maxBar = 120.0;
      final barHeight = (pct / 100.0) * maxBar;

      bars.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: 18, child: Center(child: Text('${pct.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)))),
            SizedBox(height: maxBar, width: 48, child: Align(alignment: Alignment.bottomCenter, child: Container(height: barHeight, width: 36, decoration: BoxDecoration(color: Colors.teal, borderRadius: BorderRadius.circular(6))))),
            const SizedBox(height:6),
            SizedBox(height: 16, child: Center(child: Text('W$wk', style: const TextStyle(fontSize: 12))))
          ]),
        ),
      );
    }

    final today = DateTime.now();
    final last7 = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    final moodValues = <double>[];
    for (int i = 0; i < last7.length; i++) {
      final k = DateFormat('yyyy-MM-dd').format(last7[i]);
      final v = _moodByDate[k] ?? 0.0;
      moodValues.add(v);
    }

    final hasAnyWeekData = weekToDates.isNotEmpty && weekPcts.any((p) => p > 0 || p == 0 && _dayStatus.values.any((s) => s == DayStatus.missed));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Medication Adherence Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (!hasAnyWeekData) ...[
        SizedBox(height: 120, child: Center(child: Text('No medication adherence data for ${DateFormat.yMMMM().format(_visibleMonth)}', style: TextStyle(color: Colors.grey[700])))),
      ] else ...[
        SizedBox(height: 200, child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.stretch, children: bars)),
      ],
      const SizedBox(height: 16),
      const Text('Mood Last 7 Days', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      SizedBox(
        height: 120,
        child: Row(
          children: last7.map((d) {
            final k = DateFormat('yyyy-MM-dd').format(d);
            final val = _moodByDate[k] ?? 0.0;
            final barHeight = (val / 10.0) * 100.0;
            return Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(val>0?val.toStringAsFixed(1):'', style: const TextStyle(fontSize:12)),
                const SizedBox(height:4),
                Container(width: 24, height: barHeight, decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height:4),
                Text(DateFormat.E().format(d), style: const TextStyle(fontSize:12)),
              ]),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Calendar'), Tab(text: 'Trends')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildCalendar()),
          SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildTrends()),
        ],
      ),
    );
  }
}
