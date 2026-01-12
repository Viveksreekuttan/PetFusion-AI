// lib/mock_data.dart

import 'package:flutter/material.dart';
import 'pet_model.dart';

// Mock data to simulate a database
final List<Pet> mockPets = [
  Pet(
    id: 'p1',
    name: 'Max',
    species: 'Dog',
    breed: 'Golden Retriever',
    age: '4 years',
    gender: 'Male',
    weight: '30 kg',
    color: 'Golden',
    ownerName: 'Vivek T K',
    registrationDate: DateTime(2022, 5, 15),
    photoUrl: 'assets/dog_avatar.png', // Add a placeholder image to assets
    icon: Icons.pets,
  ),
  Pet(
    id: 'p2',
    name: 'Luna',
    species: 'Cat',
    breed: 'Siamese',
    age: '2 years',
    gender: 'Female',
    weight: '5 kg',
    color: 'Cream',
    ownerName: 'Ardra N',
    registrationDate: DateTime(2023, 1, 10),
    photoUrl: 'assets/cat_avatar.png', // Add a placeholder image to assets
    icon: Icons.cruelty_free,
  ),
  Pet(
    id: 'p3',
    name: 'Bella',
    species: 'Cow',
    breed: 'Holstein',
    age: '5 years',
    gender: 'Female',
    weight: '600 kg',
    color: 'Black & White',
    ownerName: 'Arjun P S',
    registrationDate: DateTime(2021, 11, 20),
    photoUrl: 'assets/cow_avatar.png', // Add a placeholder image to assets
    icon: Icons.grass,
  ),
];