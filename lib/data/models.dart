import 'dart:ui';

import 'vi_format.dart';

/// One of the two fixed profiles; everything else is shared and only records
/// who added it.
class Person {
  const Person({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;
}

class Photo {
  const Photo({
    required this.id,
    required this.takenAt,
    required this.addedBy,
    this.thumbUrl,
    this.title,
    this.momentId,
  });

  final String id;
  final DateTime takenAt;
  final String addedBy;
  final String? thumbUrl;

  /// Free-form, any length; polaroids show one line, the viewer all of it.
  final String? title;

  /// null = a loose photo pinned on the stem.
  final String? momentId;
}

/// A "dịp": photos + title + post.
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
  });

  final String id;
  final DateTime date;
  final String title;
  final String addedBy;
  final String body;
  final List<String> photoIds;
  final String? coverPhotoId;
  final String? anniversaryId;
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
  });

  final List<Person> people;
  final List<Moment> moments;
  final List<Photo> photos;
  final List<Entry> entries;
  final List<Anniversary> anniversaries;

  /// A member removed from the console still shows up, just unnamed.
  Person person(String id) => people.firstWhere((p) => p.id == id, orElse: () => Person(id: id, name: '?', color: const Color(0xFFB99A8A)));

  /// null until "ngày bắt đầu yêu" has been set.
  int? daysTogether(DateTime today) {
    final start = anniversaries.where((a) => a.isStart).firstOrNull;
    return start == null ? null : daysBetween(start.date, today);
  }

  /// The anniversary that falls on [day], if any.
  Anniversary? anniversaryOn(DateTime day) => anniversaries
      .where((a) => a.date.month == day.month && a.date.day == day.day && (a.yearly || a.date.year == day.year))
      .firstOrNull;

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
