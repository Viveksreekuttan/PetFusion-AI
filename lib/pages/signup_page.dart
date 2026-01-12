import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_page.dart';
import 'login_page.dart'; // Import LoginPage for back navigation if needed

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;
  // Define the primary color for consistency
  final Color primaryColor = const Color(0xFF4A90E2);

  Future<void> signupUser() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      // Check mounted before showing SnackBar
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    // Check mounted before setState
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Optionally set display name immediately
      await userCredential.user?.updateDisplayName(nameController.text.trim());

      // Save user info to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(), // Use server timestamp
        // Add other fields if needed, e.g., 'role': 'user'
      });

      // Check if mounted after awaits before showing SnackBar and navigating
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signup successful! Welcome."),
          backgroundColor: Colors.green, // Success feedback
          ),
      );

      Navigator.pushAndRemoveUntil( // Go to HomePage, remove login/signup screens
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
         (route) => false, // Remove all previous routes
      );

    } on FirebaseAuthException catch (e) {
      // Check if mounted after await in catch block
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Signup failed"),
          backgroundColor: Colors.redAccent, // Make error stand out
        ),
      );
    } finally {
       // Ensure loading state is turned off
       if (mounted) {
          setState(() => isLoading = false);
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Set background to white
      backgroundColor: Colors.white,
      appBar: AppBar(
        // Themed AppBar
        title: const Text("Create Account", style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0, // No shadow
        iconTheme: const IconThemeData(color: Colors.black87), // Back button color
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // App Logo Placeholder 
                  Icon(
                    Icons.pets, // Different placeholder icon for variety
                    size: 60,
                    color: primaryColor,
                  ),
                  const SizedBox(height: 16),
                  // App Title
                  Text(
                    "Join VetFusionAI",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                   const SizedBox(height: 32),

                  // Name Field
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                       prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                      border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                      ),
                       focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  TextField(
                    controller: emailController,
                     keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                       prefixIcon: Icon(Icons.email_outlined, color: primaryColor),
                      border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                      ),
                       focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                       prefixIcon: Icon(Icons.lock_outline, color: primaryColor),
                      border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(12),
                      ),
                       focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: primaryColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Loading or Signup Button
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: signupUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Sign Up",
                            style: TextStyle(fontSize: 16, color: Colors.white),
                            ),
                        ),
                   const SizedBox(height: 16),
                   // Optional: Link to Login Page
                   TextButton(
                    onPressed: () {
                      // Navigate back to login or push replacement if preferred
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                      }
                    },
                    child: Text(
                      "Already have an account? Login",
                       style: TextStyle(color: primaryColor),
                      ),
                   )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

   @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}