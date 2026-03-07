import 'package:flutter/material.dart';

/// A parent gate that requires a deliberate hidden gesture
/// to access parent-only areas (settings, updates, exit).
///
/// Usage: Wrap any screen with [ParentGate.overlay] to add
/// hidden corner buttons that only parents know about.
class ParentGate {
  ParentGate._();

  /// Shows a confirmation dialog that requires solving a simple
  /// challenge that a baby can't solve (e.g., hold two fingers
  /// for 2 seconds, or tap a sequence).
  ///
  /// Returns true if the parent passed the gate.
  static Future<bool> challenge(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const _ParentChallengeDialog(),
        ) ??
        false;
  }

  /// Creates a positioned overlay button in the top-right corner
  /// that is nearly invisible (tiny, transparent) but tappable
  /// by parents who know it's there.
  ///
  /// [onParentVerified] is called when the parent passes the gate.
  static Widget overlay({
    required Widget child,
    required VoidCallback onParentVerified,
    required BuildContext context,
  }) {
    return Stack(
      children: [
        child,
        // Hidden button in top-right corner
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onLongPress: () async {
              final passed = await challenge(context);
              if (passed) {
                onParentVerified();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              color: Colors.transparent,
            ),
          ),
        ),
      ],
    );
  }
}

/// A dialog that asks the parent to hold a button for 3 seconds.
/// Babies won't have the patience or coordination to do this.
class _ParentChallengeDialog extends StatefulWidget {
  const _ParentChallengeDialog();

  @override
  State<_ParentChallengeDialog> createState() => _ParentChallengeDialogState();
}

class _ParentChallengeDialogState extends State<_ParentChallengeDialog> {
  bool _holding = false;
  double _progress = 0.0;
  static const _requiredDuration = Duration(seconds: 3);

  void _startHold() {
    setState(() => _holding = true);
    _runProgress();
  }

  void _cancelHold() {
    setState(() {
      _holding = false;
      _progress = 0.0;
    });
  }

  Future<void> _runProgress() async {
    const steps = 30;
    final stepDuration = Duration(
      milliseconds: _requiredDuration.inMilliseconds ~/ steps,
    );

    for (var i = 0; i < steps; i++) {
      await Future.delayed(stepDuration);
      if (!_holding || !mounted) return;
      setState(() => _progress = (i + 1) / steps);
    }

    if (mounted && _holding) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Parent Check'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Hold the button below for 3 seconds',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTapDown: (_) => _startHold(),
            onTapUp: (_) => _cancelHold(),
            onTapCancel: _cancelHold,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _holding
                    ? Colors.green.withValues(alpha: 0.3 + _progress * 0.7)
                    : Colors.grey.shade300,
              ),
              child: Center(
                child: _holding
                    ? Text(
                        '${(_progress * 3).ceil()}s',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Icon(Icons.touch_app, size: 48),
              ),
            ),
          ),
          if (_progress > 0 && _progress < 1)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(
                value: _progress,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
