import 'dart:math';

import 'package:flutter/material.dart';

import '../app/baby_theme.dart';
import '../models/models.dart';
import 'game_renderer.dart';

/// A fun bubble pop game for babies!
///
/// Colored bubbles float up from the bottom of the screen.
/// Baby taps a bubble to pop it with a satisfying animation.
/// New bubbles keep spawning. It's endlessly entertaining.
///
/// Config settings:
/// - `bubbleCount` (int): max simultaneous bubbles (default: 8)
/// - `speed` (double): float speed multiplier (default: 1.0)
/// - `minSize` (double): minimum bubble radius (default: 30)
/// - `maxSize` (double): maximum bubble radius (default: 60)
/// - `colors` (List of String): hex color strings (default: BabyTheme.funColors)
class BubblePopRenderer extends GameRenderer {
  const BubblePopRenderer({
    required super.config,
    required super.assetBasePath,
    required super.isBundled,
  });

  @override
  Widget build(BuildContext context) {
    return _BubblePopGame(
      config: config,
    );
  }
}

class _BubblePopGame extends StatefulWidget {
  final GameConfig config;

  const _BubblePopGame({required this.config});

  @override
  State<_BubblePopGame> createState() => _BubblePopGameState();
}

class _BubblePopGameState extends State<_BubblePopGame>
    with TickerProviderStateMixin {
  final List<_Bubble> _bubbles = [];
  final List<_PopAnimation> _pops = [];
  final Random _random = Random();
  late final AnimationController _tickController;

  int get _maxBubbles =>
      (widget.config.settings['bubbleCount'] as int?) ?? 8;
  double get _speed =>
      (widget.config.settings['speed'] as num?)?.toDouble() ?? 1.0;
  double get _minSize =>
      (widget.config.settings['minSize'] as num?)?.toDouble() ?? 30.0;
  double get _maxSize =>
      (widget.config.settings['maxSize'] as num?)?.toDouble() ?? 60.0;

  List<Color> get _colors {
    final configColors = widget.config.settings['colors'] as List?;
    if (configColors != null) {
      return configColors
          .map((c) => Color(int.parse((c as String).replaceFirst('#', '0xFF'))))
          .toList();
    }
    return BabyTheme.funColors;
  }

  @override
  void initState() {
    super.initState();
    _tickController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(_tick);
    _tickController.repeat();
  }

  @override
  void dispose() {
    _tickController.dispose();
    for (final pop in _pops) {
      pop.controller.dispose();
    }
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;

    setState(() {
      // Spawn new bubbles if under max
      while (_bubbles.length < _maxBubbles) {
        _spawnBubble(size);
      }

      // Move bubbles upward
      for (final bubble in _bubbles) {
        bubble.y -= bubble.speed * _speed;
        // Gentle horizontal wobble
        bubble.x += sin(bubble.y * 0.02 + bubble.wobbleOffset) * 0.5;
      }

      // Remove bubbles that have floated off screen
      _bubbles.removeWhere((b) => b.y < -b.radius * 2);

      // Remove finished pop animations
      _pops.removeWhere((p) => p.controller.isCompleted);
    });
  }

  void _spawnBubble(Size screenSize) {
    final radius = _minSize + _random.nextDouble() * (_maxSize - _minSize);
    _bubbles.add(_Bubble(
      x: radius + _random.nextDouble() * (screenSize.width - radius * 2),
      y: screenSize.height + radius + _random.nextDouble() * 100,
      radius: radius,
      color: _colors[_random.nextInt(_colors.length)],
      speed: 1.0 + _random.nextDouble() * 2.0,
      wobbleOffset: _random.nextDouble() * 2 * pi,
    ));
  }

  void _popBubble(_Bubble bubble) {
    setState(() {
      _bubbles.remove(bubble);

      // Create pop animation
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..forward();

      _pops.add(_PopAnimation(
        x: bubble.x,
        y: bubble.y,
        color: bubble.color,
        radius: bubble.radius,
        controller: controller,
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F4FD), // Light sky blue background
      child: Stack(
        children: [
          // Bubbles
          ..._bubbles.map((bubble) => Positioned(
                left: bubble.x - bubble.radius,
                top: bubble.y - bubble.radius,
                child: GestureDetector(
                  onTapDown: (_) => _popBubble(bubble),
                  child: _BubbleWidget(bubble: bubble),
                ),
              )),
          // Pop animations
          ..._pops.map((pop) => Positioned(
                left: pop.x - pop.radius,
                top: pop.y - pop.radius,
                child: _PopWidget(pop: pop),
              )),
        ],
      ),
    );
  }
}

/// Data class for a floating bubble.
class _Bubble {
  double x;
  double y;
  final double radius;
  final Color color;
  final double speed;
  final double wobbleOffset;

  _Bubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.color,
    required this.speed,
    required this.wobbleOffset,
  });
}

/// Data class for a pop animation.
class _PopAnimation {
  final double x;
  final double y;
  final Color color;
  final double radius;
  final AnimationController controller;

  _PopAnimation({
    required this.x,
    required this.y,
    required this.color,
    required this.radius,
    required this.controller,
  });
}

/// Widget that renders a single bubble with a shiny gradient.
class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;

  const _BubbleWidget({required this.bubble});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: bubble.radius * 2,
      height: bubble.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            bubble.color.withValues(alpha: 0.6),
            bubble.color.withValues(alpha: 0.9),
            bubble.color,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: bubble.color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Shine highlight
      child: Align(
        alignment: const Alignment(-0.35, -0.35),
        child: Container(
          width: bubble.radius * 0.5,
          height: bubble.radius * 0.4,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// Widget that renders the pop/burst animation.
class _PopWidget extends StatelessWidget {
  final _PopAnimation pop;

  const _PopWidget({required this.pop});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pop.controller,
      builder: (context, _) {
        final t = pop.controller.value;
        final scale = 1.0 + t * 1.5;
        final opacity = 1.0 - t;

        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: SizedBox(
              width: pop.radius * 2,
              height: pop.radius * 2,
              child: CustomPaint(
                painter: _BurstPainter(
                  color: pop.color,
                  progress: t,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter that draws expanding burst particles.
class _BurstPainter extends CustomPainter {
  final Color color;
  final double progress;

  _BurstPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 1.0 - progress)
      ..style = PaintingStyle.fill;

    // Draw burst particles radiating outward
    const particleCount = 8;
    for (var i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * pi;
      final distance = progress * size.width * 0.6;
      final particleSize = size.width * 0.12 * (1 - progress);

      final offset = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );

      canvas.drawCircle(offset, particleSize, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => true;
}
