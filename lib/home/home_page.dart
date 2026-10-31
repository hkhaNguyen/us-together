import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/models.dart';
import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/sakura_flower.dart';
import 'moment_card.dart';
import 'polaroid_stack.dart';
import 'sprout.dart';
import 'stem.dart';
import 'timeline.dart';
import 'timeline_layout.dart';

/// 02 · Trang chủ: the stem as a timeline, newest at the top under a
/// blooming flower whose center is the "+" button.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.journal, required this.meId});

  final Journal journal;

  /// Who is using this device.
  final String meId;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const _maxWidth = 480.0;

  final _scroll = ScrollController();
  final _plusFloating = ValueNotifier(false);
  late final _bloom = AnimationController(vsync: this, duration: SakuraFlower.openDuration);

  /// The center appears last in the bloom; the "+" with it.
  late final _plusIn = CurvedAnimation(parent: _bloom, curve: const Interval(.67, 1));
  late List<TimelineEntry> _entries = buildTimeline(widget.journal);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _plusFloating.value = _scroll.offset > TimelineMetrics.flowerY + TimelineMetrics.flowerSize / 2);
    _bloom.forward();
    // Card heights are measured with the real title font; lay out again
    // once it has downloaded.
    GoogleFonts.pendingFonts([MomentCard.titleStyle]).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _bloom.value = 1;
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    if (old.journal != widget.journal) _entries = buildTimeline(widget.journal);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _plusFloating.dispose();
    _plusIn.dispose();
    _bloom.dispose();
    super.dispose();
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Màn này làm ở phase sau')));
  }

  Future<void> _openAddMenu(BuildContext button) async {
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final box = button.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(value: 'photo', child: Text('Thêm ảnh')),
        PopupMenuItem(value: 'moment', child: Text('Thêm dịp')),
      ],
    );
    if (choice != null) _soon();
  }

  @override
  Widget build(BuildContext context) {
    final journal = widget.journal;
    final today = DateTime.now();
    final me = journal.person(widget.meId);
    final upcoming = journal.upcoming(today);
    final safe = MediaQuery.paddingOf(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, _maxWidth);
            final layout = layoutTimeline(_entries, width, textScaler: textScaler, momentTitleStyle: MomentCard.titleStyle);
            final m = layout.metrics;
            const fy = TimelineMetrics.flowerY;
            const half = TimelineMetrics.flowerSize / 2;

            return SingleChildScrollView(
              controller: _scroll,
              child: Center(
                child: SizedBox(
                  width: width,
                  height: layout.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(top: 0, left: 0, right: 0, height: 520, child: IgnorePointer(child: _PaperGlow())),
                      Positioned.fill(child: CustomPaint(painter: StemPainter(layout))),
                      for (final marker in layout.markers)
                        Positioned(left: m.stemX + 10, top: marker.y, height: markerHeight, child: _MonthMarker(marker.month)),
                      for (final p in layout.placed)
                        Sprout(
                          key: ValueKey(p.entry.id),
                          placed: p,
                          scroll: _scroll,
                          builder: (context, tape) => switch (p.entry) {
                            final MomentEntry e => MomentCard(entry: e, onTap: _soon),
                            final PhotoStackEntry e => PolaroidStack(entry: e, tape: tape, onTap: _soon),
                          },
                        ),
                      Positioned(
                        left: m.stemX - half,
                        top: fy - half,
                        child: SakuraFlower(bloom: _bloom, size: TimelineMetrics.flowerSize),
                      ),
                      Positioned(
                        left: m.stemX - 24,
                        top: fy - 24,
                        child: FadeTransition(
                          opacity: _plusIn,
                          child: _PlusButton(size: 28, color: Sakura.c6, onPressed: _openAddMenu),
                        ),
                      ),
                      if (upcoming != null)
                        Positioned(
                          left: m.stemX + 76,
                          top: 136,
                          child: _UpcomingNote(title: upcoming.anniversary.title, days: upcoming.days, onTap: _soon),
                        ),
                      Positioned(
                        left: 24,
                        right: 24,
                        top: math.max(52, safe.top + 12),
                        child: _Header(today: today, days: journal.daysTogether(today), me: me, onCalendar: _soon, onProfile: _soon),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Positioned(
            right: 20,
            bottom: 20 + safe.bottom,
            child: ValueListenableBuilder(
              valueListenable: _plusFloating,
              builder: (context, floating, child) => IgnorePointer(
                ignoring: !floating,
                child: AnimatedScale(scale: floating ? 1 : 0, duration: Motion.dur2, curve: Motion.easePaper, child: child),
              ),
              child: _PlusButton(size: 56, color: Sakura.c5, onPressed: _openAddMenu),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.days, required this.me, required this.onCalendar, required this.onProfile});

  final DateTime today;
  final int days;
  final Person me;
  final VoidCallback onCalendar;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('hôm nay, ${dotDate(today)}', style: AppText.script.copyWith(fontSize: 20)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  TweenAnimationBuilder(
                    tween: IntTween(begin: still ? days : 0, end: days),
                    duration: const Duration(milliseconds: 1200),
                    curve: Motion.easePaper,
                    builder: (context, value, _) => Text(thousands(value), style: AppText.display.copyWith(height: 1)),
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: Text('NGÀY BÊN NHAU', style: AppText.label.copyWith(letterSpacing: 11 * .14))),
                ],
              ),
            ],
          ),
        ),
        _CircleButton(
          tooltip: 'Ngày kỷ niệm',
          color: Paper.c1,
          side: const BorderSide(color: Paper.c5),
          onPressed: onCalendar,
          child: const Icon(Icons.event_outlined, size: 18, color: Paper.c8),
        ),
        const SizedBox(width: 8),
        _CircleButton(
          tooltip: 'Trang cá nhân',
          color: me.color,
          side: const BorderSide(color: Sakura.c2, width: 3),
          onPressed: onProfile,
          child: Text(me.name.characters.first, style: AppText.title.copyWith(color: Paper.c1, fontWeight: FontWeight.w400)),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.tooltip, required this.color, required this.side, required this.onPressed, required this.child});

  final String tooltip;
  final Color color;
  final BorderSide side;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(fixedSize: const Size.square(44), backgroundColor: color, side: side, padding: EdgeInsets.zero),
      icon: child,
    );
  }
}

