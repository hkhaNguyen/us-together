import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'stem.dart';
import 'timeline_layout.dart';

/// Items that already sprouted this session stay grown when scrolled past
/// again.
final _sprouted = <String>{};

/// One item on the stem: its branch, leaves and card. The first time the
/// item reaches 70% of the viewport the branch draws out, the leaves unfold,
/// then the card opens from the branch root (moments) or drops onto the page
/// and gets taped (photo stacks).
///
/// Builds a [Positioned], so it must be a direct child of the timeline Stack.
class Sprout extends StatefulWidget {
  const Sprout({super.key, required this.placed, required this.scroll, required this.builder});

  final PlacedEntry placed;
  final ScrollController scroll;

  /// Builds the card; `tape` runs 0 → 1 once the card has landed.
  final Widget Function(BuildContext context, Animation<double> tape) builder;

  @override
  State<Sprout> createState() => _SproutState();
}

class _SproutState extends State<Sprout> with SingleTickerProviderStateMixin {
  static const _ms = 600.0;
  static Interval _at(double start, double length, Curve curve) => Interval(start / _ms, (start + length) / _ms, curve: curve);

  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final _branch = CurvedAnimation(parent: _c, curve: _at(0, 250, Motion.easeGrow));
  late final _leaves = [for (var i = 0; i < 2; i++) CurvedAnimation(parent: _c, curve: _at(170 + 80.0 * i, 200, Motion.easeBloom))];
  late final _card = CurvedAnimation(parent: _c, curve: _at(250, 350, Motion.easePaper));
  late final _tape = CurvedAnimation(parent: _c, curve: _at(370, 230, Curves.linear));

  String get _id => widget.placed.entry.id;

  @override
  void initState() {
    super.initState();
    if (_sprouted.contains(_id)) {
      _c.value = 1;
    } else {
      widget.scroll.addListener(_check);
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_c.isCompleted) _sprout(instant: true);
  }

  void _check() {
    if (!mounted || !widget.scroll.hasClients) return;
    final pos = widget.scroll.position;
    if (widget.placed.rect.top < pos.pixels + pos.viewportDimension * .7) _sprout();
  }

  void _sprout({bool instant = false}) {
    widget.scroll.removeListener(_check);
    _sprouted.add(_id);
    if (instant) {
      _c.value = 1;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_check);
    for (final a in [_branch, ..._leaves, _card, _tape]) {
      a.dispose();
    }
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.placed;
    final right = p.side == Side.right;
    final b = BranchShapes.bounds;
    final branchArea = (right ? b : Rect.fromLTRB(-b.right, b.top, -b.left, b.bottom)).shift(p.branchStart);
    final area = p.rect.expandToInclude(branchArea);
    final card = p.rect.shift(-area.topLeft);
    final root = p.branchStart - area.topLeft;

    return Positioned.fromRect(
      rect: area,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BranchPainter(root: root, mirrored: !right, leafCount: p.leaves, branch: _branch, leaves: _leaves, repaint: _c),
            ),
          ),
          Positioned.fromRect(
            rect: card,
            child: AnimatedBuilder(
              animation: _card,
              builder: (context, child) {
                final t = _card.value;
                final fade = (t * 2).clamp(0.0, 1.0);
                if (right) {
                  final s = .9 + .1 * t;
                  return Opacity(
                    opacity: fade,
                    child: Transform(
                      origin: root - card.topLeft,
                      transform: Matrix4.diagonal3Values(s, s, 1),
                      child: Transform.rotate(angle: p.rotation, child: child),
                    ),
                  );
                }
                final from = p.rotation.sign * 8 * math.pi / 180;
                return Opacity(
                  opacity: fade,
                  child: Transform.translate(
                    offset: Offset(0, -12 * (1 - t)),
                    child: Transform.rotate(angle: from + (p.rotation - from) * t, child: child),
                  ),
                );
              },
              child: widget.builder(context, _tape),
            ),
          ),
        ],
      ),
    );
  }
}

class _BranchPainter extends CustomPainter {
  _BranchPainter({
    required this.root,
    required this.mirrored,
    required this.leafCount,
    required this.branch,
    required this.leaves,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Offset root;
  final bool mirrored;
  final int leafCount;
  final Animation<double> branch;
  final List<Animation<double>> leaves;

  @override
  void paint(Canvas canvas, Size size) {
    final t = branch.value;
    if (t <= 0) return;
    canvas.translate(root.dx, root.dy);
    if (mirrored) canvas.scale(-1, 1);

    final metric = BranchShapes.branchMetric;
    canvas.drawPath(metric.extractPath(0, metric.length * t), BranchShapes.ink..strokeWidth = 1.6);
    BranchShapes.drawLeaf(canvas, BranchShapes.leafUp, BranchShapes.leafUpBase, leaves[0].value);
    if (leafCount > 1) BranchShapes.drawLeaf(canvas, BranchShapes.leafDown, BranchShapes.leafDownBase, leaves[1].value);
  }

  @override
  bool shouldRepaint(_BranchPainter old) => old.root != root || old.mirrored != mirrored || old.leafCount != leafCount;
}
