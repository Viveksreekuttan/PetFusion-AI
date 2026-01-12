import 'package:cloud_firestore/cloud_firestore.dart';
class AdoptionPet {
  final String id;
  final String petId;
  final String ownerId;
  final String ownerName;
  final String ownerEmail;
  final String petName;
  final String species;
  final String breed;
  final String age;
  final String gender;
  final String photoUrl;
  final String description;
  final DateTime listedAt;
  final String? ownerPhone;

  AdoptionPet({
    required this.id,
    required this.petId,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.petName,
    required this.species,
    required this.breed,
    required this.age,
    required this.gender,
    required this.photoUrl,
    required this.description,
    required this.listedAt,
    this.ownerPhone,
  });

  factory AdoptionPet.fromMap(Map<String, dynamic> map) {
    return AdoptionPet(
      id: map['id'] ?? '',
      petId: map['petId'] ?? '',
      ownerId: map['ownerId'] ?? '',
      ownerName: map['ownerName'] ?? '',
      ownerEmail: map['ownerEmail'] ?? '',
      petName: map['petName'] ?? '',
      species: map['species'] ?? '',
      breed: map['breed'] ?? '',
      age: map['age'] ?? '',
      gender: map['gender'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      description: map['description'] ?? '',
      listedAt: (map['listedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerPhone: map['ownerPhone'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'petId': petId,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerEmail': ownerEmail,
      'petName': petName,
      'species': species,
      'breed': breed,
      'age': age,
      'gender': gender,
      'photoUrl': photoUrl,
      'description': description,
      'listedAt': Timestamp.fromDate(listedAt),
      'ownerPhone': ownerPhone,
    };
  }
}


