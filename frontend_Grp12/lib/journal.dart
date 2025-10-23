import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encryptpkg;
import 'package:uuid/uuid.dart';

enum JournalType { mood, medication, sideEffect, note }

extension JournalTypeExt on JournalType {
  String get label {
    switch (this) {
      case JournalType.mood:
        return 'Mood';
      case JournalType.medication:
        return 'Medication';
      case JournalType.sideEffect:
        return 'Side Effects';
      case JournalType.note:
        return 'Notes';
    }
  }
}

class JournalEntry {
  String id;
  JournalType type;
  DateTime dateTime;
  String title;
  String body;
  List<String> tags;

  JournalEntry({
    required this.id,
    required this.type,
    required this.dateTime,
    required this.title,
    required this.body,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'dateTime': dateTime.toIso8601String(),
        'title': title,
        'body': body,
        'tags': tags,
      };

  static JournalEntry fromJson(Map<String, dynamic> j) => JournalEntry(
        id: j['id'] ?? const Uuid().v4(),
        type: JournalType.values[(j['type'] ?? 0) as int],
        dateTime: DateTime.parse(j['dateTime']),
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        tags: (j['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  static const _storageKey = 'aura_journal_entries';
  final List<JournalEntry> _entries = [];
  final Set<JournalType> _filters = JournalType.values.toSet();

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = json.decode(raw) as List<dynamic>;
        setState(() {
          _entries.clear();
          _entries.addAll(list.map((e) => JournalEntry.fromJson(e as Map<String, dynamic>)));
          _entries.sort((a, b) => b.dateTime.compareTo(a.dateTime));
        });
      } catch (_) {}
    }
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final data = json.encode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }

  void _toggleFilter(JournalType t) {
    setState(() {
      if (_filters.contains(t)) {
        _filters.remove(t);
      } else {
        _filters.add(t);
      }
    });
  }

  Future<void> _showNewEntryDialog() async {
    final result = await showDialog<JournalEntry?>(
      context: context,
      builder: (c) => _NewEntryDialog(),
    );

    if (result != null && mounted) {
      setState(() => _entries.insert(0, result));
      await _saveEntries();
    }
  }

  // Public wrapper
  Future<void> showNewJournalEntryDialog(BuildContext context) async {
    final res = await showDialog<JournalEntry?>(
      context: context,
      builder: (c) => _NewEntryDialog(),
    );
    if (res != null) {
      final prefs = await SharedPreferences.getInstance();
      const key = 'aura_journal_entries';
      final raw = prefs.getString(key) ?? '[]';
      try {
        final list = json.decode(raw) as List<dynamic>;
        list.insert(0, res.toJson());
        await prefs.setString(key, json.encode(list));
      } catch (_) {}
    }
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete entry'),
        content: const Text('Are you sure you want to delete this entry? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _entries.removeWhere((e) => e.id == id));
      await _saveEntries();
    }
  }

  Future<void> _exportEncrypted() async {
    final passCtrl = TextEditingController();
    final ok = await showDialog<bool?>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Export Entries (encrypted)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a passphrase to encrypt your export file. Keep it safe.'),
            const SizedBox(height: 12),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Passphrase')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Export')),
        ],
      ),
    );

    if (ok != true || passCtrl.text.isEmpty) return;

    final plaintext = json.encode(_entries.map((e) => e.toJson()).toList());
    final keyBytes = encryptpkg.Key.fromUtf8(passCtrl.text.padRight(32).substring(0, 32));
    final iv = encryptpkg.IV.fromLength(16);
    final encrypter = encryptpkg.Encrypter(encryptpkg.AES(keyBytes));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/aura_journal_export_${DateTime.now().toIso8601String()}.enc');
    await file.writeAsBytes(encrypted.bytes);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${_entries.length} entries to ${file.path} (encrypted)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <JournalType, List<JournalEntry>>{};
    for (final t in JournalType.values) {
      grouped[t] = [];
    }
    for (final e in _entries) {
      grouped[e.type]?.add(e);
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Journal Vault',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Row(children: [
                ElevatedButton.icon(
                    onPressed: _exportEncrypted,
                    icon: const Icon(Icons.lock),
                    label: const Text('Export')),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                    onPressed: _showNewEntryDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('New Entry')),
              ])
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: JournalType.values.map((t) {
              final on = _filters.contains(t);
              return FilterChip(
                  label: Text(t.label), selected: on, onSelected: (_) => _toggleFilter(t));
            }).toList(),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: JournalType.values.where((t) => _filters.contains(t)).map((t) {
                final items = grouped[t]!..sort((a, b) => b.dateTime.compareTo(a.dateTime));
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(t.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: items
                          .map((e) => Card(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                child: ListTile(
                                  title: Text(
                                    e.title.isEmpty
                                        ? e.body.split('\n').first
                                        : e.title,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${e.dateTime.toLocal()}'),
                                      const SizedBox(height: 6),
                                      Text(e.body),
                                    ],
                                  ),
                                  trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _confirmDelete(e.id)),
                                  isThreeLine: true,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewEntryDialog extends StatefulWidget {
  @override
  State<_NewEntryDialog> createState() => _NewEntryDialogState();
}

class _NewEntryDialogState extends State<_NewEntryDialog> {
  JournalType _type = JournalType.mood;
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();

  void _submit() {
    final id = const Uuid().v4();
    final tags = _tags.text
        .split(RegExp(r'[ ,#]+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    final entry = JournalEntry(
      id: id,
      type: _type,
      dateTime: DateTime.now(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      tags: tags,
    );
    Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Journal Entry'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose the type of entry you\'d like to create'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: JournalType.values
                  .map((t) => ChoiceChip(
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            const Text('Title (optional)'),
            const SizedBox(height: 6),
            TextField(
                controller: _title,
                decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('Write your entry here...'),
            const SizedBox(height: 6),
            TextField(
                controller: _body,
                maxLines: 6,
                decoration: const InputDecoration(border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('Tags (comma or # separated)'),
            const SizedBox(height: 6),
            TextField(
                controller: _tags,
                decoration: const InputDecoration(hintText: '#anxiety, #progress')),
          ],
        ),
      ),
      actions: [
        OutlinedButton(
            onPressed: () => Navigator.pop(context, null), child: const Text('Back')),
        ElevatedButton(onPressed: _submit, child: const Text('Save Entry')),
      ],
    );
  }
}
