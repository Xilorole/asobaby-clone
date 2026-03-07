import 'dart:math';

import 'package:flutter/material.dart';

import '../app/baby_theme.dart';
import '../common/parent_gate.dart';
import '../engine/game_screen.dart';
import '../main.dart' show contentService;
import '../models/models.dart';
import 'update_screen.dart';

/// The main game catalog screen.
///
/// Displays a grid of large, colorful game cards that babies can tap.
/// Includes a prominent random/shuffle button and a hidden parent gate
/// in the top-right corner for accessing the update screen.
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with TickerProviderStateMixin {
  List<GameConfig> _games = [];
  bool _loading = true;
  late final AnimationController _shuffleController;

  @override
  void initState() {
    super.initState();
    _shuffleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
    _loadGames();
  }

  @override
  void dispose() {
    _shuffleController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    final games = await contentService.getLocalGames();
    if (mounted) {
      setState(() {
        _games = games;
        _loading = false;
      });
    }
  }

  void _launchGame(GameConfig config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameScreen(config: config),
      ),
    );
  }

  void _launchRandomGame() {
    if (_games.isEmpty) return;
    final random = Random();
    final game = _games[random.nextInt(_games.length)];
    _launchGame(game);
  }

  void _openUpdateScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UpdateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParentGate.overlay(
        context: context,
        onParentVerified: _openUpdateScreen,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                BabyTheme.accentBlue,
                BabyTheme.bgColor,
              ],
            ),
          ),
          child: SafeArea(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 6,
                    ),
                  )
                : _games.isEmpty
                    ? _buildEmptyState()
                    : _buildCatalog(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🎮',
            style: TextStyle(fontSize: 80),
          ),
          const SizedBox(height: 16),
          Text(
            'No games yet!',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Long-press the top-right corner\nto check for updates',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalog() {
    return Column(
      children: [
        const SizedBox(height: 16),
        // Shuffle / Random game button
        _buildShuffleButton(),
        const SizedBox(height: 16),
        // Game grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: _games.length,
            itemBuilder: (context, index) =>
                _buildGameCard(_games[index], index),
          ),
        ),
      ],
    );
  }

  Widget _buildShuffleButton() {
    return AnimatedBuilder(
      animation: _shuffleController,
      builder: (context, child) {
        final wobble = sin(_shuffleController.value * 2 * pi) * 0.05;
        return Transform.rotate(
          angle: wobble,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: _launchRandomGame,
        child: Container(
          width: 160,
          height: 80,
          decoration: BoxDecoration(
            color: BabyTheme.accentYellow,
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: BabyTheme.accentYellow.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '🎲',
              style: TextStyle(fontSize: 48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard(GameConfig config, int index) {
    final color = BabyTheme.funColors[index % BabyTheme.funColors.length];

    // Map game types to emoji icons
    final typeEmoji = switch (config.type) {
      GameType.bubblePop => '🫧',
      GameType.tapResponse => '👆',
      GameType.shapeMatching => '🔷',
      GameType.peekaboo => '🙈',
      GameType.drawing => '🎨',
    };

    return GestureDetector(
      onTap: () => _launchGame(config),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Text(
            typeEmoji,
            style: const TextStyle(fontSize: 64),
          ),
        ),
      ),
    );
  }
}



