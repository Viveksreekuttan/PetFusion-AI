import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/adoption_model.dart';
import 'package:printing/printing.dart';
import 'package:http/http.dart' as http;
import '../services/pet_model.dart';
import 'add_pet_page.dart';
import 'diagnose_page.dart';

// --- 1. MAIN PAGE (LIST OF PETS) ---
class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _deletePet(String petId, String petName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Pet?"),
        content: Text("Are you sure you want to remove $petName permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).collection('pets').doc(petId).delete();
        
        try {
           await _storage.ref().child('pet_images/${user.uid}/$petId.jpg').delete();
        } catch (e) {
           // Ignore if file not found
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$petName deleted")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (user == null) return const Scaffold(body: Center(child: Text("Please log in.")));

    return Scaffold(
      appBar: AppBar(title: const Text('My Pets'), elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').doc(user.uid).collection('pets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text("No pets added yet.", style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  const Text("Tap + to add your first pet!", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final pets = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; 
            return Pet.fromMap(data);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: pets.length,
            itemBuilder: (context, index) {
              final pet = pets[index];
              return _buildPetCard(pet, isDarkMode);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPetPage())),
        backgroundColor: const Color(0xFF4A90E2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPetCard(Pet pet, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PetDetailView(petId: pet.id)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Hero(
                tag: pet.id,
                child: CircleAvatar(
                  radius: 35,
                  backgroundColor: const Color(0xFF4A90E2).withOpacity(0.1),
                  backgroundImage: (pet.photoUrl.isNotEmpty && pet.photoUrl.startsWith('http'))
                      ? NetworkImage(pet.photoUrl)
                      : null,
                  child: (pet.photoUrl.isEmpty || !pet.photoUrl.startsWith('http'))
                      ? Icon(pet.icon, color: const Color(0xFF4A90E2), size: 30)
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pet.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${pet.species} • ${pet.breed}", style: TextStyle(color: isDarkMode ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                    const SizedBox(height: 4),
                    Text("${pet.age} • ${pet.gender}", style: TextStyle(color: isDarkMode ? Colors.grey[500] : Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _deletePet(pet.id, pet.name),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. DETAILED VIEW (⭐️ FIXED: Now uses StreamBuilder for real-time updates) ---
class PetDetailView extends StatelessWidget {
  final String petId; // ⭐️ Changed from Pet object to petId
  const PetDetailView({super.key, required this.petId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    // ⭐️ FIX: Stream pet data in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(petId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("Pet not found.")),
          );
        }

        // ⭐️ Convert document to Pet object
        final data = snapshot.data!.data() as Map<String, dynamic>;
        data['id'] = petId;
        final Pet pet = Pet.fromMap(data);

        return DefaultTabController(
          length: 6,
          child: Scaffold(
            appBar: AppBar(
              title: Text(pet.name),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddPetPage(existingPet: pet),
                      ),
                    );
                  },
                )
              ],
            ),
            body: Column(
              children: [
                _buildProfileHeader(context, pet),
                const TabBar(
                  isScrollable: true,
                  tabs: [
                    Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                    Tab(icon: Icon(Icons.medical_services), text: 'Medical'),
                    Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
                    Tab(icon: Icon(Icons.calendar_today), text: 'Reminders'),
                    Tab(icon: Icon(Icons.folder), text: 'Documents'),
                    Tab(icon: Icon(Icons.more_horiz), text: 'Other'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _OverviewTab(pet: pet),
                      _MedicalHistoryTab(pet: pet),
                      _HealthAnalyticsTab(pet: pet),
                      _RemindersTab(pet: pet),
                      _DocumentsTab(pet: pet),
                      _OtherTab(pet: pet),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DiagnosePage(selectedPet: pet)),
                );
              },
              label: const Text("New Diagnosis"),
              icon: const Icon(Icons.health_and_safety),
              backgroundColor: const Color(0xFF4A90E2),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(BuildContext context, Pet pet) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Hero(
            tag: pet.id,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColorLight,
              backgroundImage: (pet.photoUrl.isNotEmpty && pet.photoUrl.startsWith('http'))
                  ? NetworkImage(pet.photoUrl)
                  : null,
              child: (pet.photoUrl.isEmpty || !pet.photoUrl.startsWith('http'))
                  ? Icon(pet.icon, size: 40, color: Theme.of(context).primaryColor)
                  : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pet.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                Text('${pet.breed} | ${pet.age}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- TABS ---

class _OverviewTab extends StatelessWidget {
  final Pet pet;
  const _OverviewTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _infoCard('Basic Info', {
            'Gender': pet.gender,
            'Weight': pet.weight,
            'Color': pet.color,
            'Species': pet.species,
          }),
          _infoCard('Owner Details', {
            'Owner': pet.ownerName,
            'Registered On': DateFormat.yMMMd().format(pet.registrationDate),
          }),
        ],
      ),
    );
  }

  Widget _infoCard(String title, Map<String, String> data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 20),
            ...data.entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key, style: TextStyle(color: Colors.grey[700])),
                  Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _MedicalHistoryTab extends StatelessWidget {
  final Pet pet;
  const _MedicalHistoryTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(pet.id)
          .collection('medical_records')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyTab(message: "No medical history yet.", icon: Icons.medical_services_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.redAccent.withOpacity(0.1),
                  child: const Icon(Icons.local_hospital, color: Colors.redAccent),
                ),
                title: Text(data['diagnosis'] ?? 'Unknown Diagnosis', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Diagnosed on ${DateFormat.yMMMd().format(date)}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
              ),
            );
          },
        );
      },
    );
  }
}

class _HealthAnalyticsTab extends StatelessWidget {
  final Pet pet;
  const _HealthAnalyticsTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(pet.id)
          .collection('analytics')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyTab(message: "No AI analytics generated yet.", icon: Icons.analytics_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            return Card(
              child: ListTile(
                leading: const Icon(Icons.insights, color: Colors.purple),
                title: Text("Analysis: ${data['summary'] ?? 'N/A'}"),
                subtitle: Text("Confidence: ${data['confidence'] ?? '0'}%"),
              ),
            );
          },
        );
      },
    );
  }
}

