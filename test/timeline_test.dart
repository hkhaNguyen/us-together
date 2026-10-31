import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/data/models.dart';
import 'package:us_together/data/vi_format.dart';
import 'package:us_together/home/timeline.dart';
import 'package:us_together/home/timeline_layout.dart';

import 'mock_journal.dart';

/// Test-font stand-in for MomentCard.titleStyle (Google Fonts can't load here).
const titleStyle = TextStyle(fontSize: 15, height: 1.2);

void main() {
  final journal = mockJournal();

  group('journal', () {
    test('days together matches the design: 1.462 on 31/10/2026', () {
      expect(thousands(journal.daysTogether(DateTime(2026, 10, 31))!), '1.462');
    });

    test('the start day is "ngày bắt đầu yêu" once, "ngày kỷ niệm N năm" after', () {
      final start = journal.anniversaries.firstWhere((a) => a.isStart);
      expect(start.titleOn(DateTime(2022, 10, 30)), 'ngày bắt đầu yêu');
      expect(start.titleOn(DateTime(2027, 10, 30)), 'ngày kỷ niệm 5 năm');
      final birthday = journal.anniversaries.firstWhere((a) => !a.isStart);
      expect(birthday.titleOn(DateTime(2026, 11, 23)), birthday.title);
    });

    test('a moment\'s photos start with the cover; the first person sits left', () {
      final src = journal.moments.first;
      final m = Moment(id: src.id, date: src.date, title: src.title, addedBy: src.addedBy, photoIds: src.photoIds, coverPhotoId: src.photoIds[2]);
      final j = Journal(people: journal.people, moments: [m], photos: journal.photos, entries: const [], anniversaries: const []);
      expect(j.photosOf(m).map((p) => p.id), [m.photoIds[2], m.photoIds[0], m.photoIds[1], ...m.photoIds.skip(3)]);
      expect(journal.isLeftSide('hkha'), isTrue);
      expect(journal.isLeftSide('xuka'), isFalse);
    });

    test('no count before the start date is set; unknown authors don\'t crash', () {
      final empty = Journal(people: const [], moments: const [], photos: const [], entries: const [], anniversaries: const []);
      expect(empty.daysTogether(DateTime(2026, 10, 31)), isNull);
      expect(empty.person('someone@example.com').name, '?');
    });

    test('upcoming: nearest yearly date, today counts as 0', () {
      final next = journal.upcoming(DateTime(2026, 10, 31))!;
      expect((next.anniversary.title, next.days), ('sinh nhật Xuka', 23));
      expect(journal.upcoming(DateTime(2026, 10, 30))!.days, 0);
    });
  });

  group('timeline', () {
    final entries = buildTimeline(journal);

    test('newest first, loose photos grouped by the go they were added in', () {
      final dates = entries.map((e) => e.date).toList();
      for (var i = 1; i < dates.length; i++) {
        expect(dates[i].isAfter(dates[i - 1]), isFalse, reason: 'entry $i');
      }
      final firstStack = entries.whereType<PhotoStackEntry>().first;
      expect(firstStack.photos, hasLength(3));
    });

    test('two goes on the same day stay two stacks; old photos without one group by day', () {
      final day = DateTime(2026, 5, 1, 9);
      Photo p(String id, {String? stack}) => Photo(id: id, takenAt: day, addedBy: 'hkha', stackId: stack);
      final j = Journal(
        people: journal.people,
        moments: const [],
        photos: [p('a1', stack: 'a'), p('a2', stack: 'a'), p('b1', stack: 'b'), p('old1'), p('old2')],
        entries: const [],
        anniversaries: const [],
      );
      final sizes = buildTimeline(j).whereType<PhotoStackEntry>().map((s) => s.photos.length).toList()..sort();
      expect(sizes, [1, 2, 2]);
    });

    TimelineLayout lay(double width, [double scale = 1]) =>
        layoutTimeline(entries, width, textScaler: TextScaler.linear(scale), momentTitleStyle: titleStyle);

    test('card height follows the real title: one line is shorter than two', () {
      // Neither has cảm nghĩ, so only the title differs.
      // 480px leaves room for "Giáng sinh" on one line in the test font.
      final cards = {for (final p in lay(480).placed) p.entry.id: p.rect.height};
      expect(cards['m5']! + 17, lessThan(cards['m3']!)); // "Giáng sinh" vs a two-line title
    });

    for (final width in [360.0, 390.0, 412.0, 480.0]) {
      for (final scale in [1.0, 1.3]) {
        test('layout at ${width}px, text ×$scale: no overlaps, branches spaced', () {
          final layout = lay(width, scale);
          final placed = layout.placed;
          expect(placed, hasLength(entries.length));

          for (var i = 0; i < placed.length; i++) {
            final a = placed[i];
            expect(a.rect.left, greaterThanOrEqualTo(0));
            expect(a.rect.right, lessThanOrEqualTo(width));
            expect(a.rect.bottom, lessThan(layout.height));
            if (i > 0) {
              expect(a.branchStart.dy - placed[i - 1].branchStart.dy, greaterThanOrEqualTo(branchSpacing));
            }
            for (final b in placed.skip(i + 1).where((b) => b.side == a.side)) {
              expect(a.rect.overlaps(b.rect), isFalse, reason: '${a.entry.id} vs ${b.entry.id}');
            }
            for (final k in layout.markers) {
              final band = Rect.fromLTWH(0, k.y, width, markerHeight);
              expect(a.rect.overlaps(band), isFalse, reason: '${a.entry.id} vs marker ${k.month}');
            }
          }
        });
      }
    }

    test('items take turns left and right, and keep clear of the leaves', () {
      final layout = lay(390);
      final m = layout.metrics;
      for (final (i, p) in layout.placed.indexed) {
        expect(p.side, i.isEven ? Side.left : Side.right, reason: 'item $i');
        final nearEdge = p.side == Side.left ? m.stemX - p.rect.right : p.rect.left - m.stemX;
        // Leaves reach 41px out from the stem; the item must start past them.
        expect(nearEdge, greaterThanOrEqualTo(41), reason: 'item $i');
      }
    });

    test('a marker wherever the month changes, big leaf on new years', () {
      final layout = lay(390);
      final months = {for (final e in entries) DateTime(e.date.year, e.date.month)};
      expect(layout.markers, hasLength(months.length - 1));
      expect(layout.markers.where((k) => k.newYear).map((k) => k.month.year), [2025]);
    });

    test('branch roots sit on the stem', () {
      final m = TimelineMetrics(390);
      final metric = m.stemPath(2000).computeMetrics().first;
      for (var d = 0.0; d < metric.length; d += 37) {
        final p = metric.getTangentForOffset(d)!.position;
        expect(m.stemXAt(p.dy), closeTo(p.dx, .01));
      }
    });
  });
}
