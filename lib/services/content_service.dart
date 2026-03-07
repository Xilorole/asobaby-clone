import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

/// Information about available updates from the remote server.
class UpdateInfo {
  /// Games that are new (not present locally).
  final List<GameSummary> newGames;

  /// Games that have a newer version remotely.
  final List<GameSummary> updatedGames;

  /// Total download size in bytes.
  int get totalSizeBytes =>
      [...newGames, ...updatedGames].fold(0, (sum, g) => sum + g.sizeBytes);

  /// Whether any updates are available.
  bool get hasUpdates => newGames.isNotEmpty || updatedGames.isNotEmpty;

  const UpdateInfo({required this.newGames, required this.updatedGames});
}

/// Manages game content: loading bundled games, checking for updates,
/// and downloading new content from Azure Blob Storage.
class ContentService {
  static const String _manifestBoxName = 'manifest';
  static const String _localManifestKey = 'local_manifest';

  /// Remote URL for the content manifest.
  /// This points to an Azure Blob Storage container.
  final String remoteManifestUrl;

  final Dio _dio;
  late final Box<String> _manifestBox;
  late final String _contentDir;
  bool _initialized = false;

  ContentService({required this.remoteManifestUrl, Dio? dio})
    : _dio = dio ?? Dio();

  /// Initialize the service. Must be called before other methods.
  Future<void> init() async {
    if (_initialized) return;

    _manifestBox = await Hive.openBox<String>(_manifestBoxName);

    final appDir = await getApplicationDocumentsDirectory();
    _contentDir = '${appDir.path}/games';
    await Directory(_contentDir).create(recursive: true);

    _initialized = true;
  }

  /// Get the local content directory path.
  String get contentDir {
    assert(_initialized, 'ContentService not initialized');
    return _contentDir;
  }

  /// Load all available games (bundled + downloaded).
  ///
  /// Downloaded games with the same ID take priority over bundled ones
  /// if they have a higher version.
  Future<List<GameConfig>> getLocalGames() async {
    assert(_initialized, 'ContentService not initialized');

    final games = <String, GameConfig>{};

    // 1. Load bundled games from assets
    await _loadBundledGames(games);

    // 2. Load downloaded games (override bundled if newer)
    await _loadDownloadedGames(games);

    return games.values.toList();
  }

  /// Check the remote server for available updates.
  ///
  /// Returns null if the server is unreachable.
  Future<UpdateInfo?> checkForUpdates() async {
    assert(_initialized, 'ContentService not initialized');

    try {
      final response = await _dio.get(remoteManifestUrl);
      final remoteManifest = GameManifest.fromJson(
        response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>,
      );

      final localVersions = await _getLocalVersions();

      final newGames = <GameSummary>[];
      final updatedGames = <GameSummary>[];

      for (final game in remoteManifest.games) {
        final localVersion = localVersions[game.id];
        if (localVersion == null) {
          newGames.add(game);
        } else if (game.version > localVersion) {
          updatedGames.add(game);
        }
      }

      // Cache the remote manifest for reference
      _manifestBox.put('remote_manifest', jsonEncode(remoteManifest.toJson()));

      return UpdateInfo(newGames: newGames, updatedGames: updatedGames);
    } on DioException {
      return null; // Server unreachable
    } catch (e) {
      return null;
    }
  }

