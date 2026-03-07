/// Summary of a single game in the manifest (lightweight, for update checks).
class GameSummary {
  /// Unique game identifier, matches [GameConfig.id].
  final String id;

  /// Content version number.
  final int version;

  /// Display title.
  final String title;

  /// Approximate download size in bytes.
  final int sizeBytes;

  const GameSummary({
    required this.id,
    required this.version,
    required this.title,
    required this.sizeBytes,
  });

  factory GameSummary.fromJson(Map<String, dynamic> json) {
    return GameSummary(
      id: json['id'] as String,
      version: json['version'] as int,
      title: json['title'] as String,
      sizeBytes: json['sizeBytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'title': title,
        'sizeBytes': sizeBytes,
      };
}

/// Top-level manifest listing all available games on the content server.
///
/// The app fetches this from Azure Blob Storage to check for updates.
class GameManifest {
  /// Manifest format version.
  final int manifestVersion;

  /// Base URL for downloading game content.
  final String baseUrl;

  /// List of available games.
  final List<GameSummary> games;

  const GameManifest({
    required this.manifestVersion,
    required this.baseUrl,
    required this.games,
  });

  factory GameManifest.fromJson(Map<String, dynamic> json) {
    return GameManifest(
      manifestVersion: json['manifestVersion'] as int,
      baseUrl: json['baseUrl'] as String,
      games: (json['games'] as List)
          .map((g) => GameSummary.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'manifestVersion': manifestVersion,
        'baseUrl': baseUrl,
        'games': games.map((g) => g.toJson()).toList(),
      };
}
