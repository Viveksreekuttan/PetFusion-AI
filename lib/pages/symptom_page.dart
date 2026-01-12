import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ⭐️ Added for formatting
import '../services/pet_model.dart';
import '../services/gemini_service.dart';

class SymptomPage extends StatefulWidget {
  const SymptomPage({super.key});

  @override
  State<SymptomPage> createState() => _SymptomPageState();
}

class _SymptomPageState extends State<SymptomPage> {
  final Color primaryColor = const Color(0xFF4A90E2);
  final notesController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Pet? selectedPet;
  String? selectedDuration;
  double severity = 3.0;
  bool _isAnalyzing = false;
  List<Pet> userPets = [];
  bool _isLoadingPets = true;

  final Map<String, List<String>> symptomCategories = {
    'Behavioral Changes': ['Lethargy', 'Restlessness', 'Aggression', 'Hiding'],
    'Physical Symptoms': ['Vomiting', 'Diarrhea', 'Limping', 'Coughing', 'Sneezing', 'Skin Rash', 'Loss of Balance'],
    'Appetite/Digestion': ['Loss of Appetite', 'Increased Thirst', 'Difficulty Swallowing', 'Bloating'],
    'Respiratory': ['Difficulty Breathing', 'Nasal Discharge', 'Wheezing'],
  };

  final List<String> durationOptions = [
    'Less than 24 hours',
    '1-3 days',
    '4-7 days',
    '1-2 weeks',
    'More than 2 weeks'
  ];
  
  final Map<String, bool> selectedSymptoms = {};

  @override
  void initState() {
    super.initState();
    symptomCategories.values.expand((s) => s).forEach((symptom) {
      selectedSymptoms[symptom] = false;
    });
    _loadUserPets();
  }

