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
  final Map<String, DayStatus> _dayStatus = {}; // yyyy-MM-dd -> status
  final Map<String, List<Map<String,dynamic>>> _dayDetails = {}; // yyyy-MM-dd -> list of reminders/history entries
  double _monthAdherencePercent = 0.0;
  final Map<int,double> _weeklyAdherencePct = {}; // week index -> percent (0-100)
  final Map<String,double> _moodByDate = {}; // yyyy-MM-dd -> avg mood (0-10)

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
    final k = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
    return encryptpkg.Key.fromUtf8(k);
  }

  Future<void> _loadDataForMonth(DateTime month) async {
    _dayStatus.clear();
    _dayDetails.clear();
    final u = AuthService().currentUser;
    if (u == null) { setState(() {}); return; }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aura_reminders_${u.username}');
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
      // fallback: treat raw as plaintext JSON
      decoded = raw;
    }

    int totalForMonth = 0;
    int takenForMonth = 0;
    try {
      final list = json.decode(decoded) as List<dynamic>;
      final now = DateTime.now();
      // Build a map of statuses per day for this month
      for (final e in list) {
        try {
          final m = Map<String,dynamic>.from(e as Map);
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final key = DateFormat('yyyy-MM-dd').format(dt);
          final taken = m['takenAt'] != null;
          // record details
          _dayDetails.putIfAbsent(key, () => []).add(m);
          // determine status: taken wins, else missed if past and not taken
          final dayStart = DateTime(dt.year, dt.month, dt.day);
          final nowDayStart = DateTime(now.year, now.month, now.day);
          if (taken) {
            _dayStatus[key] = DayStatus.taken;
            if (dayStart.month == month.month && dayStart.year == month.year) { takenForMonth++; totalForMonth++; }
          } else if (dayStart.isBefore(nowDayStart) && dayStart.month == month.month && dayStart.year == month.year) {
            // if the scheduled time is earlier than now and not taken -> missed
            _dayStatus.putIfAbsent(key, () => DayStatus.missed);
            totalForMonth++;
          } else {
            _dayStatus.putIfAbsent(key, () => DayStatus.nodata);
          }
        } catch (_) {}
      }
    } catch (_) {}

    // compute monthly adherence percent
    if (totalForMonth > 0) {
      _monthAdherencePercent = (takenForMonth / totalForMonth) * 100.0;
    } else {
      _monthAdherencePercent = 0.0;
    }

    // compute weekly adherence buckets for visible month (4 weeks)
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

    // load mood entries for the last 7 days
  await _loadMoodData();

    setState(() {});
  }

  Future<void> _loadMoodData() async {
    // Read journal entries and aggregate mood scores per day (attempt to parse numeric mood values)
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
          if (type != 0) continue; // only mood entries
          final dt = DateTime.parse(m['dateTime'] as String).toLocal();
          final keyDate = DateFormat('yyyy-MM-dd').format(dt);
          // Try to parse a numeric mood score from title or body (look for 0-10 or x/10 patterns)
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
          // clamp to 0-10
          if (val < 0) val = 0; if (val > 10) val = 10;
          sums.putIfAbsent(keyDate, () => []).add(val);
        } catch (_) {}
      }
      _moodByDate.clear();
      sums.forEach((k, vals) {
        if (vals.isNotEmpty) _moodByDate[k] = vals.reduce((a,b)=>a+b)/vals.length;
      });
    } catch (_) {
      // ignore
    }
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
      content: items.isEmpty ? const Text('No reminders or logs for this day.') : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: items.map((m) {
        final taken = m['takenAt'] != null;
        final time = DateFormat.jm().format(DateTime.parse(m['dateTime']));
        return ListTile(title: Text('${m['medication']} • ${m['dosage']}'), subtitle: Text(time), trailing: Text(taken ? 'Taken' : 'Scheduled'));
      }).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))],
    ));
  }

  Widget _buildCalendar() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final startWeekday = firstOfMonth.weekday % 7; // 0=Sun..6=Sat
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final rows = <Widget>[];
  // int day unused
    // build 6 rows of 7 days
    for (int r = 0; r < 6; r++) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < 7; c++) {
        final cellIndex = r * 7 + c;
        Widget child;
        final cellDay = cellIndex - startWeekday + 1;
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
          // month adherence percent
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
    // Build calendar-week (Sun-Sat) buckets for the visible month
    final Map<int, List<String>> weekToDates = {}; // weekIndex -> list of yyyy-MM-dd
    // find the first Sunday on or before the first of month
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

    // compute pct per week and build bars with fixed vertical sections to avoid overflow
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
        // each bar column has fixed vertical pieces: percent label, bar area, week label
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

    // Mood values for last 7 days (0..10)
    final today = DateTime.now();
    final last7 = List.generate(7, (i) => DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i)));
    final moodValues = <double>[];
    for (int i = 0; i < last7.length; i++) {
      final k = DateFormat('yyyy-MM-dd').format(last7[i]);
      final v = _moodByDate[k] ?? 0.0;
      moodValues.add(v);
    }

    // if there is no adherence info at all, show a friendly message instead of empty zero-bars
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
      const Text('Mood (last 7 days)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      SizedBox(height: 180, child: Padding(padding: const EdgeInsets.symmetric(horizontal:8.0), child: _SimpleSparkline(values: moodValues, labels: last7.map((d)=>DateFormat('E').format(d)).toList()))),
    ]);
  }

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TabBar(controller: _tabController, tabs: const [Tab(text: 'Calendar'), Tab(text: 'Trends')], labelColor: Colors.teal, unselectedLabelColor: Colors.grey),
          const SizedBox(height: 12),
          Expanded(child: TabBarView(controller: _tabController, children: [SingleChildScrollView(child: _buildCalendar()), SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(8.0), child: _buildTrends()))])),
        ]),
      );
    }

  }

  class _SimpleSparkline extends StatelessWidget {
  final List<double> values;
  final List<String>? labels;
  const _SimpleSparkline({required this.values, this.labels});

  @override
  Widget build(BuildContext context) {
      final bool hasAny = values.any((v) => v != 0.0);
      if (!hasAny) {
        return Column(children: [
          Expanded(child: Center(child: Text('No mood data', style: TextStyle(color: Colors.grey[700])))),
          const SizedBox(height:6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(values.length, (i) => Expanded(child: Center(child: Text(labels?[i] ?? '', style: const TextStyle(fontSize:10))))))
        ]);
      }

      return Column(children: [
        Expanded(child: CustomPaint(painter: _SparklinePainter(values), size: Size.infinite)),
        const SizedBox(height:6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(values.length, (i) => Expanded(child: Center(child: Text(labels?[i] ?? '', style: const TextStyle(fontSize:10))))))
      ]);
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  _SparklinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.purpleAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final dotPaint = Paint()..color = Colors.purpleAccent;

    if (values.isEmpty) return;
    final double w = size.width;
    final double h = size.height;
    final double step = w / (values.length - 1 == 0 ? 1 : (values.length - 1));
    Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = step * i;
      final y = h - (values[i].clamp(0.0, 10.0) / 10.0) * (h - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => oldDelegate.values != values;
}
