// lib/profile_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

import 'edit_profile_page.dart';
import 'notifications_page.dart';
import 'offline_mode_page.dart';
import 'privacy_policy_page.dart';
import 'terms_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color primaryColor = Color(0xFF4A90E2);
  User? _currentUser;
  
  // ⭐️ Variable to hold the locally picked image path
  String? _localImagePath;

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    final user = FirebaseAuth.instance.currentUser;
    await user?.reload();
    if (mounted) {
      setState(() {
        _currentUser = FirebaseAuth.instance.currentUser;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _currentUser?.displayName?.isNotEmpty ?? false
        ? _currentUser!.displayName!
        : _currentUser?.email?.split('@')[0] ?? 'User';
    final email = _currentUser?.email ?? 'No email associated';

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshUser,
        child: ListView(
          children: [
            // 1. Profile Header
            _buildProfileHeader(context, displayName, email, isDarkMode),
            const SizedBox(height: 20),

            // 2. Settings List
            _buildSettingsList(context),

            // 3. Logout Button
            _buildLogoutButton(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, String displayName, String email, bool isDarkMode) {
    
    // ⭐️ LOGIC: Pick the correct image source
    ImageProvider? backgroundImage;
    if (_localImagePath != null) {
      // 1. Priority: Local File (Just picked)
      backgroundImage = FileImage(File(_localImagePath!));
    } else if (_currentUser?.photoURL != null) {
      // 2. Priority: Network URL (From Firebase)
      backgroundImage = NetworkImage(_currentUser!.photoURL!);
    } else {
      // 3. Priority: Asset Placeholder
      backgroundImage = const AssetImage('assets/profile.png');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            backgroundImage: backgroundImage,
            child: (_localImagePath == null && _currentUser?.photoURL == null)
                ? Icon(Icons.person,
                    size: 50,
                    color: isDarkMode ? Colors.grey : Colors.grey[400])
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon:
                const Icon(Icons.edit_outlined, size: 18, color: Colors.white),
            label: const Text('Edit Profile',
                style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              // ⭐️ Wait for result (image path) from Edit Page
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              );

              // Update local state if an image was picked
              if (result != null && result is String) {
                setState(() {
                  _localImagePath = result;
                });
              }
              
              _refreshUser(); // Always refresh user data
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('General'),
        _buildSettingsTile(
          context,
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()));
          },
        ),
        _buildSettingsTile(
          context,
          icon: Icons.offline_bolt_outlined,
          title: 'Offline Mode',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const OfflineModePage()));
          },
        ),
        _buildSettingsTile(
          context,
          icon: Icons.sync,
          title: 'Data Sync',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Syncing data... (Not fully implemented)')),
            );
          },
        ),
        const Divider(height: 30, indent: 16, endIndent: 16),
        _buildSectionHeader('Legal & About'),
        _buildSettingsTile(
          context,
          icon: Icons.security_outlined,
          title: 'Privacy & Security',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()));
          },
        ),
        _buildSettingsTile(
          context,
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TermsPage()));
          },
        ),
        _buildSettingsTile(
          context,
          icon: Icons.info_outline,
          title: 'About VetFusionAI',
          onTap: () {
            showAboutDialog(
                context: context,
                applicationName: 'VetFusionAI',
                applicationVersion: '1.0.0',
                applicationLegalese: '©2025 VetFusion Tech',
                children: <Widget>[
                  const SizedBox(height: 15),
                  const Text('Multimodal AI Veterinary Diagnostic Assistant.')
                ]);
          },
        ),
        _buildSettingsTile(
          context,
          icon: Icons.support_agent_outlined,
          title: 'Support & Feedback',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Contact support@vetfusion.ai')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding:
          const EdgeInsets.only(left: 16.0, right: 16.0, top: 8.0, bottom: 8.0),
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

  Widget _buildSettingsTile(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(title),
      trailing:
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          label: const Text('Sign Out',
              style: TextStyle(fontSize: 16, color: Colors.redAccent)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.withOpacity(0.3)),
            ),
            alignment: Alignment.center,
          ),
          onPressed: () async {
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
                final nav = Navigator.of(context);
                await FirebaseAuth.instance.signOut();
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (Route<dynamic> route) => false,
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error signing out: $e'),
                        backgroundColor: Colors.redAccent),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
}