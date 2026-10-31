import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../add/photo_pipeline.dart';
import '../theme/tokens.dart';
import 'models.dart';

/// The journal plus which person is signed in on this device.
typedef Session = ({Journal journal, String me});

/// Firestore layout. `addedBy` / `author` hold a person id, not an email, so
/// either of someone's emails shows up as the same person.
///
///   people/{personId}    name, color ('sakura' | 'sage')     ┐ added by hand
///   members/{email}      person (a personId) — the access    ┘ in the console
///                        list for the rules; several emails per person
///   moments/{id}         date, title, body, photoIds, coverPhotoId, addedBy,
///                        anniversaryId, createdAt
///   photos/{id}          takenAt, addedBy, title, momentId, thumbUrl, fullUrl,
///                        w, h, createdAt — files under photos/{id}/ in Storage
///   entries/{id}         momentId, author, text, createdAt
///   anniversaries/{id}   title, date, yearly, isStart
class JournalStore {
  JournalStore(this._db, this._uploader);

  final FirebaseFirestore _db;
  final PhotoUploader _uploader;

  static const _collections = ['members', 'people', 'moments', 'photos', 'entries', 'anniversaries'];

  /// The whole journal, re-emitted whenever either of them changes anything.
  /// Errors with `permission-denied` when [email] isn't listed under members/.
  Stream<Session> watch(String email) {
    final latest = List<QuerySnapshot<Map<String, dynamic>>?>.filled(_collections.length, null);
    final subs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    late final StreamController<Session> controller;
    controller = StreamController(
      onListen: () {
        for (final (i, name) in _collections.indexed) {
          subs.add(_db.collection(name).snapshots().listen(
            (snapshot) {
              latest[i] = snapshot;
              if (latest.every((s) => s != null)) {
                final [members, ...rest] = [for (final s in latest) s!.docs];
                final me = members.where((d) => d.id == email).firstOrNull?.data()['person'] as String?;
                controller.add((journal: _journal(rest), me: me ?? email));
              }
            },
            onError: controller.addError,
          ));
        }
      },
      onCancel: () => Future.wait([for (final s in subs) s.cancel()]),
    );
    return controller.stream;
  }

  Future<void> setStartDate(DateTime date) => _db.collection('anniversaries').add({
        'title': 'ngày bắt đầu yêu',
        'date': Timestamp.fromDate(date),
        'yearly': true,
        'isStart': true,
      });

  /// Loose photos, each with its own date and title. [onProgress] gets the
  /// number uploaded so far.
  Future<void> addPhotos(List<PickedPhoto> photos, {required String by, ValueChanged<int>? onProgress}) async {
    final batch = _db.batch();
    await _uploadAll(photos, batch, by: by, onProgress: onProgress);
    await batch.commit();
  }

  /// A moment and its photos, in the order given; [cover] indexes [photos].
  Future<void> addMoment({
    required List<PickedPhoto> photos,
    required int cover,
    required DateTime date,
    required String title,
    required String body,
    required String? anniversaryId,
    required String by,
    ValueChanged<int>? onProgress,
  }) async {
    final moment = _db.collection('moments').doc();
    final batch = _db.batch();
    final ids = await _uploadAll(photos, batch, by: by, momentId: moment.id, onProgress: onProgress);
    batch.set(moment, {
      'date': Timestamp.fromDate(date),
      'title': title,
      'body': body,
      'photoIds': ids,
      'coverPhotoId': ids.isEmpty ? null : ids[cover],
      'addedBy': by,
      'anniversaryId': anniversaryId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  /// Uploads every file first and only queues the documents in [batch], so a
  /// dropped connection never leaves half a moment visible to the other one.
  Future<List<String>> _uploadAll(
    List<PickedPhoto> photos,
    WriteBatch batch, {
    required String by,
    String? momentId,
    ValueChanged<int>? onProgress,
  }) async {
    final ids = <String>[];
    for (final p in photos) {
      final doc = _db.collection('photos').doc();
      final files = await _uploader.upload(doc.id, p);
      final title = p.title.trim();
      batch.set(doc, {
        ...files,
        'takenAt': Timestamp.fromDate(p.takenAt),
        'addedBy': by,
        'title': title.isEmpty ? null : title,
        'momentId': momentId,
        'createdAt': FieldValue.serverTimestamp(),
      });
      ids.add(doc.id);
      onProgress?.call(ids.length);
    }
    return ids;
  }

  static Journal _journal(List<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docs) {
    final [people, moments, photos, entries, anniversaries] = docs;
    DateTime date(Object? v) => (v as Timestamp).toDate();

    return Journal(
      people: [
        for (final d in people)
          Person(id: d.id, name: d['name'] as String, color: d.data()['color'] == 'sage' ? Sage.c2 : Sakura.c5),
      ],
      moments: [
        for (final d in moments)
          Moment(
            id: d.id,
            date: date(d['date']),
            title: d['title'] as String,
            addedBy: d['addedBy'] as String,
            body: d.data()['body'] as String? ?? '',
            photoIds: List<String>.from(d.data()['photoIds'] as List? ?? const []),
            coverPhotoId: d.data()['coverPhotoId'] as String?,
            anniversaryId: d.data()['anniversaryId'] as String?,
          ),
      ],
      photos: [
        for (final d in photos)
          Photo(
            id: d.id,
            takenAt: date(d['takenAt']),
            addedBy: d['addedBy'] as String,
            thumbUrl: d.data()['thumbUrl'] as String?,
            title: d.data()['title'] as String?,
            momentId: d.data()['momentId'] as String?,
          ),
      ],
      entries: [
        for (final d in entries)
          Entry(
            id: d.id,
            momentId: d['momentId'] as String,
            author: d['author'] as String,
            text: d['text'] as String,
            createdAt: date(d['createdAt']),
          ),
      ],
      anniversaries: [
        for (final d in anniversaries)
          Anniversary(
            id: d.id,
            title: d['title'] as String,
            date: date(d['date']),
            yearly: d.data()['yearly'] as bool? ?? true,
            isStart: d.data()['isStart'] as bool? ?? false,
          ),
      ],
    );
  }
}
