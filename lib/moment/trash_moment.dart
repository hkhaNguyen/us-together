import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// The design's three-way question before a moment goes to the trash: keep
/// its photos on the stem, trash them with it, or never mind. True if it
/// was trashed.
Future<bool> confirmTrashMoment(BuildContext context, JournalStore store, Moment moment, {required String me}) async {
  final photoCount = moment.photoIds.length;
  final choice = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: Paper.c1,
      title: Text('Xoá kỷ niệm này?', style: AppText.title.copyWith(fontSize: 18)),
      content: Text(
        'Kỷ niệm sẽ vào thùng giấy ${Trashed.keepDays} ngày, hai đứa đều khôi phục được.'
        '${photoCount > 0 ? ' Còn $photoCount tấm ảnh trong đó thì sao?' : ''}',
        style: AppText.body.copyWith(fontSize: 14),
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: Space.s2,
      actions: [
        if (photoCount > 0)
          OutlinedButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Giữ ảnh lại trên thân hoa')),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'all'),
          style: FilledButton.styleFrom(backgroundColor: Sakura.c7),
          child: Text(photoCount > 0 ? 'Xoá cả kỷ niệm lẫn $photoCount ảnh' : 'Xoá'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Thôi, giữ lại')),
      ],
    ),
  );
  if (choice == null) return false;
  await store.trashMoment(moment, withPhotos: choice == 'all', by: me);
  return true;
}
