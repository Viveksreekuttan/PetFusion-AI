import 'dart:convert';
import 'package:http/http.dart' as http;
import 'pet_model.dart';

class DietAdvisorService {
  // ⚠️ IMPORTANT: Update this based on your setup:
  // 
  // FOR PHYSICAL DEVICE (Real Phone/Tablet):
  // 1. Run 'ipconfig' in Windows PowerShell (or 'ifconfig' on Mac/Linux)
  // 2. Find your IPv4 Address (e.g., 192.168.1.3)
  // 3. Replace below with: 'http://YOUR_IP:5000'
  // Example: static const String baseUrl = 'http://192.168.1.3:5000';
  //
  // FOR ANDROID EMULATOR:
  // Use: 'http://10.0.2.2:5000'
  //
  // FOR iOS SIMULATOR:
  // Use: 'http://localhost:5000'
  
  static const String baseUrl = 'http://localhost:5000';  // ⚠️ CHANGE THIS TO YOUR IP!

  // Helper to safely parse age string to int
  static int parseAge(String ageStr) {
    try {
      // Remove any non-numeric characters except decimal point
      final cleaned = ageStr.replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleaned).round();
    } catch (e) {
      print('Error parsing age: $ageStr - $e');
      return 1; // Default to 1 year if parsing fails
    }
  }

  // Helper to safely parse weight string to double
  static double parseWeight(String weightStr) {
    try {
      // Remove any non-numeric characters except decimal point
      final cleaned = weightStr.replaceAll(RegExp(r'[^\d.]'), '');
      return double.parse(cleaned);
    } catch (e) {
      print('Error parsing weight: $weightStr - $e');
      return 10.0; // Default to 10kg if parsing fails
    }
  }

  // Size calculation based on breed, age, and weight
  static String calculateSize(String breed, String weightStr, String ageStr) {
    breed = breed.toLowerCase().trim();
    final weight = parseWeight(weightStr);
    final age = parseAge(ageStr);
    
    // Common small breeds
    final smallBreeds = [
      'chihuahua', 'pomeranian', 'yorkshire terrier', 'maltese', 
      'shih tzu', 'pug', 'dachshund', 'toy poodle', 'papillon',
      'miniature pinscher', 'havanese', 'french bulldog', 'boston terrier',
      'cairn terrier', 'miniature schnauzer', 'toy', 'teacup'
    ];
    
    // Common medium breeds
    final mediumBreeds = [
      'beagle', 'cocker spaniel', 'border collie', 'bulldog',
      'corgi', 'basset hound', 'shetland sheepdog', 'bull terrier',
      'whippet', 'springer spaniel', 'brittany'
    ];
    
    // Common large breeds
    final largeBreeds = [
      'labrador', 'golden retriever', 'german shepherd', 'rottweiler',
      'boxer', 'doberman', 'great dane', 'mastiff', 'saint bernard',
      'afghan hound', 'irish setter', 'bernese mountain dog', 'husky',
      'malamute', 'newfoundland', 'great pyrenees', 'akita', 'weimaraner',
      'rhodesian ridgeback', 'bloodhound', 'old english sheepdog'
    ];

    // Check breed-based classification first
    for (var smallBreed in smallBreeds) {
      if (breed.contains(smallBreed)) {
        return 'small';
      }
    }
    
    for (var mediumBreed in mediumBreeds) {
      if (breed.contains(mediumBreed)) {
        return 'medium';
      }
    }
    
    for (var largeBreed in largeBreeds) {
      if (breed.contains(largeBreed)) {
        return 'large';
      }
    }

    // Weight-based classification (in kg)
    // Adjust thresholds based on age (puppies are lighter)
    double smallThreshold = age < 1 ? 8 : 10;
    double largeThreshold = age < 1 ? 18 : 25;

    if (weight < smallThreshold) {
      return 'small';
    } else if (weight > largeThreshold) {
      return 'large';
    } else {
      return 'medium';
    }
  }

  // Get diet advice for a pet
  static Future<Map<String, dynamic>> getDietAdvice(Pet pet) async {
    try {
      // Parse age and weight from strings
      final age = parseAge(pet.age);
      final weight = parseWeight(pet.weight);
      
      // Calculate size
      String size = calculateSize(pet.breed, pet.weight, pet.age);

      // Prepare request body
      final requestBody = {
        'breed': pet.breed.toLowerCase().trim(),
        'size': size,
        'age': age,
        'weight': weight,
      };

      print('🔄 Sending request to: $baseUrl/diet-advisor');
      print('📤 Request body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/diet-advisor'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception(
            'Connection timeout. Please check:\n'
            '1. Flask server is running (python app.py)\n'
            '2. Server shows "Running on http://..." message\n'
            '3. No firewall blocking port 5000\n'
            '4. Using correct URL for your device type\n'
            '5. Both devices on same WiFi network (for physical device)'
          );
        },
      );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data,
          'calculatedSize': size,
          'parsedAge': age,
          'parsedWeight': weight,
        };
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        return {
          'success': false,
          'error': error['error'] ?? 'Invalid request',
        };
      } else {
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('❌ Error in getDietAdvice: $e');
      return {
        'success': false,
        'error': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Check API health
  static Future<bool> checkApiHealth() async {
    try {
      print('🔍 Testing connection to: $baseUrl');
      print('⏱️ Starting request...');
      
      final response = await http.get(
        Uri.parse('$baseUrl/'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏰ TIMEOUT: Request took more than 10 seconds');
          print('   This usually means:');
          print('   1. Flask server is not running');
          print('   2. Wrong IP/URL configuration');
          print('   3. Firewall blocking the connection');
          print('   4. Devices not on same WiFi network');
          throw Exception('Connection timeout');
        },
      );
      
      print('✅ Connection test: ${response.statusCode == 200 ? "SUCCESS" : "FAILED"}');
      print('📥 Response: ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('❌ API health check failed:');
      print('   Error type: ${e.runtimeType}');
      print('   Error message: $e');
      print('');
      print('🔧 Troubleshooting steps:');
      print('   1. Verify Flask is running: python app.py');
      print('   2. Check Flask terminal shows: "Running on http://0.0.0.0:5000"');
      print('   3. For PHYSICAL DEVICE:');
      print('      - Run "ipconfig" to find your IP');
      print('      - Update baseUrl in diet_advisor_service.dart');
      print('      - Make sure phone and PC on same WiFi');
      print('      - Allow Flask through Windows Firewall');
      print('   4. For EMULATOR: Use http://10.0.2.2:5000');
      return false;
    }
  }
}