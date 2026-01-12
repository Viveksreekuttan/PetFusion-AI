// lib/home_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';                       

// --- IMPORTS ---
import 'package:vetfusion_ai/pages/settings_page.dart';
import 'package:vetfusion_ai/pages/my_pets_page.dart';
import 'package:vetfusion_ai/pages/diagnose_page.dart';
import 'package:vetfusion_ai/pages/library_page.dart';
import 'package:vetfusion_ai/pages/profile_page.dart';
import 'package:vetfusion_ai/pages/search_page.dart';
import 'package:vetfusion_ai/pages/notifications_page.dart';
import 'package:vetfusion_ai/pages/ai_assistant_page.dart';
import 'package:vetfusion_ai/pages/pet_profile_page.dart';
import 'package:vetfusion_ai/pages/set_reminder_dialog.dart'; 
import 'package:vetfusion_ai/services/data_preloader.dart'; // ⭐️ NEW IMPORT

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // ⭐️ Pages List
  final List<Widget> _pages = [
    const HomeContentPage(),
    const MyPetsPage(),
    const DiagnosePage(), 
    const LibraryPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // ⭐️ Public method to allow child widgets to switch tabs
  void switchTab(int index) {
    _onItemTapped(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF4A90E2),
        unselectedItemColor: Colors.grey,
        backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'My Pets'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Diagnose'),
          BottomNavigationBarItem(icon: Icon(Icons.library_books), label: 'Library'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      // ⭐️ Floating Action Buttons (Clock + AI Assistant)
      floatingActionButton: _selectedIndex == 0
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 1. Small Clock Button (Set Reminder)
                FloatingActionButton.small(
                  heroTag: "btn_reminder",
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const SetReminderDialog(),
                    );
                  },
                  backgroundColor: const Color(0xFFFF5722),
                  child: const Icon(Icons.alarm_add, color: Colors.white),
                ),
                const SizedBox(height: 12),

                // 2. AI Assistant Button
                FloatingActionButton.extended(
                  heroTag: "btn_ai",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiAssistantPage()),
                    );
                  },
                  backgroundColor: const Color(0xFF4A90E2),
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  label: const Text('AI Assistant', style: TextStyle(color: Colors.white)),
                ),
              ],
            )
          : null,
    );
  }
}

// ⭐️ HOME CONTENT (Real Data Dashboard with Cached Loading)
class HomeContentPage extends StatefulWidget {
  const HomeContentPage({super.key});

  @override
  State<HomeContentPage> createState() => _HomeContentPageState();
}

class _HomeContentPageState extends State<HomeContentPage> {
  final DataPreloader _dataPreloader = DataPreloader(); // ⭐️ NEW

  // ⭐️ UPDATED: Now uses DataPreloader instead of direct Firestore calls
  Future<Map<String, dynamic>> _fetchDashboardData({bool forceRefresh = false}) async {
    return await _dataPreloader.getDashboardData(forceRefresh: forceRefresh);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.settings_outlined, color: textColor),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())),
        ),
        title: Text(
          'VetFusionAI',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: textColor),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage())),
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchDashboardData(),
        builder: (context, snapshot) {
          // ⭐️ Shows cached data instantly if available (no loading indicator!)
          if (snapshot.connectionState == ConnectionState.waiting && !_dataPreloader.isCacheValid) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final int petCount = data['petCount'] ?? 0;
          final int medicalCount = data['medicalCount'] ?? 0;
          final int reminderCount = data['reminderCount'] ?? 0;
          final List<Map<String, dynamic>> activities = data['activities'] ?? [];

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- OVERVIEW SECTION ---
                  Text('Overview', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 130,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _statCard(context, 'Total Pets', '$petCount', Icons.pets, const Color(0xFF4A90E2), () {
                           (context.findAncestorStateOfType<_HomePageState>())?.switchTab(1);
                        }),
                        _statCard(context, 'Medical\nRecords', '$medicalCount', Icons.history, const Color(0xFF9013FE), () {
                           (context.findAncestorStateOfType<_HomePageState>())?.switchTab(2);
                        }),
                        _statCard(context, 'Active\nReminders', '$reminderCount', Icons.notifications_active, const Color(0xFFF5A623), () {
                           (context.findAncestorStateOfType<_HomePageState>())?.switchTab(1);
                        }),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- QUICK ACTIONS ---
                  Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.3,
                    children: [
                      _actionCard(context, 'X-Ray Analysis', Icons.camera_alt, const Color(0xFF4A90E2), () {
                        (context.findAncestorStateOfType<_HomePageState>())?.switchTab(2);
                      }),
                      _actionCard(context, 'Symptom Check', Icons.edit_note, const Color(0xFF7ED321), () {
                        (context.findAncestorStateOfType<_HomePageState>())?.switchTab(2);
                      }),
                      _actionCard(context, 'Gait Analysis', Icons.videocam, const Color(0xFFF5A623), () {
                        (context.findAncestorStateOfType<_HomePageState>())?.switchTab(2);
                      }),
                      _actionCard(context, 'Audio Scan', Icons.mic, const Color(0xFF9013FE), () {
                        (context.findAncestorStateOfType<_HomePageState>())?.switchTab(2);
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // --- RECENT ACTIVITY ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Recent Activity', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      // ⭐️ UPDATED: Force refresh button now clears cache
                      TextButton(
                        onPressed: () { 
                          setState(() {}); 
                          _fetchDashboardData(forceRefresh: true);
                        }, 
                        child: const Text('Refresh')
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  if (activities.isEmpty)
                     Center(child: Padding(
                       padding: const EdgeInsets.all(20.0),
                       child: Text("No recent activity found.", style: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey)),
                     )),

                  // ⭐️ Map icon strings back to IconData
                  ...activities.map((act) => _activityItem(
                    context,
                    title: "${act['title']} for ${act['petName']}",
                    time: DateFormat.yMMMd().add_jm().format(act['date']),
                    icon: _getIconData(act['icon']),
                    color: _getColorFromString(act['color']),
                    onTap: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => PetDetailView(petId: act['petId']))
                      );
                    }
                  )),

                  const SizedBox(height: 24),

                  // --- DAILY TIP ---
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 2,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4A90E2), Color(0xFF7ED321)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline, color: Colors.white, size: 40),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Daily Tip', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                const Text('Regular dental care prevents 80% of oral diseases in pets', style: TextStyle(color: Colors.white, fontSize: 14)),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.white.withOpacity(0.2),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  ),
                                  child: const Text('Learn More', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ⭐️ Helper to convert string to IconData
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'local_hospital':
        return Icons.local_hospital;
      case 'notifications_active':
        return Icons.notifications_active;
      default:
        return Icons.info;
    }
  }

  // ⭐️ Helper to convert string to Color
  Color _getColorFromString(String colorName) {
    switch (colorName) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  Widget _statCard(BuildContext context, String title, String value, IconData icon, Color color, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 12),
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 130,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(0.1),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13, 
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityItem(BuildContext context, {
    required String title, 
    required String time, 
    required IconData icon, 
    required Color color,
    required VoidCallback onTap
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[50], 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!)
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: isDarkMode ? Colors.grey[500] : Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}