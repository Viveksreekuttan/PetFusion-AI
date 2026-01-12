// lib/set_reminder_dialog.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SetReminderDialog extends StatefulWidget {
  const SetReminderDialog({super.key});

  @override
  State<SetReminderDialog> createState() => _SetReminderDialogState();
}

class _SetReminderDialogState extends State<SetReminderDialog> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? selectedPetId;
  String? selectedPetName;
  String selectedType = 'Vaccination';
  final TextEditingController _detailsController = TextEditingController();
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  bool isLoading = false;
  List<Map<String, String>> pets = [];
  bool isPetsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }

  Future<void> _loadPets() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => isPetsLoading = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .get();

      if (mounted) {
        setState(() {
          pets = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] as String? ?? 'Unknown',
                  })
              .toList();
          isPetsLoading = false;
        });
      }

      // Auto-select first pet if only one exists
      if (pets.length == 1 && mounted) {
        setState(() {
          selectedPetId = pets[0]['id'];
          selectedPetName = pets[0]['name'];
        });
      }
    } catch (e) {
      print("Error loading pets: $e");
      if (mounted) {
        setState(() => isPetsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pets: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        selectedTime = picked;
      });
    }
  }

  Future<void> _saveReminder() async {
    // Validation
    if (selectedPetId == null || selectedPetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a pet'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_detailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter reminder details'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Combine date and time
      final reminderDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        selectedTime!.hour,
        selectedTime!.minute,
      );

      print("Saving reminder for pet: $selectedPetId");
      print("Reminder date: $reminderDateTime");

      // Save to Firestore
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(selectedPetId)
          .collection('reminders')
          .add({
        'title': '$selectedType - ${_detailsController.text.trim()}',
        'type': selectedType,
        'notes': _detailsController.text.trim(),
        'dueDate': Timestamp.fromDate(reminderDateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'isCompleted': false,
      });

      print("Reminder saved with ID: ${docRef.id}");

      if (mounted) {
        // Close dialog
        Navigator.pop(context);
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${selectedPetName ?? "your pet"}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error saving reminder: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save reminder: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth > 600 ? 500 : screenWidth - 32,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: isPetsLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading pets...'),
                  ],
                ),
              )
            : pets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pets, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No pets found',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please add a pet first',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Row(
                          children: [
                            const Icon(Icons.alarm_add, color: Color(0xFF4A90E2), size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Set New Reminder',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Select Pet
                        Text(
                          'Select Pet *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              value: selectedPetId,
                              hint: const Text('Choose a pet'),
                              items: pets.map((pet) {
                                return DropdownMenuItem<String>(
                                  value: pet['id'],
                                  child: Row(
                                    children: [
                                      const Icon(Icons.pets, size: 18),
                                      const SizedBox(width: 8),
                                      Text(pet['name']!),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedPetId = value;
                                  selectedPetName = pets.firstWhere(
                                    (pet) => pet['id'] == value,
                                  )['name'];
                                });
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Reminder Type
                        Text(
                          'Reminder Type *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Vaccination', 'Medication', 'Test', 'Checkup', 'Grooming', 'Other'].map((type) {
                            final isSelected = selectedType == type;
                            return ChoiceChip(
                              label: Text(type),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  selectedType = type;
                                });
                              },
                              selectedColor: const Color(0xFF4A90E2),
                              backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : (isDarkMode ? Colors.white : Colors.black),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 16),

                        // Details
                        Text(
                          'Details *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _detailsController,
                          maxLines: 3,
                          maxLength: 200,
                          decoration: InputDecoration(
                            hintText: 'e.g., Annual Rabies shot',
                            counterText: '',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Date & Time Row
                        Row(
                          children: [
                            // Date
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _pickDate,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.calendar_today, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              selectedDate == null
                                                  ? 'Pick date'
                                                  : DateFormat('MMM dd').format(selectedDate!),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: selectedDate == null ? Colors.grey : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Time *',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  InkWell(
                                    onTap: _pickTime,
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              selectedTime == null
                                                  ? 'Pick time'
                                                  : selectedTime!.format(context),
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: selectedTime == null ? Colors.grey : null,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _saveReminder,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A90E2),
                              disabledBackgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Set Reminder',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}