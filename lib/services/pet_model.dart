import 'package:flutter/material.dart';

class Pet {
  final String id;
  final String name;
  final String species;
  final String breed;
  final String age;
  final String gender;
  final String weight;
  final String color;
  final String ownerName;
  final DateTime registrationDate;
  final String photoUrl;
  final IconData icon; // UI-specific, handled carefully in toMap

  Pet({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.age,
    required this.gender,
    required this.weight,
    required this.color,
    required this.ownerName,
    required this.registrationDate,
    required this.photoUrl,
    required this.icon,
  });

  // ⭐️ 1. Convert Pet Object -> Map (For Firestore Saving)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'age': age,
      'gender': gender,
      'weight': weight,
      'color': color,
      'ownerName': ownerName,
      'registrationDate': registrationDate.toIso8601String(), // Store dates as String
      'photoUrl': photoUrl,
      // We generally don't store 'icon' (IconData) in DB. 
      // It's better to derive it from 'species' when loading.
    };
  }

  // ⭐️ 2. Create Pet Object <- Map (For Firestore Loading)
  factory Pet.fromMap(Map<String, dynamic> map) {
    // Helper logic to re-assign icons based on species text
    IconData determineIcon(String species) {
      final s = species.toLowerCase();
      if (s.contains('cat')) return Icons.cruelty_free;
      if (s.contains('dog')) return Icons.pets;
      if (s.contains('cow')) return Icons.grass;
      if (s.contains('bird')) return Icons.flutter_dash;
      return Icons.pets; // Default
    }

    return Pet(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      species: map['species'] ?? '',
      breed: map['breed'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'] ?? 'Unknown',
      weight: map['weight'] ?? '',
      color: map['color'] ?? '',
      ownerName: map['ownerName'] ?? '',
      registrationDate: map['registrationDate'] != null 
          ? DateTime.parse(map['registrationDate']) 
          : DateTime.now(),
      photoUrl: map['photoUrl'] ?? 'assets/default_pet_avatar.png',
      icon: determineIcon(map['species'] ?? ''),
    );
  }
} 