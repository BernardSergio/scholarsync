import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, String>> _emergency = [];

  List<Map<String, dynamic>> _filteredClinics = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // ensure UI updates (search bar visibility) when user changes tabs
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    // Try to load saved data; otherwise populate with built-in offline samples
    try {
      final prefs = await SharedPreferences.getInstance();
      final clinicsRaw = prefs.getString('resources_clinics');
      final articlesRaw = prefs.getString('resources_articles');
      final emergencyRaw = prefs.getString('resources_emergency');

      if (clinicsRaw != null && clinicsRaw.isNotEmpty) {
        _clinics = List<Map<String,dynamic>>.from(jsonDecode(clinicsRaw) as List<dynamic>);
      } else {
        _clinics = _defaultClinics();
      }

      if (articlesRaw != null && articlesRaw.isNotEmpty) {
        _articles = List<Map<String,dynamic>>.from(jsonDecode(articlesRaw) as List<dynamic>);
      } else {
        _articles = _defaultArticles();
      }

      if (emergencyRaw != null && emergencyRaw.isNotEmpty) {
        _emergency = List<Map<String,String>>.from(jsonDecode(emergencyRaw) as List<dynamic>);
      } else {
        _emergency = _defaultEmergency();
      }
    } catch (_) {
      // fallback to defaults
      _clinics = _defaultClinics();
      _articles = _defaultArticles();
      _emergency = _defaultEmergency();
    }

    setState(() {
      _filteredClinics = List.of(_clinics);
    });
  }

  // no compute helper needed for small data

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredClinics = List.of(_clinics));
      return;
    }
    setState(() {
      _filteredClinics = _clinics.where((c) {
        final name = (c['name'] as String).toLowerCase();
        final addr = (c['address'] as String).toLowerCase();
        final services = ((c['services'] as List<dynamic>).join(' ')).toLowerCase();
        return name.contains(q) || addr.contains(q) || services.contains(q);
      }).toList();
    });
  }

  List<Map<String,dynamic>> _defaultClinics() {
    return [
      {
        'name': 'Wellness Mental Health Center',
        'address': '123 Main Street, Downtown',
        'phone': '+1 555 123 4567',
        'hours': 'Mon–Fri 8AM–6PM',
        'services': ['Therapy','Psychiatry','Group Sessions']
      },
      {
        'name': 'MindCare Pharmacy',
        'address': '456 Oak Avenue, Midtown',
        'phone': '+1 555 987 6543',
        'hours': 'Mon–Sat 9AM–9PM',
        'services': ['Pharmacy','Medication Counseling','24/7 Emergency']
      },
      {
        'name': 'Community Mental Health Services',
        'address': '789 Pine Road, West Side',
        'phone': '+1 555 456 7890',
        'hours': 'Mon–Fri 7AM–7PM',
        'services': ['Crisis Support','Counseling','Peer Support']
      }
    ];
  }

  List<Map<String,dynamic>> _defaultArticles() {
    return [
      {'title':'Understanding Antidepressants','summary':'Learn about different types of antidepressants and what to expect.','content':'Full article content about antidepressants.','link':''},
      {'title':'Mindfulness Techniques for Anxiety','summary':'Practical mindfulness exercises to manage anxiety.','content':'Full article content about mindfulness.','link':''},
      {'title':'Sleep Hygiene and Mental Health','summary':'How sleep affects mental health and tips for better sleep habits.','content':'Full article content about sleep hygiene.','link':''},
    ];
  }

  List<Map<String,String>> _defaultEmergency() {
    return [
      {'name':'National Suicide Prevention Lifeline','number':'988','desc':'24/7 crisis support for people in suicidal crisis or emotional distress'},
      {'name':'Crisis Text Line','number':'741741','desc':'Text HOME to 741741 for 24/7 support'},
      {'name':'NAMI Helpline','number':'1-800-950-NAMI (6264)','desc':'Information and support for mental health conditions'},
    ];
  }

  void _callNumber(String number) {
    // Placeholder: in real app use url_launcher to dial
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Calling $number (placeholder)')));
  }

  void _openDirections(String address) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Open directions to $address (placeholder)')));
  }

  void _showArticle(Map<String,dynamic> article) {
    showDialog(context: context, builder: (c) => AlertDialog(title: Text(article['title'] as String), content: SingleChildScrollView(child: Text(article['content'] as String)), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close'))]));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Resources'), backgroundColor: Colors.white, foregroundColor: Colors.teal, elevation: 1, bottom: PreferredSize(preferredSize: const Size.fromHeight(56), child: Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:8), child: _buildTabs()))),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          // Search bar only for locations
          if (_tabController.index == 0) _buildSearchBar(),
          const SizedBox(height:8),
          Expanded(child: TabBarView(controller: _tabController, children: [
            _buildLocationsTab(),
            _buildArticlesTab(),
            _buildEmergencyTab(),
          ])),
        ]),
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      // use the same look & feel as the Dashboard TabBar
      indicatorColor: Colors.teal,
      labelColor: Colors.teal,
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      tabs: const [Tab(text: 'Locations'), Tab(text: 'Articles'), Tab(text: 'Emergency')],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(hintText: 'Search by name, service, or location', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
    );
  }

  Widget _buildLocationsTab() {
    if (_filteredClinics.isEmpty) return const Center(child: Text('No results'));
    return ListView.builder(
      itemCount: _filteredClinics.length,
      itemBuilder: (context, i) {
        final c = _filteredClinics[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical:8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)), Text(c['hours'], style: const TextStyle(color: Colors.grey, fontSize:12))]),
              const SizedBox(height:6),
              Text(c['address']),
              const SizedBox(height:6),
              Row(children: [Icon(Icons.phone, size:14, color: Colors.grey), const SizedBox(width:6), Text(c['phone'])]),
              const SizedBox(height:8),
              Wrap(spacing:8, children: (c['services'] as List<dynamic>).map((s) => Chip(label: Text('$s', style: const TextStyle(fontSize:12)), backgroundColor: Colors.grey[100])).toList()),
              const SizedBox(height:8),
              Row(children: [ElevatedButton.icon(onPressed: () => _openDirections(c['address']), icon: const Icon(Icons.directions), label: const Text('Directions'), style: ElevatedButton.styleFrom(backgroundColor: Colors.teal)), const SizedBox(width:8), OutlinedButton.icon(onPressed: () => _callNumber(c['phone']), icon: const Icon(Icons.call), label: const Text('Call'))])
            ]),
          ),
        );
      },
    );
  }

  Widget _buildArticlesTab() {
    return ListView.builder(
      itemCount: _articles.length,
      itemBuilder: (context, i) {
        final a = _articles[i];
        return Card(margin: const EdgeInsets.symmetric(vertical:8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: ListTile(
          title: Text(a['title']),
          subtitle: Text(a['summary']),
          trailing: IconButton(icon: const Icon(Icons.open_in_new), onPressed: () => _showArticle(a)),
        ));
      },
    );
  }

  Widget _buildEmergencyTab() {
    return ListView.builder(
      itemCount: _emergency.length,
      itemBuilder: (context, i) {
        final e = _emergency[i];
        return Card(margin: const EdgeInsets.symmetric(vertical:8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(e['name']!, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height:6), Text(e['desc']!)])),
          ElevatedButton.icon(onPressed: () => _callNumber(e['number']!), icon: const Icon(Icons.call), label: const Text('Call Now'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red))
        ])));
      },
    );
  }
}

// helpers

