// The real app's screens on made-up data, for the README screenshots.
// `?screen=` picks one: login, home, moment, photo, anniversaries, trash,
// add-photos, add-moment, edit-moment.
// Built and shot by tool/screenshots/shoot.mjs; nothing here talks to the
// journal — Firebase is only initialised so the pages can be built.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:us_together/add/add_moment_sheet.dart';
import 'package:us_together/add/add_photos_sheet.dart';
import 'package:us_together/add/photo_pipeline.dart';
import 'package:us_together/add/sheet_frame.dart';
import 'package:us_together/anniversaries/anniversaries_page.dart';
import 'package:us_together/auth/login_page.dart';
import 'package:us_together/data/journal_store.dart';
import 'package:us_together/data/models.dart';
import 'package:us_together/firebase_options.dart';
import 'package:us_together/home/home_page.dart';
import 'package:us_together/moment/moment_page.dart';
import 'package:us_together/theme/app_theme.dart';
import 'package:us_together/theme/tokens.dart';
import 'package:us_together/trash/trash_page.dart';
import 'package:us_together/viewer/photo_viewer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final store = JournalStore(FirebaseFirestore.instance, PhotoUploader(FirebaseStorage.instance));
  final session = ValueNotifier<Session?>((journal: _journal(), me: 'hkha'));
  final journal = session.value!.journal;

  final home = HomePage(journal: journal, meId: 'hkha', store: store, session: session, onSignOut: () async {});
  final page = switch (Uri.base.queryParameters['screen']) {
    'login' => const LoginPage(),
    'trash' => TrashPage(session: session, store: store),
    'add-photos' => _WithSheet(home, AddPhotosSheet(store: store, me: 'hkha')),
    'add-moment' => _WithSheet(home, AddMomentSheet(store: store, journal: journal, me: 'hkha')),
    'edit-moment' => _WithSheet(home, AddMomentSheet(store: store, journal: journal, me: 'hkha', editing: journal.moment('m1'))),
    'moment' => MomentPage(session: session, store: store, momentId: 'm1'),
    'photo' => PhotoViewer(
        session: session,
        store: store,
        photoIds: [for (final p in journal.photos) if (p.stackId == 'l1') p.id],
      ),
    'anniversaries' => AnniversariesPage(session: session, store: store),
    _ => home,
  };

  runApp(
    MaterialApp(
      theme: buildAppTheme(),
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      home: page,
    ),
  );
}

/// [page] with [sheet] opened over it, as the app shows sheets.
class _WithSheet extends StatefulWidget {
  const _WithSheet(this.page, this.sheet);

  final Widget page;
  final Widget sheet;

  @override
  State<_WithSheet> createState() => _WithSheetState();
}

class _WithSheetState extends State<_WithSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => showPaperSheet(context, widget.sheet));
  }

  @override
  Widget build(BuildContext context) => widget.page;
}

Journal _journal() {
  const hkha = Person(id: 'hkha', name: 'hkha', color: Sakura.c5);
  const xuka = Person(id: 'xuka', name: 'Xuka', color: Sage.c2);
  final photos = <Photo>[];
  var next = 0;

  // Painted stand-ins from demo_photos_test.dart, cycling portrait,
  // landscape and square.
  List<String> add(int count, DateTime at, String by, {String? momentId, String? stackId, String? title, Trashed? trashed}) => [
        for (var i = 0; i < count; i++)
          () {
            final n = next++ % 18;
            final photo = Photo(
              id: 'p$next',
              takenAt: at.add(Duration(minutes: i)),
              addedBy: by,
              thumbUrl: 'demo-photos/$n.png',
              fullUrl: 'demo-photos/$n.png',
              aspectRatio: const [.8, 1.5, 1.0][n % 3],
              title: title,
              momentId: momentId,
              stackId: stackId,
              trashed: trashed,
            );
            photos.add(photo);
            return photo.id;
          }(),
      ];

  Moment moment(String id, DateTime date, String title, String by, int count, {String body = '', String? anniversaryId}) {
    final ids = add(count, date, by, momentId: id);
    return Moment(id: id, date: date, title: title, addedBy: by, body: body, photoIds: ids, coverPhotoId: ids.first, anniversaryId: anniversaryId);
  }

  final moments = [
    moment(
      'm1',
      DateTime(2026, 10, 18),
      'Đà Lạt mùa mưa',
      'hkha',
      9,
      body: 'Mưa cả ba ngày mà vẫn vui. Sáng nào cũng đi tìm một quán cà phê mới, '
          'tối về ăn bánh căn rồi ngồi nghe mưa trên mái tôn.',
    ),
    moment('m2', DateTime(2026, 8, 30), 'Đi biển một ngày', 'xuka', 5),
    moment('m3', DateTime(2026, 2, 14), 'Kỷ niệm 3 năm', 'xuka', 4, anniversaryId: 'a-start'),
    moment('m4', DateTime(2025, 12, 24), 'Giáng sinh ở nhà', 'hkha', 6),
  ];
  add(3, DateTime(2026, 10, 26, 8), 'xuka', stackId: 'l1', title: 'cà phê sáng chủ nhật');
  add(1, DateTime(2026, 9, 21, 18), 'hkha', stackId: 'l2', title: 'hoàng hôn trên cầu');
  add(2, DateTime(2026, 4, 3, 19), 'xuka', stackId: 'l3', title: 'đêm trăng');
  add(4, DateTime(2025, 10, 6, 20), 'hkha', stackId: 'l4', title: 'trung thu');

  // In the trash: a moment with its photos, and one loose photo.
  final binned = Trashed(at: DateTime.now().subtract(const Duration(days: 4)), by: 'xuka', withMoment: 't1');
  final binnedIds = add(3, DateTime(2026, 5, 9), 'xuka', momentId: 't1', trashed: binned);
  add(1, DateTime(2026, 6, 1, 9), 'hkha', stackId: 't2', title: 'ảnh mờ',
      trashed: Trashed(at: DateTime.now().subtract(const Duration(days: 12)), by: 'hkha'));

  Entry entry(String id, String author, String text, int day) =>
      Entry(id: id, momentId: 'm1', author: author, text: text, createdAt: DateTime(2026, 10, day, 21));

  return Journal(
    people: const [hkha, xuka],
    moments: moments,
    photos: [for (final p in photos) if (p.trashed == null) p],
    trashedMoments: [
      Moment(
        id: 't1',
        date: DateTime(2026, 5, 9),
        title: 'Picnic công viên',
        addedBy: 'xuka',
        photoIds: binnedIds,
        coverPhotoId: binnedIds.first,
        trashed: binned,
      ),
    ],
    trashedPhotos: [for (final p in photos) if (p.trashed != null) p],
    entries: [
      entry('e1', 'xuka', 'Lần sau đi mùa khô nha, nhưng mà mưa cũng thích ghê.', 20),
      entry('e2', 'hkha', 'Nhớ cái quán có con mèo nằm trên quầy.', 21),
    ],
    anniversaries: [
      Anniversary(id: 'a-start', title: 'ngày bắt đầu yêu', date: DateTime(2023, 2, 14), isStart: true),
      Anniversary(id: 'a-xuka', title: 'sinh nhật Xuka', date: DateTime(2001, 11, 23)),
      Anniversary(id: 'a-hkha', title: 'sinh nhật hkha', date: DateTime(2001, 3, 2)),
    ],
  );
}
