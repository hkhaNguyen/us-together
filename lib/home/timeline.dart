import '../data/models.dart';

/// One thing hanging off the stem: a moment card (right) or a stack of
/// same-day loose photos (left).
sealed class TimelineEntry {
  const TimelineEntry();

  String get id;
  DateTime get date;
}

class MomentEntry extends TimelineEntry {
  const MomentEntry({
    required this.moment,
    required this.addedBy,
    required this.cover,
    required this.anniversary,
    required this.entryAuthors,
    required this.entryCount,
  });

  final Moment moment;
  final Person addedBy;
  final Photo? cover;
  final Anniversary? anniversary;

  /// Distinct people who wrote a cảm nghĩ, in first-written order.
  final List<Person> entryAuthors;
  final int entryCount;

  int get photoCount => moment.photoIds.length;

  @override
  String get id => moment.id;

  @override
  DateTime get date => moment.date;
}

class PhotoStackEntry extends TimelineEntry {
  const PhotoStackEntry({required this.photos, required this.addedBy});

  /// Newest first; the first one is on top of the stack.
  final List<Photo> photos;
  final Person addedBy;

  @override
  String get id => 'stack-${photos.first.id}';

  @override
  DateTime get date => photos.first.takenAt;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Moments plus loose photos grouped by day, newest day first; on a shared
/// day the moment comes before the photo stack.
List<TimelineEntry> buildTimeline(Journal journal) {
  final entries = <TimelineEntry>[];

  for (final m in journal.moments) {
    final momentEntries = journal.entries.where((e) => e.momentId == m.id).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    entries.add(MomentEntry(
      moment: m,
      addedBy: journal.person(m.addedBy),
      cover: journal.photos.where((p) => p.id == m.coverPhotoId).firstOrNull,
      anniversary: journal.anniversaries.where((a) => a.id == m.anniversaryId).firstOrNull,
      entryAuthors: [for (final id in {for (final e in momentEntries) e.author}) journal.person(id)],
      entryCount: momentEntries.length,
    ));
  }

  final looseByDay = <DateTime, List<Photo>>{};
  for (final p in journal.photos.where((p) => p.momentId == null)) {
    looseByDay.putIfAbsent(_day(p.takenAt), () => []).add(p);
  }
  for (final photos in looseByDay.values) {
    photos.sort((a, b) => b.takenAt.compareTo(a.takenAt));
    entries.add(PhotoStackEntry(photos: photos, addedBy: journal.person(photos.first.addedBy)));
  }

  int rank(TimelineEntry e) => e is MomentEntry ? 0 : 1;
  entries.sort((a, b) {
    final byDay = _day(b.date).compareTo(_day(a.date));
    return byDay != 0 ? byDay : rank(a) - rank(b);
  });
  return entries;
}
