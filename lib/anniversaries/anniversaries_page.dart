import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../add/sheet_frame.dart';
import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/vi_format.dart';
import '../moment/moment_page.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/sakura_flower.dart';
import 'anniversary_sheet.dart';

/// 07 · Ngày kỷ niệm: the start day first, then yearly days by how soon they
/// come round, then one-off days.
class AnniversariesPage extends StatelessWidget {
  const AnniversariesPage({super.key, required this.session, required this.store});

  final ValueListenable<Session?> session;
  final JournalStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, s, _) {
        if (s == null) return const Scaffold();
        final journal = s.journal;
        final today = DateUtils.dateOnly(DateTime.now());
        final start = journal.anniversaries.where((a) => a.isStart).firstOrNull;
        final others = journal.anniversaries.where((a) => !a.isStart);
        int daysTo(Anniversary a) => daysBetween(today, a.yearly ? nextOccurrence(a.date, today) : a.date);
        final yearly = others.where((a) => a.yearly).toList()..sort((a, b) => daysTo(a).compareTo(daysTo(b)));
        final once = others.where((a) => !a.yearly).toList()..sort((a, b) => b.date.compareTo(a.date));

        List<Moment> momentsOf(Anniversary a) =>
            journal.moments.where((m) => m.anniversaryId == a.id).toList()..sort((x, y) => y.date.compareTo(x.date));

        void edit(Anniversary? a) => showPaperSheet(
              context,
              AnniversarySheet(
                store: store,
                anniversary: a,
                moments: a == null ? const [] : momentsOf(a),
                onOpenMoment: (m) {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => MomentPage(session: session, store: store, momentId: m.id)));
                },
              ),
            );

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Row(
                      children: [
                        _RoundButton(tooltip: 'Về trang chủ', icon: Icons.arrow_back, onPressed: () => Navigator.pop(context)),
                        Expanded(child: Text('Ngày kỷ niệm', textAlign: TextAlign.center, style: AppText.h1.copyWith(fontSize: 24))),
                        _RoundButton(tooltip: 'Thêm ngày kỷ niệm', icon: Icons.add, onPressed: () => edit(null)),
                      ],
                    ),
                    const SizedBox(height: Space.s5),
                    _StartCard(
                      start: start,
                      days: journal.daysTogether(today),
                      onTap: () async {
                        if (start != null) return edit(start);
                        final date = await showDatePicker(
                          context: context,
                          helpText: 'Ngày bắt đầu yêu',
                          initialDate: today,
                          firstDate: DateTime(1990),
                          lastDate: today,
                        );
                        if (date != null) await store.setStartDate(date);
                      },
                    ),
                    const SizedBox(height: Space.s6),
                    Text('SẮP TỚI', style: AppText.label),
                    const SizedBox(height: Space.s2),
                    if (yearly.isEmpty) _Empty('chưa có ngày nào lặp hằng năm — bấm + để thêm sinh nhật, ngày quen nhau…'),
                    for (final a in yearly)
                      _Row(anniversary: a, today: today, days: daysTo(a), saved: momentsOf(a).length, onTap: () => edit(a)),
                    if (once.isNotEmpty) ...[
                      const SizedBox(height: Space.s5),
                      Text('MỘT LẦN', style: AppText.label),
                      const SizedBox(height: Space.s2),
                      for (final a in once)
                        _Row(anniversary: a, today: today, days: daysTo(a), saved: momentsOf(a).length, onTap: () => edit(a)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.start, required this.days, required this.onTap});

  final Anniversary? start;
  final int? days;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = this.start;
    return Material(
      color: Paper.c1,
      borderRadius: BorderRadius.circular(Radii.card),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(Space.s4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.paper),
          child: Row(
            children: [
              const SakuraFlower(bloom: AlwaysStoppedAnimation(1), size: 56),
              const SizedBox(width: Space.s4),
              Expanded(
                child: start == null
                    ? Text('đặt ngày bắt đầu yêu', style: AppText.title.copyWith(fontSize: 17, decoration: TextDecoration.underline))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NGÀY BẮT ĐẦU YÊU', style: AppText.label.copyWith(fontSize: 10)),
                          Text(dotDate(start.date), style: AppText.script.copyWith(fontSize: 22)),
                          if (days != null) Text('${thousands(days!)} ngày bên nhau', style: AppText.body.copyWith(fontSize: 13)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.anniversary, required this.today, required this.days, required this.saved, required this.onTap});

  final Anniversary anniversary;
  final DateTime today;

  /// Until it comes round; negative for a one-off day already past.
  final int days;
  final int saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = anniversary;
    final kind = a.yearly ? 'hằng năm' : (days < 0 ? 'không lặp · đã qua' : 'không lặp');
    final when = days == 0 ? 'hôm nay' : (days > 0 ? 'còn $days ngày' : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s2),
      child: Material(
        color: Paper.c1,
        borderRadius: BorderRadius.circular(Radii.card),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4, vertical: Space.s3),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Column(
                    children: [
                      Text(a.date.day.toString().padLeft(2, '0'), style: AppText.h1.copyWith(fontSize: 22, height: 1)),
                      Text('th.${a.date.month}', style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0)),
                    ],
                  ),
                ),
                const SizedBox(width: Space.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, style: AppText.title.copyWith(fontSize: 15)),
                      Text(
                        [kind, if (saved > 0) '$saved kỷ niệm đã lưu'].join(' · '),
                        style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                if (when != null) Text(when, style: AppText.script.copyWith(fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.s2),
        child: Text(text, style: AppText.body.copyWith(fontSize: 13, color: Paper.c7)),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(backgroundColor: Paper.c1, side: const BorderSide(color: Paper.c5), fixedSize: const Size.square(44)),
        icon: Icon(icon, size: 18, color: Paper.c8),
      );
}
