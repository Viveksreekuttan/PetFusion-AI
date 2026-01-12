// lib/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A simple class to manage theme state
class ThemeService with ChangeNotifier {
  // Singleton pattern to access it easily from anywhere
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  // Load saved theme on app start
  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('themeMode') ?? 'system';
    
    if (themeString == 'light') _themeMode = ThemeMode.light;
    else if (themeString == 'dark') _themeMode = ThemeMode.dark;
    else _themeMode = ThemeMode.system;
    
    notifyListeners(); // Tell the app to rebuild
  }

  // Update theme and save to storage
  Future<void> updateTheme(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners(); // Tell the app to rebuild immediately

    final prefs = await SharedPreferences.getInstance();
    String modeString = 'system';
    if (mode == ThemeMode.light) modeString = 'light';
    if (mode == ThemeMode.dark) modeString = 'dark';
    
    await prefs.setString('themeMode', modeString);
  }
}