import 'package:flutter/material.dart';

import '../main.dart' show contentService;
import '../services/content_service.dart';

/// Parent-facing screen for checking and downloading game updates.
///
/// Accessed via the parent gate from the catalog screen.
class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen> {
  UpdateInfo? _updateInfo;
  bool _checking = false;
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _checking = true;
      _error = null;
      _successMessage = null;
    });

    final info = await contentService.checkForUpdates();

    if (mounted) {
      setState(() {
        _checking = false;
        _updateInfo = info;
        if (info == null) {
          _error =
              'Could not reach the update server.\n'
              'Check your internet connection.';
        }
      });
    }
  }

  Future<void> _downloadUpdates() async {
    if (_updateInfo == null || !_updateInfo!.hasUpdates) return;

    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _error = null;
    });

    final downloaded = await contentService.downloadAllUpdates(
      _updateInfo!,
      onProgress: (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      },
    );

    if (mounted) {
      setState(() {
        _downloading = false;
        if (downloaded > 0) {
          _successMessage = 'Downloaded $downloaded game(s)!';
          _updateInfo = null; // Clear so UI shows "up to date"
        } else {
          _error = 'Download failed. Please try again.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Updates'),
        toolbarHeight: 56,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status section
            _buildStatusSection(),
            const SizedBox(height: 24),

            // Update list
            if (_updateInfo != null && _updateInfo!.hasUpdates)
              _buildUpdateList(),

            const Spacer(),

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    if (_checking) {
      return const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          SizedBox(width: 16),
          Text('Checking for updates...', style: TextStyle(fontSize: 18)),
        ],
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      );
    }

    if (_successMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Text(
              _successMessage!,
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_updateInfo != null && !_updateInfo!.hasUpdates) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade700),
            const SizedBox(width: 12),
            Text(
              'All games are up to date!',
              style: TextStyle(color: Colors.green.shade700),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildUpdateList() {
    final allUpdates = [
      ..._updateInfo!.newGames.map((g) => (g, true)),
      ..._updateInfo!.updatedGames.map((g) => (g, false)),
    ];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${allUpdates.length} update(s) available'
            ' (${_formatBytes(_updateInfo!.totalSizeBytes)})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: allUpdates.length,
              itemBuilder: (context, index) {
                final (game, isNew) = allUpdates[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isNew
                        ? Colors.blue.shade100
                        : Colors.orange.shade100,
                    child: Icon(
                      isNew ? Icons.new_releases : Icons.update,
                      color: isNew
                          ? Colors.blue.shade700
                          : Colors.orange.shade700,
                    ),
                  ),
                  title: Text(game.title),
                  subtitle: Text(
                    '${isNew ? "New" : "Update"}'
                    ' • v${game.version}'
                    ' • ${_formatBytes(game.sizeBytes)}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_downloading) {
      return Column(
        children: [
          LinearProgressIndicator(
            value: _downloadProgress,
            borderRadius: BorderRadius.circular(8),
            minHeight: 8,
          ),
          const SizedBox(height: 12),
          Text(
            'Downloading... ${(_downloadProgress * 100).toInt()}%',
            style: const TextStyle(fontSize: 16),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_updateInfo != null && _updateInfo!.hasUpdates)
          FilledButton.icon(
            onPressed: _downloadUpdates,
            icon: const Icon(Icons.download),
            label: const Text('Download Updates'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _checking ? null : _checkForUpdates,
          icon: const Icon(Icons.refresh),
          label: const Text('Check for Updates'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }
}
