// lib/home_screen.dart

import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, dynamic>> _todayActivity = [];

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
          IconButton(
            icon: Icon(Icons.logout, color: Colors.grey[700]),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildOverviewCard(),
          const SizedBox(height: 24),
          _buildQuickActions(),
          const SizedBox(height: 24),
          _buildActivityList(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Journal'),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
    // AC A: Static placeholders
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today's Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text("😊 Current Mood: Feeling Good (Placeholder)"),
            SizedBox(height: 8),
            Text("💊 Medication Adherence: 85% (Placeholder)"),
            SizedBox(height: 8),
            Text("✨ AI Insights: Your mood is improving... (Placeholder)"),
          ],
        ),
      ),
    );
  }

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
                onPressed: () => _logActivity('Mood logged', 'Feeling optimistic - 7/10', Icons.sentiment_satisfied, Colors.blue),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.medication, color: Colors.white),
                label: const Text('Log Meds', style: TextStyle(color: Colors.white)),
                onPressed: () => _logActivity('Morning medication taken', 'Sertraline 50mg - 8:00 AM', Icons.check_circle, Colors.green),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text('Free Note', style: TextStyle(color: Colors.white)),
                onPressed: () => _logActivity('Free Note saved', 'Just a quick thought...', Icons.edit, Colors.orange),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActivityList() {
    // AC D: Today's Activity list
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Today's Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _todayActivity.isEmpty
            ? const Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: Text("No entries yet.", style: TextStyle(color: Colors.grey))),
                ),
              )
            : Column(
                children: _todayActivity.map((activity) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(activity['icon'], color: activity['color']),
                      title: Text(activity['title']),
                      subtitle: Text(activity['subtitle']),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }
}