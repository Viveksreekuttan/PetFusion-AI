// lib/firebase_service.dart
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // 1. Generic File Upload Function (Storage)
  // Takes a local file -> Uploads to Firebase Storage -> Returns the public URL
  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      // Create a unique filename: users/{uid}/{folder}/{timestamp_filename}
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final destination = 'users/$userId/$folder/$fileName';
      
      final ref = _storage.ref(destination);
      UploadTask task = ref.putFile(file);
      
      // Wait for upload to complete
      TaskSnapshot snapshot = await task;
      
      // Get the download URL
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file to $folder: $e');
      throw Exception('Upload failed: $e');
    }
  }

  // 2. Save Multimodal Fusion Data (Firestore)
  Future<void> saveFusionDiagnosis({
    required File xrayFile,
    required File videoFile,
    required File audioFile,
    required String symptoms,
    required String aiResult,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    // A. Upload all files concurrently to save time
    final results = await Future.wait([
      _uploadFile(xrayFile, 'xrays'),
      _uploadFile(videoFile, 'videos'),
      _uploadFile(audioFile, 'audio'),
    ]);

    final String? xrayUrl = results[0];
    final String? videoUrl = results[1];
    final String? audioUrl = results[2];

    if (xrayUrl == null || videoUrl == null || audioUrl == null) {
      throw Exception("Failed to upload one or more media files.");
    }

    // B. Write the document to Firestore
    await _firestore.collection('diagnoses').add({
      'userId': user.uid,
      'userName': user.displayName ?? 'Unknown',
      'userEmail': user.email,
      'timestamp': FieldValue.serverTimestamp(),
      'type': 'fusion', 
      'status': 'completed',
      'symptoms': symptoms,
      'aiResult': aiResult,
      // URLs linking to the files in Storage
      'xrayUrl': xrayUrl,
      'videoUrl': videoUrl,
      'audioUrl': audioUrl,
    });
  }
}