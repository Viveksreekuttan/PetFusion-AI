// lib/pages/splash_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vetfusion_ai/services/auth_wrapper.dart';
import 'package:vetfusion_ai/services/data_preloader.dart'; // ⭐️ NEW IMPORT

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Initialize Animation Controller (runs for 2 seconds)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // 2. Define Animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // 3. Start Animation
    _controller.forward();

    // ⭐️ NEW: Start preloading data in parallel with animation
    _preloadDataAndNavigate();
  }

  /// Preload data while animation plays, then navigate
  Future<void> _preloadDataAndNavigate() async {
    // Start preloading immediately (runs in background)
    final preloadFuture = DataPreloader().preloadDashboardData();
    
    // Wait for minimum splash duration (3.6 seconds for animation)
    final minDurationFuture = Future.delayed(const Duration(seconds: 3, milliseconds: 600));
    
    // Wait for BOTH to complete (whichever takes longer)
    await Future.wait([preloadFuture, minDurationFuture]);
    
    // Navigate to AuthWrapper
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ⭐️ GIF Animation Container
            ScaleTransition(
              scale: _scaleAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.deepPurple.withOpacity(0.05),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/animations/Animal care Loading.gif',
                      height: 180,
                      width: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            // ⭐️ App Title Text
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    "VetFusionAI",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Advanced Veterinary Diagnostics",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}