import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:us_together/add/photo_pipeline.dart';

import 'mock_journal.dart';

void main() {
  group('EXIF date', () {
    test('reads the camera format', () {
      expect(parseExifDate('2024:10:30 18:22:01'), DateTime(2024, 10, 30, 18, 22, 1));
      expect(parseExifDate(' 2024:10:30 18:22:01\u0000'), DateTime(2024, 10, 30, 18, 22, 1));
    });

    test('ignores missing or blank dates', () {
      for (final v in [null, '', '0000:00:00 00:00:00', '    :  :     :  :  ', '2024-10-30']) {
        expect(parseExifDate(v), isNull, reason: '$v');
      }
    });
  });

  test('tells WebP from what Safari hands back instead', () {
    Uint8List bytes(String head) => Uint8List.fromList([...head.codeUnits, ...List.filled(8, 0)]);
    expect(PhotoUploader.isWebp(bytes('RIFF\x00\x00\x00\x00WEBPVP8 ')), isTrue);
    expect(PhotoUploader.isWebp(bytes('\x89PNG\r\n\x1a\n\x00\x00\x00\x0dIHDR')), isFalse);
    expect(PhotoUploader.isWebp(Uint8List(4)), isFalse);
  });

  group('anniversary on a date', () {
    final journal = mockJournal();

    test('yearly ones match on day and month in any year', () {
      expect(journal.anniversaryOn(DateTime(2031, 10, 30))?.isStart, isTrue);
      expect(journal.anniversaryOn(DateTime(2026, 11, 23))?.title, 'sinh nhật Xuka');
    });

    test('other days have none', () {
      expect(journal.anniversaryOn(DateTime(2026, 10, 31)), isNull);
    });
  });
}
