import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../add/add_moment_sheet.dart';
import '../add/add_photos_sheet.dart';
import '../add/photo_pipeline.dart';
import '../add/shared_photos.dart';
import '../add/sheet_frame.dart';
import '../anniversaries/anniversaries_page.dart';
import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/push.dart';
import '../data/vi_format.dart';
import '../moment/moment_page.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../trash/trash_page.dart';
import '../viewer/photo_viewer.dart';
import '../widgets/avatar_cropper.dart';
import '../widgets/paper_bits.dart';
import '../widgets/sakura_flower.dart';
import 'anniversary_day.dart';
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
    required this.store,
    required this.session,
    required this.onSignOut,
  });

  final Journal journal;

  /// Who is using this device.
  final String meId;
  final JournalStore store;

  /// The live journal, handed to pages opened from here.
  final ValueListenable<Session?> session;
  final Future<void> Function() onSignOut;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  /// Wide enough for two columns of cards around the centred stem.
  static const _maxWidth = 560.0;

  final _scroll = ScrollController();
  late final _push = Push(widget.store);
  final _plusFloating = ValueNotifier(false);
  late final _bloom = AnimationController(
    vsync: this,
    duration: SakuraFlower.openDuration,
  );

  /// The flower's center appears last in the bloom; the "+" with it.
  late final _plusIn = CurvedAnimation(
    parent: _bloom,
    curve: const Interval(.67, 1),
  );
  late List<TimelineEntry> _entries = buildTimeline(widget.journal);

  /// Heart, halo and confetti on an anniversary; replayed by tapping the flower.
  late final _celebrate = AnimationController(
    vsync: this,
    duration: AnniversaryDay.duration,
  );

  bool get _isAnniversary =>
      widget.journal.anniversariesOn(DateTime.now()).isNotEmpty;

  /// "Xem từ đầu": the page starts at the pot with the stem shrunk to
  /// nothing; swiping up grows it back ([_tip] is its top) and every branch
  /// sprouts again in order. At the top the bud opens slowly with the heart.
  var _replay = false;
  var _replayEnding = false;
  var _heartAfterReplay = false;
  final _tip = ValueNotifier(double.infinity);

  /// The replay's last beat: the day count rises from behind the flower,
  /// stands big at the top, then hands back to the header.
  late final _finale = AnimationController(
    vsync: this,
    duration: _DaysFinale.duration,
  );

  @override
  void initState() {
    super.initState();
    // Once the flower scrolls away, the "+" floats bottom-right instead.
    _scroll.addListener(
      () => _plusFloating.value =
          _scroll.offset >
          TimelineMetrics.flowerY + TimelineMetrics.flowerSize / 2,
    );
    _scroll.addListener(_followReplay);
    _bloom.forward();
    if (_isAnniversary) _celebrate.forward();
    // Card heights are measured with the real title font; lay out again
    // once it has downloaded.
    GoogleFonts.pendingFonts([MomentCard.titleStyle]).then((_) {
      if (mounted) setState(() {});
    });
    // Notifications for the other one's news; Android asks once by itself.
    _push.start(widget.meId, ask: !kIsWeb);
    // Photos shared from the gallery open straight in the add-photos sheet.
    SharedPhotos.listen((photos) {
      if (!mounted) return;
      showPaperSheet(
        context,
        AddPhotosSheet(store: widget.store, me: widget.meId, initial: photos),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _bloom.value = 1;
      _celebrate.value = 1; // heart and halo still, no confetti
    }
  }

  @override
  void didUpdateWidget(HomePage old) {
    super.didUpdateWidget(old);
    if (old.journal != widget.journal) _entries = buildTimeline(widget.journal);
  }

  @override
  void dispose() {
    SharedPhotos.stop();
    _push.dispose();
    _scroll.dispose();
    _plusFloating.dispose();
    _plusIn.dispose();
    _bloom.dispose();
    _celebrate.dispose();
    _tip.dispose();
    _finale.dispose();
    super.dispose();
  }

  void _startReplay() {
    setState(() {
      _replay = true;
      _replayEnding = false;
      _heartAfterReplay = false;
    });
    _tip.value = double.infinity;
    _bloom.value = .1; // a closed bud
    _celebrate.value = 0;
    _finale.reset();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
      _followReplay();
    });
  }

  /// The stem's top follows 60% down the screen, and only ever grows.
  void _followReplay() {
    if (!_replay || _replayEnding || !_scroll.hasClients) return;
    final pos = _scroll.position;
    final tip = pos.pixels + pos.viewportDimension * .6;
    if (tip < _tip.value) _tip.value = tip;
    if (pos.pixels <= 0) _finishReplay();
  }

  Future<void> _finishReplay() async {
    _replayEnding = true;
    _tip.value = TimelineMetrics.flowerY;
    setState(() => _heartAfterReplay = true);
    _celebrate.forward(from: 0);
    if (widget.journal.daysTogether(DateTime.now()) != null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _finale.forward(from: 0);
    }
    _bloom.duration = Motion.dur4; // the slow bloom
    await _bloom.forward(from: .1);
    _bloom.duration = SakuraFlower.openDuration;
    if (mounted) setState(() => _replay = false);
  }

  void _stopReplay() {
    _finale.reset();
    setState(() => _replay = false);
    _tip.value = TimelineMetrics.flowerY;
    _bloom.value = 1;
  }

  /// "Lưu lại hôm nay": a new moment dated today, its anniversary picked.
  void _saveToday() => showPaperSheet(
    context,
    AddMomentSheet(
      store: widget.store,
      journal: widget.journal,
      me: widget.meId,
    ),
  );

  Future<T?> _menuAt<T>(BuildContext button, List<PopupMenuEntry<T>> items) {
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final box = button.findRenderObject()! as RenderBox;
    final rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    return showMenu<T>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: items,
    );
  }

  Future<void> _openAddMenu(BuildContext button) async {
    final choice = await _menuAt(button, const [
      PopupMenuItem(
        value: 'photos',
        child: _AddChoice(icon: Icons.photo_outlined, title: 'Thêm ảnh'),
      ),
      PopupMenuItem(
        value: 'moment',
        child: _AddChoice(icon: Icons.article_outlined, title: 'Thêm kỷ niệm'),
      ),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'photos':
        await showPaperSheet(
          context,
          AddPhotosSheet(store: widget.store, me: widget.meId),
        );
      case 'moment':
        await showPaperSheet(
          context,
          AddMomentSheet(
            store: widget.store,
            journal: widget.journal,
            me: widget.meId,
          ),
        );
    }
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  void _openAnniversaries() =>
      _open(AnniversariesPage(session: widget.session, store: widget.store));

  Future<void> _openProfileMenu(BuildContext button) async {
    // Android asks on its own at start; a browser needs this tap to ask.
    final offerPush = kIsWeb && await _push.supported && !await _push.allowed;
    if (!button.mounted) return;
    final choice = await _menuAt(button, [
      const PopupMenuItem(value: 'replay', child: Text('Xem từ đầu')),
      const PopupMenuItem(value: 'avatar', child: Text('Đổi ảnh đại diện')),
      const PopupMenuItem(value: 'trash', child: Text('Thùng giấy')),
      if (offerPush) const PopupMenuItem(value: 'push', child: Text('Bật thông báo')),
      const PopupMenuItem(value: 'sign-out', child: Text('Đăng xuất')),
    ]);
    switch (choice) {
      case 'push':
        final on = await _push.start(widget.meId, ask: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(on ? 'đã bật thông báo' : 'trình duyệt chưa cho phép thông báo'),
          ));
        }
      case 'replay':
        _startReplay();
      case 'avatar':
        await _changeAvatar();
      case 'trash':
        _open(TrashPage(session: widget.session, store: widget.store));
      case 'sign-out':
        await _push.forget();
        await widget.onSignOut();
    }
  }

  Future<void> _changeAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    void say(String text) => messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
    try {
      final picked = await pickOnePhoto();
      if (picked == null || !mounted) return;
      final bytes = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => AvatarCropper(bytes: picked),
        ),
      );
      if (bytes == null) return;
      say('đang đổi ảnh đại diện…');
      await widget.store.setAvatar(widget.journal.person(widget.meId), bytes);
      say('đã đổi ảnh đại diện');
    } catch (e) {
      say('chưa đổi được ảnh ($e)');
    }
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
    if (date != null) await widget.store.setStartDate(date);
  }

  @override
  Widget build(BuildContext context) {
    final journal = widget.journal;
    final today = DateTime.now();
    final me = journal.person(widget.meId);
    final upcoming = journal.upcoming(today);
    final safe = MediaQuery.paddingOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final celebrating = _isAnniversary || _heartAfterReplay;
    final headerTop = math.max(52.0, safe.top + 12);

    return Scaffold(
      floatingActionButton: ValueListenableBuilder(
        valueListenable: _plusFloating,
        builder: (context, floating, child) => IgnorePointer(
          ignoring: !floating || _replay,
          child: AnimatedScale(
            scale: floating && !_replay ? 1 : 0,
            duration: Motion.dur2,
            curve: Motion.easePaper,
            child: child,
          ),
        ),
        child: _PlusButton(size: 56, color: Sakura.c5, onPressed: _openAddMenu),
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, _maxWidth);
              final layout = layoutTimeline(
                _entries,
                width,
                textScaler: textScaler,
                momentTitleStyle: MomentCard.titleStyle,
              );
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
                        Positioned.fill(
                          child: CustomPaint(
                            painter: StemPainter(
                              layout,
                              tip: _replay ? _tip : null,
                            ),
                          ),
                        ),
                        if (_replay)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: layout.stemBottom - 150,
                            child: _SwipeUpHint(
                              tip: _tip,
                              from: layout.stemBottom - 150,
                            ),
                          ),
                        for (final marker in layout.markers)
                          Positioned(
                            left: m.stemX + 10,
                            top: marker.y,
                            height: markerHeight,
                            child: _MonthMarker(marker.month),
                          ),
                        for (final p in layout.placed)
                          Sprout(
                            // A fresh one per mode: in a replay every item
                            // waits for the stem again.
                            key: ValueKey((p.entry.id, _replay)),
                            placed: p,
                            scroll: _scroll,
                            stemTip: _replay ? _tip : null,
                            builder: (context, tape) => switch (p.entry) {
                              final MomentEntry e => MomentCard(
                                entry: e,
                                onTap: () => _open(
                                  MomentPage(
                                    session: widget.session,
                                    store: widget.store,
                                    momentId: e.moment.id,
                                  ),
                                ),
                              ),
                              final PhotoStackEntry e => PolaroidStack(
                                entry: e,
                                tape: tape,
                                onTap: () => _open(
                                  PhotoViewer(
                                    session: widget.session,
                                    store: widget.store,
                                    photoIds: [for (final p in e.photos) p.id],
                                  ),
                                ),
                              ),
                            },
                          ),
                        if (celebrating)
                          Positioned(
                            left: m.stemX - 120,
                            top: fy - 120,
                            width: 240,
                            height: 240,
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _celebrate,
                                builder: (context, _) => Opacity(
                                  opacity: AnniversaryDay.haloOpacity(
                                    _celebrate.value,
                                  ),
                                  child: const DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(
                                        radius: .5,
                                        colors: [Pollen.c1, Color(0x00F3DFA8)],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // Under the flower, so it starts hidden behind the petals.
                        if (journal.daysTogether(today) case final days?)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: fy + half,
                            child: IgnorePointer(
                              child: _DaysFinale(
                                animation: _finale,
                                days: days,
                                fromY: fy,
                                toY: headerTop + 56,
                                centerX: m.stemX,
                              ),
                            ),
                          ),
                        Positioned(
                          left: m.stemX - half,
                          top: fy - half,
                          child: GestureDetector(
                            // On an anniversary, tapping the flower plays it again.
                            onTap: celebrating
                                ? () => _celebrate.forward(from: 0)
                                : null,
                            child: SakuraFlower(
                              bloom: _bloom,
                              size: TimelineMetrics.flowerSize,
                            ),
                          ),
                        ),
                        if (celebrating)
                          Positioned(
                            left: m.stemX - 34,
                            top: fy - 34,
                            width: 68,
                            height: 68,
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: HeartPainter(_celebrate),
                              ),
                            ),
                          ),
                        if (!_replay)
                          Positioned(
                            left: m.stemX - 24,
                            top: fy - 24,
                            child: FadeTransition(
                              opacity: _plusIn,
                              child: _PlusButton(
                                size: 28,
                                color: Sakura.c6,
                                onPressed: _openAddMenu,
                              ),
                            ),
                          ),
                        if (upcoming != null)
                          Positioned(
                            left: m.stemX + 20,
                            width: math.min(190, m.width - m.stemX - 34),
                            top: TimelineMetrics.noteTop,
                            child: _UpcomingNote(
                              title: upcoming.anniversary.titleOn(
                                today.add(Duration(days: upcoming.days)),
                              ),
                              days: upcoming.days,
                              onTap: upcoming.days == 0
                                  ? _saveToday
                                  : _openAnniversaries,
                            ),
                          ),
                        Positioned(
                          left: 24,
                          right: 24,
                          top: headerTop,
                          // Steps aside while the finale holds the top.
                          child: FadeTransition(
                            opacity: _finale.drive(_DaysFinale.headerOpacity),
                            child: _Header(
                              today: today,
                              days: journal.daysTogether(today),
                              me: me,
                              onPickStartDate: _pickStartDate,
                              onCalendar: _openAnniversaries,
                              onProfile: _openProfileMenu,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          if (_replay)
            Positioned(
              top: safe.top + 12,
              right: 16,
              child: IconButton(
                tooltip: 'Thoát xem từ đầu',
                onPressed: _stopReplay,
                style: IconButton.styleFrom(
                  backgroundColor: Paper.c1,
                  side: const BorderSide(color: Paper.c5),
                  fixedSize: const Size.square(44),
                ),
                icon: const Icon(Icons.close, size: 18, color: Paper.c8),
              ),
            ),
          // Confetti falls across the screen, not the scrolling page.
          if (celebrating && !MediaQuery.disableAnimationsOf(context))
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: ConfettiPainter(_celebrate)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The end of "xem từ đầu": the day count grows out from behind the flower
/// to the top of the screen, counting up, holds, then fades so the header
/// can take over again.
class _DaysFinale extends AnimatedWidget {
  const _DaysFinale({
    required Animation<double> animation,
    required this.days,
    required this.fromY,
    required this.toY,
    required this.centerX,
  }) : super(listenable: animation);

  final int days;

  /// Centre heights: the flower's, and where it comes to rest.
  final double fromY;
  final double toY;
  final double centerX;

  static const duration = Duration(milliseconds: 5200);

  // Slices of [duration]. The rise overshoots a little, like the petals.
  static const _rise = Interval(.04, .34, curve: Motion.easeBloom);
  static const _appear = Interval(.04, .14);
  static const _count = Interval(.08, .5, curve: Curves.easeOutCubic);
  static const _leave = Interval(.86, 1, curve: Motion.easePaper);

  /// The header fades out as this rises and back in as this leaves.
  static final headerOpacity = TweenSequence([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 4),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 10),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 72),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 14),
  ]);

  @override
  Widget build(BuildContext context) {
    final t = (listenable as Animation<double>).value;
    if (t == 0 || t == 1) return const SizedBox.shrink();
    final rise = _rise.transform(t);
    final leave = _leave.transform(t);
    final count = (days * _count.transform(t)).round();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: centerX,
          top: fromY + (toY - fromY) * rise,
          child: FractionalTranslation(
            translation: const Offset(-.5, -.5),
            child: Opacity(
              opacity: _appear.transform(t) * (1 - leave),
              child: Transform.scale(
                scale: (.2 + .8 * rise) * (1 - .1 * leave),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      thousands(count),
                      style: AppText.display.copyWith(
                        fontSize: 84,
                        height: 1,
                        shadows: const [Shadow(color: Pollen.c1, blurRadius: 28)],
                      ),
                    ),
                    const SizedBox(height: Space.s2),
                    Text(
                      'NGÀY BÊN NHAU',
                      style: AppText.label.copyWith(
                        fontSize: 14,
                        letterSpacing: 14 * .3,
                        color: Sakura.c6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.today,
    required this.days,
    required this.me,
    required this.onPickStartDate,
    required this.onCalendar,
    required this.onProfile,
  });

  final DateTime today;

  /// null until the start date is set.
  final int? days;
  final Person me;
  final VoidCallback onPickStartDate;
  final VoidCallback onCalendar;
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
              Text(
                'hôm nay, ${dotDate(today)}',
                style: AppText.script.copyWith(fontSize: 20),
              ),
              if (days == null)
                TextButton(
                  onPressed: onPickStartDate,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: Paper.c8,
                  ),
                  child: Text(
                    'đặt ngày bắt đầu yêu',
                    style: AppText.h1.copyWith(
                      fontSize: 22,
                      decoration: TextDecoration.underline,
                    ),
                  ),
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
                      builder: (context, value, _) => Text(
                        thousands(value),
                        style: AppText.display.copyWith(height: 1),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'NGÀY BÊN NHAU',
                        style: AppText.label.copyWith(letterSpacing: 11 * .14),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Ngày kỷ niệm',
          onPressed: onCalendar,
          style: IconButton.styleFrom(
            fixedSize: const Size.square(44),
            backgroundColor: Paper.c1,
            side: const BorderSide(color: Paper.c5),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.event_outlined, size: 18, color: Paper.c8),
        ),
        const SizedBox(width: Space.s2),
        Builder(
          builder: (button) => IconButton(
            tooltip: 'Trang cá nhân',
            onPressed: () => onProfile(button),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              padding: EdgeInsets.zero,
            ),
            icon: PersonAvatar(
              person: me,
              size: 44,
              ring: const BorderSide(color: Sakura.c2, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "+" — flower center (28px) at the top, floating (56px) further down.
/// The tap area is at least 48px either way.
class _PlusButton extends StatelessWidget {
  const _PlusButton({
    required this.size,
    required this.color,
    required this.onPressed,
  });

  final double size;
  final Color color;
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (button) => IconButton(
        tooltip: 'Thêm mới',
        onPressed: () => onPressed(button),
        style: IconButton.styleFrom(
          fixedSize: Size.square(math.max(48, size)),
          padding: EdgeInsets.zero,
        ),
        icon: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Sakura.c7, width: 1.5),
            boxShadow: Shadows.pink,
          ),
          child: Icon(
            Icons.add,
            size: size * .57,
            color: const Color(0xFFFFF5F8),
          ),
        ),
      ),
    );
  }
}

/// A row of the "+" menu: icon and name.
class _AddChoice extends StatelessWidget {
  const _AddChoice({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Sakura.c7),
        const SizedBox(width: Space.s3),
        Text(
          title,
          style: AppText.body.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UpcomingNote extends StatelessWidget {
  const _UpcomingNote({
    required this.title,
    required this.days,
    required this.onTap,
  });

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
            // Wide enough for "ngày kỷ niệm 10 năm" on one line.
            constraints: const BoxConstraints(minWidth: 140, maxWidth: 190),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Paper.c1,
              borderRadius: BorderRadius.circular(Radii.tape),
              boxShadow: Shadows.paperSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'HÔM NAY LÀ' : 'SẮP TỚI',
                  style: AppText.label.copyWith(fontSize: 10, letterSpacing: 1),
                ),
                Text(title, style: AppText.title.copyWith(fontSize: 13)),
                Text(
                  isToday ? 'Lưu lại hôm nay →' : 'còn $days ngày',
                  style: AppText.script.copyWith(fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "vuốt lên nhó" over the pot, until the stem has grown past it.
class _SwipeUpHint extends StatelessWidget {
  const _SwipeUpHint({required this.tip, required this.from});

  final ValueListenable<double> tip;
  final double from;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: tip,
      builder: (context, y, child) => AnimatedOpacity(
        opacity: y > from ? 1 : 0,
        duration: Motion.dur2,
        child: child,
      ),
      child: Column(
        children: [
          const Icon(Icons.keyboard_double_arrow_up, color: Sakura.c7),
          Text('vuốt lên nhó', style: AppText.script.copyWith(fontSize: 20)),
        ],
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
      decoration: BoxDecoration(
        color: Paper.c1,
        borderRadius: BorderRadius.circular(Radii.tape),
        boxShadow: Shadows.paperSm,
      ),
      child: Text(
        monthLabel(month),
        style: AppText.script.copyWith(fontSize: 14, height: 1),
      ),
    );
  }
}

/// Soft light and a pink haze behind the flower, as in the design. Each is a
/// circle that fades out inside itself, so it never shows an edge — not even
/// where it spills past the content column on a wide screen.
List<Widget> _paperGlow(double stemX) => [
  _glow(Offset(stemX - 33, 84), 323, const Color(0x66FFFFFF)),
  _glow(
    Offset(stemX + 6, TimelineMetrics.flowerY),
    205,
    const Color(0x38F39BB5),
  ),
];

Widget _glow(Offset center, double radius, Color color) => Positioned(
  left: center.dx - radius,
  top: center.dy - radius,
  width: radius * 2,
  height: radius * 2,
  child: IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: .5,
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    ),
  ),
);
