import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_update_service.dart';

void main() {
  runApp(const ProviderScope(child: UpdateCheckerApp()));
}

class UpdateCheckerApp extends StatelessWidget {
  const UpdateCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Asobaby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(updateProvider.notifier).init();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(updateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Asobaby')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VersionCard(state: s),
            const SizedBox(height: 24),
            _CheckButton(state: s),
            if (s.downloading) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(value: s.downloadProgress),
              const SizedBox(height: 8),
              Text('${(s.downloadProgress * 100).toStringAsFixed(0)}%'),
            ],
            if (s.error != null) ...[
              const SizedBox(height: 16),
              Text(s.error!, style: const TextStyle(color: Colors.red)),
            ],
            if (!isAndroid) ...[
              const SizedBox(height: 16),
              const Text(
                'Note: APK install is only supported on Android.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ───────────────────────────────────────────────────────

class _VersionCard extends StatelessWidget {
  const _VersionCard({required this.state});
  final UpdateState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Version',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              'v${state.currentVersion}',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Text(
              'Build ${state.buildNumber}',
              style: const TextStyle(color: Colors.grey),
            ),
            if (state.release != null) ...[
              const Divider(height: 24),
              Text(
                'Latest: v${state.release!.version}',
                style: const TextStyle(fontSize: 16),
              ),
              if (state.hasUpdate)
                const Text(
                  '⬆ Update available',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '✓ Up to date',
                  style: TextStyle(color: Colors.green),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CheckButton extends ConsumerWidget {
  const _CheckButton({required this.state});
  final UpdateState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = state.checking || state.downloading;

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: busy ? null : () => _onPressed(context, ref),
        icon: state.checking
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh),
        label: Text(state.checking ? 'Checking...' : 'Check for Update'),
      ),
    );
  }

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    await ref.read(updateProvider.notifier).checkForUpdate();

    if (!context.mounted) return;
    final s = ref.read(updateProvider);

    if (s.error != null) return;

    if (s.hasUpdate) {
      _showUpdateDialog(context, s.release!, ref);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Up to date (v${s.release?.version})')),
      );
    }
  }

  void _showUpdateDialog(
    BuildContext context,
    AppRelease release,
    WidgetRef ref,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New version: ${release.version}'),
            if (release.sizeMB.isNotEmpty) Text('Size: ${release.sizeMB}'),
            if (release.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Release notes:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                release.releaseNotes,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(updateProvider.notifier).downloadAndInstall();
            },
            child: const Text('Install'),
          ),
        ],
      ),
    );
  }
}
