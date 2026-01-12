import 'package:flutter/material.dart';
import 'diet_nutrition_page.dart';
import 'adoption_page.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Care Library'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            const TextField(
              decoration: InputDecoration(
                hintText: 'Search library...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12.0)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Category Grid
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildCategoryCard(
                  context,
                  'Diet & Nutrition',
                  Icons.restaurant_menu,
                  Colors.green,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DietNutritionPage(),
                      ),
                    );
                  },
                ),
                _buildCategoryCard(
                  context,
                  'Adoption',
                  Icons.favorite,
                  Colors.pink,
                  () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdoptionPage(),
                      ),
                    );
                  },
                ),
                _buildCategoryCard(
                  context,
                  'Vaccines',
                  Icons.vaccines,
                  Colors.blue,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Vaccination info coming soon!')),
                    );
                  },
                ),
                _buildCategoryCard(
                  context,
                  'Training',
                  Icons.sports_kabaddi,
                  Colors.orange,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Training tips coming soon!')),
                    );
                  },
                ),
                _buildCategoryCard(
                  context,
                  'First Aid',
                  Icons.medical_services,
                  Colors.red,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('First Aid guide coming soon!')),
                    );
                  },
                ),
                _buildCategoryCard(
                  context,
                  'Diseases',
                  Icons.coronavirus,
                  Colors.teal,
                  () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Disease database coming soon!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
