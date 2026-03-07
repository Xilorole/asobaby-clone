import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/baby_theme.dart';
import '../common/parent_gate.dart';
import '../models/models.dart';
import '../main.dart' show contentService;
import 'bubble_pop_renderer.dart';
import 'game_renderer.dart';

/// The game screen that hosts a game renderer.
///
/// Enters immersive fullscreen mode, creates the appropriate renderer
/// based on [GameConfig.type], and wraps it with a parent gate overlay
/// for exiting back to the catalog.
class GameScreen extends StatefulWidget {
  final GameConfig config;

  const GameScreen({super.key, required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late GameRenderer _renderer;
  late AnimationController _shuffleBounce;
  List<GameConfig> _allGames = [];

  @override
  void initState() {
    super.initState();
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _shuffleBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _initRenderer();
    _loadAllGames();
  }

  void _initRenderer() {
    // Create the renderer
    final isBundled = !contentService.isDownloaded(widget.config);
    final basePath = isBundled
        ? 'assets/games/${widget.config.id}'
        : '${contentService.contentDir}/${widget.config.id}';

    _renderer = _createRenderer(
      config: widget.config,
      assetBasePath: basePath,
      isBundled: isBundled,
    );
  }

  Future<void> _loadAllGames() async {
    final games = await contentService.getLocalGames();
    if (mounted) {
      setState(() => _allGames = games);
    }
  }

  @override
  void dispose() {
    _renderer.dispose();
    _shuffleBounce.dispose();
    // Restore immersive mode (in case it was changed)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  void _switchToRandomGame() {
    if (_allGames.length <= 1) return;

    final random = Random();
    GameConfig next;
    do {
      next = _allGames[random.nextInt(_allGames.length)];
    } while (next.id == widget.config.id && _allGames.length > 1);

    // Bounce animation on the button
    _shuffleBounce.forward(from: 0.0);

    // Replace this screen with a new game
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GameScreen(config: next),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _goToCatalog() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParentGate.overlay(
        context: context,
        onParentVerified: _exitGame,
        child: Stack(
          children: [
            // Game content
            _renderer.build(context),

            // Bottom navigation bar with home + shuffle buttons
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(
                      bottom: 16, left: 24, right: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Home / catalog button
                      _GameNavButton(
                        emoji: '🏠',
                        color: BabyTheme.accentBlue,
                        onTap: _goToCatalog,
                      ),
                      // Shuffle / random game button
                      if (_allGames.length > 1)
                        ScaleTransition(
                          scale: Tween(begin: 1.0, end: 1.3)
                              .chain(CurveTween(curve: Curves.elasticOut))
                              .animate(_shuffleBounce),
                          child: _GameNavButton(
                            emoji: '🎲',
                            color: BabyTheme.accentYellow,
                            onTap: _switchToRandomGame,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Factory that creates the appropriate renderer for a game type.
  static GameRenderer _createRenderer({
    required GameConfig config,
    required String assetBasePath,
    required bool isBundled,
  }) {
    switch (config.type) {
      case GameType.bubblePop:
        return BubblePopRenderer(
          config: config,
          assetBasePath: assetBasePath,
          isBundled: isBundled,
        );
      // Future game types will be added here:
      // case GameType.tapResponse:
      //   return TapResponseRenderer(...);
      // case GameType.shapeMatching:
      //   return ShapeMatchingRenderer(...);
      // case GameType.peekaboo:
      //   return PeekabooRenderer(...);
      // case GameType.drawing:
      //   return DrawingRenderer(...);
      default:
        return _FallbackRenderer(
          config: config,
          assetBasePath: assetBasePath,
          isBundled: isBundled,
        );
    }
  }
}

/// Fallback renderer for game types that don't have a renderer yet.
class _FallbackRenderer extends GameRenderer {
  const _FallbackRenderer({
    required super.config,
    required super.assetBasePath,
    required super.isBundled,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BabyTheme.accentPurple,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🚧', style: TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              config.title,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${config.type.name} coming soon!',
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large, round, baby-friendly navigation button with an emoji icon.
class _GameNavButton extends StatelessWidget {
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _GameNavButton({
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 36),
          ),
        ),
      ),
    );
  }
}
