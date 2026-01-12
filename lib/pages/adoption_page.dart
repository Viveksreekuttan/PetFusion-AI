import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/adoption_model.dart';

class AdoptionPage extends StatefulWidget {
  const AdoptionPage({super.key});

  @override
  State<AdoptionPage> createState() => _AdoptionPageState();
}

class _AdoptionPageState extends State<AdoptionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _selectedSpecies = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _speciesCategories = [
    'All',
    'Dog',
    'Cat',
    'Bird',
    'Rabbit',
    'Hamster',
    'Fish',
    'Other'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<List<AdoptionPet>> _getAdoptionPets() {
    Query query = _firestore.collection('adoptions');

    // Filter by species if not 'All'
    if (_selectedSpecies != 'All') {
      query = query.where('species', isEqualTo: _selectedSpecies);
    }

    return query.snapshots().map((snapshot) {
      List<AdoptionPet> pets = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return AdoptionPet.fromMap(data);
      }).toList();

      // Filter by breed search if query exists
      if (_searchQuery.isNotEmpty) {
        pets = pets.where((pet) {
          return pet.breed.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                 pet.petName.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }

      return pets;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Adoption'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by breed or pet name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Species Category Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _speciesCategories.length,
              itemBuilder: (context, index) {
                final category = _speciesCategories[index];
                final isSelected = _selectedSpecies == category;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedSpecies = category);
                    },
                    selectedColor: const Color(0xFF4A90E2),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Adoption Pets List
          Expanded(
            child: StreamBuilder<List<AdoptionPet>>(
              stream: _getAdoptionPets(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No pets found matching "$_searchQuery"'
                              : 'No pets available for adoption',
                          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final pets = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: pets.length,
                  itemBuilder: (context, index) {
                    final pet = pets[index];
                    return _buildAdoptionCard(pet, isDarkMode);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdoptionCard(AdoptionPet pet, bool isDarkMode) {
    final user = _auth.currentUser;
    final isOwnPet = user?.uid == pet.ownerId;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey[800] : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showPetDetails(pet, isOwnPet),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pet Image
            if (pet.photoUrl.isNotEmpty && pet.photoUrl.startsWith('http'))
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.network(
                  pet.photoUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.pets, size: 64, color: Colors.grey),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF4A90E2).withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.pets, size: 64, color: Color(0xFF4A90E2)),
                ),
              ),

            // Pet Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pet.petName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isOwnPet)
                        Chip(
                          label: const Text(
                            'Your Pet',
                            style: TextStyle(fontSize: 11),
                          ),
                          backgroundColor: Colors.orange[100],
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.category, pet.species, Colors.blue),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.pets, pet.breed, Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.cake, pet.age, Colors.purple),
                      const SizedBox(width: 8),
                      _buildInfoChip(
                        pet.gender == 'Male' ? Icons.male : Icons.female,
                        pet.gender,
                        pet.gender == 'Male' ? Colors.blue : Colors.pink,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pet.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Owner: ${pet.ownerName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      if (!isOwnPet)
                        ElevatedButton.icon(
                          onPressed: () => _contactOwner(pet),
                          icon: const Icon(Icons.email, size: 16),
                          label: const Text('Contact'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4A90E2),
                            foregroundColor: Colors.white,
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
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: color.withOpacity(0.1),
      padding: const EdgeInsets.all(4),
    );
  }

  void _showPetDetails(AdoptionPet pet, bool isOwnPet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Pet Image
                  if (pet.photoUrl.isNotEmpty && pet.photoUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        pet.photoUrl,
                        height: 250,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A90E2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Icon(Icons.pets, size: 80, color: Color(0xFF4A90E2)),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  Text(
                    pet.petName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildDetailRow('Species', pet.species, Icons.category),
                  _buildDetailRow('Breed', pet.breed, Icons.pets),
                  _buildDetailRow('Age', pet.age, Icons.cake),
                  _buildDetailRow('Gender', pet.gender, 
                    pet.gender == 'Male' ? Icons.male : Icons.female),
                  
                  const SizedBox(height: 20),
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pet.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                  
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  
                  const Text(
                    'Owner Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Name', pet.ownerName, Icons.person),
                  _buildDetailRow('Email', pet.ownerEmail, Icons.email),
                  if (pet.ownerPhone != null && pet.ownerPhone!.isNotEmpty)
                    _buildDetailRow('Phone', pet.ownerPhone!, Icons.phone),
                  
                  if (!isOwnPet) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _contactOwner(pet);
                        },
                        icon: const Icon(Icons.email),
                        label: const Text('Contact Owner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _removeFromAdoption(pet),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove from Adoption'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4A90E2)),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _contactOwner(AdoptionPet pet) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: pet.ownerEmail,
      query: 'subject=Interested in adopting ${pet.petName}&body=Hi ${pet.ownerName},%0D%0A%0D%0AI am interested in adopting ${pet.petName}. Please let me know the next steps.%0D%0A%0D%0AThank you!',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Contact owner at: ${pet.ownerEmail}'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Copy',
                onPressed: () {
                  // You can add clipboard functionality here
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact owner at: ${pet.ownerEmail}')),
        );
      }
    }
  }

  Future<void> _removeFromAdoption(AdoptionPet pet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Adoption?'),
        content: Text('Are you sure you want to remove ${pet.petName} from adoption listings?'),
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

    if (confirm == true) {
      try {
        await _firestore.collection('adoptions').doc(pet.id).delete();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pet removed from adoption')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}
