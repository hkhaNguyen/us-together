import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'photo_pipeline.dart';
import 'sheet_frame.dart';

/// 05 · Thêm ảnh lẻ: each photo gets its own date (from EXIF) and a free
/// title, then they're pinned on the stem.
class AddPhotosSheet extends StatefulWidget {
  const AddPhotosSheet({super.key, required this.store, required this.me});

  final JournalStore store;
  final String me;

  @override
  State<AddPhotosSheet> createState() => _AddPhotosSheetState();
}

class _AddPhotosSheetState extends State<AddPhotosSheet> {
  final _photos = <PickedPhoto>[];
  var _picking = false;
  int? _uploaded;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Browsers only open a file dialog from a real tap, so on the web the
    // picker waits for the button.
    if (!kIsWeb) WidgetsBinding.instance.addPostFrameCallback((_) => _pick(closeIfNone: true));
  }

  Future<void> _pick({bool closeIfNone = false}) async {
    // On the web a dismissed dialog may never report back, so the button
    // isn't locked while waiting there.
    setState(() {
      _picking = !kIsWeb;
      _error = null;
    });
    try {
      final picked = await pickPhotos();
      if (!mounted) return;
      if (picked.isEmpty && _photos.isEmpty && closeIfNone) {
        Navigator.pop(context);
        return;
      }
      setState(() => _photos.addAll(picked));
    } catch (e) {
      if (mounted) setState(() => _error = 'chưa mở được ảnh ($e)');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _uploaded = 0;
      _error = null;
    });
    try {
      await widget.store.addPhotos(_photos, by: widget.me, onProgress: (n) => setState(() => _uploaded = n));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _uploaded = null;
        _error = 'chưa dán được, thử lại nha ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = _uploaded;
    return SheetFrame(
      title: 'Thêm ảnh',
      action: 'Dán lên',
      onAction: _photos.isEmpty || _picking ? null : _save,
      status: uploaded == null ? null : 'đang dán ${uploaded + 1 > _photos.length ? _photos.length : uploaded + 1}/${_photos.length}…',
      error: _error,
      children: [
        for (final p in _photos)
          _PhotoRow(
            key: ObjectKey(p),
            photo: p,
            enabled: uploaded == null,
            onChanged: () => setState(() {}),
            onRemove: () => setState(() => _photos.remove(p)),
          ),
        const SizedBox(height: Space.s2),
        OutlinedButton.icon(
          onPressed: _picking || uploaded != null ? null : _pick,
          icon: const Icon(Icons.add, size: 18),
          label: Text(_picking ? 'đang mở thư viện…' : (_photos.isEmpty ? 'chọn ảnh' : 'chọn thêm ảnh')),
          style: OutlinedButton.styleFrom(
            foregroundColor: Paper.c8,
            side: const BorderSide(color: Paper.c6, style: BorderStyle.solid),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({super.key, required this.photo, required this.enabled, required this.onChanged, required this.onRemove});

  final PickedPhoto photo;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            // Decoded small: the originals can be 12+ megapixels.
            child: Image.memory(photo.bytes, width: 72, height: 72, fit: BoxFit.cover, cacheWidth: 216),
          ),
          const SizedBox(width: Space.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IgnorePointer(
                  ignoring: !enabled,
                  child: DateField(
                    date: photo.takenAt,
                    label: 'ngày chụp',
                    onChanged: (d) {
                      photo.takenAt = d;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(height: Space.s2),
                TextFormField(
                  initialValue: photo.title,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => photo.title = v,
                  style: AppText.script.copyWith(fontSize: 18),
                  decoration: const InputDecoration(hintText: 'tiêu đề ảnh — viết gì cũng được…'),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Bỏ ảnh này',
            onPressed: enabled ? onRemove : null,
            icon: const Icon(Icons.close, size: 20, color: Paper.c7),
          ),
        ],
      ),
    );
  }
}
