import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/baby_theme.dart';
import 'services/app_update_service.dart';
import 'services/content_service.dart';
import 'catalog/catalog_screen.dart';

/// Remote manifest URL (Azure Blob Storage).
/// Replace with your actual Azure Blob container URL.
const kRemoteManifestUrl =
    'https://stasobabyclone.blob.core.windows.net/games/manifest.json';

late ContentService contentService;
late AppUpdateService appUpdateService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize content service
  contentService = ContentService(remoteManifestUrl: kRemoteManifestUrl);
  await contentService.init();

  // Initialize app update service
  appUpdateService = AppUpdateService(
    owner: 'Xilorole',
    repo: 'asobaby-clone',
  );
  await appUpdateService.init();

  // Enter immersive fullscreen (hide status bar + nav bar)
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Lock to portrait for now (individual games can override)
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const AsobabyApp());
}

class AsobabyApp extends StatelessWidget {
  const AsobabyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asobaby',
      debugShowCheckedModeBanner: false,
      theme: BabyTheme.themeData,
      home: const _BootScreen(),
    );
  }
}

/// Wrapper that checks for app updates on boot, then shows catalog.
class _BootScreen extends StatefulWidget {
  const _BootScreen();

  @override
  State<_BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<_BootScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppUpdate();
  }

  Future<void> _checkAppUpdate() async {
    // Only check on Android (APK installs)
    if (!Platform.isAndroid) return;

    final release = await appUpdateService.checkForUpdate();
    if (release != null && appUpdateService.hasUpdate && mounted) {
      _showUpdateDialog(release);
    }
  }

  void _showUpdateDialog(AppRelease release) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _AppUpdateDialog(release: release),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const CatalogScreen();
  }
}

/// Dialog shown at boot when an app update is available.
class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.release});

  final AppRelease release;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _install() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    final success = await appUpdateService.downloadAndInstall(
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else {
        setState(() {
          _downloading = false;
          _error = 'Install failed. Please try again.';
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.blue.shade700),
          const SizedBox(width: 10),
          const Expanded(child: Text('Update Available')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'v${appUpdateService.currentVersion} → v${widget.release.version}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade700,
              fontSize: 16,
            ),
          ),
          if (widget.release.apkSizeBytes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Size: ${_formatBytes(widget.release.apkSizeBytes!)}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
          if (widget.release.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              widget.release.releaseNotes,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ],
          if (_downloading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _progress,
              borderRadius: BorderRadius.circular(8),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading... ${(_progress * 100).toInt()}%',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: _downloading
          ? null
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              FilledButton.icon(
                onPressed: _install,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Install'),
              ),
            ],
    );
  }
}
