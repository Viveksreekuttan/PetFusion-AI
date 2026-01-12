import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/pet_model.dart';

// ⭐️ IMPORT YOUR PAGES HERE
import 'symptom_page.dart'; // ✅ Added this import
import 'xray_page.dart';
import 'gait_page.dart';
import 'audio_page.dart';
import 'fusion_page.dart';

class DiagnosePage extends StatefulWidget {
  final Pet? selectedPet;

  const DiagnosePage({super.key, this.selectedPet});

  @override
  State<DiagnosePage> createState() => _DiagnosePageState();
}

class _DiagnosePageState extends State<DiagnosePage> {
  Pet? _currentPet;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.selectedPet;
  }

  // Helper to change selected pet
  void _changePet() {
    setState(() {
      _currentPet = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDarkMode ? Colors.grey[850]! : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPet == null ? 'Select Pet' : 'Diagnose ${_currentPet!.name}'),
        actions: _currentPet != null 
          ? [
              IconButton(
                icon: const Icon(Icons.swap_horiz),
                tooltip: 'Change Pet',
                onPressed: _changePet,
              ),
              const SizedBox(width: 8),
            ]
          : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PET SELECTOR SECTION ---
            if (_currentPet == null) ...[
              Text(
                "Which pet needs a checkup?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('users').doc(_auth.currentUser?.uid).collection('pets').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  
                  final pets = snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id; // Ensure ID is mapped
                    return Pet.fromMap(data);
                  }).toList();

                  if (pets.isEmpty) {
                    return Center(child: Text("No pets found. Please add a pet profile first.", style: TextStyle(color: subTextColor)));
                  }

                  return DropdownButtonFormField<Pet>(
                    dropdownColor: isDarkMode ? Colors.grey[800] : Colors.white,
                    style: TextStyle(color: textColor, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "Select Pet",
                      labelStyle: TextStyle(color: subTextColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[400]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    value: _currentPet,
                    items: pets.map((pet) {
                      return DropdownMenuItem(
                        value: pet,
                        child: Text(pet.name, style: TextStyle(color: textColor)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _currentPet = val;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 20),
              Divider(color: isDarkMode ? Colors.grey[700] : Colors.grey[300]),
              const SizedBox(height: 20),
            ],

            // --- DIAGNOSIS OPTIONS SECTION ---
            Text(
              'Select Diagnosis Method',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Warning if no pet selected
            if (_currentPet == null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1), 
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3))
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text("Please select a pet above to proceed.", style: TextStyle(color: isDarkMode ? Colors.orange[200] : Colors.orange[900]))),
                  ],
                ),
              ),
            
            const SizedBox(height: 16),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                // 1. X-Ray
                _buildDiagnosisCard(
                  context, 'X-Ray Analysis', Icons.camera_alt, const Color(0xFF4A90E2),
                  cardColor, textColor,
                  () => _navigateTo(context, (pet) => XRayPage(pet: pet)),
                ),
                
                // 2. Text / Symptoms (⭐️ UPDATED CONNECTION)
                _buildDiagnosisCard(
                  context, 'Text / Symptoms', Icons.edit_note, const Color(0xFF7ED321),
                  cardColor, textColor,
                  () {
                    if (_currentPet != null) {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (context) => const SymptomPage()), // ✅ Direct Navigation
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a pet first."), backgroundColor: Colors.red));
                    }
                  }, 
                ),

                // 3. Gait Analysis
                _buildDiagnosisCard(
                  context, 'Gait Analysis', Icons.videocam, const Color(0xFFF5A623),
                  cardColor, textColor,
                  () => _navigateTo(context, (pet) => GaitPage(pet: pet)),
                ),

                // 4. Audio Scan
                _buildDiagnosisCard(
                  context, 'Audio Scan', Icons.mic, const Color(0xFF9013FE),
                  cardColor, textColor,
                  () => _navigateTo(context, (pet) => AudioPage(pet: pet)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // 5. Fusion Card
            _buildFusionCard(
              context, 'Multimodal Fusion', 'Combine Multiple Inputs', Icons.mediation, Colors.deepPurple,
              cardColor, textColor,
              () => _navigateTo(context, (pet) => FusionPage(pet: pet)),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget Function(Pet) pageBuilder) {
    if (_currentPet != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => pageBuilder(_currentPet!)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a pet first."), backgroundColor: Colors.red));
    }
  }

  Widget _buildDiagnosisCard(BuildContext context, String title, IconData icon, Color iconColor, Color cardColor, Color textColor, VoidCallback onTap) {
    final bool isEnabled = _currentPet != null;
    final effectiveCardColor = isEnabled ? cardColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200]);
    final effectiveTextColor = isEnabled ? textColor : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        color: effectiveCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: isEnabled ? iconColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              child: Icon(icon, color: isEnabled ? iconColor : Colors.grey, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: effectiveTextColor)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFusionCard(BuildContext context, String title, String subtitle, IconData icon, Color iconColor, Color cardColor, Color textColor, VoidCallback onTap) {
    final bool isEnabled = _currentPet != null;
    final effectiveCardColor = isEnabled ? cardColor : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200]);
    final effectiveTextColor = isEnabled ? textColor : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        color: effectiveCardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isEnabled ? iconColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                child: Icon(icon, color: isEnabled ? iconColor : Colors.grey, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: effectiveTextColor)),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: isEnabled ? Colors.grey[600] : Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}