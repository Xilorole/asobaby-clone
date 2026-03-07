import 'package:flutter/material.dart';

import '../app/baby_theme.dart';

/// Placeholder catalog screen — will be fully built in a later commit.
/// Shows a colorful welcome screen for now.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BabyTheme.accentBlue,
              BabyTheme.accentPurple,
              BabyTheme.primaryColor,
            ],
          ),
        ),
        child: const Center(
          child: Text(
            '🎮',
            style: TextStyle(fontSize: 120),
          ),
        ),
      ),
    );
  }
}
