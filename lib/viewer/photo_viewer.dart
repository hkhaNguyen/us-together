import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/paper_bits.dart';
import 'save_photo.dart';

/// 06 · Xem một ảnh: the only dark screen. Swipe sideways through [photoIds],
/// pinch to zoom, swipe down to close.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.session, required this.store, required this.photoIds, this.initial = 0});

  final ValueListenable<Session?> session;
  final JournalStore store;
  final List<String> photoIds;
  final int initial;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late var _index = widget.initial;
  var _zoomed = false;
  var _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save(Photo photo) async {
    setState(() => _saving = true);
    try {
      final bytes = await widget.store.downloadPhoto(photo);
      if (bytes == null) throw StateError('không có dữ liệu');
      await savePhoto(bytes, 'us-together-${photo.takenAt.toIso8601String().substring(0, 10)}-${photo.id}');
      _say(kIsWeb ? 'đã tải ảnh về' : 'đã lưu vào thư viện ảnh');
    } catch (e) {
      _say('chưa tải được ảnh ($e)');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editTitle(Photo photo) async {
    final title = await showDialog<String>(context: context, builder: (_) => _TitleDialog(initial: photo.title ?? ''));
    if (title != null) await widget.store.setPhotoTitle(photo.id, title);
  }

  Future<void> _attach(Journal journal, Photo photo) async {
    // Moments closest in time to the photo come first.
    final moments = [...journal.moments]
      ..sort((a, b) => a.date.difference(photo.takenAt).abs().compareTo(b.date.difference(photo.takenAt).abs()));
    final chosen = await showModalBottomSheet<Moment>(
      context: context,
      backgroundColor: Paper.c1,
      showDragHandle: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Gắn vào kỷ niệm nào?', style: AppText.title.copyWith(fontSize: 18)),
          ),
          for (final m in moments)
            ListTile(
              title: Text(m.title, style: AppText.title.copyWith(fontSize: 15)),
              subtitle: Text(dotDate(m.date), style: AppText.script.copyWith(fontSize: 15)),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    await widget.store.attachPhoto(photo.id, chosen.id);
    _say('đã gắn vào “${chosen.title}”');
  }

  Future<void> _more(BuildContext button, Journal journal, Photo photo) async {
    final moment = photo.momentId == null ? null : journal.moment(photo.momentId!);
    if (moment == null) return;
    final overlay = Overlay.of(button).context.findRenderObject()! as RenderBox;
    final box = button.findRenderObject()! as RenderBox;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(box.localToGlobal(Offset.zero, ancestor: overlay) & box.size, Offset.zero & overlay.size),
      items: [
        if (moment.coverPhotoId != photo.id) const PopupMenuItem(value: 'cover', child: Text('Đặt làm bìa kỷ niệm')),
        const PopupMenuItem(value: 'detach', child: Text('Gỡ khỏi kỷ niệm (về thân hoa)')),
      ],
    );
    switch (choice) {
      case 'cover':
        await widget.store.setCover(moment.id, photo.id);
        _say('đã đặt làm bìa');
      case 'detach':
        await widget.store.detachPhoto(photo.id, moment);
        _say('ảnh đã về thân hoa');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.session,
      builder: (context, session, _) {
        final journal = session?.journal;
        final photos = [for (final id in widget.photoIds) ?journal?.photo(id)];
        if (journal == null || photos.isEmpty) {
          return const Scaffold(backgroundColor: Paper.c9, body: Center(child: CircularProgressIndicator(color: Paper.c4)));
        }
        final index = _index.clamp(0, photos.length - 1);
        final photo = photos[index];
        final adder = journal.person(photo.addedBy);
        final mine = photo.addedBy == session!.me;
        const outline = BorderSide(color: Paper.c7);

        return Scaffold(
          backgroundColor: Paper.c9,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Đóng',
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(side: outline, fixedSize: const Size.square(44)),
                        icon: const Icon(Icons.close, size: 18, color: Paper.c1),
                      ),
                      Expanded(
                        child: Text(
                          photos.length > 1 ? '${index + 1} / ${photos.length}' : '',
                          textAlign: TextAlign.center,
                          style: AppText.body.copyWith(fontSize: 12, color: Paper.c5),
                        ),
                      ),
                      if (photo.momentId != null)
                        Builder(
                          builder: (button) => IconButton(
                            tooltip: 'Thêm tuỳ chọn',
                            onPressed: () => _more(button, journal, photo),
                            style: IconButton.styleFrom(side: outline, fixedSize: const Size.square(44)),
                            icon: const Icon(Icons.more_horiz, size: 18, color: Paper.c1),
                          ),
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    // Swipe down to close, unless zoomed in (then it pans).
                    onVerticalDragEnd: (d) {
                      if (!_zoomed && (d.primaryVelocity ?? 0) > 600) Navigator.pop(context);
                    },
                    child: PageView.builder(
                      controller: _pages,
                      physics: _zoomed ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _Polaroid(
                        photo: photos[i],
                        tapeColor: journal.person(photos[i].addedBy).color,
                        onZoomed: (z) => setState(() => _zoomed = z),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          AvatarDot(color: adder.color, size: 26),
                          const SizedBox(width: Space.s2),
                          Expanded(
                            child: Text.rich(
                              TextSpan(children: [
                                TextSpan(text: '${adder.name} thêm · '),
                                TextSpan(text: dotDate(photo.takenAt), style: AppText.script.copyWith(fontSize: 15, color: Sakura.c2)),
                              ]),
                              style: AppText.body.copyWith(fontSize: 12, color: Paper.c5),
                            ),
                          ),
                          if (photos.length > 1 && photos.length <= 12) _Dots(count: photos.length, index: index),
                        ],
                      ),
                      const SizedBox(height: Space.s3),
                      Row(
                        children: [
                          if (photo.momentId == null && journal.moments.isNotEmpty)
                            _PillButton(label: 'gắn vào kỷ niệm', onPressed: () => _attach(journal, photo)),
                          if (mine) _PillButton(label: 'sửa tiêu đề', onPressed: () => _editTitle(photo)),
                          _PillButton(label: _saving ? 'đang tải…' : 'tải về', onPressed: _saving ? null : () => _save(photo)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One page: the photo on a polaroid with its title on the tail. The
/// thumbnail shows at once and the full image replaces it when loaded.
class _Polaroid extends StatefulWidget {
  const _Polaroid({required this.photo, required this.tapeColor, required this.onZoomed});

  final Photo photo;
  final Color tapeColor;
  final ValueChanged<bool> onZoomed;

  @override
  State<_Polaroid> createState() => _PolaroidState();
}

class _PolaroidState extends State<_Polaroid> {
  final _zoom = TransformationController();

  @override
  void dispose() {
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photo;
    final title = p.title ?? '';
    return LayoutBuilder(builder: (context, box) {
      // Fit the photo plus the polaroid's frame and title into the space.
      final titleSpace = title.isEmpty ? 36.0 : 96.0;
      final maxW = math.min(box.maxWidth - 40, 480.0);
      final maxH = box.maxHeight - 24 - 24 - titleSpace;
      final w = math.max(80.0, math.min(maxW - 24, maxH * p.aspectRatio));

      return Center(
        child: Transform.rotate(
          angle: -math.pi / 180,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: w + 24,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  color: Paper.polaroid,
                  boxShadow: [BoxShadow(offset: const Offset(0, 24), blurRadius: 48, color: Colors.black.withValues(alpha: .5))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InteractiveViewer(
                      transformationController: _zoom,
                      minScale: 1,
                      maxScale: 4,
                      onInteractionEnd: (_) => widget.onZoomed(_zoom.value.getMaxScaleOnAxis() > 1.01),
                      child: Hero(
                        tag: 'photo-${p.id}',
                        child: SizedBox(
                          width: w,
                          height: w / p.aspectRatio,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PhotoBox(url: p.thumbUrl),
                              if (p.fullUrl != null)
                                Image.network(
                                  p.fullUrl!,
                                  fit: BoxFit.cover,
                                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                                  frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                                    opacity: sync || frame != null ? 1 : 0,
                                    duration: Motion.dur1,
                                    child: child,
                                  ),
                                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: titleSpace - 12,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Text(title, textAlign: TextAlign.center, style: AppText.script.copyWith(fontSize: 20, height: 1.3)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -9,
                left: (w + 24) / 2 - 45,
                child: Tape(color: widget.tapeColor, width: 90, height: 22, degrees: -3),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.dur1,
            margin: const EdgeInsets.only(left: 4),
            width: i == index ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == index ? Paper.c1 : Paper.c7, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: Paper.c1,
            side: const BorderSide(color: Paper.c7),
            minimumSize: const Size.fromHeight(44),
            textStyle: AppText.body.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _TitleDialog extends StatefulWidget {
  const _TitleDialog({required this.initial});

  final String initial;

  @override
  State<_TitleDialog> createState() => _TitleDialogState();
}

class _TitleDialogState extends State<_TitleDialog> {
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
      title: Text('Tiêu đề ảnh', style: AppText.title.copyWith(fontSize: 18)),
      content: TextField(
        controller: _text,
        autofocus: true,
        minLines: 1,
        maxLines: 5,
        textCapitalization: TextCapitalization.sentences,
        style: AppText.script.copyWith(fontSize: 18),
        decoration: const InputDecoration(hintText: 'viết gì cũng được…'),
      ),
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
