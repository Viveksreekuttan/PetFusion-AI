// lib/terms_page.dart
import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        // ⭐️ FIXED: Inherits Theme colors automatically
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms and Conditions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Last updated: October 24, 2025',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('1. Acceptance of Terms'),
            const SizedBox(height: 8),
            const Text(
              'By using the VetFusionAI application ("App"), you agree to be bound by these Terms and Conditions ("Terms"). If you disagree with any part of the terms, then you do not have permission to access the App.',
              style: TextStyle(height: 1.4),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('2. Disclaimer'),
            const SizedBox(height: 8),
            const Text(
              'VetFusionAI provides AI-assisted diagnostic suggestions and pet care information. It is NOT a substitute for professional veterinary advice, diagnosis, or treatment. Always seek the advice of your veterinarian or other qualified health provider with any questions you may have regarding a medical condition.',
              style: TextStyle(
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('3. Use License'),
            const SizedBox(height: 8),
            const Text(
              'Permission is granted to temporarily download one copy of the App for personal, non-commercial transitory viewing only. This is the grant of a license, not a transfer of title...',
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