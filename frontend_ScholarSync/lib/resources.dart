import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _clinics = [];
  List<Map<String, dynamic>> _articles = [];
  List<Map<String, String>> _emergency = [];
  List<Map<String, String>> _faqs = [];

  List<Map<String, dynamic>> _filteredClinics = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadData();
    _searchCtrl.addListener(_onSearch);
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clinicsRaw = prefs.getString('resources_clinics');
      final articlesRaw = prefs.getString('resources_articles');
      final emergencyRaw = prefs.getString('resources_emergency');

      if (clinicsRaw != null && clinicsRaw.isNotEmpty) {
        _clinics = List<Map<String, dynamic>>.from(jsonDecode(clinicsRaw) as List);
      } else {
        _clinics = _defaultClinics();
      }

      if (articlesRaw != null && articlesRaw.isNotEmpty) {
        _articles = List<Map<String, dynamic>>.from(jsonDecode(articlesRaw) as List);
      } else {
        _articles = _defaultArticles();
      }

      if (emergencyRaw != null && emergencyRaw.isNotEmpty) {
        _emergency = List<Map<String, String>>.from(jsonDecode(emergencyRaw) as List);
      } else {
        _emergency = _defaultEmergency();
      }
    } catch (_) {
      _clinics = _defaultClinics();
      _articles = _defaultArticles();
      _emergency = _defaultEmergency();
    }

    _faqs = _defaultFaqs();

    setState(() {
      _filteredClinics = List.of(_clinics);
    });
  }

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

  // ---- DEFAULT DATA ----

  List<Map<String, dynamic>> _defaultClinics() {
    return [
      {
        'name': 'University of the Philippines Diliman University Library',
        'address': 'Ilustrado St., UP Campus, Diliman, Quezon City',
        'phone': '(02) 8981-8500',
        'hours': 'Mon–Fri 8AM–8PM',
        'services': ['Research Assistance', 'Study Rooms', 'Academic Databases'],
        'maps': 'https://www.google.com/maps/dir//H2JV%2BJMR,+Nueve+de+Febrero,+Mandaluyong+City,+Kalakhang+Maynila/@14.5815966,120.9617484,12z/data=!4m8!4m7!1m0!1m5!1m1!1s0x3397c836239b4299:0x927b4ad146f31d2d!2m2!1d121.0441502!2d14.581611?entry=ttu&g_ep=EgoyMDI1MTAyMi4wIKXMDSoASAFQAw%3D%3D'
      },
      {
        'name': 'DLSU Learning Commons',
        'address': 'Gokongwei Hall, De La Salle University, Manila',
        'phone': '(02) 8524-4611',
        'hours': 'Mon–Sat 7AM–9PM',
        'services': ['Tutoring', 'Study Groups', 'Academic Writing'],
        'maps': 'https://www.google.com/maps?gs_lcrp=EgZjaHJvbWUyBggAEEUYOTIGCAEQLhhA0gEHNjc5ajBqNKgCALACAA&um=1&ie=UTF-8&fb=1&gl=ph&sa=X&geocode=KT00ddilt5czMaCXOvpWY58V&daddr=18+East+Ave,+Diliman,+Quezon+City,+1100+Metro+Manila'
      },
      {
        'name': 'Ateneo de Manila University Rizal Library',
        'address': 'Katipunan Ave., Loyola Heights, Quezon City',
        'phone': '(02) 8426-6001',
        'hours': 'Mon–Fri 7:30AM–9PM',
        'services': ['Research Support', 'Study Spaces', 'Digital Resources'],
        'maps': 'https://www.google.com/maps?s=web&lqi=CitUaGUgTWVkaWNhbCBDaXR5IEJlaGF2aW9yYWwgTWVkaWNpbmUgQ2VudGVyIgOIAQFIho_NveetgIAIWkMQABABEAIQAxAEEAUYARgCGAMYBBgFIit0aGUgbWVkaWNhbCBjaXR5IGJlaGF2aW9yYWwgbWVkaWNpbmUgY2VudGVykgEGZG9jdG9ymgEkQ2hkRFNVaE5NRzluUzBWSlEwRm5TVU5xZVdRMlJXMUJSUkFC-gEECAAQNg&vet=12ahUKEwjlvNXslMSQAxX5YvUHHaL7LiwQ1YkKegQIJRAB..i&cs=1&um=1&ie=UTF-8&fb=1&gl=ph&sa=X&geocode=KbnsulOCyZczMRdSUO4dOd5C&daddr=H3R9%2B3HH,+Medical+City+Dr,+Pasig,+Metro+Manila'
      },
    ];
  }

  List<Map<String, dynamic>> _defaultArticles() {
    return [
      {
        'title': 'How to Study Smarter, Not Harder',
        'summary': 'Evidence-based techniques to improve retention, focus, and academic performance.',
        'content': '',
        'link': 'https://www.coursera.org/articles/study-tips'
      },
      {
        'title': 'Beating Procrastination: A Student\'s Guide',
        'summary': 'Practical strategies for managing your time and tackling assignments before deadlines.',
        'content': '',
        'link': 'https://www.uvm.edu/tss/docs/Overcoming_Procrastination.pdf'
      },
      {
        'title': 'The Science of Effective Note-Taking',
        'summary': 'Research-backed methods like the Cornell system to maximize what you retain from lectures.',
        'content': '',
        'link': 'https://learningcenter.unc.edu/tips-and-tools/taking-notes-while-reading/'
      },
    ];
  }

  List<Map<String, String>> _defaultEmergency() {
    return [
      {
        'name': 'CHED Student Assistance Hotline',
        'number': '(02) 8441-1177',
        'desc': 'Commission on Higher Education support for students nationwide'
      },
      {
        'name': 'UP Diliman Office of Student Affairs',
        'number': '(02) 8981-8500 loc. 3941',
        'desc': 'Academic and student support services'
      },
      {
        'name': 'DLSU Counseling and Career Center',
        'number': '(02) 8524-4611 loc. 166',
        'desc': 'Academic counseling and career guidance for students'
      },
    ];
  }

  List<Map<String, String>> _defaultFaqs() {
    return [
      {
        'q': 'What is ScholarSync?',
        'a': 'ScholarSync is a specialized academic task and deadline manager designed to help high school and college students manage their academic responsibilities more effectively. It functions as a centralized hub combining automated nudge notifications, performance analytics, and secure data management — all built specifically around how students work and learn.'
      },
      {
        'q': 'What problems does ScholarSync solve?',
        'a': 'ScholarSync addresses three problems that generic productivity tools don\'t solve: missed deadlines caused by poor timeline management, the lack of student-specific analytics, and growing concerns over data privacy in educational technology.'
      },
      {
        'q': 'How does ScholarSync protect my data?',
        'a': 'ScholarSync uses a client-side encryption architecture that ensures all sensitive academic data is processed and stored locally on your device — no third-party server access. This sets it apart from every comparable tool in the market.'
      },
      {
        'q': 'What are the six key features of ScholarSync?',
        'a': '1. Academic Home Dashboard — at-a-glance status updates.\n2. Smart Nudge Reminders — personalized notifications based on urgency and motivation.\n3. Performance Analytics — track progress and identify weak subjects.\n4. Academic Resource Vault — centralized encrypted storage.\n5. Adherence Calendar — color-coded streak tracking and self-regulation.\n6. Quick Action Buttons — fast, frictionless daily use.'
      },
      {
        'q': 'Is ScholarSync aligned with any global goals?',
        'a': 'Yes. ScholarSync is directly aligned with the United Nations\' Sustainable Development Goal 4 (SDG-4), which calls for inclusive and equitable quality education for all. By reducing cognitive overload, promoting accountability through data-driven insights, and offering a freemium model, ScholarSync is purpose-built not just as a productivity tool — but as an education equity tool.'
      },
      {
        'q': 'Who is ScholarSync designed for?',
        'a': 'ScholarSync is designed for high school and college students who need a smarter way to manage assignments, deadlines, study sessions, and academic resources — all in one secure, student-focused platform.'
      },
      {
        'q': 'How is ScholarSync different from other reminder apps?',
        'a': 'Unlike general-purpose reminder apps, ScholarSync is built exclusively around student workflows. It combines deadline management, performance analytics, encrypted local storage, and personalized nudge notifications in a single platform — features no generic productivity app offers together.'
      },
    ];
  }

  // ---- ACTIONS ----

  void _callNumber(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Cannot call $number')));
    }
  }

  void _openDirections(String mapsUrl) async {
    final Uri uri = Uri.parse(mapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _showArticle(Map<String, dynamic> article) async {
    final Uri uri = Uri.parse(article['link']);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open article link.')),
      );
    }
  }

  // ---- UI ----

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Resources'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFFFC107),
        elevation: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildTabs(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_tabController.index == 0) _buildSearchBar(),
            const SizedBox(height: 8),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLocationsTab(),
                  _buildArticlesTab(),
                  _buildEmergencyTab(),
                  _buildFaqTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return TabBar(
      controller: _tabController,
      indicatorColor: const Color(0xFFFFC107),
      labelColor: const Color(0xFFFFC107),
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      tabs: const [
        Tab(text: 'Locations'),
        Tab(text: 'Articles'),
        Tab(text: 'Emergency'),
        Tab(text: 'FAQ'),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        hintText: 'Search by name, service, or campus',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildLocationsTab() {
    if (_filteredClinics.isEmpty) return const Center(child: Text('No results'));
    return ListView.builder(
      itemCount: _filteredClinics.length,
      itemBuilder: (context, i) {
        final c = _filteredClinics[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      c['hours'],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(c['address']),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.phone, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(c['phone']),
                ]),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (c['services'] as List<dynamic>)
                      .map((s) => Chip(
                            label: Text('$s', style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey[100],
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  ElevatedButton.icon(
                    onPressed: () => _openDirections(c['maps']),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC107),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _callNumber(c['phone']),
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ]),
              ],
            ),
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
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: const Icon(Icons.article, color: Color(0xFFFFC107)),
            title: Text(
              a['title'],
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(a['summary']),
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new, color: Color(0xFFFFC107)),
              onPressed: () => _showArticle(a),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmergencyTab() {
    return ListView.builder(
      itemCount: _emergency.length,
      itemBuilder: (context, i) {
        final e = _emergency[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        e['number']!,
                        style: const TextStyle(
                          color: Color(0xFFFFC107),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(e['desc']!),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _callNumber(e['number']!),
                  icon: const Icon(Icons.call),
                  label: const Text('Call Now'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFaqTab() {
    return ListView.builder(
      itemCount: _faqs.length,
      itemBuilder: (context, i) {
        final f = _faqs[i];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            iconColor: const Color(0xFFFFC107),
            collapsedIconColor: Colors.grey,
            title: Text(
              f['q']!,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  f['a']!,
                  style: TextStyle(color: Colors.grey[800], height: 1.5),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}