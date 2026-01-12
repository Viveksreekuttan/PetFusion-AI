import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/pet_model.dart';
import '../services/diet_advisor_service.dart';

class DietNutritionPage extends StatefulWidget {
  const DietNutritionPage({super.key});

  @override
  State<DietNutritionPage> createState() => _DietNutritionPageState();
}

class _DietNutritionPageState extends State<DietNutritionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  Pet? selectedPet;
  String? selectedPetId;
  bool isLoading = false;
  bool isTestingConnection = false;
  Map<String, dynamic>? dietAdvice;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _testServerConnection();
  }

  Future<void> _testServerConnection() async {
    setState(() {
      isTestingConnection = true;
      errorMessage = null;
    });

    final isConnected = await DietAdvisorService.checkApiHealth();
    
    if (mounted) {
      setState(() {
        isTestingConnection = false;
        if (!isConnected) {
          errorMessage = 'Cannot connect to server. Please check:\n\n'
              '1. Flask server is running:\n'
              '   Run: python app.py\n\n'
              '2. Check terminal shows:\n'
              '   "Running on http://..."\n\n'
              '3. For PHYSICAL DEVICE:\n'
              '   - Find your IP: Run "ipconfig"\n'
              '   - Update baseUrl in diet_advisor_service.dart\n'
              '   - Both devices on same WiFi\n'
              '   - Allow port 5000 in firewall\n\n'
              '4. For EMULATOR:\n'
              '   - Use: http://10.0.2.2:5000';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diet & Nutrition')),
        body: const Center(child: Text('Please log in to access this feature.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet & Nutrition Advisor'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _testServerConnection,
            tooltip: 'Test server connection',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            if (isTestingConnection) _buildConnectionTestIndicator(),
            if (!isTestingConnection && errorMessage != null) 
              _buildConnectionStatusCard(false),
            if (!isTestingConnection && errorMessage == null)
              _buildConnectionStatusCard(true),
            const SizedBox(height: 24),
            _buildPetSelector(user.uid),
            const SizedBox(height: 24),
            if (selectedPet != null) ...[
              _buildAnalyzeButton(),
              const SizedBox(height: 24),
            ],
            if (isLoading) _buildLoadingIndicator(),
            if (errorMessage != null && !isTestingConnection && dietAdvice == null) 
              _buildErrorCard(),
            if (dietAdvice != null && !isLoading) _buildDietAdviceCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTestIndicator() {
    return Card(
      color: Colors.blue.shade50,
      child: const Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text('Testing server connection...'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatusCard(bool isConnected) {
    return Card(
      color: isConnected ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(
              isConnected ? Icons.check_circle : Icons.warning,
              color: isConnected ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isConnected 
                    ? 'Server connected successfully!' 
                    : 'Server not connected - see details below',
                style: TextStyle(
                  color: isConnected ? Colors.green.shade900 : Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant_menu, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI-Powered Diet Advisor',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Get personalized nutrition recommendations',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetSelector(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('users').doc(userId).collection('pets').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(Icons.pets, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  const Text(
                    'No pets found. Please add a pet first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        final pets = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Pet.fromMap(data);
        }).toList();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Your Pet',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: DropdownButtonFormField<String>(
                    value: selectedPetId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      prefixIcon: const Icon(Icons.pets),
                    ),
                    hint: const Text('Choose a pet'),
                    isExpanded: true,
                    items: pets.map((pet) {
                      return DropdownMenuItem<String>(
                        value: pet.id,
                        child: Text('${pet.name} (${pet.breed})'),
                      );
                    }).toList(),
                    onChanged: (String? petId) {
                      setState(() {
                        selectedPetId = petId;
                        selectedPet = pets.firstWhere((p) => p.id == petId);
                        dietAdvice = null;
                        errorMessage = null;
                      });
                    },
                  ),
                ),
                if (selectedPet != null) ...[
                  const SizedBox(height: 16),
                  _buildPetInfo(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPetInfo() {
    if (selectedPet == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Breed', selectedPet!.breed),
          _buildInfoRow('Age', selectedPet!.age),
          _buildInfoRow('Weight', selectedPet!.weight),
          _buildInfoRow(
            'Calculated Size',
            DietAdvisorService.calculateSize(
              selectedPet!.breed,
              selectedPet!.weight,
              selectedPet!.age,
            ).toUpperCase(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAnalyzeButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _analyzeNutrition,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.analytics),
        label: const Text('Analyze Nutrition Needs', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing nutrition needs...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Connection Error',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                errorMessage ?? 'An error occurred',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testServerConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Test Connection Again'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDietAdviceCard() {
    if (dietAdvice == null) return const SizedBox.shrink();

    final data = dietAdvice!['data'];
    final diseaseRisk = data['disease_risk'] ?? 'Unknown';
    final lifestage = data['lifestage'] ?? 'Unknown';
    final nutritionPlan = data['nutrition_plan'] ?? {};
    final foods = data['recommended_foods'] ?? [];

    return Column(
      children: [
        // Disease Risk & Lifestage
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.medical_services, color: Colors.orange.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Health Analysis',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildHealthRow('Disease Risk', diseaseRisk, Colors.orange),
                _buildHealthRow('Life Stage', lifestage.toUpperCase(), Colors.blue),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Nutrition Plan
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Nutrition Plan',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNutritionItem('Protein', nutritionPlan['protein'] ?? 'N/A'),
                _buildNutritionItem('Fat', nutritionPlan['fat'] ?? 'N/A'),
                _buildNutritionItem('Fiber', nutritionPlan['fiber'] ?? 'N/A'),
                _buildNutritionItem('Calories', nutritionPlan['calories'] ?? 'N/A'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Recommended Foods
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant, color: Colors.purple.shade700),
                    const SizedBox(width: 8),
                    const Text(
                      'Recommended Foods',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...foods.map<Widget>((food) => _buildFoodItem(food)).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHealthRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodItem(Map<String, dynamic> food) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            food['product_title'] ?? 'Unknown Product',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientBadge('Protein', '${food['protein'] ?? 0}%', Colors.red),
              _buildNutrientBadge('Fat', '${food['fat'] ?? 0}%', Colors.orange),
              _buildNutrientBadge(
                'Cal',
                '${food['calories_100g']?.toStringAsFixed(0) ?? 0} kcal/100g',
                Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Future<void> _analyzeNutrition() async {
    if (selectedPet == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
      dietAdvice = null;
    });

    try {
      final result = await DietAdvisorService.getDietAdvice(selectedPet!);

      if (mounted) {
        setState(() {
          isLoading = false;
          if (result['success'] == true) {
            dietAdvice = result;
            errorMessage = null;
          } else {
            errorMessage = result['error'] ?? 'Failed to get diet advice';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Error: $e';
        });
      }
    }
  }
}