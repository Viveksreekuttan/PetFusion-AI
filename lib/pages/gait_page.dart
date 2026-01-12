import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pet_model.dart';

class GaitPage extends StatefulWidget {
  final Pet pet; 
  const GaitPage({super.key, required this.pet});

  @override
  State<GaitPage> createState() => _GaitPageState();
}

class _GaitPageState extends State<GaitPage> {
  File? _selectedVideo;
  final ImagePicker _picker = ImagePicker();
  final Color primaryColor = const Color(0xFFF5A623);

  Future<void> _pickVideo(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickVideo(source: source, maxDuration: const Duration(seconds: 30));
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDarkMode ? Colors.grey[850]! : Colors.grey[200]!;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(title: Text('Gait Analysis: ${widget.pet.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
              ),
              child: _selectedVideo == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam, size: 60, color: hintColor),
                        const SizedBox(height: 10),
                        Text("Upload Video of Pet Walking", style: TextStyle(color: hintColor)),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 60, color: Colors.green),
                        const SizedBox(height: 10),
                        Text("Video Selected", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _selectedVideo!.path.split('/').last,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: hintColor),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickVideo(ImageSource.camera),
                    icon: const Icon(Icons.videocam),
                    label: const Text("Record"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _pickVideo(ImageSource.gallery),
                    icon: const Icon(Icons.video_library),
                    label: const Text("Select"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode ? Colors.grey[800] : Colors.white,
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedVideo == null ? null : () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Analyzing Gait... (Feature coming soon)')));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("ANALYZE GAIT", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}