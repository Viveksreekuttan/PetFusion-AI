// lib/privacy_policy_page.dart
import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Security'),
        // ⭐️ FIXED: Inherits Theme colors automatically
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Last updated: October 24, 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Information We Collect'),
            const SizedBox(height: 8),
            const Text(
              'We collect information you provide directly to us, such as when you create an account (name, email), and information related to your pets and diagnoses (images, notes, audio, video) to provide and improve our services.\n\nWe also collect anonymous usage data to understand how the app is used.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('How We Use Information'),
            const SizedBox(height: 8),
            const Text(
              'Your data is used to provide AI diagnostic assistance, manage pet profiles, send reminders, and improve the accuracy of our models. Anonymized data may be used for research.\n\nWe do not sell your personal information.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Data Security'),
            const SizedBox(height: 8),
            const Text(
              'We implement reasonable security measures (like encryption and secure cloud storage) to protect your information. However, no system is completely secure.',
              style: TextStyle(height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}