// lib/search_page.dart
import 'package:flutter/material.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'Search diagnoses, pets, library...',
            border: InputBorder.none,
          ),
          autofocus: true, // Automatically focus the search field
        ),
      ),
      body: const Center(
        child: Text('Search results will appear here.'),
      ),
    );
  }
}