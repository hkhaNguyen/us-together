import 'dart:ui';

import 'vi_format.dart';

/// One of the two fixed profiles; everything else is shared and only records
/// who added it.
class Person {
  const Person({required this.id, required this.name, required this.color, this.avatarUrl});

  final String id;
  final String name;
  final Color color;

  /// Their own picture; until set, the initial on their colour.
  final String? avatarUrl;
}

class Photo {
  const Photo({
    required this.id,
    required this.takenAt,
    required this.addedBy,
    this.thumbUrl,
    this.fullUrl,
    this.aspectRatio = 1,
    this.title,
    this.stackId,
    this.isStackCover = false,
    this.momentId,
    this.trashed,
  });

  final String id;
  final DateTime takenAt;
  final String addedBy;
  final String? thumbUrl;
  final String? fullUrl;

  /// Width / height, known before the image loads so nothing jumps.
  final double aspectRatio;

  /// Free-form, any length, shared by the whole stack; polaroids show one
  /// line, the viewer all of it.
  final String? title;

  /// Photos added in one go share this and hang as one stack.
  final String? stackId;

  /// Picked to sit on top of its stack; otherwise the newest one does.
  final bool isStackCover;

  /// null = a loose photo pinned on the stem.
  final String? momentId;

  /// Set while it sits in the trash.
  final Trashed? trashed;
}

/// When and by whom something went into the trash ("thùng giấy").
class Trashed {
  const Trashed({required this.at, required this.by, this.withMoment});

  final DateTime at;
  final String by;

  /// A photo that went in along with this moment, and comes back with it.
  final String? withMoment;

  static const keepDays = 30;

  /// Days before it's gone for good.
  int daysLeft(DateTime today) => keepDays - daysBetween(at, today);
}

/// A moment ("kỷ niệm" in the app): photos + title + post.
class Moment {
  const Moment({
    required this.id,
    required this.date,
    required this.title,
    required this.addedBy,
    this.body = '',
    this.photoIds = const [],
    this.coverPhotoId,
    this.anniversaryId,
    this.trashed,
    this.keptPhotoIds = const [],
  });

  final String id;
  final DateTime date;
  final String title;
  final String addedBy;
  final String body;
  final List<String> photoIds;
  final String? coverPhotoId;
  final String? anniversaryId;
  final Trashed? trashed;

  /// Photos that went back on the stem when it was trashed; restoring the
  /// moment takes back the ones still loose.
  final List<String> keptPhotoIds;
}

/// A "cảm nghĩ" written under a moment.
class Entry {
  const Entry({required this.id, required this.momentId, required this.author, required this.text, required this.createdAt});

  final String id;
  final String momentId;
  final String author;
  final String text;
  final DateTime createdAt;
}

class Anniversary {
  const Anniversary({required this.id, required this.title, required this.date, this.yearly = true, this.isStart = false});

  final String id;
  final String title;
  final DateTime date;
  final bool yearly;

  /// "ngày bắt đầu yêu" — the source of the days-together count.
  final bool isStart;

  /// What to call the occurrence on [on]: the start day happened once; each
  /// return after it is "ngày kỷ niệm N năm".
  String titleOn(DateTime on) {
    final years = on.year - date.year;
    return isStart && years > 0 ? 'ngày kỷ niệm $years năm' : title;
  }
}

/// Snapshot of everything the two of them share.
class Journal {
  const Journal({
    required this.people,
    required this.moments,
    required this.photos,
    required this.entries,
    required this.anniversaries,
    this.trashedMoments = const [],
    this.trashedPhotos = const [],
  });

  final List<Person> people;

  /// Live moments and photos only; trashed ones are kept apart below.
  final List<Moment> moments;
  final List<Photo> photos;
  final List<Moment> trashedMoments;
  final List<Photo> trashedPhotos;
  final List<Entry> entries;
  final List<Anniversary> anniversaries;

  Photo? photo(String id) => photos.where((p) => p.id == id).firstOrNull;
  Moment? moment(String id) => moments.where((m) => m.id == id).firstOrNull;

  /// A moment's photos with the cover first, then in the order they were added.
  List<Photo> photosOf(Moment m) {
    final ids = [?m.coverPhotoId, ...m.photoIds.where((id) => id != m.coverPhotoId)];
    return [for (final id in ids) ?photo(id)];
  }

  /// Who sits on which side of the reflections: the first person (by id) on
  /// the left, as in the design.
  bool isLeftSide(String personId) => people.isEmpty || personId == (people.map((p) => p.id).toList()..sort()).first;

  /// A member removed from the console still shows up, just unnamed.
  Person person(String id) => people.firstWhere((p) => p.id == id, orElse: () => Person(id: id, name: '?', color: const Color(0xFFB99A8A)));

  /// null until "ngày bắt đầu yêu" has been set.
  int? daysTogether(DateTime today) {
    final start = anniversaries.where((a) => a.isStart).firstOrNull;
    return start == null ? null : daysBetween(start.date, today);
  }

  /// Anniversaries that fall on [day]: yearly ones on its day and month, a
  /// one-off only on its exact date. A moment can only belong to these.
  List<Anniversary> anniversariesOn(DateTime day) => [
        for (final a in anniversaries)
          if (a.date.month == day.month && a.date.day == day.day && (a.yearly || a.date.year == day.year)) a,
      ];

  Anniversary? anniversaryOn(DateTime day) => anniversariesOn(day).firstOrNull;

  /// The nearest anniversary from [today] on (today itself counts), or null.
  ({Anniversary anniversary, int days})? upcoming(DateTime today) {
    ({Anniversary anniversary, int days})? best;
    for (final a in anniversaries) {
      final next = a.yearly ? nextOccurrence(a.date, today) : a.date;
      final days = daysBetween(today, next);
      if (days < 0) continue;
      if (best == null || days < best.days) best = (anniversary: a, days: days);
    }
    return best;
  }
}
