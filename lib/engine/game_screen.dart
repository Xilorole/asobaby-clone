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

class _GameScreenState extends State<GameScreen> {
  late final GameRenderer _renderer;

  @override
  void initState() {
    super.initState();
    // Enter immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

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

  @override
  void dispose() {
    _renderer.dispose();
    // Restore immersive mode (in case it was changed)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  void _exitGame() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParentGate.overlay(
        context: context,
        onParentVerified: _exitGame,
        child: _renderer.build(context),
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
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
