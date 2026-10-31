import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../viewer/photo_viewer.dart';
import '../widgets/paper_bits.dart';

/// 03 · Trang kỷ niệm (a moment): photos, the story, and what each of them felt.
class MomentPage extends StatelessWidget {
  const MomentPage({super.key, required this.session, required this.store, required this.momentId});

  final ValueListenable<Session?> session;
  final JournalStore store;
  final String momentId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: session,
      builder: (context, s, _) {
        final moment = s?.journal.moment(momentId);
        if (s == null || moment == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Paper.c3),
            body: Center(child: Text('Kỷ niệm này không còn trong sổ nữa.', style: AppText.body)),
          );
        }
        final journal = s.journal;
        final photos = journal.photosOf(moment);
        final entries = journal.entries.where((e) => e.momentId == moment.id).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final anniversary = journal.anniversaries.where((a) => a.id == moment.anniversaryId).firstOrNull;

        void openPhoto(int i) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PhotoViewer(session: session, store: store, photoIds: [for (final p in photos) p.id], initial: i),
              ),
            );

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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                tooltip: 'Về trang chủ',
                                onPressed: () => Navigator.pop(context),
                                style: _roundButton,
                                icon: const Icon(Icons.arrow_back, size: 18, color: Paper.c8),
                              ),
                              // Only whoever made the moment can delete it.
                              if (moment.addedBy == s.me)
                                IconButton(
                                  tooltip: 'Xoá kỷ niệm',
                                  onPressed: () => _trashMoment(context, moment, photos.length, s.me),
                                  style: _roundButton,
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Paper.c8),
                                ),
                            ],
                          ),
                          const SizedBox(height: Space.s3),
                          Text(
                            [dotDate(moment.date), if (anniversary != null) anniversary.titleOn(moment.date)].join(' · '),
                            style: AppText.script.copyWith(fontSize: 20),
                          ),
                          Text(moment.title, style: AppText.h1.copyWith(height: 1.15)),
                          const SizedBox(height: 4),
                          Text(
                            '${journal.person(moment.addedBy).name} thêm · ${photos.length} ảnh',
                            style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w400),
                          ),
                          const SizedBox(height: Space.s4),
                          if (photos.isNotEmpty)
                            _PhotoGrid(
                              photos: photos,
                              momentId: moment.id,
                              onOpen: openPhoto,
                              onHold: (p) => _photoActions(context, moment, p),
                            ),
                          if (moment.body.isNotEmpty) ...[
                            const SizedBox(height: Space.s5),
                            _StoryCard(text: moment.body, tapeColor: journal.person(moment.addedBy).color),
                          ],
                          const SizedBox(height: Space.s5),
                          Text('TỤI MÌNH CẢM THẤY', style: AppText.label),
                          const SizedBox(height: Space.s3),
                          if (entries.isEmpty)
                            Text('chưa ai viết gì, mở lời trước đi…', style: AppText.body.copyWith(fontSize: 13, color: Paper.c7)),
                          for (final e in entries)
                            _Bubble(
                              entry: e,
                              author: journal.person(e.author),
                              left: journal.isLeftSide(e.author),
                              onHold: e.author == s.me ? () => _entryActions(context, e) : null,
                            ),
                        ],
                      ),
                    ),
                    _Composer(me: journal.person(s.me), onSend: (text) => store.addEntry(moment.id, text, by: s.me)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static final _roundButton = IconButton.styleFrom(
    backgroundColor: Paper.c1,
    side: const BorderSide(color: Paper.c5),
    fixedSize: const Size.square(44),
  );

  /// The design's three-way question: keep the photos on the stem, trash
  /// them with it, or never mind.
  Future<void> _trashMoment(BuildContext context, Moment moment, int photoCount, String me) async {
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
    if (choice == null) return;
    await store.trashMoment(moment, withPhotos: choice == 'all', by: me);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _photoActions(BuildContext context, Moment moment, Photo photo) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Paper.c1,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (moment.coverPhotoId != photo.id)
            ListTile(leading: const Icon(Icons.star_outline), title: const Text('Đặt làm bìa'), onTap: () => Navigator.pop(context, 'cover')),
          ListTile(
            leading: const Icon(Icons.call_split),
            title: const Text('Gỡ khỏi kỷ niệm (về thân hoa)'),
            onTap: () => Navigator.pop(context, 'detach'),
          ),
          const SizedBox(height: Space.s4),
        ],
      ),
    );
    switch (choice) {
      case 'cover':
        await store.setCover(moment.id, photo.id);
      case 'detach':
        await store.detachPhoto(photo.id, moment);
    }
  }

  Future<void> _entryActions(BuildContext context, Entry entry) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Paper.c1,
      showDragHandle: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Sửa'), onTap: () => Navigator.pop(context, 'edit')),
          ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Xoá'), onTap: () => Navigator.pop(context, 'delete')),
          const SizedBox(height: Space.s4),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'edit':
        final text = await showDialog<String>(context: context, builder: (_) => _EditEntryDialog(initial: entry.text));
        if (text != null && text.trim().isNotEmpty) await store.updateEntry(entry.id, text);
      case 'delete':
        final sure = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Paper.c1,
            content: const Text('Xoá cảm nghĩ này?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('thôi')),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Sakura.c7),
                child: const Text('Xoá'),
              ),
            ],
          ),
        );
        if (sure ?? false) await store.deleteEntry(entry.id);
    }
  }
}

