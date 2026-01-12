import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart'; 
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vetfusion_ai/services/pet_model.dart';
import 'package:vetfusion_ai/services/gemini_service.dart';

class AddPetPage extends StatefulWidget {
  final Pet? existingPet;

  const AddPetPage({super.key, this.existingPet});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _formKey = GlobalKey<FormState>();
  final Color primaryColor = const Color(0xFF4A90E2);

  // Firebase Instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  // Controllers
  late TextEditingController nameController;
  late TextEditingController speciesController;
  late TextEditingController breedController;
  late TextEditingController ageController;
  late TextEditingController weightController;
  late TextEditingController colorController;
  late TextEditingController ownerNameController;

  String? selectedGender;
  bool _isSaving = false;
  bool _isScanning = false;
  File? _petImage; // Local file for preview

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.existingPet?.name ?? '');
    speciesController = TextEditingController(text: widget.existingPet?.species ?? '');
    breedController = TextEditingController(text: widget.existingPet?.breed ?? '');
    ageController = TextEditingController(text: widget.existingPet?.age ?? '');
    weightController = TextEditingController(text: widget.existingPet?.weight ?? '');
    colorController = TextEditingController(text: widget.existingPet?.color ?? '');

    final user = _auth.currentUser;
    ownerNameController = TextEditingController(text: user?.displayName ?? "Unknown Owner");

    if (widget.existingPet != null) {
      selectedGender = widget.existingPet!.gender;
    } else {
      // Show dialog only for new pets
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _showEntryMethodDialog();
      });
    }

    // Listener: Update UI icon when Species text changes
    speciesController.addListener(() {
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    speciesController.dispose();
    breedController.dispose();
    ageController.dispose();
    weightController.dispose();
    colorController.dispose();
    ownerNameController.dispose();
    super.dispose();
  }

  // --- 1. ICON HELPER ---
  IconData _getSpeciesIcon(String speciesInput) {
    final s = speciesInput.toLowerCase().trim();
    if (s.contains('cat') || s.contains('kitten')) return Icons.cruelty_free; 
    if (s.contains('dog') || s.contains('puppy')) return Icons.pets; 
    if (s.contains('cow') || s.contains('cattle')) return Icons.grass;
    if (s.contains('bird') || s.contains('parrot')) return Icons.flutter_dash;
    if (s.contains('fish')) return Icons.water;
    return Icons.pets; 
  }

  // --- 2. SELECTION DIALOGS ---

  void _showEntryMethodDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How would you like to add?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.edit_note,
                    title: "Manual Entry",
                    color: Colors.orange,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.qr_code_scanner,
                    title: "AI Scanner",
                    color: primaryColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showImageSourceSelection(isScanning: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _showImageSourceSelection({bool isScanning = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isScanning ? "Scan Photo From..." : "Select Profile Photo", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.camera_alt,
                    title: "Camera",
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera, isScanning);
                    },
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildOptionCard(
                    icon: Icons.photo_library,
                    title: "Gallery",
                    color: Colors.teal,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery, isScanning);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            CircleAvatar(backgroundColor: color, radius: 25, child: Icon(icon, color: Colors.white, size: 28)),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // --- 3. IMAGE PICKER & AI LOGIC ---

  Future<void> _pickImage(ImageSource source, bool isScanning) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      setState(() {
        _petImage = File(image.path);
      });

      if (isScanning) {
        _scanImageWithGemini();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error picking image: $e")));
    }
  }

  Future<void> _scanImageWithGemini() async {
    if (_petImage == null) return;

    setState(() => _isScanning = true);

    try {
      String prompt = """
      Analyze this pet image. Return a raw JSON object (NO markdown, NO backticks) with these keys:
      {
        "species": "Dog/Cat/Bird/etc",
        "breed": "Best guess",
        "color": "Dominant colors",
        "gender": "Unknown", 
        "age": "Estimated age in years (e.g. '2') if visible, else Unknown"
      }
      If you can't guess gender/age, use 'Unknown'.
      """;

      String response = await GeminiService.analyzeImage(
        imageFile: _petImage!,
        prompt: prompt,
      );

      _parseAiResponse(response);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Scan Error: $e")));
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _parseAiResponse(String response) {
    try {
      String cleanJson = response.replaceAll('```json', '').replaceAll('```', '').trim();
      Map<String, dynamic> data = jsonDecode(cleanJson);

      setState(() {
        speciesController.text = data['species'] ?? '';
        breedController.text = data['breed'] ?? '';
        colorController.text = data['color'] ?? '';
        ageController.text = data['age'] != "Unknown" ? "${data['age']} years" : "";
        
        String aiGender = (data['gender'] ?? 'Unknown').toString().toLowerCase();
        if (aiGender.contains('male')) selectedGender = 'Male';
        else if (aiGender.contains('female')) selectedGender = 'Female';
        else selectedGender = 'Unknown';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Details scanned! Please enter Name & Weight manually."), backgroundColor: Colors.green),
      );
    } catch (e) {
      print("JSON Parse Error: $response");
    }
  }

  // --- 4. UPLOAD & SAVE LOGIC ---

  Future<String> _uploadImage(String petId) async {
    if (_petImage == null) return ""; 

    try {
      final user = _auth.currentUser;
      if (user == null) return "";

      // Path: pet_images / {userId} / {petId}.jpg
      final ref = _storage.ref().child('pet_images/${user.uid}/$petId.jpg');
      await ref.putFile(_petImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Upload Error: $e");
      return ""; 
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill required fields"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final petId = widget.existingPet?.id ?? DateTime.now().millisecondsSinceEpoch.toString();

      // 1. Handle Image URL
      String photoUrl = widget.existingPet?.photoUrl ?? ""; 
      
      if (_petImage != null) {
        String uploadedUrl = await _uploadImage(petId);
        if (uploadedUrl.isNotEmpty) {
          photoUrl = uploadedUrl;
        }
      }

      // 2. Determine Icon
      IconData iconData = _getSpeciesIcon(speciesController.text);

      final newPet = Pet(
        id: petId,
        name: nameController.text.trim(),
        species: speciesController.text.trim(),
        breed: breedController.text.trim(),
        age: ageController.text.trim(),
        gender: selectedGender ?? 'Unknown',
        weight: weightController.text.trim(),
        color: colorController.text.trim(),
        ownerName: ownerNameController.text.trim(),
        registrationDate: widget.existingPet?.registrationDate ?? DateTime.now(),
        photoUrl: photoUrl,
        icon: iconData,
      );

      // 3. Save to Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(petId)
          .set(newPet.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pet saved successfully!"), backgroundColor: Colors.green));
        Navigator.pop(context, newPet);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ⭐️ 5. DELETE PET & CLEANUP STORAGE LOGIC ---
  Future<void> _deletePet() async {
    if (widget.existingPet == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Pet?"),
        content: Text("Permanently remove ${widget.existingPet!.name} and ALL associated records?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true); // Use saving indicator for deleting too
      try {
        final user = _auth.currentUser;
        if (user != null) {
          final petId = widget.existingPet!.id;

          // A. Delete Database Record
          await _firestore.collection('users').doc(user.uid).collection('pets').doc(petId).delete();

          // B. Delete Profile Image from Storage
          try {
            await _storage.ref().child('pet_images/${user.uid}/$petId.jpg').delete();
          } catch (e) {
            // Ignore if file doesn't exist
            print("Profile image cleanup error (ignored): $e");
          }

          // C. Delete Diagnosis Images Folder contents
          // Note: Firebase Storage doesn't delete folders, we must list files and delete them.
          try {
            final diagList = await _storage.ref().child('diagnosis_images/${user.uid}/$petId').listAll();
            for (var item in diagList.items) {
              await item.delete();
            }
          } catch (e) {
            print("Diagnosis images cleanup error: $e");
          }

          // D. Delete PDF Reports Folder contents
          try {
            final reportList = await _storage.ref().child('pet_reports/${user.uid}/$petId').listAll();
            for (var item in reportList.items) {
              await item.delete();
            }
          } catch (e) {
            print("Report documents cleanup error: $e");
          }

          if (mounted) {
            Navigator.pop(context); // Close Edit Page
            Navigator.pop(context); // Close Detail Page (Go back to List)
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error deleting: $e")));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Logic to determine Avatar Background
    ImageProvider? backgroundImage;
    if (_petImage != null) {
      backgroundImage = FileImage(_petImage!);
    } else if (widget.existingPet != null && widget.existingPet!.photoUrl.isNotEmpty && widget.existingPet!.photoUrl.startsWith('http')) {
      backgroundImage = NetworkImage(widget.existingPet!.photoUrl);
    }

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(widget.existingPet == null ? 'Add New Pet' : 'Edit Pet'),
            elevation: 1,
            actions: [
              if (widget.existingPet != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _isSaving ? null : _deletePet,
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Image
                  Center(
                    child: GestureDetector(
                      onTap: () => _showImageSourceSelection(isScanning: false),
                      child: CircleAvatar(
                        radius: 60,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        backgroundImage: backgroundImage,
                        child: backgroundImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_getSpeciesIcon(speciesController.text), size: 40, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(height: 4),
                                  Icon(Icons.camera_alt, size: 20, color: primaryColor),
                                ],
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(child: Text(backgroundImage != null ? "Change Photo" : "Tap to Add Photo", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey))),
                  const SizedBox(height: 20),

                  // Form Fields
                  _buildTextFormField(controller: nameController, label: 'Pet Name', icon: Icons.badge_outlined),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: speciesController, label: 'Species', icon: Icons.category_outlined),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: breedController, label: 'Breed', icon: Icons.pets),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: ageController, label: 'Age', icon: Icons.cake_outlined),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: selectedGender,
                    items: ['Male', 'Female', 'Unknown'].map((gender) {
                      return DropdownMenuItem<String>(value: gender, child: Text(gender));
                    }).toList(),
                    onChanged: (val) => setState(() => selectedGender = val),
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.wc_outlined, color: primaryColor),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2), borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (val) => val == null ? 'Please select gender' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildTextFormField(controller: weightController, label: 'Weight', icon: Icons.monitor_weight_outlined),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: colorController, label: 'Color', icon: Icons.color_lens_outlined),
                  const SizedBox(height: 16),
                  _buildTextFormField(controller: ownerNameController, label: 'Owner Name', icon: Icons.person_outline, enabled: false),

                  const SizedBox(height: 30),

                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitForm,
                    icon: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_alt_outlined, color: Colors.white),
                    label: Text(_isSaving ? "Saving..." : 'Save Pet', style: const TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (_isScanning)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text("AI is scanning pet...", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextFormField({required TextEditingController controller, required String label, required IconData icon, bool enabled = true}) {
    final theme = Theme.of(context);
    final disabledColor = theme.brightness == Brightness.dark ? theme.colorScheme.surfaceContainerHighest : Colors.grey[200];

    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2), borderRadius: BorderRadius.circular(12)),
        filled: !enabled,
        fillColor: !enabled ? disabledColor : null,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Please enter $label';
        return null;
      },
      textCapitalization: label == 'Pet Name' || label == 'Owner Name' ? TextCapitalization.words : TextCapitalization.sentences,
    );
  }
}