import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/pet_model.dart';
import '../services/gemini_service.dart';

class AudioPage extends StatefulWidget {
  final Pet pet; 
  const AudioPage({super.key, required this.pet});

  @override
  State<AudioPage> createState() => _AudioPageState();
}

class _AudioPageState extends State<AudioPage> {
  File? _selectedAudio;
  final Color primaryColor = const Color(0xFF9013FE);
  
  bool _isRecording = false;
  bool _isAnalyzing = false;
  String? _analysisResult;
  late final AudioRecorder _audioRecorder;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    try {
      if (_isRecording) {
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _selectedAudio = File(path);
            _isRecording = false;
            _analysisResult = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Recording Saved!"))
          );
        }
      } else {
        if (await _audioRecorder.hasPermission()) {
          final dir = await getApplicationDocumentsDirectory();
          final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
          await _audioRecorder.start(const RecordConfig(), path: path);
          setState(() => _isRecording = true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission denied"))
          );
        }
      }
    } catch (e) {
      print("Recording Error: $e");
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Recording error: $e"))
      );
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedAudio = File(result.files.single.path!);
          _analysisResult = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Selected: ${result.files.single.name}"))
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"))
      );
    }
  }

  Future<void> _analyzeAudio() async {
    if (_selectedAudio == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
    });

    try {
      final prompt = """
You are a veterinary diagnostician analyzing respiratory sounds for ${widget.pet.name}, a ${widget.pet.species}.

Analyze the audio recording for respiratory conditions and provide:

1. **Sound Characteristics**: Describe the breathing sounds detected (e.g., wheezing, crackling, stridor, normal breathing)

2. **Possible Conditions**: List potential respiratory conditions based on the sounds:
   - Upper respiratory infections
   - Asthma or bronchitis
   - Pneumonia
   - Heart-related respiratory issues
   - Foreign body obstruction
   - Tracheal collapse
   - Allergic reactions

3. **Severity Assessment**: Rate the severity (Mild/Moderate/Severe)

4. **Recommendations**: 
   - Urgency of veterinary care needed
   - Home monitoring suggestions
   - Warning signs to watch for

5. **Additional Notes**: Any other observations about breathing pattern, rate, or quality

Format your response clearly with these sections. Be thorough but concise.
""";

      print("🎵 Starting audio analysis for ${widget.pet.name}...");
      
      final result = await GeminiService.analyzeAudio(
        audioFile: _selectedAudio!,
        prompt: prompt,
        petName: widget.pet.name,
      );

      setState(() {
        _analysisResult = result;
        _isAnalyzing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Analysis complete!"),
          backgroundColor: Colors.green,
        )
      );

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisResult = "Analysis failed: ${e.toString()}";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Analysis error: $e"),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  // Helper function to parse and render markdown-like text
  List<TextSpan> _parseMarkdownText(String text, Color textColor) {
    final List<TextSpan> spans = [];
    final RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    
    int lastIndex = 0;
    for (final match in boldPattern.allMatches(text)) {
      // Add text before bold
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: textColor),
        ));
      }
      
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ));
      
      lastIndex = match.end;
    }
    
    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: textColor),
      ));
    }
    
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final containerColor = isDarkMode ? Colors.grey[850]! : Colors.grey[200]!;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Respiratory Audio: ${widget.pet.name}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Audio Preview Container
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!
                ),
              ),
              child: _selectedAudio == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRecording ? Icons.fiber_manual_record : Icons.mic, 
                          size: 60, 
                          color: _isRecording ? Colors.red : hintColor
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isRecording 
                            ? "Recording... Tap Stop to Finish" 
                            : "Record or Upload Respiratory Audio",
                          style: TextStyle(
                            color: _isRecording ? Colors.red : hintColor,
                            fontWeight: _isRecording 
                              ? FontWeight.bold 
                              : FontWeight.normal
                          )
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.graphic_eq, size: 60, color: primaryColor),
                        const SizedBox(height: 10),
                        Text(
                          "Audio File Ready", 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: textColor
                          )
                        ),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _selectedAudio!.path.split('/').last,
                            style: TextStyle(fontSize: 12, color: hintColor),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // Record and Upload Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _toggleRecording, 
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(_isRecording ? "Stop" : "Record"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? Colors.red : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _pickAudio, 
                    icon: const Icon(Icons.upload_file),
                    label: const Text("Upload"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDarkMode 
                        ? Colors.grey[800] 
                        : Colors.white,
                      foregroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      disabledBackgroundColor: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Analyze Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_selectedAudio == null || _isAnalyzing) 
                  ? null 
                  : _analyzeAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black87,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)
                  ),
                  disabledBackgroundColor: Colors.grey,
                ),
                child: _isAnalyzing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          "ANALYZING SOUND...",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    )
                  : const Text(
                      "ANALYZE SOUND",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold
                      )
                    ),
              ),
            ),

            // Analysis Result Section
            if (_analysisResult != null) ...[
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.health_and_safety,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Diagnosis Result",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                    const SizedBox(height: 16),
                    // ⭐ FIXED: Use RichText with TextSpan to render markdown
                    SelectableText.rich(
                      TextSpan(
                        children: _parseMarkdownText(_analysisResult!, textColor),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3)
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "This is an AI-assisted analysis. Please consult a veterinarian for professional diagnosis.",
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode 
                                  ? Colors.orange[200] 
                                  : Colors.orange[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}