class _RemindersTab extends StatelessWidget {
  final Pet pet;
  const _RemindersTab({required this.pet});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pets')
          .doc(pet.id)
          .collection('reminders')
          .orderBy('dueDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyTab(message: "No upcoming reminders.", icon: Icons.notifications_none);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
            final date = (data['dueDate'] as Timestamp).toDate();

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.alarm, color: Colors.white),
                ),
                title: Text(data['title'] ?? 'Medication', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Due: ${DateFormat.yMMMd().add_jm().format(date)}"),
                trailing: Switch(value: true, onChanged: (v) {}),
              ),
            );
          },
        );
      },
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final Pet pet;
  const _DocumentsTab({required this.pet});

  Future<void> _launchURL(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url.trim());
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!await launchUrl(uri)) {
           throw 'Could not launch URL';
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteDocument(BuildContext context, String docId, String? fileUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Document?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('pets').doc(pet.id).collection('documents').doc(docId).delete();
          if (fileUrl != null && fileUrl.isNotEmpty) {
            try { await FirebaseStorage.instance.refFromURL(fileUrl).delete(); } catch (_) {}
          }
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document deleted")));
        } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('pets').doc(pet.id).collection('documents').orderBy('uploadedAt', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const _EmptyTab(message: "No diagnosis documents.", icon: Icons.folder_open);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                leading: SizedBox(
                  width: 50,
                  height: 70,
                  child: _PdfThumbnail(url: data['fileUrl'] ?? ""),
                ),
                title: Text(
                  data['fileName'] ?? 'Report', 
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(data['type'] ?? 'Diagnosis Report', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.blue),
                      tooltip: "Download",
                      onPressed: () {
                        if (data['fileUrl'] != null) _launchURL(context, data['fileUrl']);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      tooltip: "Delete",
                      onPressed: () => _deleteDocument(context, docId, data['fileUrl']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PdfThumbnail extends StatefulWidget {
  final String url;
  const _PdfThumbnail({required this.url});

  @override
  State<_PdfThumbnail> createState() => _PdfThumbnailState();
}

class _PdfThumbnailState extends State<_PdfThumbnail> {
  Uint8List? _imageBytes;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
      return;
    }

    try {
      final response = await http.get(Uri.parse(widget.url));
      if (response.statusCode == 200) {
        await for (var page in Printing.raster(
          response.bodyBytes, 
          pages: [0],
          dpi: 72,
        )) {
          final png = await page.toPng();
          if (mounted) {
            setState(() {
              _imageBytes = png;
              _isLoading = false;
            });
          }
          break;
        }
      } else {
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
      }
    } catch (e) {
      print("Thumbnail Error: $e");
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200], 
          borderRadius: BorderRadius.circular(4)
        ),
        child: const Center(
          child: SizedBox(
            width: 15, 
            height: 15, 
            child: CircularProgressIndicator(strokeWidth: 2)
          )
        ),
      );
    }
    
    if (_hasError || _imageBytes == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.red[50], 
          borderRadius: BorderRadius.circular(4), 
          border: Border.all(color: Colors.red[100]!)
        ),
        child: const Center(
          child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 24)
        ),
      );
    }
    
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!), 
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
      ),
    );
  }
}

