import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../services/pet_model.dart';

class FusionPage extends StatefulWidget {
  final Pet pet; 
  const FusionPage({super.key, required this.pet});

  @override
  State<FusionPage> createState() => _FusionPageState();
}

class _FusionPageState extends State<FusionPage> {
  File? _xrayFile;
  String? _symptomsText;
  File? _gaitVideo;
  File? _audioFile;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickXRay() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _xrayFile = File(file.path));
  }

  void _enterSymptoms() {
    final textController = TextEditingController(text: _symptomsText);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Clinical Symptoms"),
        content: TextField(
          controller: textController,
          maxLines: 5,
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: "E.g., Limping on left leg, loss of appetite...",
            hintStyle: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              setState(() => _symptomsText = textController.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          )
        ],
      ),
    );
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null) setState(() => _gaitVideo = File(file.path));
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        setState(() => _audioFile = File(result.files.single.path!));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected: ${result.files.single.name}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  bool get _isReady => _xrayFile != null && (_symptomsText?.isNotEmpty ?? false) && _gaitVideo != null && _audioFile != null;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(title: Text('Fusion: ${widget.pet.name}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Required Data Inputs", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 5),
            Text("Please insert all 4 data types to enable Fusion Analysis.", style: TextStyle(color: subTextColor)),
            const SizedBox(height: 20),

            _buildInputTile(context, title: "1. X-Ray Image", subtitle: _xrayFile != null ? "Image Selected" : "Tap to upload X-Ray", icon: Icons.image, isCompleted: _xrayFile != null, onTap: _pickXRay),
            _buildInputTile(context, title: "2. Clinical Symptoms", subtitle: _symptomsText != null ? "Symptoms Recorded" : "Tap to enter details", icon: Icons.edit_note, isCompleted: _symptomsText != null && _symptomsText!.isNotEmpty, onTap: _enterSymptoms),
            _buildInputTile(context, title: "3. Gait Video", subtitle: _gaitVideo != null ? "Video Selected" : "Tap to upload Video", icon: Icons.videocam, isCompleted: _gaitVideo != null, onTap: _pickVideo),
            _buildInputTile(context, title: "4. Audio Scan", subtitle: _audioFile != null ? _audioFile!.path.split('/').last : "Tap to upload Audio", icon: Icons.mic, isCompleted: _audioFile != null, onTap: _pickAudio),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isReady ? () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Processing Fusion Analysis... (Feature coming)"), backgroundColor: Colors.deepPurple));
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  disabledForegroundColor: Colors.grey[500],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_isReady) const Icon(Icons.lock, size: 18),
                    if (!_isReady) const SizedBox(width: 8),
                    Text(_isReady ? "RUN FUSION ANALYSIS" : "INSERT ALL DATA TO UNLOCK", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputTile(BuildContext context, {required String title, required String subtitle, required IconData icon, required bool isCompleted, required VoidCallback onTap}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    
    return Card(
      elevation: 2,
      color: cardColor,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: isCompleted ? const BorderSide(color: Colors.green, width: 1.5) : BorderSide.none),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted ? Colors.green.withOpacity(0.1) : (isDarkMode ? Colors.grey[800] : Colors.grey[200]),
          child: Icon(icon, color: isCompleted ? Colors.green : (isDarkMode ? Colors.grey[400] : Colors.grey[600])),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isCompleted ? Colors.green : textColor)),
        subtitle: Text(subtitle, style: TextStyle(color: subTextColor), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: isCompleted ? const Icon(Icons.check_circle, color: Colors.green) : Icon(Icons.arrow_forward_ios, size: 16, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}