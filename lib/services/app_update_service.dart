import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Checks GitHub Releases for app updates and triggers in-app install.
class AppUpdateService {
  AppUpdateService({
    required this.owner,
    required this.repo,
  });

  final String owner;
  final String repo;
  final Dio _dio = Dio();

  /// Info about current app version.
  String? _currentVersion;

  /// Fetched release info (cached after first check).
  AppRelease? _latestRelease;

  /// Initialise with current app version.
  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    _currentVersion = info.version; // e.g. "1.0.0"
  }

  String get currentVersion => _currentVersion ?? '0.0.0';

  /// Check GitHub Releases API for the latest release.
  /// Returns null on network error.
  Future<AppRelease?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final tagName = data['tag_name'] as String; // e.g. "v1.1.0"
      final version = tagName.replaceFirst(RegExp(r'^v'), '');
      final body = data['body'] as String? ?? '';

      // Find APK asset
      String? apkUrl;
      int? apkSize;
      final assets = data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          apkSize = asset['size'] as int?;
          break;
        }
      }

      _latestRelease = AppRelease(
        version: version,
        tagName: tagName,
        releaseNotes: body,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
      );

      return _latestRelease;
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Whether the latest release is newer than the current app version.
  bool get hasUpdate {
    if (_latestRelease == null || _currentVersion == null) return false;
    return _compareVersions(_latestRelease!.version, _currentVersion!) > 0;
  }

  /// Download APK and trigger Android installer.
  ///
  /// [onProgress] receives 0.0–1.0 progress values.
  /// Returns true if install was triggered successfully.
  Future<bool> downloadAndInstall({
    void Function(double progress)? onProgress,
  }) async {
    final release = _latestRelease;
    if (release == null || release.apkDownloadUrl == null) return false;

    try {
      // Download to temp directory
      final dir = await getTemporaryDirectory();
      final apkPath = '${dir.path}/asobaby-${release.version}.apk';

      await _dio.download(
        release.apkDownloadUrl!,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress?.call(received / total);
          }
        },
      );

      // Trigger Android package installer
      final result = await OpenFilex.open(apkPath);
      return result.type == ResultType.done;
    } on DioException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Compare two semver strings. Returns >0 if a > b, <0 if a < b, 0 if equal.
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map(int.tryParse).toList();
    final partsB = b.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final va = i < partsA.length ? (partsA[i] ?? 0) : 0;
      final vb = i < partsB.length ? (partsB[i] ?? 0) : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }

  // Only supported on Android
  static bool get isSupported => Platform.isAndroid;
}

/// Represents a GitHub Release.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tagName,
    required this.releaseNotes,
    this.apkDownloadUrl,
    this.apkSizeBytes,
  });

  final String version;
  final String tagName;
  final String releaseNotes;
  final String? apkDownloadUrl;
  final int? apkSizeBytes;
}