  Future<void> _loadUserPets() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingPets = false);
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .get();

      setState(() {
        userPets = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Pet.fromMap(data);
        }).toList();

        if (userPets.isNotEmpty) {
          selectedPet = userPets.first;
        }
        _isLoadingPets = false;
      });
    } catch (e) {
      setState(() => _isLoadingPets = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pets: $e'))
        );
      }
    }
  }

  Future<void> _analyzeSymptoms() async {
    if (selectedPet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pet'))
      );
      return;
    }

    List<String> activeSymptoms = selectedSymptoms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (activeSymptoms.isEmpty && notesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select symptoms or add notes'))
      );
      return;
    }

    setState(() => _isAnalyzing = true);

    String prompt = """
    I need a veterinary assessment for my pet.
    PET DETAILS:
    - Name: ${selectedPet!.name}
    - Species: ${selectedPet!.species}
    - Breed: ${selectedPet!.breed}
    - Age: ${selectedPet!.age}
    
    SYMPTOMS: ${activeSymptoms.join(', ')}
    DURATION: ${selectedDuration ?? 'Not specified'}
    SEVERITY: ${severity.round()}/5
    NOTES: ${notesController.text}
    
    Provide a comprehensive veterinary assessment including:
    1. Possible diagnosis
    2. Recommended care steps
    3. Emergency status (Emergency/Urgent/Routine)
    4. When to see a vet
    """;

    try {
      String response = await GeminiService.getChatResponse(
        systemPrompt: "You are VetFusionAI, a veterinary diagnostic expert. Provide clear, professional medical assessments.",
        history: [], 
        message: prompt, 
      );

      if (!mounted) return;

      // Save to Firestore
      await _saveAnalysisToFirestore(activeSymptoms, response);

      _showResultDialog(response);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
        );
      }
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _saveAnalysisToFirestore(List<String> symptoms, String analysis) async {
    final user = _auth.currentUser;
    if (user == null || selectedPet == null) return;

    try {
      final recordData = {
        'petId': selectedPet!.id,
        'petName': selectedPet!.name,
        'symptoms': symptoms,
        'duration': selectedDuration ?? 'Not specified',
        'severity': severity.round(),
        'notes': notesController.text,
        'analysis': analysis,
        'date': FieldValue.serverTimestamp(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Save to medical_records subcollection under the pet
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(selectedPet!.id)
          .collection('medical_records')
          .add(recordData);

      // Also save to a general symptom_analyses collection for easy querying
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('symptom_analyses')
          .add(recordData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis saved successfully'),
            backgroundColor: Colors.green,
          )
        );
      }
    } catch (e) {
      print("Error saving to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save analysis: $e'))
        );
      }
    }
  }

  // ⭐️ UPDATED DIALOG: Uses MarkdownBody to parse asterisks
  void _showResultDialog(String result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.health_and_safety, color: primaryColor),
            const SizedBox(width: 10),
            const Text("AI Assessment")
          ]
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            // ⭐️ FIX: Using MarkdownBody to render asterisks as formatting
            child: MarkdownBody(
              data: result,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, height: 1.5),
                h1: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                h2: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                listBullet: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetForm();
            },
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _resetForm() {
    setState(() {
      selectedSymptoms.updateAll((key, value) => false);
      notesController.clear();
      selectedDuration = null;
      severity = 3.0;
    });
  }

  Icon _getCategoryIcon(String category) {
    IconData iconData;
    switch (category) {
      case 'Behavioral Changes':
        iconData = Icons.psychology_outlined;
        break;
      case 'Physical Symptoms':
        iconData = Icons.sentiment_very_dissatisfied_outlined;
        break;
      case 'Appetite/Digestion':
        iconData = Icons.restaurant_menu_outlined;
        break;
      case 'Respiratory':
        iconData = Icons.air_outlined;
        break;
      default:
        iconData = Icons.help_outline;
    }
    return Icon(iconData, color: primaryColor);
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: primaryColor,
        ),
      ),
    );
  }

  Widget _buildSymptomChecklist(bool isDarkMode) {
    return Column(
      children: symptomCategories.entries.map((entry) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: isDarkMode ? Colors.grey[800] : Colors.white,
          child: ExpansionTile(
            title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
            leading: _getCategoryIcon(entry.key),
            children: entry.value.map((symptom) {
              return CheckboxListTile(
                title: Text(symptom),
                value: selectedSymptoms[symptom],
                activeColor: primaryColor,
                onChanged: (val) => setState(() => selectedSymptoms[symptom] = val!),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter Symptoms'), elevation: 1),
      body: _isLoadingPets
          ? const Center(child: CircularProgressIndicator())
          : userPets.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text(
                        'No pets found',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('Please add a pet first to analyze symptoms'),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Go Back'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Select Pet'),
                      DropdownButtonFormField<Pet>(
                        value: selectedPet,
                        isExpanded: true,
                        items: userPets.map((pet) => DropdownMenuItem(
                          value: pet,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: primaryColor.withOpacity(0.1),
                                backgroundImage: (pet.photoUrl.isNotEmpty && pet.photoUrl.startsWith('http'))
                                    ? NetworkImage(pet.photoUrl)
                                    : null,
                                child: (pet.photoUrl.isEmpty || !pet.photoUrl.startsWith('http'))
                                    ? Icon(pet.icon, size: 18, color: primaryColor)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  '${pet.name} (${pet.species})',
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                        onChanged: (val) => setState(() => selectedPet = val),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.pets, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Select Symptoms'),
                      _buildSymptomChecklist(isDarkMode),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Duration'),
                      DropdownButtonFormField<String>(
                        value: selectedDuration,
                        isExpanded: true,
                        hint: const Text('How long has this been occurring?'),
                        items: durationOptions.map((duration) => DropdownMenuItem(
                          value: duration,
                          child: Text(
                            duration,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        )).toList(),
                        onChanged: (val) => setState(() => selectedDuration = val),
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.schedule, color: primaryColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Severity Level: ${severity.round()}/5'),
                      Slider(
                        value: severity,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: primaryColor,
                        label: severity.round().toString(),
                        onChanged: (val) => setState(() => severity = val),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mild', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          Text('Severe', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader('Additional Notes'),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'Describe any additional observations or concerns...',
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 32),

                      Center(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isAnalyzing ? null : _analyzeSymptoms,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isAnalyzing 
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Analyze Symptoms',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }
}