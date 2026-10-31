import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/paper_bits.dart';

/// 10 · Thùng giấy: what either of them deleted, kept 30 days. Restoring puts
/// it back where it was on the stem.
class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.session, required this.store});

  final ValueListenable<Session?> session;
  final JournalStore store;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, s, _) {
        if (s == null) return const Scaffold();
        final journal = s.journal;
        final today = DateTime.now();
        final items = _items(journal)..sort((a, b) => b.trashed.at.compareTo(a.trashed.at));

        return Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Quay lại',
                                onPressed: () => Navigator.pop(context),
                                style: IconButton.styleFrom(
                                  backgroundColor: Paper.c1,
                                  side: const BorderSide(color: Paper.c5),
                                  fixedSize: const Size.square(44),
                                ),
                                icon: const Icon(Icons.arrow_back, size: 18, color: Paper.c8),
                              ),
                              Expanded(child: Text('Thùng giấy', textAlign: TextAlign.center, style: AppText.h1.copyWith(fontSize: 24))),
                              const SizedBox(width: 44),
                            ],
                          ),
                          const SizedBox(height: Space.s3),
                          Text(
                            'Những gì đã xoá nằm đây ${Trashed.keepDays} ngày rồi mới mất hẳn. '
                            'Khôi phục thì nó mọc lại đúng chỗ cũ trên thân hoa.',
                            style: AppText.body.copyWith(fontSize: 13, color: Paper.c7),
                          ),
                          const SizedBox(height: Space.s5),
                          if (items.isEmpty)
                            Text('thùng giấy đang trống', textAlign: TextAlign.center, style: AppText.script.copyWith(fontSize: 18)),
                          for (final item in items)
                            _Row(
                              item: item,
                              who: journal.person(item.trashed.by).name,
                              daysLeft: item.trashed.daysLeft(today),
                              onRestore: () => item.moment != null
                                  ? store.restoreMoment(item.moment!, journal)
                                  : store.restorePhotos([for (final p in item.photos) p.id]),
                              onPurge: () => _confirmPurge(context, 'Xoá hẳn “${item.title}”? Không khôi phục được nữa.').then((sure) async {
                                if (!sure) return;
                                item.moment != null ? await store.purgeMoment(item.moment!, journal) : await store.purgePhotos(item.photos);
                              }),
                            ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: OutlinedButton(
                          onPressed: () async {
                            if (!await _confirmPurge(context, 'Dọn sạch thùng giấy? Mọi thứ trong này sẽ mất hẳn.')) return;
                            for (final m in journal.trashedMoments) {
                              await store.purgeMoment(m, journal);
                            }
                            await store.purgePhotos([for (final p in journal.trashedPhotos) if (p.trashed!.withMoment == null) p]);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Sakura.c7,
                            side: const BorderSide(color: Sakura.c4),
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text('Dọn sạch thùng giấy'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Trashed moments, and loose photos grouped the way they hung on the stem.
  /// Photos that went in with a moment show as part of that moment.
  static List<_Item> _items(Journal journal) {
    final stacks = <Object, List<Photo>>{};
    for (final p in journal.trashedPhotos.where((p) => p.trashed!.withMoment == null)) {
      stacks.putIfAbsent(p.stackId ?? p.id, () => []).add(p);
    }
    return [
      for (final m in journal.trashedMoments)
        _Item(
          moment: m,
          photos: [for (final p in journal.trashedPhotos) if (p.trashed!.withMoment == m.id) p],
          trashed: m.trashed!,
        ),
      for (final photos in stacks.values) _Item(photos: photos, trashed: photos.first.trashed!),
    ];
  }

  static Future<bool> _confirmPurge(BuildContext context, String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Paper.c1,
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('thôi')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Sakura.c7),
              child: const Text('Xoá hẳn'),
            ),
          ],
        ),
      ) ??
      false;
}

class _Item {
  const _Item({this.moment, required this.photos, required this.trashed});

  final Moment? moment;
  final List<Photo> photos;
  final Trashed trashed;

  String get title => moment?.title ?? photos.first.title ?? '${photos.length} ảnh';
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.who, required this.daysLeft, required this.onRestore, required this.onPurge});

  final _Item item;
  final String who;
  final int daysLeft;
  final VoidCallback onRestore;
  final VoidCallback onPurge;

  @override
  Widget build(BuildContext context) {
    final photos = item.photos;
    final kind = item.moment != null
        ? 'kỷ niệm · ${photos.length} ảnh'
        : 'ảnh lẻ · ${dotDate(photos.first.takenAt)}${photos.length > 1 ? ' · ×${photos.length}' : ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Container(
        padding: const EdgeInsets.all(Space.s3),
        decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.paperSm),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 56,
              child: Opacity(opacity: .7, child: PhotoBox(url: photos.firstOrNull?.thumbUrl, radius: Radii.photo)),
            ),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(fontSize: 15)),
                  Text('$kind · $who xoá', style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w400)),
                  Text(daysLeft <= 1 ? 'mai là mất hẳn' : 'còn $daysLeft ngày', style: AppText.script.copyWith(fontSize: 15)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FilledButton(
                  onPressed: onRestore,
                  style: FilledButton.styleFrom(backgroundColor: Paper.c8, visualDensity: VisualDensity.compact),
                  child: const Text('khôi phục'),
                ),
                TextButton(
                  onPressed: onPurge,
                  style: TextButton.styleFrom(foregroundColor: Sakura.c7, visualDensity: VisualDensity.compact),
                  child: const Text('xoá hẳn'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
