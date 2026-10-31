import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import '../theme/tokens.dart';
import 'timeline_layout.dart';

/// Branch and leaf shapes from the SVG assets, for a right-side branch with
/// its root at the origin. Left branches are drawn mirrored.
abstract final class BranchShapes {
  static final branch = Path()
    ..moveTo(0, 0)
    ..cubicTo(19, -4, 37, -12, 53, -28);
  static final branchMetric = branch.computeMetrics().first;

  /// Leaf pointing up along the branch, and an optional one hanging below.
  static final leafUp = Path()
    ..moveTo(25, -8)
    ..cubicTo(15, -22, 19, -38, 35, -40)
    ..cubicTo(41, -24, 37, -12, 25, -8)
    ..close();
  static const leafUpBase = Offset(25, -8);
  static final leafDown = Path()
    ..moveTo(15, 0)
    ..cubicTo(9, 12, 15, 24, 29, 24)
    ..cubicTo(33, 12, 27, 2, 15, 0)
    ..close();
  static const leafDownBase = Offset(15, 0);

  /// Area the branch and its leaves can cover, relative to the root.
  static const bounds = Rect.fromLTRB(0, -42, 56, 26);

  static final ink = Paint()
    ..color = Paper.c8
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final leafFill = Paint()..color = Sage.c2;

  static void drawLeaf(Canvas canvas, Path leaf, Offset base, double scale) {
    if (scale <= 0) return;
    canvas
      ..save()
      ..translate(base.dx, base.dy)
      ..scale(scale)
      ..translate(-base.dx, -base.dy)
      ..drawPath(leaf, leafFill)
      ..drawPath(leaf, ink..strokeWidth = 1)
      ..restore();
  }
}

/// The main stem from the flower down, already fully grown, plus the big
/// leaf that marks each new year.
class StemPainter extends CustomPainter {
  StemPainter(this.layout, {this.tip}) : super(repaint: tip);

  final TimelineLayout layout;

  /// In "xem từ đầu": the stem only grows from the pot up to this y.
  final ValueListenable<double>? tip;

  @override
  void paint(Canvas canvas, Size size) {
    final m = layout.metrics;
    final top = math.max(TimelineMetrics.flowerY, tip?.value ?? 0);
    final path = m.stemPath(layout.stemBottom);
    final ink = BranchShapes.ink..strokeWidth = 2.4;
    if (top <= TimelineMetrics.flowerY) {
      canvas.drawPath(path, ink);
    } else {
      // The stem is nearly vertical, so length along it tracks height.
      final metric = path.computeMetrics().first;
      final grown =
          ((layout.stemBottom - top) /
                  (layout.stemBottom - TimelineMetrics.flowerY))
              .clamp(0.0, 1.0);
      canvas.drawPath(
        metric.extractPath(metric.length * (1 - grown), metric.length),
        ink,
      );
    }
    _paintPot(canvas, m.stemX, layout.stemBottom);

    for (final marker in layout.markers.where((k) => k.newYear && k.y >= top)) {
      final y = marker.y + markerHeight / 2;
      canvas
        ..save()
        ..translate(m.stemXAt(y), y)
        ..scale(-1.8, 1.8) // mirrored to the left, opposite the marker
        ..translate(-BranchShapes.leafUpBase.dx, -BranchShapes.leafUpBase.dy);
      BranchShapes.drawLeaf(
        canvas,
        BranchShapes.leafUp,
        BranchShapes.leafUpBase,
        1,
      );
      canvas.restore();
    }
  }

  /// Hand-drawn clay pot the stem grows out of, with two small leaves at its
  /// foot.
  static void _paintPot(Canvas canvas, double x, double soil) {
    final ink = BranchShapes.ink..strokeWidth = 1.6;
    for (final dir in [-1.0, 1.0]) {
      canvas
        ..save()
        ..translate(x, soil - 14)
        ..scale(dir * .8, .8)
        ..translate(-BranchShapes.leafUpBase.dx, -BranchShapes.leafUpBase.dy);
      BranchShapes.drawLeaf(
        canvas,
        BranchShapes.leafUp,
        BranchShapes.leafUpBase,
        1,
      );
      canvas.restore();
    }

    final rim = RRect.fromRectAndRadius(
      Rect.fromLTRB(x - 52, soil, x + 52, soil + 16),
      const Radius.circular(4),
    );
    final body = Path()
      ..moveTo(x - 45, soil + 16)
      ..lineTo(x + 45, soil + 16)
      ..lineTo(x + 33, soil + TimelineMetrics.potHeight - 4)
      ..quadraticBezierTo(
        x + 32,
        soil + TimelineMetrics.potHeight,
        x + 28,
        soil + TimelineMetrics.potHeight,
      )
      ..lineTo(x - 28, soil + TimelineMetrics.potHeight)
      ..quadraticBezierTo(
        x - 32,
        soil + TimelineMetrics.potHeight,
        x - 33,
        soil + TimelineMetrics.potHeight - 4,
      )
      ..close();
    canvas
      ..drawPath(body, Paint()..color = Paper.c6)
      ..drawPath(body, ink)
      // A soft light stripe down the pot.
      ..drawLine(
        Offset(x - 30, soil + 24),
        Offset(x - 24, soil + TimelineMetrics.potHeight - 10),
        Paint()
          ..color = Paper.c4.withValues(alpha: .7)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      )
      ..drawRRect(rim, Paint()..color = Paper.c5)
      ..drawRRect(rim, ink)
      // Soil showing inside the rim.
      ..drawOval(
        Rect.fromLTRB(x - 44, soil - 3, x + 44, soil + 5),
        Paint()..color = Paper.c8,
      );
  }

  @override
  bool shouldRepaint(StemPainter old) => old.layout != layout || old.tip != tip;
}