/// The "+" — flower center (28px) at the top, floating (56px) further down.
/// The tap area is at least 48px either way.
class _PlusButton extends StatelessWidget {
  const _PlusButton({required this.size, required this.color, required this.onPressed});

  final double size;
  final Color color;
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (button) => IconButton(
        tooltip: 'Thêm mới',
        onPressed: () => onPressed(button),
        style: IconButton.styleFrom(fixedSize: Size.square(math.max(48, size)), padding: EdgeInsets.zero),
        icon: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Sakura.c7, width: 1.5),
            boxShadow: Shadows.pink,
          ),
          child: Icon(Icons.add, size: size * .57, color: const Color(0xFFFFF5F8)),
        ),
      ),
    );
  }
}

class _UpcomingNote extends StatelessWidget {
  const _UpcomingNote({required this.title, required this.days, required this.onTap});

  final String title;
  final int days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isToday = days == 0;
    return Transform.rotate(
      angle: 2 * math.pi / 180,
      child: Semantics(
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.tape), boxShadow: Shadows.paperSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isToday ? 'HÔM NAY LÀ' : 'SẮP TỚI', style: AppText.label.copyWith(fontSize: 10, letterSpacing: 1)),
                Text(title, style: AppText.title.copyWith(fontSize: 13)),
                if (!isToday) Text('còn $days ngày', style: AppText.script.copyWith(fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrap of paper pinned to the stem where the month changes.
class _MonthMarker extends StatelessWidget {
  const _MonthMarker(this.month);

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.tape), boxShadow: Shadows.paperSm),
      child: Text(monthLabel(month), style: AppText.script.copyWith(fontSize: 14, height: 1)),
    );
  }
}

/// Soft light and a pink haze behind the flower, as in the design.
class _PaperGlow extends StatelessWidget {
  const _PaperGlow();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(-.4, -.8), radius: .8, colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)]),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(-.2, -.25), radius: .6, colors: [Color(0x38F39BB5), Color(0x00F39BB5)]),
          ),
        ),
      ],
    );
  }
}
