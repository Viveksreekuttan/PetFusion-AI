// lib/services/data_preloader.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pet_model.dart';

class DataPreloader {
  // Singleton Pattern
  static final DataPreloader _instance = DataPreloader._internal();
  factory DataPreloader() => _instance;
  DataPreloader._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache Storage
  Map<String, dynamic>? _cachedDashboardData;
  DateTime? _lastFetchTime;

  // Cache validity duration (5 minutes)
  final Duration _cacheValidity = const Duration(minutes: 5);

  /// Check if cached data is still valid
  bool get isCacheValid {
    if (_cachedDashboardData == null || _lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheValidity;
  }

  /// Preload dashboard data (called during splash screen)
  Future<void> preloadDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) {
      _cachedDashboardData = null;
      return;
    }

    try {
      print("🔄 DataPreloader: Starting preload...");
      _cachedDashboardData = await _fetchDashboardData();
      _lastFetchTime = DateTime.now();
      print("✅ DataPreloader: Preload complete!");
    } catch (e) {
      print("❌ DataPreloader: Preload failed - $e");
      _cachedDashboardData = null;
    }
  }

  /// Get cached data or fetch fresh data
  Future<Map<String, dynamic>> getDashboardData({bool forceRefresh = false}) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && isCacheValid && _cachedDashboardData != null) {
      print("📦 DataPreloader: Returning cached data");
      return _cachedDashboardData!;
    }

    // Fetch fresh data
    print("🔄 DataPreloader: Fetching fresh data...");
    await preloadDashboardData();
    return _cachedDashboardData ?? {};
  }

  /// Clear cache (useful for logout)
  void clearCache() {
    _cachedDashboardData = null;
    _lastFetchTime = null;
    print("🗑️ DataPreloader: Cache cleared");
  }

  /// Internal fetch method (same logic as your original _fetchDashboardData)
  Future<Map<String, dynamic>> _fetchDashboardData() async {
    final user = _auth.currentUser;
    if (user == null) return {};

    int petCount = 0;
    int medicalCount = 0;
    int reminderCount = 0;
    List<Map<String, dynamic>> activities = [];

    try {
      // 1. Get Pets
      final petsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .get();
      petCount = petsSnapshot.docs.length;

      // 2. Iterate Pets to get Sub-collection Data
      for (var doc in petsSnapshot.docs) {
        final petData = doc.data();
        petData['id'] = doc.id;
        final pet = Pet.fromMap(petData);

        // A. Fetch recent medical records
        final meds = await doc.reference
            .collection('medical_records')
            .orderBy('date', descending: true)
            .limit(1)
            .get();

        if (meds.docs.isNotEmpty) {
          medicalCount++;
          final mData = meds.docs.first.data();
          activities.add({
            'type': 'medical',
            'title': mData['diagnosis'] ?? 'Checkup',
            'date': (mData['date'] as Timestamp).toDate(),
            'petName': pet.name,
            'petId': pet.id,
            'icon': 'local_hospital',
            'color': 'green',
          });
        }

        // B. Fetch upcoming reminders
        final rems = await doc.reference
            .collection('reminders')
            .where('dueDate', isGreaterThan: Timestamp.now())
            .orderBy('dueDate')
            .limit(1)
            .get();

        if (rems.docs.isNotEmpty) {
          reminderCount++;
          final rData = rems.docs.first.data();
          activities.add({
            'type': 'reminder',
            'title': rData['title'] ?? 'Reminder',
            'date': (rData['dueDate'] as Timestamp).toDate(),
            'petName': pet.name,
            'petId': pet.id,
            'icon': 'notifications_active',
            'color': 'orange',
          });
        }
      }

      // 3. Sort Combined Activities by Date Descending
      activities.sort((a, b) => b['date'].compareTo(a['date']));

      // Keep only top 5
      if (activities.length > 5) {
        activities = activities.sublist(0, 5);
      }
    } catch (e) {
      print("Error fetching dashboard: $e");
    }

    return {
      'petCount': petCount,
      'medicalCount': medicalCount,
      'reminderCount': reminderCount,
      'activities': activities,
    };
  }
}