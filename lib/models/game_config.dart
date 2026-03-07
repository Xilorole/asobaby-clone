import 'game_type.dart';

/// Configuration for a single game instance.
///
/// A [GameConfig] defines everything a game renderer needs:
/// which type of game to run, what assets to use, and any
/// type-specific settings (colors, timing, difficulty, etc.).
///
/// Game configs can be bundled in the APK or downloaded from
/// a remote content server.
class GameConfig {
  /// Unique identifier for this game (e.g. "bubble_pop_animals").
  final String id;

  /// Which game renderer to use.
  final GameType type;

  /// Display title (shown in parent-facing UI only).
  final String title;

  /// Short description (parent-facing).
  final String description;

  /// Relative path to the thumbnail image for the catalog.
  final String thumbnailPath;

  /// Map of logical asset names to relative file paths.
  ///
  /// Example: `{"bg": "background.png", "pop_sound": "pop.mp3"}`
  /// Paths are relative to the game's content directory.
  final Map<String, String> assets;

  /// Type-specific settings interpreted by the renderer.
  ///
  /// For example, a bubble pop game might have:
  /// `{"bubbleCount": 10, "speed": 1.5, "colors": ["#FF0000", "#00FF00"]}`
  final Map<String, dynamic> settings;

  /// Content version number. Higher = newer.
  final int version;

  const GameConfig({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.thumbnailPath,
    required this.assets,
    required this.settings,
    required this.version,
  });

  /// Create a [GameConfig] from a JSON map.
  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      id: json['id'] as String,
      type: GameType.values.firstWhere(
        (t) => t.name == json['type'] as String,
      ),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      thumbnailPath: json['thumbnailPath'] as String,
      assets: Map<String, String>.from(json['assets'] as Map),
      settings: Map<String, dynamic>.from(json['settings'] as Map? ?? {}),
      version: json['version'] as int? ?? 1,
    );
  }

  /// Serialize this config to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'thumbnailPath': thumbnailPath,
      'assets': assets,
      'settings': settings,
      'version': version,
    };
  }

  @override
  String toString() => 'GameConfig($id, $type, v$version)';
}
