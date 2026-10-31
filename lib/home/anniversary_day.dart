import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 08 · đúng ngày kỷ niệm. One 2.5s run drives everything: the heart pops in
/// over the flower's centre (0–0.6s) and beats twice (0.6–2s), the honey halo
/// fades in behind the flower, and paper confetti falls once.
abstract final class AnniversaryDay {
  static const duration = Duration(milliseconds: 2500);
  static const _ms = 2500.0;

  static final _pop = Interval(0, 600 / _ms, curve: Motion.easeBloom);
  static const _beats = Interval(600 / _ms, 2000 / _ms);

  static double heartScale(double t) {
    final beat = _beats.transform(t);
    // Two beats: 1 → 1.08 → 1, twice.
    return _pop.transform(t) * (1 + .08 * math.sin(beat * 2 * math.pi * 2).abs());
  }

  static double haloOpacity(double t) => .55 * _pop.transform(t).clamp(0, 1);
}

/// A filled heart, drawn around the flower's centre.
class HeartPainter extends CustomPainter {
  HeartPainter(this.run) : super(repaint: run);

  final Animation<double> run;

  static final _heart = Path()
    ..moveTo(50, 90)
    ..cubicTo(10, 65, 0, 35, 22, 20)
    ..cubicTo(37, 10, 50, 22, 50, 32)
    ..cubicTo(50, 22, 63, 10, 78, 20)
    ..cubicTo(100, 35, 90, 65, 50, 90)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final s = AnniversaryDay.heartScale(run.value);
    if (s <= 0) return;
    canvas
      ..translate(size.width / 2, size.height / 2)
      ..scale(s * size.width / 100)
      ..translate(-50, -52)
      ..drawPath(_heart, Paint()..color = Sakura.c6)
      ..drawPath(
        _heart,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Sakura.c7,
      );
  }

  @override
  bool shouldRepaint(HeartPainter old) => old.run != run;
}

/// Up to 40 paper bits falling once across the screen.
class ConfettiPainter extends CustomPainter {
  ConfettiPainter(this.run) : super(repaint: run);

  final Animation<double> run;

  static const _colors = [Sakura.c4, Sage.c2, Pollen.c2, Sakura.c2];

  /// Fixed seed: the same fall every time, decided once.
  static final _bits = () {
    final r = math.Random(30102022);
    return [
      for (var i = 0; i < 40; i++)
        (
          x: r.nextDouble(),
          delay: r.nextDouble() * .3,
          speed: .8 + r.nextDouble() * .5,
          sway: (r.nextDouble() - .5) * 60,
          spin: (r.nextDouble() - .5) * 12,
          color: _colors[i % _colors.length],
        ),
    ];
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = run.value;
    if (t <= 0 || t >= 1) return;
    final paint = Paint();
    for (final b in _bits) {
      final p = ((t - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
      if (p == 0) continue;
      final y = -20 + p * b.speed * (size.height + 40);
      final x = b.x * size.width + math.sin(p * math.pi * 2) * b.sway;
      paint.color = b.color.withValues(alpha: (1 - p) * .9 + .1);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p * b.spin)
        ..drawRect(const Rect.fromLTWH(-3, -5, 6, 10), paint)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => old.run != run;
}
