import 'package:flutter/material.dart';

import '../models/models.dart';

/// Base class for all game renderers.
///
/// Each game type (bubblePop, tapResponse, etc.) implements this
/// to provide its own interactive widget. The renderer receives
/// a [GameConfig] and the base path where assets are stored.
abstract class GameRenderer {
  /// The game configuration driving this renderer.
  final GameConfig config;

  /// Base directory path for resolving asset files.
  /// For bundled games: "assets/games/{gameId}"
  /// For downloaded games: "/data/.../games/{gameId}"
  final String assetBasePath;

  /// Whether assets are bundled in the APK (true) or downloaded (false).
  final bool isBundled;

  const GameRenderer({
    required this.config,
    required this.assetBasePath,
    required this.isBundled,
  });

  /// Build the game widget.
  Widget build(BuildContext context);

  /// Called when the game is disposed. Override to clean up resources.
  void dispose() {}
}
