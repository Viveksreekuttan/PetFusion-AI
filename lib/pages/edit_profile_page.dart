import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  File? _imageFile;
  bool _isLoading = false;
  String? _currentPhotoUrl;
  final Color primaryColor = const Color(0xFF4A90E2);

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _currentPhotoUrl = user?.photoURL;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- 1. Pick Image ---
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  // --- 2. Save Profile Logic ---
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String newName = _nameController.text.trim();
      String? newPhotoUrl = _currentPhotoUrl;

      // A. If image is changed, Upload to Storage
      if (_imageFile != null) {
        // Path: profile_images/{uid}.jpg
        final ref = _storage.ref().child('profile_images/${user.uid}.jpg');
        await ref.putFile(_imageFile!);
        newPhotoUrl = await ref.getDownloadURL();
      }

      // B. Update Firebase Authentication (The Core User)
      if (newName != user.displayName) {
        await user.updateDisplayName(newName);
      }
      if (newPhotoUrl != user.photoURL && newPhotoUrl != null) {
        await user.updatePhotoURL(newPhotoUrl);
      }
      
      // Reload user to ensure local state matches cloud
      await user.reload(); 

      // C. Update Firestore Database (The User Document)
      // This updates the 'name' field inside users/ckhdaz... 
      // It DOES NOT change the document ID 'ckhdaz...', which is correct.
      await _firestore.collection('users').doc(user.uid).set({
        'name': newName,
        'email': user.email,
        'photoUrl': newPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // Merge prevents overwriting other fields

      // D. Batch update Owner Name in Pets collection
      // Since you store 'ownerName' in pets, update all pet documents if the name changed.
      if (newName != user.displayName) {
         await _updateOwnerNameInPets(user.uid, newName);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
        );
        // Return the local image path so ProfilePage updates instantly
        Navigator.pop(context, _imageFile?.path); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Helper: Update ownerName in all Pet documents ---
  Future<void> _updateOwnerNameInPets(String uid, String newName) async {
    final petsQuery = await _firestore
        .collection('users')
        .doc(uid)
        .collection('pets')
        .get();

    final batch = _firestore.batch();

    for (var doc in petsQuery.docs) {
      batch.update(doc.reference, {'ownerName': newName});
    }

    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final inputBorderColor = isDarkMode ? Colors.grey[700]! : Colors.grey[300]!;
    final disabledFillColor = isDarkMode ? Colors.grey[900] : Colors.grey[100];
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Picker
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (_currentPhotoUrl != null
                              ? NetworkImage(_currentPhotoUrl!) as ImageProvider
                              : const AssetImage('assets/profile.png') as ImageProvider),
                      child: (_imageFile == null && _currentPhotoUrl == null)
                          ? Icon(Icons.person, size: 60, color: isDarkMode ? Colors.grey : Colors.grey[400])
                          : null,
                    ),
                    Material(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _pickImage,
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Name Field
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline, color: primaryColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: primaryColor, width: 2),
                  ),
                ),
                validator: (val) => val != null && val.isNotEmpty ? null : 'Name cannot be empty',
              ),
              const SizedBox(height: 16),

              // Email Field (Read-only)
              TextFormField(
                initialValue: user?.email ?? 'No email',
                enabled: false,
                style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
                decoration: InputDecoration(
                  labelText: 'Email (Cannot be changed)',
                  prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.grey[800]! : Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: disabledFillColor,
                ),
              ),
              const SizedBox(height: 40),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_outlined, color: Colors.white),
                  label: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}