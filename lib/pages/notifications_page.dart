// lib/notifications_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_profile_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  Future<List<Map<String, dynamic>>> _fetchReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    List<Map<String, dynamic>> allReminders = [];

    try {
      // Get all pets
      final petsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .get();

      // For each pet, get their reminders
      for (var petDoc in petsSnapshot.docs) {
        final petData = petDoc.data();
        final petName = petData['name'] ?? 'Unknown Pet';
        final petId = petDoc.id;

        final remindersSnapshot = await petDoc.reference
            .collection('reminders')
            .orderBy('dueDate', descending: false)
            .get();

        for (var reminderDoc in remindersSnapshot.docs) {
          final reminderData = reminderDoc.data();
          final dueDate = (reminderData['dueDate'] as Timestamp).toDate();
          
          allReminders.add({
            'id': reminderDoc.id,
            'petId': petId,
            'petName': petName,
            'title': reminderData['title'] ?? 'Reminder',
            'dueDate': dueDate,
            'notes': reminderData['notes'] ?? '',
          });
        }
      }

      // Sort by due date (closest first)
      allReminders.sort((a, b) => a['dueDate'].compareTo(b['dueDate']));
    } catch (e) {
      print("Error fetching reminders: $e");
    }

    return allReminders;
  }

  String _getTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.isNegative) {
      // Past due
      final days = difference.inDays.abs();
      if (days == 0) return 'Today';
      if (days == 1) return '1 day overdue';
      return '$days days overdue';
    } else {
      // Upcoming
      final days = difference.inDays;
      if (days == 0) return 'Due today';
      if (days == 1) return 'Due tomorrow';
      if (days < 7) return 'Due in $days days';
      if (days < 30) return 'Due in ${(days / 7).round()} weeks';
      return 'Due in ${(days / 30).round()} months';
    }
  }

  Color _getReminderColor(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return Colors.red; // Overdue
    } else if (difference.inDays <= 1) {
      return Colors.orange; // Due today or tomorrow
    } else if (difference.inDays <= 7) {
      return Colors.blue; // Due this week
    } else {
      return Colors.green; // Future
    }
  }

  IconData _getReminderIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('vaccination') || lowerTitle.contains('vaccine')) {
      return Icons.vaccines;
    } else if (lowerTitle.contains('medication') || lowerTitle.contains('medicine')) {
      return Icons.medication;
    } else if (lowerTitle.contains('checkup') || lowerTitle.contains('appointment')) {
      return Icons.medical_services;
    } else if (lowerTitle.contains('grooming')) {
      return Icons.content_cut;
    } else {
      return Icons.notifications_active;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        elevation: 0,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reminders yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add reminders for your pets to see them here',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          final reminders = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final reminder = reminders[index];
              return _buildNotificationTile(
                context,
                reminder['title'],
                'For ${reminder['petName']}${reminder['notes'].isNotEmpty ? ' - ${reminder['notes']}' : ''}',
                _getReminderIcon(reminder['title']),
                _getReminderColor(reminder['dueDate']),
                _getTimeAgo(reminder['dueDate']),
                reminder['petId'],
                isDarkMode,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String time,
    String petId,
    bool isDarkMode,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ],
        ),
        onTap: () {
          // Navigate to the pet's detail page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PetDetailView(petId: petId),
            ),
          );
        },
      ),
    );
  }
}