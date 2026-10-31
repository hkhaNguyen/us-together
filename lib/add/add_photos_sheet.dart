import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'photo_pipeline.dart';
import 'sheet_frame.dart';

/// 05 · Thêm ảnh lẻ: one go = one stack on the stem, with one date (from
/// the first photo's EXIF) and one title shared by every photo in it.
class AddPhotosSheet extends StatefulWidget {
  const AddPhotosSheet({super.key, required this.store, required this.me});

  final JournalStore store;
  final String me;

  @override
  State<AddPhotosSheet> createState() => _AddPhotosSheetState();
}

class _AddPhotosSheetState extends State<AddPhotosSheet> {
  final _photos = <PickedPhoto>[];
  final _title = TextEditingController();
  var _date = DateTime.now();

  /// Until they change it by hand, the date follows the first photo.
  var _dateTouched = false;
  var _picking = false;
  int? _uploaded;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Browsers only open a file dialog from a real tap, so on the web the
    // picker waits for the button.
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(closeIfNone: true));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
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
      setState(() {
        _photos.addAll(picked);
        if (!_dateTouched && _photos.isNotEmpty) _date = _photos.first.takenAt;
      });
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
      await widget.store.addPhotoStack(
        _photos,
        date: _date,
        title: _title.text,
        by: widget.me,
        onProgress: (n) => setState(() => _uploaded = n),
      );
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
    final busy = uploaded != null;
    return SheetFrame(
      title: 'Thêm ảnh',
      action: 'Dán lên',
      onAction: _photos.isEmpty || _picking ? null : _save,
      status: busy
          ? 'đang dán ${uploaded < _photos.length ? uploaded + 1 : _photos.length}/${_photos.length}…'
          : null,
      error: _error,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            const gap = Space.s2;
            final size = (box.maxWidth - 3 * gap) / 4;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                AddPhotoTile(
                  busy: _picking,
                  onTap: busy ? null : _pick,
                  size: size,
                ),
                for (final p in _photos)
                  PickedPhotoTile(
                    key: ObjectKey(p),
                    photo: p,
                    size: size,
                    onRemove: busy
                        ? null
                        : () => setState(() => _photos.remove(p)),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: Space.s4),
        const FieldLabel('ngày chụp'),
        IgnorePointer(
          ignoring: busy,
          child: DateField(
            date: _date,
            label: 'ngày chụp',
            onChanged: (d) => setState(() {
              _date = d;
              _dateTouched = true;
            }),
          ),
        ),
        const SizedBox(height: Space.s4),
        const FieldLabel('tiêu đề'),
        TextField(
          controller: _title,
          enabled: !busy,
          minLines: 1,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.script.copyWith(fontSize: 18),
          decoration: const InputDecoration(hintText: 'chỗ này để title ạaaa'),
        ),
      ],
    );
  }
}
