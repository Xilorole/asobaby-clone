import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app/baby_theme.dart';
import '../models/models.dart';
import 'game_renderer.dart';

/// A hide-and-seek (いないいないばあ) game for babies!
///
/// Cute animals hide behind colorful shapes on screen.
/// Baby taps a hiding spot to reveal the animal underneath
/// with a fun "peekaboo!" bounce animation. After a short
/// display the animal hides again and positions shuffle.
///
/// Config settings:
/// - `revealDurationMs` (int): how long the animal stays visible (default: 2000)
/// - `hidingSpots` (int): number of hiding spots on screen (default: 3)
/// - `backgroundColors` (List of String): hex background colors to cycle
/// - `hideColors` (List of String): hex colors for the hiding-spot shapes
class PeekabooRenderer extends GameRenderer {
  const PeekabooRenderer({
    required super.config,
    required super.assetBasePath,
    required super.isBundled,
  });

  @override
  Widget build(BuildContext context) {
    return _PeekabooGame(
      config: config,
      assetBasePath: assetBasePath,
      isBundled: isBundled,
    );
  }
}

// ─── Data ──────────────────────────────────────────────────────────

class _HidingSpot {
  final Offset center; // fractional 0..1
  final double size; // fractional of screen width
  final Color color;
  final String animalAssetKey;
  final int shapeType; // 0=circle, 1=roundedRect, 2=star
  bool revealed = false;

  _HidingSpot({
    required this.center,
    required this.size,
    required this.color,
    required this.animalAssetKey,
    required this.shapeType,
  });
}

// ─── Game Widget ───────────────────────────────────────────────────

class _PeekabooGame extends StatefulWidget {
  final GameConfig config;
  final String assetBasePath;
  final bool isBundled;

  const _PeekabooGame({
    required this.config,
    required this.assetBasePath,
    required this.isBundled,
  });

  @override
  State<_PeekabooGame> createState() => _PeekabooGameState();
}

