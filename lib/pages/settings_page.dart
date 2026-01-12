import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:share_plus/share_plus.dart'; // Uncomment if you add share_plus package
import 'login_page.dart';
import '../services/theme_service.dart'; // <--- ⭐️ REQUIRED IMPORT

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final Color primaryColor = const Color(0xFF4A90E2); // Theme color

  // Helper to get the current theme string directly from the Service
  // This ensures the dropdown always matches the actual app state.
  String get _currentThemeString {
    final mode = ThemeService().themeMode;
    if (mode == ThemeMode.light) return 'light';
    if (mode == ThemeMode.dark) return 'dark';
    return 'system';
  }

  // --- Feature 1: Rating Dialog (Preserved) ---
  void _showRatingDialog() {
    int rating = 0; 
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Rate VetFusionAI'),
          content: StatefulBuilder( 
            builder: (BuildContext context, StateSetter setState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        rating = index + 1;
                      });
                    },
                  );
                }),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Thanks for rating $rating stars!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  // --- Feature 2: Share App (Preserved) ---
  Future<void> _shareApp() async {
    // await Share.share('Check out VetFusionAI...'); 
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality not implemented yet.')),
    );
  }

  // --- Feature 3: Sign Out (Preserved) ---
  Future<void> _signOut() async {
    bool? confirmLogout = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmLogout == true) {
      try {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (Route<dynamic> route) => false, 
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
      ),
      body: ListView( 
        padding: const EdgeInsets.symmetric(vertical: 16.0), 
        children: [

          // --- Appearance Section ---
          _buildSectionHeader('Appearance'),
          ListTile(
            leading: Icon(Icons.palette_outlined, color: primaryColor),
            title: const Text('Theme'),
            trailing: DropdownButton<String>(
              value: _currentThemeString, // ⭐️ Updated to use Getter
              underline: Container(), 
              items: const [
                DropdownMenuItem(value: 'light', child: Text('Light')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
                DropdownMenuItem(value: 'system', child: Text('System Default')),
              ],
              onChanged: (String? value) {
                if (value == null) return;
                
                // ⭐️ NEW LOGIC: Update ThemeService
                if (value == 'light') {
                  ThemeService().updateTheme(ThemeMode.light);
                } else if (value == 'dark') {
                  ThemeService().updateTheme(ThemeMode.dark);
                } else {
                  ThemeService().updateTheme(ThemeMode.system);
                }
                
                // Force UI rebuild to update dropdown text
                setState(() {});
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Theme set to $value')),
                );
              },
            ),
          ),

          const Divider(height: 30, indent: 16, endIndent: 16), 

           // --- About & Feedback Section ---
          _buildSectionHeader('About & Feedback'),
           ListTile(
            leading: Icon(Icons.star_outline, color: primaryColor),
            title: const Text('Rate VetFusionAI'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _showRatingDialog,
          ),
          ListTile(
            leading: Icon(Icons.share_outlined, color: primaryColor),
            title: const Text('Share App'),
             trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: _shareApp,
          ),
           ListTile(
            leading: Icon(Icons.info_outline, color: primaryColor),
            title: const Text('About App'),
             trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () {
               showAboutDialog(
                context: context,
                applicationName: 'VetFusionAI',
                applicationVersion: '1.0.0', 
                applicationLegalese: '©2025 VetFusion Tech', 
                 children: <Widget>[
                    const SizedBox(height: 15),
                    const Text('Multimodal AI Veterinary Diagnostic Assistant.')
                 ]
              );
            },
          ),

           const Divider(height: 30, indent: 16, endIndent: 16),

           // --- Account Section ---
           _buildSectionHeader('Account'),
           ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
            onTap: _signOut,
          ),
           const SizedBox(height: 20), 
        ],
      ),
    );
  }

  // Helper widget for section headers
  Widget _buildSectionHeader(String title) {
     return Padding(
       padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
       child: Text(
         title.toUpperCase(),
         style: TextStyle(
           color: Colors.grey[600],
           fontWeight: FontWeight.bold,
           fontSize: 12,
         ),
       ),
     );
  }
}