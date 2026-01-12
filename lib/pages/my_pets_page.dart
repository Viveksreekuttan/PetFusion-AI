import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/pet_model.dart';
import 'pet_profile_page.dart';
import 'add_pet_page.dart';

class MyPetsPage extends StatefulWidget {
  const MyPetsPage({super.key});

  @override
  State<MyPetsPage> createState() => _MyPetsPageState();
}

class _MyPetsPageState extends State<MyPetsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color primaryColor = const Color(0xFF4A90E2);

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

    if (user == null) {
      return const Scaffold(body: Center(child: Text("Please log in to see your pets.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').doc(user.uid).collection('pets').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No pets added yet.\nTap the + button to add one!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final pets = snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return Pet.fromMap(data);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSearchAndFilter(isDarkMode),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: pets.length,
                    itemBuilder: (context, index) {
                      final pet = pets[index];
                      return _buildPetCard(pet, isDarkMode);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddPetPage()),
          );
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Pet'),
      ),
    );
  }

  Widget _buildPetCard(Pet pet, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: Hero(
          tag: pet.id,
          child: CircleAvatar(
            backgroundColor: primaryColor.withOpacity(0.1),
            backgroundImage: pet.photoUrl.startsWith('http') 
                ? NetworkImage(pet.photoUrl) 
                : const AssetImage('assets/default_pet_avatar.png') as ImageProvider,
            child: pet.photoUrl.contains('assets') ? Icon(pet.icon, color: primaryColor) : null,
          ),
        ),
        title: Text(pet.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${pet.species} | ${pet.breed}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              onPressed: () => _deletePet(pet.id, pet.name),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
        onTap: () {
          // ⭐️ FIX: Navigate using petId instead of pet object
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PetDetailView(petId: pet.id), 
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    Color borderColor = isDark ? Colors.grey[700]! : Colors.grey[300]!;
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search pets...',
              prefixIcon: Icon(Icons.search, color: primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            ),
            onChanged: (value) {
              // Search logic can be implemented here later
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(icon: Icon(Icons.filter_list, color: primaryColor), onPressed: () {}),
      ],
    );
  }
}