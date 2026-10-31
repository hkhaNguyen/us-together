import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'moment_card.dart';
import 'polaroid_stack.dart';
import 'timeline.dart';

enum Side { left, right }

/// Positions on the mobile home page, scaled from the 390px design.
class TimelineMetrics {
  TimelineMetrics(this.width) : stemX = width * 150 / 390;

  final double width;
  final double stemX;

  static const flowerY = 200.0;
  static const flowerSize = 126.0;

  /// The stem is drawn in segments this tall, starting at the flower.
  static const segment = 250.0;

  double get cardLeft => stemX + 46;
  double get cardWidth => width - cardLeft - 22;
  double get polaroidLeft => stemX - 126;

  /// Each segment has its control points at a third and two thirds of its
  /// height, so y is linear in t and the stem's x at any y is exact.
  double stemXAt(double y) {
    final t = ((y - flowerY) % segment) / segment;
    return stemX + 24 * t * (1 - t) * (1 - 2 * t);
  }

  Path stemPath(double bottom) {
    final path = Path()..moveTo(stemX, flowerY);
    for (var y = flowerY; y < bottom; y += segment) {
      path.cubicTo(stemX + 8, y + segment / 3, stemX - 8, y + segment * 2 / 3, stemX, y + segment);
    }
    return path;
  }
}

class PlacedEntry {
  const PlacedEntry({
    required this.entry,
    required this.side,
    required this.rect,
    required this.branchStart,
    required this.rotation,
    required this.leaves,
  });

  final TimelineEntry entry;
  final Side side;
  final Rect rect;

  /// Where the branch leaves the stem.
  final Offset branchStart;

  /// Resting tilt in radians.
  final double rotation;

  /// 1 or 2 leaves on the branch.
  final int leaves;
}

class MonthMarker {
  const MonthMarker({required this.month, required this.y, required this.newYear});

  final DateTime month;
  final double y;

  /// First marker of a new year also gets a big leaf on the stem.
  final bool newYear;
}

class TimelineLayout {
  const TimelineLayout({required this.metrics, required this.placed, required this.markers, required this.stemBottom});

  final TimelineMetrics metrics;
  final List<PlacedEntry> placed;
  final List<MonthMarker> markers;
  final double stemBottom;

  double get height => stemBottom + 80;
}

const branchSpacing = 120.0;
const _sideGap = 24.0;
const markerHeight = 26.0;

/// Where the branch meets the stem, measured from the item's top.
const _branchOffset = {Side.right: 94.0, Side.left: 60.0};

/// Lays [entries] (newest first) down the stem: moments on the right, photo
/// stacks on the left. Items on opposite sides may overlap vertically, but
/// branches stay at least [branchSpacing] apart. A month marker goes on the
/// stem wherever the month changes, below the newest month's items.
TimelineLayout layoutTimeline(
  List<TimelineEntry> entries,
  double width, {
  required TextScaler textScaler,
  required TextStyle momentTitleStyle,
}) {
  final m = TimelineMetrics(width);
  // The upcoming note sits above the right column, the flower above the left.
  final nextTop = {Side.right: 236.0, Side.left: 290.0};
  var lastBranchY = -double.infinity;
  final placed = <PlacedEntry>[];
  final markers = <MonthMarker>[];
  DateTime? month;

  for (final e in entries) {
    final eMonth = DateTime(e.date.year, e.date.month);
    if (month != null && eMonth != month) {
      final y = [nextTop[Side.right]!, nextTop[Side.left]!, lastBranchY + 40].reduce(math.max);
      markers.add(MonthMarker(month: eMonth, y: y, newYear: eMonth.year != month.year));
      nextTop[Side.right] = nextTop[Side.left] = y + markerHeight + 16;
    }
    month = eMonth;

    final side = e is MomentEntry ? Side.right : Side.left;
    final offset = _branchOffset[side]!;
    final top = math.max(nextTop[side]!, lastBranchY + branchSpacing - offset);
    final size = switch (e) {
      MomentEntry() => Size(m.cardWidth, MomentCard.heightFor(e, width: m.cardWidth, textScaler: textScaler, titleStyle: momentTitleStyle)),
      PhotoStackEntry() => Size(PolaroidStack.width, PolaroidStack.heightFor(textScaler)),
    };
    final left = side == Side.right ? m.cardLeft : m.polaroidLeft;
    final branchY = top + offset;

    placed.add(PlacedEntry(
      entry: e,
      side: side,
      rect: Offset(left, top) & size,
      branchStart: Offset(m.stemXAt(branchY), branchY),
      rotation: _rotation(e),
      leaves: _unit('${e.id}#') > .5 ? 2 : 1,
    ));
    nextTop[side] = top + size.height + _sideGap;
    lastBranchY = branchY;
  }

  final contentBottom = [nextTop[Side.right]!, nextTop[Side.left]!, lastBranchY + branchSpacing].reduce(math.max);
  final segments = ((contentBottom - TimelineMetrics.flowerY) / TimelineMetrics.segment).ceil();
  return TimelineLayout(
    metrics: m,
    placed: placed,
    markers: markers,
    stemBottom: TimelineMetrics.flowerY + segments * TimelineMetrics.segment,
  );
}

/// Stable 0..1 value per id, so tilts don't change between launches.
double _unit(String s) {
  var h = 7;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x3FFFFFFF;
  }
  return h / 0x3FFFFFFF;
}

const _deg = math.pi / 180;

/// Cards tilt −1.5°…1.5°, polaroids 3–6° either way.
double _rotation(TimelineEntry e) => switch (e) {
      MomentEntry() => (_unit(e.id) * 2 - 1) * 1.5 * _deg,
      PhotoStackEntry() => (_unit('${e.id}~') > .5 ? 1 : -1) * (3 + _unit(e.id) * 3) * _deg,
    };