class _PeekabooGameState extends State<_PeekabooGame>
    with TickerProviderStateMixin {
  final Random _random = Random();
  late List<_HidingSpot> _spots;
  late Color _bgColor;

  // Animation controllers per spot index
  final Map<int, AnimationController> _revealControllers = {};
  final Map<int, AnimationController> _wobbleControllers = {};

  // Animal asset keys extracted from config
  late List<String> _animalKeys;

  int get _spotCount => (widget.config.settings['hidingSpots'] as int?) ?? 3;
  int get _revealMs =>
      (widget.config.settings['revealDurationMs'] as int?) ?? 2000;

  List<Color> get _bgColors {
    final list = widget.config.settings['backgroundColors'] as List?;
    if (list != null) {
      return list
          .map((c) => Color(int.parse((c as String).replaceFirst('#', '0xFF'))))
          .toList();
    }
    return const [
      Color(0xFFE8F8E8),
      Color(0xFFF8E8F8),
      Color(0xFFE8F0F8),
      Color(0xFFFFF8E0),
    ];
  }

  List<Color> get _hideColors {
    final list = widget.config.settings['hideColors'] as List?;
    if (list != null) {
      return list
          .map((c) => Color(int.parse((c as String).replaceFirst('#', '0xFF'))))
          .toList();
    }
    return BabyTheme.funColors;
  }

  @override
  void initState() {
    super.initState();

    // Collect animal asset keys from config
    _animalKeys = widget.config.assets.keys
        .where((k) => k.startsWith('animal_'))
        .toList();
    if (_animalKeys.isEmpty) {
      // Fallback — generate placeholder keys so the game still works
      _animalKeys = ['animal_fallback'];
    }

    _bgColor = _bgColors[_random.nextInt(_bgColors.length)];
    _spots = _generateSpots();
    _startIdleWobbles();
  }

  @override
  void dispose() {
    for (final c in _revealControllers.values) {
      c.dispose();
    }
    for (final c in _wobbleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Spot generation ────────────────────────────────────────────

  List<_HidingSpot> _generateSpots() {
    final spots = <_HidingSpot>[];
    final colors = _hideColors;
    final usedAnimals = <String>[];

    for (var i = 0; i < _spotCount; i++) {
      // Pick a non-repeating animal (if possible)
      String animal;
      if (usedAnimals.length >= _animalKeys.length) {
        animal = _animalKeys[_random.nextInt(_animalKeys.length)];
      } else {
        do {
          animal = _animalKeys[_random.nextInt(_animalKeys.length)];
        } while (usedAnimals.contains(animal));
      }
      usedAnimals.add(animal);

      spots.add(
        _HidingSpot(
          center: _randomCenter(i),
          size: 0.22 + _random.nextDouble() * 0.08, // 22-30% of width
          color: colors[i % colors.length],
          animalAssetKey: animal,
          shapeType: _random.nextInt(3),
        ),
      );
    }
    return spots;
  }

  Offset _randomCenter(int index) {
    // Distribute spots roughly evenly with some randomness
    final cols = (_spotCount <= 2) ? _spotCount : (_spotCount <= 4 ? 2 : 3);
    final rows = (_spotCount / cols).ceil();
    final col = index % cols;
    final row = index ~/ cols;

    final cellW = 1.0 / cols;
    final cellH = 1.0 / rows;

    // Center within cell ± jitter
    final cx = cellW * (col + 0.5) + (_random.nextDouble() - 0.5) * cellW * 0.3;
    final cy = cellH * (row + 0.5) + (_random.nextDouble() - 0.5) * cellH * 0.2;

    return Offset(cx.clamp(0.15, 0.85), cy.clamp(0.15, 0.75));
  }

  void _startIdleWobbles() {
    for (var i = 0; i < _spots.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 1200 + _random.nextInt(600)),
      )..repeat(reverse: true);
      _wobbleControllers[i] = ctrl;
    }
  }

  // ── Tap handling ───────────────────────────────────────────────

  void _onSpotTapped(int index) {
    if (_spots[index].revealed) return;

    setState(() => _spots[index].revealed = true);

    // Create reveal animation
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _revealControllers[index] = ctrl;

    // After reveal duration, hide again and reshuffle
    Future.delayed(Duration(milliseconds: _revealMs), () {
      if (!mounted) return;
      ctrl.reverse().then((_) {
        if (!mounted) return;
        ctrl.dispose();
        _revealControllers.remove(index);
        _reshuffle();
      });
    });
  }

  void _reshuffle() {
    // Dispose old wobble controllers
    for (final c in _wobbleControllers.values) {
      c.dispose();
    }
    _wobbleControllers.clear();

    setState(() {
      _bgColor = _bgColors[_random.nextInt(_bgColors.length)];
      _spots = _generateSpots();
    });

    _startIdleWobbles();
  }

  // ── Asset resolution ───────────────────────────────────────────

  Widget _buildAnimalImage(String assetKey, double sizePx) {
    final assetPath = widget.config.assets[assetKey];
    if (assetPath == null) {
      // Fallback emoji
      return Text(
        _fallbackEmoji(assetKey),
        style: TextStyle(fontSize: sizePx * 0.6),
      );
    }

    final fullPath = '${widget.assetBasePath}/$assetPath';

    if (widget.isBundled) {
      return Image.asset(
        fullPath,
        width: sizePx * 0.75,
        height: sizePx * 0.75,
        fit: BoxFit.contain,
        errorBuilder: (_, e1, s1) => Text(
          _fallbackEmoji(assetKey),
          style: TextStyle(fontSize: sizePx * 0.55),
        ),
      );
    } else {
      return Image.file(
        File(fullPath),
        width: sizePx * 0.75,
        height: sizePx * 0.75,
        fit: BoxFit.contain,
        errorBuilder: (_, e2, s2) => Text(
          _fallbackEmoji(assetKey),
          style: TextStyle(fontSize: sizePx * 0.55),
        ),
      );
    }
  }

  String _fallbackEmoji(String key) {
    if (key.contains('cat')) return '🐱';
    if (key.contains('dog')) return '🐶';
    if (key.contains('rabbit')) return '🐰';
    if (key.contains('bear')) return '🐻';
    if (key.contains('panda')) return '🐼';
    if (key.contains('penguin')) return '🐧';
    return '🐾';
  }

  // ── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      color: _bgColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          return Stack(
            children: [
              // Decorative background elements
              ..._buildBackgroundDecorations(w, h),

              // Hiding spots
              for (var i = 0; i < _spots.length; i++) _buildSpot(i, w, h),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBackgroundDecorations(double w, double h) {
    // Small pastel circles scattered in background
    return List.generate(6, (i) {
      final size = 20.0 + (i * 12.0);
      return Positioned(
        left: (i * 0.17 * w) % w,
        top: (i * 0.19 * h + 30) % h,
        child: Opacity(
          opacity: 0.15,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BabyTheme.funColors[i % BabyTheme.funColors.length],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSpot(int index, double screenW, double screenH) {
    final spot = _spots[index];
    final sizePx = spot.size * screenW;
    final left = spot.center.dx * screenW - sizePx / 2;
    final top = spot.center.dy * screenH - sizePx / 2;

    // Idle wobble
    final wobble = _wobbleControllers[index];
    // Reveal animation
    final reveal = _revealControllers[index];

    Widget child;

    if (spot.revealed && reveal != null) {
      // Show animal with bounce-in
      child = AnimatedBuilder(
        animation: reveal,
        builder: (context, _) {
          final t = Curves.elasticOut.transform(reveal.value);
          return Transform.scale(
            scale: t,
            child: _buildAnimalImage(spot.animalAssetKey, sizePx),
          );
        },
      );
    } else {
      // Show hiding shape with wobble
      child = wobble != null
          ? AnimatedBuilder(
              animation: wobble,
              builder: (context, c) {
                final t = wobble.value;
                final scale = 1.0 + sin(t * pi) * 0.06;
                final rotation = sin(t * pi * 2) * 0.05;
                return Transform.scale(
                  scale: scale,
                  child: Transform.rotate(angle: rotation, child: c),
                );
              },
              child: _HidingShape(
                color: spot.color,
                shapeType: spot.shapeType,
                size: sizePx,
              ),
            )
          : _HidingShape(
              color: spot.color,
              shapeType: spot.shapeType,
              size: sizePx,
            );
    }

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTapDown: (_) => _onSpotTapped(index),
        child: SizedBox(
          width: sizePx,
          height: sizePx,
          child: Center(child: child),
        ),
      ),
    );
  }
}

// ─── Hiding Shape Widget ───────────────────────────────────────────

class _HidingShape extends StatelessWidget {
  final Color color;
  final int shapeType;
  final double size;

  const _HidingShape({
    required this.color,
    required this.shapeType,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _ShapePainter(color: color, shapeType: shapeType),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final Color color;
  final int shapeType;

  _ShapePainter({required this.color, required this.shapeType});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    switch (shapeType) {
      case 0: // Circle
        canvas.drawCircle(center + const Offset(2, 4), r, shadowPaint);
        paint.shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            color.withValues(alpha: 0.8),
            color,
            color.withValues(alpha: 0.9),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
        canvas.drawCircle(center, r, paint);

        // Question mark
        _drawQuestionMark(canvas, center, r);
        break;

      case 1: // Rounded rectangle
        final rect = Rect.fromCenter(
          center: center,
          width: size.width * 0.9,
          height: size.height * 0.9,
        );
        final shadowRect = rect.shift(const Offset(2, 4));
        canvas.drawRRect(
          RRect.fromRectAndRadius(shadowRect, const Radius.circular(20)),
          shadowPaint,
        );
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.8)],
        ).createShader(rect);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(20)),
          paint,
        );
        _drawQuestionMark(canvas, center, r);
        break;

      case 2: // Star shape
        canvas.save();
        canvas.translate(2, 4);
        _drawStar(canvas, center, r * 0.9, shadowPaint);
        canvas.restore();

        paint.color = color;
        _drawStar(canvas, center, r * 0.9, paint);
        _drawQuestionMark(canvas, center, r * 0.7);
        break;
    }

    // Shine highlight
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(center.dx - r * 0.25, center.dy - r * 0.25),
      r * 0.18,
      shinePaint,
    );
  }

  void _drawQuestionMark(Canvas canvas, Offset center, double radius) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '?',
        style: TextStyle(
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w900,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final r = (i.isEven) ? radius : radius * 0.5;
      final angle = (i * pi / points) - pi / 2;
      final point = Offset(
        center.dx + cos(angle) * r,
        center.dy + sin(angle) * r,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShapePainter oldDelegate) =>
      color != oldDelegate.color || shapeType != oldDelegate.shapeType;
}
