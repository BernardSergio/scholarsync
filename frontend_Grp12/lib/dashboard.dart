import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'auth_service.dart';
import 'reminders.dart';

// Fixed IV for consistent encryption/decryption across the app
final _fixedIV = encryptpkg.IV.fromUtf8('aura_fixed_iv_2025'.padRight(16).substring(0, 16));

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

enum DayStatus { taken, missed, nodata }

  /// Enhanced medication tracking diagnostics
String explainDayStatus(DateTime day, DayStatus? status, List<Map<String,dynamic>>? details) {
  final key = DateFormat('yyyy-MM-dd').format(day);
  final now = DateTime.now();
  final dayStart = DateTime(day.year, day.month, day.day);
  final nowDayStart = DateTime(now.year, now.month, now.day);
  final isPast = dayStart.isBefore(nowDayStart);
  final isToday = dayStart.isAtSameMomentAs(nowDayStart);
  
  final sb = StringBuffer();
  sb.writeln('📅 Status for $key');
  sb.writeln('Current status: ${status?.toString() ?? 'No Status'}');
  if (isPast) sb.writeln('⏪ Past day');
  if (isToday) sb.writeln('📍 Today');  if (details != null && details.isNotEmpty) {
    sb.writeln('Details:');
    for (final d in details) {
      try {
        final dt = DateTime.parse(d['dateTime'] as String);
        final taken = d['takenAt'] != null;
        sb.writeln('- ${d['medication'] ?? 'Unknown med'} @ ${DateFormat.jm().format(dt)}: ${taken ? 'Taken' : 'Not taken'}');
      } catch (_) {}
    }
  } else {
    sb.writeln('No reminder details found');
  }
  
  return sb.toString();
}

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
    try { remindersNotifier.addListener(_onRemindersChanged); } catch (_) {}
    // Also reload when becoming visible (e.g., switching to Dashboard tab)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final ancestor = context.findAncestorWidgetOfExactType<Navigator>();
        if (ancestor != null) {
          _loadDataForMonth(_visibleMonth);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    try { remindersNotifier.removeListener(_onRemindersChanged); } catch (_) {}
    _tabController.dispose();
    super.dispose();
  }

  void _onRemindersChanged() {
    // reload the visible month when reminders change
    _loadDataForMonth(_visibleMonth);
    // Debug: print what changed
    try {
      debugPrint('Dashboard: Reminders changed notification received, reloading month ${DateFormat.yMMM().format(_visibleMonth)}');
    } catch (_) {}
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
  Future<List<dynamic>> decodeList(String? raw) async {
    if (raw == null || raw.isEmpty) return <dynamic>[];
    try {
      final key = await _keyForUser();
      if (key != null) {
        final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
        final dec = encrypter.decrypt64(raw, iv: _fixedIV);
        return json.decode(dec) as List<dynamic>;
      }
    } catch (_) {}
    try {
      return json.decode(raw) as List<dynamic>;
    } catch (_) {
      return <dynamic>[];
    }
  }
  int totalForMonth = 0;
  int takenForMonth = 0;
  final rawRem = prefs.getString('aura_reminders_${u['username']}'); // Fixed here
  final remList = await decodeList(rawRem);
  for (final e in remList) {
    try {
      final Map<String, dynamic> m = Map<String, dynamic>.from(e as Map);
      if (m['dateTime'] == null) continue;
      final dt = DateTime.parse(m['dateTime'] as String).toLocal();
      final key = DateFormat('yyyy-MM-dd').format(dt);
      final entry = {
        'id': m['id'] ?? '',
        'medication': m['medication'] ?? '',
        'dosage': m['dosage'] ?? '',
        'dateTime': (m['dateTime'] ?? '').toString(),
        'takenAt': m['takenAt'],
        'source': 'reminder'
      };
      _dayDetails.putIfAbsent(key, () => []).add(entry);
      final dayStart = DateTime(dt.year, dt.month, dt.day);
      final nowDayStart = DateTime.now();
      if (dayStart.month == month.month && dayStart.year == month.year) {
        final taken = entry['takenAt'] != null;
        if (taken) {
          _dayStatus[key] = DayStatus.taken;
          takenForMonth++;
          totalForMonth++;
        } else if (dayStart.isBefore(nowDayStart)) {
          if (_dayStatus[key] != DayStatus.taken) {
            _dayStatus[key] = DayStatus.missed;
            totalForMonth++;
          }
        } else if (dayStart.isAtSameMomentAs(nowDayStart)) {
          if (dt.isBefore(DateTime.now())) {
            if (_dayStatus[key] != DayStatus.taken) {
              _dayStatus[key] = DayStatus.missed;
              totalForMonth++;
            }
          } else {
            if (_dayStatus[key] == null) {
              _dayStatus[key] = DayStatus.nodata;
            }
            totalForMonth++;
          }
        } else {
          _dayStatus[key] = DayStatus.nodata;
        }
      }
    } catch (_) {}
  }
  if (totalForMonth > 0) {
    _monthAdherencePercent = (takenForMonth / totalForMonth) * 100.0;
  } else {
    _monthAdherencePercent = 0.0;
  }
  setState(() {});
}

  // Enhanced color and style handling for day status
  Map<String, dynamic> _styleForStatus(DayStatus? s, bool isToday) {
    final baseColor = {
      DayStatus.taken: Colors.green,
      DayStatus.missed: Colors.red,
      DayStatus.nodata: Colors.grey,
    }[s] ?? Colors.grey;

    return {
      'color': isToday 
          ? baseColor.shade100  // Lighter shade for today
          : s == DayStatus.taken 
              ? baseColor.shade300
              : s == DayStatus.missed
                  ? baseColor.shade200
                  : Colors.grey.shade300,
      'borderColor': isToday ? baseColor : Colors.transparent,
      'icon': s == DayStatus.taken 
          ? Icons.check_circle_outline
          : s == DayStatus.missed 
              ? Icons.cancel_outlined
              : null,
      'iconColor': isToday ? baseColor : baseColor.shade700,
    };
  }

  Future<void> _showDayDetails(DateTime date) async {
    final key = DateFormat('yyyy-MM-dd').format(date);
    final items = List<Map<String, dynamic>>.from(_dayDetails[key] ?? []);

    // Fallback: if no items in memory for this day, attempt to read from
    // SharedPreferences (decrypting if necessary) and collect reminders/history
    // that match the selected date. This handles cases where stored DateTime
    // strings may parse to a different calendar date due to timezone offsets.
    if (items.isEmpty) {
      try {
        final u = AuthService().currentUser;
        if (u != null) {
          final prefs = await SharedPreferences.getInstance();
          // helper to decode a stored key (encrypted or plaintext)
          Future<List<dynamic>> decode(String? raw) async {
            if (raw == null || raw.isEmpty) return <dynamic>[];
            try {
              final keyStr = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
              final key = encryptpkg.Key.fromUtf8(keyStr);
              final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));
              final dec = encrypter.decrypt64(raw, iv: _fixedIV);
              return json.decode(dec) as List<dynamic>;
            } catch (_) {
              try {
                return json.decode(raw) as List<dynamic>;
              } catch (_) {
                return <dynamic>[];
              }
            }
          }

          // reminders
          final rawRem = prefs.getString('aura_reminders_${u['username']}');
          final remList = await decode(rawRem);
          for (final e in remList) {
            try {
              final m = Map<String, dynamic>.from(e as Map);
              if (m['dateTime'] == null) continue;
              final dt = DateTime.parse(m['dateTime'] as String).toLocal();
              if (dt.year == date.year && dt.month == date.month && dt.day == date.day) {
                items.add({
                  'id': m['id'] ?? '',
                  'medication': m['medication'] ?? '',
                  'dosage': m['dosage'] ?? '',
                  'dateTime': (m['dateTime'] ?? '').toString(),
                  'takenAt': m['takenAt'],
                  'source': 'reminder'
                });
              }
            } catch (_) {}
          }

          // history
          final rawHist = prefs.getString('aura_reminder_history_${u['username']}');
          final histList = await decode(rawHist);
          for (final h in histList) {
            try {
              final hm = Map<String, dynamic>.from(h as Map);
              if ((hm['status'] ?? '') == 'taken' && hm['when'] != null) {
                final dt = DateTime.parse(hm['when'] as String).toLocal();
                if (dt.year == date.year && dt.month == date.month && dt.day == date.day) {
                  items.add({
                    'id': hm['id'] ?? '',
                    'medication': hm['medication'] ?? '',
                    'dosage': hm['dosage'] ?? '',
                    'dateTime': hm['when'],
                    'takenAt': hm['when'],
                    'source': 'history'
                  });
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }
    
    // Calculate adherence stats for this day
    int takenCount = 0;
    int takenOnTime = 0;
    int missedCount = 0;
    
    final now = DateTime.now();
    for (final m in items) {
      try {
        final scheduled = DateTime.parse(m['dateTime'] as String).toLocal();
        final taken = m['takenAt'] != null;
        if (taken) {
          takenCount++;
          final takenAt = DateTime.parse(m['takenAt'] as String).toLocal();
          if (takenAt.difference(scheduled).inHours.abs() <= 2) {
            takenOnTime++;
          }
        } else {
          // Only count as missed if the scheduled time is in the past
          if (scheduled.isBefore(now)) {
            missedCount++;
          }
        }
      } catch (_) {}
    }
    
    showDialog(
      context: context, 
      builder: (c) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.teal),
            const SizedBox(width: 8),
            Text(DateFormat.yMMMMd().format(date)),
          ]
        ),
        content: items.isEmpty 
          ? const Text('No medications scheduled for this day.')
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Daily Summary Card
                  if (items.isNotEmpty) Card(
                    color: Colors.teal.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('✅ Taken: $takenCount ($takenOnTime on time)'),
                          Text('❌ Missed: $missedCount'),
                          if (items.isNotEmpty) Text(
                            '📊 Adherence: ${(takenCount / items.length * 100).toStringAsFixed(1)}%',
                            style: TextStyle(fontWeight: FontWeight.w500)
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Medication List
                  ...items.map((m) {
                    final scheduled = DateTime.parse(m['dateTime'] as String).toLocal();
                    final taken = m['takenAt'] != null;
                    final takenAt = taken ? DateTime.parse(m['takenAt'] as String).toLocal() : null;
                    final nowLocal = DateTime.now();
                    final onTime = taken && takenAt != null && takenAt.difference(scheduled).inHours.abs() <= 2;

                    Color statusColor;
                    String statusText;
                    if (taken) {
                      statusColor = onTime ? Colors.green : Colors.orange;
                      statusText = onTime ? '✅ Taken on time' : '⚠️ Taken ${DateFormat.jm().format(takenAt!)}';
                    } else {
                      if (scheduled.isBefore(nowLocal)) {
                        statusColor = Colors.red;
                        statusText = '❌ Missed';
                      } else {
                        statusColor = Colors.grey.shade700;
                        statusText = '⏳ Scheduled';
                      }
                    }

                    return Card(
                      child: ListTile(
                        title: Text(
                          '${m['medication']} • ${m['dosage']}',
                          style: TextStyle(fontWeight: FontWeight.w500)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Scheduled: ${DateFormat.jm().format(scheduled)}'),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w500
                              )
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  }),
                ],
              )
            ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c), 
            child: const Text('Close')
          )
        ],
      )
    );
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
        final cellDay = cellIndex - startWeekday + 1;
        Widget cellWidget;
        if (cellDay < 1 || cellDay > daysInMonth) {
          cellWidget = const SizedBox.shrink();
        } else {
          final date = DateTime(_visibleMonth.year, _visibleMonth.month, cellDay);
          final key = DateFormat('yyyy-MM-dd').format(date);
          final status = _dayStatus[key];
          final today = DateTime.now();
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final style = _styleForStatus(status, isToday);
          final details = _dayDetails[key] ?? [];
          
          // Calculate completion for the day
          int total = details.length;
          int taken = details.where((d) => d['takenAt'] != null).length;
          double completionRate = total > 0 ? taken / total : 0.0;
          
          cellWidget = GestureDetector(
            onTap: () {
              final debug = explainDayStatus(date, status, details);
              debugPrint(debug);
              _showDayDetails(date);
            },
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: style['color'] as Color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: style['borderColor'] as Color,
                  width: isToday ? 2 : 0
                ),
              ),
              height: 84,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$cellDay',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: isToday ? 16 : 14
                    )
                  ),
                  if (style['icon'] != null) Icon(
                    style['icon'] as IconData,
                    color: style['iconColor'] as Color,
                    size: 16
                  ),
                  if (total > 0) Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 24,
                    height: 3,
                    decoration: BoxDecoration(
                      color: style['iconColor'] as Color,
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          style['iconColor'] as Color,
                          Colors.grey.shade300
                        ],
                        stops: [completionRate, completionRate],
                      )
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        rowChildren.add(Expanded(child: cellWidget));
      }
      rows.add(Row(children: rowChildren));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)), Text(DateFormat.yMMM().format(_visibleMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right))]),
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
    // Build calendar-week (Mon-Sun) buckets for the visible month
    final Map<int, List<String>> weekToDates = {}; // weekIndex -> list of yyyy-MM-dd
    // find the first Monday on or before the first of month
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    // Calculate days to subtract to get to Monday (1=Mon, 7=Sun)
    final daysToMonday = ((firstOfMonth.weekday - 1) % 7);
    DateTime start = firstOfMonth.subtract(Duration(days: daysToMonday));
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

    // Enhanced weekly trends calculation with detailed stats
    final List<Map<String, dynamic>> weekStats = [];
    final List<Widget> bars = [];
    
    for (final e in weekToDates.entries) {
      final wk = e.key;
      final dates = e.value;
      int wkTotal = 0;
      int wkTaken = 0;
      int wkTakenOnTime = 0;
      int totalMeds = 0;
      
      // Analyze each day in the week
      for (final k in dates) {
        final details = _dayDetails[k] ?? [];
        for (final med in details) {
          totalMeds++;
          final scheduled = DateTime.parse(med['dateTime'] as String);
          final taken = med['takenAt'] != null;
          if (taken) {
            wkTaken++;
            // Check if taken within 2 hours of scheduled time
            final takenAt = DateTime.parse(med['takenAt'] as String);
            if (takenAt.difference(scheduled).inHours.abs() <= 2) {
              wkTakenOnTime++;
            }
          }
        }
        if (details.isNotEmpty) wkTotal++;
      }
      
      final stats = {
        'week': wk,
        'dates': dates,
        'daysWithMeds': wkTotal,
        'totalMeds': totalMeds,
        'takenMeds': wkTaken,
        'takenOnTime': wkTakenOnTime,
        'adherenceRate': totalMeds > 0 ? (wkTaken / totalMeds) * 100.0 : 0.0,
        'onTimeRate': wkTaken > 0 ? (wkTakenOnTime / wkTaken) * 100.0 : 0.0
      };
      weekStats.add(stats);
      
  final adherencePct = stats['adherenceRate'] as double;
      final double maxBar = 120.0;
      final barHeight = (adherencePct / 100.0) * maxBar;

      // Create an enhanced bar visualization with adherence data
      bars.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Adherence percentage
              SizedBox(
                height: 18,
                child: Center(
                  child: Text(
                    '${adherencePct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: adherencePct >= 80 ? Colors.green.shade700 
                           : adherencePct >= 50 ? Colors.orange.shade700
                           : Colors.red.shade700
                    )
                  )
                )
              ),
              // Bar visualization
              SizedBox(
                height: maxBar,
                width: 48,
                child: Stack(
                  children: [
                    // Main adherence bar
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: barHeight,
                        width: 36,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.teal.shade300,
                              Colors.teal.shade500,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 2,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // On-time marker
                    if (((stats['takenOnTime'] as int?) ?? 0) > 0)
                      Positioned(
                        bottom: ((stats['onTimeRate'] as double?) ?? 0.0) / 100.0 * maxBar - 2,
                        left: 12,
                        child: Container(
                          width: 24,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Week label with medication count
              SizedBox(
                height: 32,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('W$wk', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    if (((stats['totalMeds'] as int?) ?? 0) > 0)
                      Text(
                        '${stats['takenMeds'] as int}/${stats['totalMeds'] as int}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
  final hasAnyWeekData = weekStats.any((stats) => (stats['totalMeds'] as int) > 0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Medication Adherence Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        // seed demo data button for quick visual verification
        OutlinedButton.icon(
          onPressed: _seedDemoData,
          icon: const Icon(Icons.bug_report, size: 16),
          label: const Text('Seed demo data'),
        ),
      ]),
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

  /// Seed demo reminders, appointments and mood journal entries so charts show data.
  Future<void> _seedDemoData() async {
    final prefs = await SharedPreferences.getInstance();
    final u = AuthService().currentUser;
    final now = DateTime.now();

    // Seed appointments (global storage)
    try {
      final rawAppt = prefs.getString('aura_appointments') ?? '[]';
      final apptList = (json.decode(rawAppt) as List<dynamic>?)?.toList() ?? [];
      // add two appointments: one today, one later this month
      apptList.insert(0, {
        'title': 'Check-in with Dr. Smith',
        'dateTime': DateTime(now.year, now.month, now.day, 10, 30).toIso8601String(),
        'provider': 'Dr. Smith',
        'location': 'Clinic A',
        'notes': 'Regular follow-up',
        'type': 'In Person'
      });
      apptList.insert(0, {
        'title': 'Therapy Session',
        'dateTime': DateTime(now.year, now.month, (now.day + 3) > 28 ? 28 : now.day + 3, 14, 0).toIso8601String(),
        'provider': 'Therapist',
        'location': 'Telehealth',
        'notes': '',
        'type': 'Video Call'
      });
      await prefs.setString('aura_appointments', json.encode(apptList));
    } catch (_) {}

    // Seed journal mood entries (plain storage) - create entries for entire month
    try {
      final rawJournal = prefs.getString('aura_journal_entries') ?? '[]';
      final journalList = (json.decode(rawJournal) as List<dynamic>?)?.toList() ?? [];
      // Create one mood entry per day from Oct 1 to today, values cycle 5..9
      for (int day = 1; day <= now.day; day++) {
        final dt = DateTime(now.year, now.month, day);
        final val = 5 + ((day - 1) % 5); // cycles 5,6,7,8,9
        journalList.insert(0, {
          'id': 'seed_mood_${dt.toIso8601String()}',
          'type': 0,
          'dateTime': dt.toIso8601String(),
          'title': 'Mood $val/10',
          'body': '$val/10',
          'tags': ['seed']
        });
      }
      await prefs.setString('aura_journal_entries', json.encode(journalList));
    } catch (_) {}

    // Seed reminders (encrypted per-user). If no user, skip reminders seeding.
    if (u != null) {
      try {
        final keyStr = ('${u.passphrase}aura_salt_2025').padRight(32).substring(0,32);
        final key = encryptpkg.Key.fromUtf8(keyStr);
        final encrypter = encryptpkg.Encrypter(encryptpkg.AES(key));

        final storageKey = 'aura_reminders_${u['username']}';
        final historyKey = 'aura_reminder_history_${u['username']}';
        
        // Clear existing data
        List<dynamic> existing = [];
        List<dynamic> history = [];

        // Create reminders for every day Oct 1-26, alternating taken/missed
        final sample = <Map<String,dynamic>>[];
        final historyEntries = <Map<String,dynamic>>[];

        // Fixed range Oct 1-26 regardless of current date
        for (int day = 1; day <= 26; day++) {
          // Morning med (8am) - alternating pattern
          final dtMorning = DateTime(now.year, now.month, day, 8, 0);
          final idMorning = 'seed_med_${dtMorning.toIso8601String()}';
          if (day % 2 == 0) {
            // Even days: moved to history as taken
            historyEntries.add({
              'id': idMorning,
              'medication': 'Morning Med',
              'dosage': '10 mg',
              'when': dtMorning.add(const Duration(minutes: 5)).toIso8601String(),
              'status': 'taken'
            });
          } else {
            // Odd days: in reminders as missed
            sample.add({
              'id': idMorning,
              'medication': 'Morning Med',
              'dosage': '10 mg',
              'dateTime': dtMorning.toIso8601String(),
              'enabled': true,
              'notify': true,
              'repeatDaily': false
            });
          }

          // Evening med (8pm) - opposite pattern
          final dtEvening = DateTime(now.year, now.month, day, 20, 0);
          final idEvening = 'seed_med_evening_${dtEvening.toIso8601String()}';
          if (day % 2 == 1) {
            // Odd days: moved to history as taken
            historyEntries.add({
              'id': idEvening,
              'medication': 'Evening Med',
              'dosage': '5 mg',
              'when': dtEvening.add(const Duration(minutes: 5)).toIso8601String(),
              'status': 'taken'
            });
          } else {
            // Even days: in reminders as missed
            sample.add({
              'id': idEvening,
              'medication': 'Evening Med',
              'dosage': '5 mg',
              'dateTime': dtEvening.toIso8601String(),
              'enabled': true,
              'notify': true,
              'repeatDaily': false
            });
          }
        }

        // Today's meds
        sample.add({
          'id': 'seed_med_today_morning',
          'medication': 'Morning Med',
          'dosage': '10 mg',
          'dateTime': DateTime(now.year, now.month, now.day, 8, 0).toIso8601String(),
          'enabled': true,
          'notify': true,
          'repeatDaily': false
        });
        sample.add({
          'id': 'seed_med_today_evening',
          'medication': 'Evening Med',
          'dosage': '5 mg',
          'dateTime': DateTime(now.year, now.month, now.day, 20, 0).toIso8601String(),
          'enabled': true,
          'notify': true,
          'repeatDaily': false
        });

        // Save reminders (encrypted)
        existing.insertAll(0, sample);
        final payload = json.encode(existing);
        final encrypted = encrypter.encrypt(payload, iv: _fixedIV).base64;
        await prefs.setString(storageKey, encrypted);

        // Save history (encrypted)
        history.insertAll(0, historyEntries);
        final historyPayload = json.encode(history);
        final encryptedHistory = encrypter.encrypt(historyPayload, iv: _fixedIV).base64;
        await prefs.setString(historyKey, encryptedHistory);
      } catch (_) {}
    }

    // reload data and refresh UI (best-effort). Also inject visible demo state so charts update immediately.
    await _loadDataForMonth(_visibleMonth);

    // Inject demo state to ensure charts show even if loaders miss encrypted reminders when not signed in.
    try {
      final today = DateTime.now();
      // clear existing caches for visible month
      _dayStatus.clear();
      _dayDetails.clear();

      // seed day details from demo reminders we added above
      final demoTodayKey = DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, today.day));
      final demoYesterdayKey = DateFormat('yyyy-MM-dd').format(DateTime(today.year, today.month, today.day - 1));

      // today: one scheduled (pending)
      _dayDetails[demoTodayKey] = [
        {'medication': 'Med A', 'dosage': '10 mg', 'dateTime': DateTime(today.year, today.month, today.day, 9, 0).toIso8601String(), 'takenAt': null}
      ];
      _dayStatus[demoTodayKey] = DayStatus.nodata; // will be pending or nodata depending on time

      // yesterday: one taken
      _dayDetails[demoYesterdayKey] = [
        {'medication': 'Med B', 'dosage': '5 mg', 'dateTime': DateTime(today.year, today.month, today.day - 1, 20, 0).toIso8601String(), 'takenAt': DateTime(today.year, today.month, today.day - 1, 20, 5).toIso8601String()}
      ];
      _dayStatus[demoYesterdayKey] = DayStatus.taken;

  // compute a simple month adherence: mark demo days
  int totalForMonth = 0;
  int takenForMonth = 0;
      final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
      for (int d = 1; d <= daysInMonth; d++) {
        final k = DateFormat('yyyy-MM-dd').format(DateTime(_visibleMonth.year, _visibleMonth.month, d));
        final s = _dayStatus[k];
        if (s != null && s != DayStatus.nodata) {
          totalForMonth++;
          if (s == DayStatus.taken) takenForMonth++;
        }
      }
      _monthAdherencePercent = totalForMonth == 0 ? 0.0 : (takenForMonth / totalForMonth) * 100.0;

      // weekly buckets (simple 4-week slice as UI expects)
      _weeklyAdherencePct.clear();
      for (int w = 0; w < 4; w++) {
        int wkTotal = 0; int wkTaken = 0;
        final start = w * 7 + 1;
        for (int d = start; d <= (start + 6) && d <= daysInMonth; d++) {
          final key = DateFormat('yyyy-MM-dd').format(DateTime(_visibleMonth.year, _visibleMonth.month, d));
          final s = _dayStatus[key];
          if (s != null && s != DayStatus.nodata) { wkTotal++; if (s == DayStatus.taken) wkTaken++; }
        }
        _weeklyAdherencePct[w+1] = wkTotal == 0 ? 0.0 : (wkTaken / wkTotal) * 100.0;
      }

      // seed mood values for last 7 days (4..10)
      _moodByDate.clear();
      for (int i = 0; i < 7; i++) {
        final dt = DateTime(today.year, today.month, today.day).subtract(Duration(days: 6 - i));
        final key = DateFormat('yyyy-MM-dd').format(dt);
        _moodByDate[key] = (4 + i).toDouble();
      }

      setState(() {});
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo data seeded — check Trends and Reminders')));
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
