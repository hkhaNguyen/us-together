import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'photo_pipeline.dart';
import 'sheet_frame.dart';

/// 04 · Thêm kỷ niệm (a moment): photos, date, anniversary, title and the story.
class AddMomentSheet extends StatefulWidget {
  const AddMomentSheet({
    super.key,
    required this.store,
    required this.journal,
    required this.me,
  });

  final JournalStore store;
  final Journal journal;
  final String me;

  @override
  State<AddMomentSheet> createState() => _AddMomentSheetState();
}

class _AddMomentSheetState extends State<AddMomentSheet> {
  final _photos = <PickedPhoto>[];
  final _title = TextEditingController();
  final _body = TextEditingController();
  var _cover = 0;
  var _date = DateUtils.dateOnly(DateTime.now());
  String? _anniversaryId;

  /// Until they pick by hand, the date follows the first photo's EXIF and
  /// the anniversary follows the date.
  var _dateTouched = false;
  var _anniversaryTouched = false;

  var _picking = false;
  int? _uploaded;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _anniversaryId = widget.journal.anniversaryOn(_date)?.id;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _setDate(DateTime date, {required bool byHand}) {
    _date = DateUtils.dateOnly(date);
    _dateTouched |= byHand;
    // A moment can only belong to an anniversary on its own date; a choice
    // that no longer fits the new date is dropped.
    final fits = widget.journal.anniversariesOn(_date);
    if (!_anniversaryTouched || !fits.any((a) => a.id == _anniversaryId)) {
      _anniversaryId = fits.firstOrNull?.id;
      _anniversaryTouched = false;
    }
  }

  Future<void> _pick() async {
    // On the web a dismissed file dialog may never report back, so the tile
    // isn't locked while waiting there.
    setState(() {
      _picking = !kIsWeb;
      _error = null;
    });
    try {
      final picked = await pickPhotos();
      if (!mounted) return;
      setState(() {
        _photos.addAll(picked);
        if (!_dateTouched && _photos.isNotEmpty) {
          _setDate(_photos.first.takenAt, byHand: false);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'chưa mở được ảnh ($e)');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _remove(int i) => setState(() {
    _photos.removeAt(i);
    if (_cover >= i && _cover > 0) _cover--;
  });

  Future<void> _save() async {
    setState(() {
      _uploaded = 0;
      _error = null;
    });
    try {
      await widget.store.addMoment(
        photos: _photos,
        cover: _cover,
        date: _date,
        title: _title.text.trim(),
        body: _body.text.trim(),
        anniversaryId: _anniversaryId,
        by: widget.me,
        onProgress: (n) => setState(() => _uploaded = n),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _uploaded = null;
        _error = 'chưa lưu được, thử lại nha ($e)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = _uploaded;
    final busy = uploaded != null;
    final status = !busy
        ? null
        : _photos.isEmpty || uploaded >= _photos.length
        ? 'đang lưu…'
        : 'đang tải ảnh ${uploaded + 1}/${_photos.length}…';

    return SheetFrame(
      title: 'Thêm kỷ niệm',
      action: 'Lưu',
      onAction: _title.text.trim().isEmpty || _picking ? null : _save,
      status: status,
      error: _error,
      children: [
        FieldLabel(
          'ẢNH · ${_photos.length} ĐÃ CHỌN${_photos.length > 1 ? ' — chạm ảnh để chọn bìa' : ''}',
        ),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: Space.s2),
            itemBuilder: (context, i) => i == 0
                ? AddPhotoTile(busy: _picking, onTap: busy ? null : _pick)
                : PickedPhotoTile(
                    photo: _photos[i - 1],
                    isCover: _cover == i - 1,
                    onTap: busy ? null : () => setState(() => _cover = i - 1),
                    onRemove: busy ? null : () => _remove(i - 1),
                  ),
          ),
        ),
        const SizedBox(height: Space.s5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('ngày'),
                  IgnorePointer(
                    ignoring: busy,
                    child: DateField(
                      date: _date,
                      onChanged: (d) =>
                          setState(() => _setDate(d, byHand: true)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Space.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FieldLabel('thuộc ngày kỷ niệm'),
                  DropdownButtonFormField<String?>(
                    initialValue: _anniversaryId,
                    key: ValueKey(_anniversaryId),
                    isExpanded: true,
                    onChanged: busy
                        ? null
                        : (id) => setState(() {
                            _anniversaryId = id;
                            _anniversaryTouched = true;
                          }),
                    style: AppText.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— không —'),
                      ),
                      for (final a in widget.journal.anniversariesOn(_date))
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                            a.titleOn(_date),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.s5),
        const FieldLabel('tiêu đề'),
        TextField(
          controller: _title,
          enabled: !busy,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.title.copyWith(fontSize: 20),
          decoration: const InputDecoration(
            hintText: 'Ví dụ: Đi sở thú cùng béo iu',
          ),
        ),
        const SizedBox(height: Space.s5),
        const FieldLabel('Nội dung'),
        TextField(
          controller: _body,
          enabled: !busy,
          minLines: 6,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.quote.copyWith(height: 1.6),
          decoration: InputDecoration(
            hintText: 'Viết gì cũng được ạ, bựa bựa cũng oki',
            fillColor: Paper.polaroid,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Paper.c5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Paper.c8, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
