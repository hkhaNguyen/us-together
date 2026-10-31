import 'package:us_together/theme/tokens.dart';
import 'package:us_together/data/models.dart';

/// Sample journal for tests.
/// Titles and notes are stand-ins; birthdays only matter by day and month.
Journal mockJournal() {
  const hkha = Person(id: 'hkha', name: 'hkha', color: Sakura.c5);
  const xuka = Person(id: 'xuka', name: 'Xuka', color: Sage.c2);

  final photos = <Photo>[];
  final moments = <Moment>[];

  void moment(String id, DateTime date, String title, String by, int photoCount, {String? anniversaryId}) {
    final ids = [for (var i = 1; i <= photoCount; i++) '$id-p$i'];
    photos.addAll([for (final p in ids) Photo(id: p, takenAt: date, addedBy: by, momentId: id)]);
    moments.add(Moment(
      id: id,
      date: date,
      title: title,
      addedBy: by,
      photoIds: ids,
      coverPhotoId: ids.first,
      anniversaryId: anniversaryId,
    ));
  }

  void loose(String id, DateTime date, String by, int count, {String? title}) {
    for (var i = 1; i <= count; i++) {
      photos.add(Photo(id: '$id-$i', takenAt: date.add(Duration(minutes: i)), addedBy: by, title: title, stackId: id));
    }
  }

  moment('m1', DateTime(2026, 10, 30), 'Kỷ niệm 4 năm', 'hkha', 9, anniversaryId: 'a-start');
  loose('l1', DateTime(2026, 10, 12, 8), 'xuka', 3, title: 'cà phê sáng');
  moment('m2', DateTime(2026, 9, 14), 'Đi biển một ngày', 'xuka', 5);
  loose('l2', DateTime(2026, 8, 20, 18), 'hkha', 1, title: 'mèo nhà hàng xóm');
  moment('m3', DateTime(2026, 7, 2), 'Buổi hoà nhạc đầu tiên đi cùng nhau', 'hkha', 3);
  loose('l3', DateTime(2026, 3, 8, 10), 'hkha', 2);
  moment('m4', DateTime(2026, 2, 14), 'Valentine ở nhà', 'xuka', 4);
  moment('m5', DateTime(2025, 12, 24), 'Giáng sinh', 'hkha', 6);
  loose('l4', DateTime(2025, 11, 11, 16), 'xuka', 1, title: 'mưa');
  moment('m6', DateTime(2025, 10, 30), 'Kỷ niệm 3 năm', 'xuka', 2, anniversaryId: 'a-start');
  loose('l5', DateTime(2025, 8, 15, 20), 'hkha', 4, title: 'trung thu');
  moment('m7', DateTime(2025, 6, 1), 'Đà Lạt', 'hkha', 12);

  Entry entry(String id, String momentId, String author) =>
      Entry(id: id, momentId: momentId, author: author, text: '[cảm nghĩ]', createdAt: DateTime(2026, 10, 31));

  return Journal(
    people: const [hkha, xuka],
    moments: moments,
    photos: photos,
    entries: [
      entry('e1', 'm1', 'hkha'),
      entry('e2', 'm1', 'xuka'),
      entry('e3', 'm2', 'xuka'),
      entry('e4', 'm4', 'xuka'),
      entry('e5', 'm4', 'hkha'),
      entry('e6', 'm7', 'hkha'),
      entry('e7', 'm7', 'xuka'),
      entry('e8', 'm7', 'hkha'),
    ],
    anniversaries: [
      Anniversary(id: 'a-start', title: 'ngày bắt đầu yêu', date: DateTime(2022, 10, 30), isStart: true),
      Anniversary(id: 'a-xuka', title: 'sinh nhật Xuka', date: DateTime(2000, 11, 23)),
      Anniversary(id: 'a-hkha', title: 'sinh nhật hkha', date: DateTime(2000, 3, 2)),
    ],
  );
}
