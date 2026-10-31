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
/// blooming flower.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.journal,
    required this.meId,
    required this.onSetStartDate,
    required this.onSignOut,
  });

  final Journal journal;

  /// Who is using this device.
  final String meId;

  /// Saves "ngày bắt đầu yêu", the source of the days-together count.
  final Future<void> Function(DateTime date) onSetStartDate;
  final Future<void> Function() onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  static const _maxWidth = 480.0;

  final _scroll = ScrollController();
  late final _bloom = AnimationController(vsync: this, duration: SakuraFlower.openDuration);
  late List<TimelineEntry> _entries = buildTimeline(widget.journal);

  @override
  void initState() {
    super.initState();
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
    _bloom.dispose();
    super.dispose();
  }

  Future<void> _openProfileMenu(BuildContext button) async {
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final box = button.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: const [PopupMenuItem(value: 'sign-out', child: Text('Đăng xuất'))],
    );
    if (choice == 'sign-out') await widget.onSignOut();
  }

  Future<void> _pickStartDate() async {
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      helpText: 'Ngày bắt đầu yêu',
      initialDate: today,
      firstDate: DateTime(1990),
      lastDate: today,
    );
    if (date != null) await widget.onSetStartDate(date);
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
      body: LayoutBuilder(builder: (context, constraints) {
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
                  ..._paperGlow(m.stemX),
                  Positioned.fill(child: CustomPaint(painter: StemPainter(layout))),
                  for (final marker in layout.markers)
                    Positioned(left: m.stemX + 10, top: marker.y, height: markerHeight, child: _MonthMarker(marker.month)),
                  for (final p in layout.placed)
                    Sprout(
                      key: ValueKey(p.entry.id),
                      placed: p,
                      scroll: _scroll,
                      builder: (context, tape) => switch (p.entry) {
                        final MomentEntry e => MomentCard(entry: e),
                        final PhotoStackEntry e => PolaroidStack(entry: e, tape: tape),
                      },
                    ),
                  Positioned(
                    left: m.stemX - half,
                    top: fy - half,
                    child: SakuraFlower(bloom: _bloom, size: TimelineMetrics.flowerSize),
                  ),
                  if (upcoming != null)
                    Positioned(
                      left: m.stemX + 76,
                      top: 136,
                      child: _UpcomingNote(
                        title: upcoming.anniversary.titleOn(today.add(Duration(days: upcoming.days))),
                        days: upcoming.days,
                      ),
                    ),
                  Positioned(
                    left: 24,
                    right: 24,
                    top: math.max(52, safe.top + 12),
                    child: _Header(
                      today: today,
                      days: journal.daysTogether(today),
                      me: me,
                      onPickStartDate: _pickStartDate,
                      onProfile: _openProfileMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.today, required this.days, required this.me, required this.onPickStartDate, required this.onProfile});

  final DateTime today;

  /// null until the start date is set.
  final int? days;
  final Person me;
  final VoidCallback onPickStartDate;
  final ValueChanged<BuildContext> onProfile;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    final days = this.days;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('hôm nay, ${dotDate(today)}', style: AppText.script.copyWith(fontSize: 20)),
              if (days == null)
                TextButton(
                  onPressed: onPickStartDate,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Paper.c8),
                  child: Text('đặt ngày bắt đầu yêu', style: AppText.h1.copyWith(fontSize: 22, decoration: TextDecoration.underline)),
                )
              else
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
        Builder(
          builder: (button) => IconButton(
            tooltip: 'Trang cá nhân',
            onPressed: () => onProfile(button),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(44),
              backgroundColor: me.color,
              side: const BorderSide(color: Sakura.c2, width: 3),
              padding: EdgeInsets.zero,
            ),
            icon: Text(me.name.characters.first, style: AppText.title.copyWith(color: Paper.c1, fontWeight: FontWeight.w400)),
          ),
        ),
      ],
    );
  }
}

class _UpcomingNote extends StatelessWidget {
  const _UpcomingNote({required this.title, required this.days});

  final String title;
  final int days;

  @override
  Widget build(BuildContext context) {
    final isToday = days == 0;
    return Transform.rotate(
      angle: 2 * math.pi / 180,
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

/// Soft light and a pink haze behind the flower, as in the design. Each is a
/// circle that fades out inside itself, so it never shows an edge — not even
/// where it spills past the content column on a wide screen.
List<Widget> _paperGlow(double stemX) => [
      _glow(Offset(stemX - 33, 84), 323, const Color(0x66FFFFFF)),
      _glow(Offset(stemX + 6, TimelineMetrics.flowerY), 205, const Color(0x38F39BB5)),
    ];

Widget _glow(Offset center, double radius, Color color) => Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(radius: .5, colors: [color, color.withValues(alpha: 0)]),
          ),
        ),
      ),
    );
