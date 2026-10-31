import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/tokens.dart';

/// The five-petal cherry blossom at the top of the stem.
///
/// [bloom] runs 0 → 1 over the whole open sequence; each part takes its own
/// slice of it, so the same painter serves the quick open-app bloom and the
/// slow "xem từ đầu" bloom — only the controller's duration differs.
class SakuraFlower extends StatelessWidget {
  const SakuraFlower({super.key, required this.bloom, this.size = 200});

  final Animation<double> bloom;
  final double size;

  /// Sequence length the slices below are measured against: petals stagger
  /// 40ms over 600ms, stamens follow 150ms after the last petal, center last.
  static const openDuration = Duration(milliseconds: 900);

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SakuraPainter(bloom)),
    );
  }
}

class _SakuraPainter extends CustomPainter {
  _SakuraPainter(this.bloom) : super(repaint: bloom);

  final Animation<double> bloom;

  // Slices of the 900ms sequence, in ms.
  static const _total = 900.0;
  static Interval _slice(double startMs, double lengthMs, Curve curve) =>
      Interval(startMs / _total, (startMs + lengthMs) / _total, curve: curve);

  static final _petals = [for (var i = 0; i < 5; i++) _slice(40.0 * i, 600, Motion.easeBloom)];
  static final _petalFade = [for (var i = 0; i < 5; i++) _slice(40.0 * i, 240, Curves.linear)];
  static final _stamens = _slice(310, 400, Motion.easeGrow);
  static final _anthers = _slice(450, 350, Motion.easeBloom);
  static final _center = _slice(600, 300, Motion.easeBloom);

  // Geometry in the 300×300 box of the SVG asset.
  static const _c = Offset(150, 150);
  static final _petalPath = Path()
    ..moveTo(150, 150)
    ..cubicTo(116, 136, 104, 86, 128, 54)
    ..cubicTo(137, 42, 145, 46, 150, 62)
    ..cubicTo(155, 46, 163, 42, 172, 54)
    ..cubicTo(196, 86, 184, 136, 150, 150)
    ..close();
  static final _petalFill = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(150, 150),
      const Offset(150, 46),
      const [Sakura.c3, Sakura.c2, Sakura.c1],
      const [0, .55, 1],
    );
  static final _petalStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..color = Sakura.petalStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final t = bloom.value;
    canvas.scale(size.width / 300);

    for (var i = 0; i < 5; i++) {
      final opacity = _petalFade[i].transform(t);
      if (opacity == 0) continue;
      final scale = .6 + .4 * _petals[i].transform(t);
      canvas.save();
      canvas
        ..translate(_c.dx, _c.dy)
        ..rotate(i * 72 * math.pi / 180)
        ..scale(scale)
        ..translate(-_c.dx, -_c.dy);
      if (opacity < 1) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
      canvas
        ..drawPath(_petalPath, _petalFill)
        ..drawPath(_petalPath, _petalStroke);
      if (opacity < 1) canvas.restore();
      canvas.restore();
    }

    final reach = _stamens.transform(t);
    if (reach > 0) {
      final line = Paint()
        ..color = Sakura.c6
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round;
      final antherFill = Paint()..color = Pollen.c2;
      final antherStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Sakura.c7;
      final antherR = 6 * _anthers.transform(t);
      for (var i = 0; i < 8; i++) {
        final a = -math.pi / 2 + i * math.pi / 4;
        final tip = _c + Offset(math.cos(a), math.sin(a)) * 70 * reach;
        canvas.drawLine(_c, tip, line);
        if (antherR > 0) {
          canvas
            ..drawCircle(tip, antherR, antherFill)
            ..drawCircle(tip, antherR, antherStroke);
        }
      }
    }

    final centerR = 18 * _center.transform(t);
    if (centerR > 0) {
      canvas
        ..drawCircle(_c, centerR, Paint()..color = Sakura.c6)
        ..drawCircle(
          _c,
          centerR,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = Sakura.c7,
        );
    }
  }

  @override
  bool shouldRepaint(_SakuraPainter old) => old.bloom != bloom;
}
