import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// ─── Config ────────────────────────────────────────────────────────

const owner = 'Xilorole';
const repo = 'asobaby-clone';

// ─── Model ─────────────────────────────────────────────────────────

@immutable
class AppRelease {
  const AppRelease({
    required this.version,
    required this.releaseNotes,
    this.apkUrl,
    this.apkSizeBytes,
  });

  final String version;
  final String releaseNotes;
  final String? apkUrl;
  final int? apkSizeBytes;

  String get sizeMB => apkSizeBytes != null
      ? '${(apkSizeBytes! / 1024 / 1024).toStringAsFixed(1)} MB'
      : '';
}

// ─── State ─────────────────────────────────────────────────────────

@immutable
class UpdateState {
  const UpdateState({
    this.currentVersion = '',
    this.buildNumber = '',
    this.release,
    this.checking = false,
    this.downloading = false,
    this.downloadProgress = 0,
    this.error,
  });

  final String currentVersion;
  final String buildNumber;
  final AppRelease? release;
  final bool checking;
  final bool downloading;
  final double downloadProgress;
  final String? error;

  bool get hasUpdate =>
      release != null && _compareVersions(release!.version, currentVersion) > 0;

  UpdateState copyWith({
    String? currentVersion,
    String? buildNumber,
    AppRelease? release,
    bool? checking,
    bool? downloading,
    double? downloadProgress,
    String? error,
    bool clearError = false,
  }) {
    return UpdateState(
      currentVersion: currentVersion ?? this.currentVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      release: release ?? this.release,
      checking: checking ?? this.checking,
      downloading: downloading ?? this.downloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Notifier ──────────────────────────────────────────────────────

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  final _dio = Dio();

  Future<void> init() async {
    final info = await PackageInfo.fromPlatform();
    state = state.copyWith(
      currentVersion: info.version,
      buildNumber: info.buildNumber,
    );
  }

  Future<void> checkForUpdate() async {
    state = state.copyWith(checking: true, clearError: true);

    try {
      final res = await _dio.get(
        'https://api.github.com/repos/$owner/$repo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = res.data as Map<String, dynamic>;
      final tag = data['tag_name'] as String;
      final version = tag.replaceFirst(RegExp(r'^v'), '');

      String? apkUrl;
      int? apkSize;
      // Prefer architecture-specific APK matching this device, fall back to fat APK
      final preferredAbis = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
      final assets = (data['assets'] as List? ?? []);

      // First try to find a split APK for this device
      for (final abi in preferredAbis) {
        for (final a in assets) {
          final name = a['name'] as String? ?? '';
          if (name.contains(abi) && name.endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String?;
            apkSize = a['size'] as int?;
            break;
          }
        }
        if (apkUrl != null) break;
      }
      // Fall back to any .apk (fat APK)
      if (apkUrl == null) {
        for (final a in assets) {
          if ((a['name'] as String? ?? '').endsWith('.apk')) {
            apkUrl = a['browser_download_url'] as String?;
            apkSize = a['size'] as int?;
            break;
          }
        }
      }

      state = state.copyWith(
        checking: false,
        release: AppRelease(
          version: version,
          releaseNotes: data['body'] as String? ?? '',
          apkUrl: apkUrl,
          apkSizeBytes: apkSize,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        checking: false,
        error: 'Failed to fetch release info.\n$e',
      );
    }
  }

  Future<bool> downloadAndInstall() async {
    final release = state.release;
    if (release?.apkUrl == null) return false;

    state = state.copyWith(downloading: true, downloadProgress: 0);

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/asobaby-${release!.version}.apk';

      await _dio.download(
        release.apkUrl!,
        path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(downloadProgress: received / total);
          }
        },
      );

      state = state.copyWith(downloading: false);
      final result = await OpenFilex.open(path);
      return result.type == ResultType.done;
    } catch (_) {
      state = state.copyWith(downloading: false, error: 'Download failed.');
      return false;
    }
  }
}

// ─── Provider ──────────────────────────────────────────────────────

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((
  ref,
) {
  return UpdateNotifier();
});

// ─── Helpers ───────────────────────────────────────────────────────

int _compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va - vb;
  }
  return 0;
}

bool get isAndroid => !kIsWeb && Platform.isAndroid;