class _OtherTab extends StatefulWidget {
  final Pet pet;
  const _OtherTab({required this.pet});

  @override
  State<_OtherTab> createState() => _OtherTabState();
}

class _OtherTabState extends State<_OtherTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isListedForAdoption = false;
  String? _adoptionId;

  @override
  void initState() {
    super.initState();
    _checkAdoptionStatus();
  }

  Future<void> _checkAdoptionStatus() async {
    try {
      final querySnapshot = await _firestore
          .collection('adoptions')
          .where('petId', isEqualTo: widget.pet.id)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isListedForAdoption = querySnapshot.docs.isNotEmpty;
          if (_isListedForAdoption) {
            _adoptionId = querySnapshot.docs.first.id;
          }
        });
      }
    } catch (e) {
      print('Error checking adoption status: $e');
    }
  }

  Future<void> _showAdoptionDialog() async {
    final descriptionController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Put for Adoption'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You are about to list ${widget.pet.name} for adoption.',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Tell potential adopters about your pet...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 500,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'Your contact number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              const Text(
                'Note: Your email will be visible to potential adopters.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (descriptionController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please provide a description')),
                );
                return;
              }
              Navigator.pop(ctx, {
                'description': descriptionController.text.trim(),
                'phone': phoneController.text.trim(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
            ),
            child: const Text('List for Adoption'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _listForAdoption(result['description']!, result['phone']);
    }
  }

  Future<void> _listForAdoption(String description, String? phone) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userName = userDoc.data()?['name'] ?? 'Unknown';

      final adoptionPet = AdoptionPet(
        id: '', // Will be set by Firestore
        petId: widget.pet.id,
        ownerId: user.uid,
        ownerName: userName,
        ownerEmail: user.email ?? '',
        petName: widget.pet.name,
        species: widget.pet.species,
        breed: widget.pet.breed,
        age: widget.pet.age,
        gender: widget.pet.gender,
        photoUrl: widget.pet.photoUrl,
        description: description,
        listedAt: DateTime.now(),
        ownerPhone: phone?.isNotEmpty == true ? phone : null,
      );

      await _firestore.collection('adoptions').add(adoptionPet.toMap());

      if (mounted) {
        setState(() {
          _isListedForAdoption = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.pet.name} is now listed for adoption!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeFromAdoption() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Adoption?'),
        content: Text(
          'Are you sure you want to remove ${widget.pet.name} from adoption listings?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && _adoptionId != null) {
      try {
        await _firestore.collection('adoptions').doc(_adoptionId).delete();

        if (mounted) {
          setState(() {
            _isListedForAdoption = false;
            _adoptionId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pet removed from adoption listings'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isListedForAdoption ? Icons.check_circle : Icons.favorite,
                        color: _isListedForAdoption ? Colors.green : const Color(0xFF4A90E2),
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Adoption',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isListedForAdoption
                                  ? 'This pet is listed for adoption'
                                  : 'List this pet for adoption',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  if (_isListedForAdoption)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.green, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${widget.pet.name} is visible to potential adopters in the Adoption section.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _removeFromAdoption,
                          icon: const Icon(Icons.remove_circle_outline),
                          label: const Text('Remove from Adoption'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Find a loving home for ${widget.pet.name}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '• Your pet will be visible to other users\n'
                          '• Interested adopters can contact you directly\n'
                          '• You can remove the listing anytime',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showAdoptionDialog,
                          icon: const Icon(Icons.favorite),
                          label: const Text('Put for Adoption'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF4A90E2)),
              title: const Text(
                'About Adoption',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Help pets find loving homes through our community',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String message;
  final IconData icon;

  const _EmptyTab({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }
}