  /// Download a specific game's content from the remote server.
  ///
  /// [onProgress] reports download progress as a fraction (0.0 to 1.0).
  Future<bool> downloadGame(
    GameSummary game, {
    void Function(double progress)? onProgress,
  }) async {
    assert(_initialized, 'ContentService not initialized');

    try {
      // Get the cached remote manifest to find the base URL
      final manifestJson = _manifestBox.get('remote_manifest');
      if (manifestJson == null) return false;

      final manifest = GameManifest.fromJson(
        jsonDecode(manifestJson) as Map<String, dynamic>,
      );

      final baseUrl = manifest.baseUrl.endsWith('/')
          ? manifest.baseUrl
          : '${manifest.baseUrl}/';

      // Download the game's config.json
      final configUrl = '$baseUrl${game.id}/config.json';
      final configResponse = await _dio.get(configUrl);
      final configData = configResponse.data is String
          ? jsonDecode(configResponse.data as String) as Map<String, dynamic>
          : configResponse.data as Map<String, dynamic>;

      final config = GameConfig.fromJson(configData);

      // Create game directory
      final gameDir = '$_contentDir/${game.id}';
      await Directory(gameDir).create(recursive: true);

      // Save config.json
      await File(
        '$gameDir/config.json',
      ).writeAsString(jsonEncode(config.toJson()));

      // Download all assets
      final assetEntries = config.assets.entries.toList();
      for (var i = 0; i < assetEntries.length; i++) {
        final entry = assetEntries[i];
        final assetUrl = '$baseUrl${game.id}/${entry.value}';
        final assetPath = '$gameDir/${entry.value}';

        // Ensure subdirectory exists
        await File(assetPath).parent.create(recursive: true);

        await _dio.download(assetUrl, assetPath);

        if (onProgress != null) {
          onProgress((i + 1) / assetEntries.length);
        }
      }

      // Download thumbnail
      final thumbnailUrl = '$baseUrl${game.id}/${config.thumbnailPath}';
      final thumbnailPath = '$gameDir/${config.thumbnailPath}';
      await File(thumbnailPath).parent.create(recursive: true);
      try {
        await _dio.download(thumbnailUrl, thumbnailPath);
      } catch (_) {
        // Thumbnail is optional, don't fail the whole download
      }

      // Update local manifest
      await _updateLocalManifest(game);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Download all available updates.
  ///
  /// [onProgress] reports overall progress as a fraction (0.0 to 1.0).
  Future<int> downloadAllUpdates(
    UpdateInfo updateInfo, {
    void Function(double progress)? onProgress,
  }) async {
    final allGames = [...updateInfo.newGames, ...updateInfo.updatedGames];
    var downloaded = 0;

    for (var i = 0; i < allGames.length; i++) {
      final success = await downloadGame(allGames[i]);
      if (success) downloaded++;

      if (onProgress != null) {
        onProgress((i + 1) / allGames.length);
      }
    }

    return downloaded;
  }

  // — Private helpers —

  /// Load bundled games from the APK's assets/games/ directory.
  Future<void> _loadBundledGames(Map<String, GameConfig> games) async {
    try {
      // Load the bundled manifest that lists available games
      final manifestStr = await rootBundle.loadString(
        'assets/games/manifest.json',
      );
      final manifestData = jsonDecode(manifestStr) as Map<String, dynamic>;
      final gameIds = (manifestData['games'] as List)
          .map((g) => (g as Map<String, dynamic>)['id'] as String)
          .toList();

      for (final id in gameIds) {
        try {
          final configStr = await rootBundle.loadString(
            'assets/games/$id/config.json',
          );
          final config = GameConfig.fromJson(
            jsonDecode(configStr) as Map<String, dynamic>,
          );
          games[config.id] = config;
        } catch (_) {
          // Skip games that fail to load
        }
      }
    } catch (_) {
      // No bundled manifest or games, that's fine
    }
  }

  /// Load downloaded games from the local content directory.
  Future<void> _loadDownloadedGames(Map<String, GameConfig> games) async {
    final dir = Directory(_contentDir);
    if (!await dir.exists()) return;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final configFile = File('${entity.path}/config.json');
        if (await configFile.exists()) {
          try {
            final configStr = await configFile.readAsString();
            final config = GameConfig.fromJson(
              jsonDecode(configStr) as Map<String, dynamic>,
            );
            // Only override bundled if version is higher or equal
            final existing = games[config.id];
            if (existing == null || config.version >= existing.version) {
              games[config.id] = config;
            }
          } catch (_) {
            // Skip corrupted configs
          }
        }
      }
    }
  }

  /// Get a map of game ID → local version number.
  Future<Map<String, int>> _getLocalVersions() async {
    final games = await getLocalGames();
    return {for (final g in games) g.id: g.version};
  }

  /// Update the local manifest stored in Hive after a successful download.
  Future<void> _updateLocalManifest(GameSummary game) async {
    Map<String, dynamic> manifestData;

    final existing = _manifestBox.get(_localManifestKey);
    if (existing != null) {
      manifestData = jsonDecode(existing) as Map<String, dynamic>;
    } else {
      manifestData = {'games': []};
    }

    final gamesList = manifestData['games'] as List;

    // Remove existing entry for this game
    gamesList.removeWhere((g) => (g as Map<String, dynamic>)['id'] == game.id);

    // Add updated entry
    gamesList.add(game.toJson());
    manifestData['games'] = gamesList;

    await _manifestBox.put(_localManifestKey, jsonEncode(manifestData));
  }

  /// Resolve the file path for a game asset.
  ///
  /// Returns the path to the downloaded file if it exists,
  /// otherwise returns the bundled asset path.
  String resolveAssetPath(GameConfig config, String assetKey) {
    final downloadedPath =
        '$_contentDir/${config.id}/${config.assets[assetKey]}';
    if (File(downloadedPath).existsSync()) {
      return downloadedPath;
    }
    // Return bundled asset path
    return 'assets/games/${config.id}/${config.assets[assetKey]}';
  }

  /// Check if a game's assets are downloaded (vs bundled).
  bool isDownloaded(GameConfig config) {
    final configFile = File('$_contentDir/${config.id}/config.json');
    return configFile.existsSync();
  }
}