/// Cover as a 2×2 tile, then up to four more; a seventh photo onwards turns
/// the last tile into "+N".
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({required this.photos, required this.momentId, required this.onOpen, required this.onHold});

  final List<Photo> photos;
  final String momentId;
  final ValueChanged<int> onOpen;
  final ValueChanged<Photo> onHold;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      if (photos.length == 1) {
        return AspectRatio(aspectRatio: math.max(.8, photos.first.aspectRatio), child: _tile(0, cover: true));
      }
      final small = (box.maxWidth - 2 * _gap) / 3;
      final big = small * 2 + _gap;
      final overflow = photos.length > 6;
      final shown = overflow ? 6 : photos.length;

      Widget at(int i) => SizedBox.square(
            dimension: small,
            child: i >= shown ? null : (overflow && i == 5 ? _more(photos.length - 5) : _tile(i)),
          );

      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(dimension: big, child: _tile(0, cover: true)),
              const SizedBox(width: _gap),
              Column(children: [at(1), const SizedBox(height: _gap), at(2)]),
            ],
          ),
          if (shown > 3) ...[
            const SizedBox(height: _gap),
            Row(children: [at(3), const SizedBox(width: _gap), at(4), const SizedBox(width: _gap), at(5)]),
          ],
        ],
      );
    });
  }

  Widget _tile(int i, {bool cover = false}) {
    final p = photos[i];
    final image = PhotoBox(url: cover ? p.fullUrl ?? p.thumbUrl : p.thumbUrl, radius: Radii.photo);
    return Semantics(
      button: true,
      label: p.title ?? 'Ảnh ${i + 1}',
      child: GestureDetector(
        onTap: () => onOpen(i),
        onLongPress: () => onHold(p),
        child: cover ? Hero(tag: 'cover-$momentId', child: image) : image,
      ),
    );
  }

  Widget _more(int rest) => Semantics(
        button: true,
        label: 'Xem thêm $rest ảnh',
        child: GestureDetector(
          onTap: () => onOpen(5),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Paper.c8, borderRadius: BorderRadius.circular(Radii.photo)),
            child: Text('+$rest', style: AppText.body.copyWith(color: Paper.c1, fontSize: 15, fontWeight: FontWeight.w400)),
          ),
        ),
      );
}

class _StoryCard extends StatelessWidget {
  const _StoryCard({required this.text, required this.tapeColor});

  final String text;
  final Color tapeColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(color: Paper.c1, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.paper),
          child: SelectableText(text, style: AppText.quote.copyWith(height: 1.6)),
        ),
        Positioned(top: -8, right: 20, child: Tape(color: tapeColor, width: 58, height: 16, degrees: 4)),
      ],
    );
  }
}

/// One cảm nghĩ. Not a chat: each of them can write as often and as long as
/// they like; the first person sits left, the other right.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.entry, required this.author, required this.left, required this.onHold});

  final Entry entry;
  final Person author;
  final bool left;

  /// Only set for your own: hold to edit or delete.
  final VoidCallback? onHold;

  @override
  Widget build(BuildContext context) {
    final nameColor = author.color == Sage.c2 ? Sage.c3 : Sakura.c7;
    const r = Radius.circular(14);
    const corner = Radius.circular(4);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: left ? TextDirection.ltr : TextDirection.rtl,
        children: [
          PersonAvatar(person: author),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onLongPress: onHold,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: Paper.c1,
                  borderRadius: BorderRadius.only(topLeft: left ? corner : r, topRight: left ? r : corner, bottomLeft: r, bottomRight: r),
                  boxShadow: Shadows.paperSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(author.name, style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0, color: nameColor))),
                        Text(dotDate(entry.createdAt), style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0, fontWeight: FontWeight.w400)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(entry.text, style: AppText.body.copyWith(fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Fixed at the bottom; Ctrl+Enter sends on a keyboard.
class _Composer extends StatefulWidget {
  const _Composer({required this.me, required this.onSend});

  final Person me;
  final Future<void> Function(String text) onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _text = TextEditingController();
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
      _text.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('chưa gửi được ($e)')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _text.text.trim().isNotEmpty && !_sending;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: const BoxDecoration(color: Paper.c3, border: Border(top: BorderSide(color: Paper.c5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(padding: const EdgeInsets.only(bottom: 7), child: PersonAvatar(person: widget.me)),
          const SizedBox(width: 10),
          Expanded(
            child: CallbackShortcuts(
              bindings: {const SingleActivator(LogicalKeyboardKey.enter, control: true): _send},
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                decoration: InputDecoration(
                  hintText: 'viết gì đó về kỷ niệm này…',
                  fillColor: Paper.c1,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Paper.c5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Paper.c8)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Gửi cảm nghĩ',
            onPressed: canSend ? _send : null,
            style: IconButton.styleFrom(
              backgroundColor: Paper.c8,
              disabledBackgroundColor: Paper.c5,
              fixedSize: const Size.square(44),
            ),
            icon: const Icon(Icons.send_rounded, size: 18, color: Paper.c1),
          ),
        ],
      ),
    );
  }
}

class _EditEntryDialog extends StatefulWidget {
  const _EditEntryDialog({required this.initial});

  final String initial;

  @override
  State<_EditEntryDialog> createState() => _EditEntryDialogState();
}

class _EditEntryDialogState extends State<_EditEntryDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Paper.c1,
      title: Text('Sửa cảm nghĩ', style: AppText.title.copyWith(fontSize: 18)),
      content: TextField(controller: _text, autofocus: true, minLines: 3, maxLines: 10, style: AppText.body.copyWith(fontSize: 14)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('huỷ')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text),
          style: FilledButton.styleFrom(backgroundColor: Paper.c8),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}
