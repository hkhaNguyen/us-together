import 'package:flutter/material.dart';

import '../data/journal_store.dart';
import '../data/models.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'photo_pipeline.dart';
import 'sheet_frame.dart';

/// 04 · Thêm dịp: photos, date, anniversary, title and the story.
class AddMomentSheet extends StatefulWidget {
  const AddMomentSheet({super.key, required this.store, required this.journal, required this.me});

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
    if (!_anniversaryTouched) _anniversaryId = widget.journal.anniversaryOn(_date)?.id;
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    final picked = await pickPhotos();
    if (!mounted) return;
    setState(() {
      _picking = false;
      _photos.addAll(picked);
      if (!_dateTouched && _photos.isNotEmpty) _setDate(_photos.first.takenAt, byHand: false);
    });
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
      title: 'Thêm dịp',
      action: 'Lưu',
      onAction: _title.text.trim().isEmpty || _picking ? null : _save,
      status: status,
      error: _error,
      children: [
        FieldLabel('ẢNH · ${_photos.length} ĐÃ CHỌN${_photos.length > 1 ? ' — chạm ảnh để chọn bìa' : ''}'),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photos.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: Space.s2),
            itemBuilder: (context, i) => i == 0
                ? _AddTile(busy: _picking, onTap: busy ? null : _pick)
                : _PhotoTile(
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
                    child: DateField(date: _date, onChanged: (d) => setState(() => _setDate(d, byHand: true))),
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
                    style: AppText.body.copyWith(fontSize: 13, fontWeight: FontWeight.w400),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— không —')),
                      for (final a in widget.journal.anniversaries)
                        DropdownMenuItem(value: a.id, child: Text(a.titleOn(_date), overflow: TextOverflow.ellipsis)),
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
          decoration: const InputDecoration(hintText: 'Ví dụ: Bốn năm, vẫn là em'),
        ),
        const SizedBox(height: Space.s5),
        const FieldLabel('chuyện gì đã xảy ra'),
        TextField(
          controller: _body,
          enabled: !busy,
          minLines: 6,
          maxLines: null,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.quote.copyWith(height: 1.6),
          decoration: InputDecoration(
            hintText: 'viết tự nhiên như ghi nhật ký… xuống dòng thoải mái',
            fillColor: Paper.polaroid,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Paper.c5)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Paper.c8, width: 1.5)),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paper.c3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Paper.c6, width: 1.5)),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox.square(
          dimension: 84,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Paper.c8))
                  : const Icon(Icons.add, size: 20, color: Paper.c8),
              const SizedBox(height: 4),
              Text('thêm', style: AppText.label.copyWith(fontSize: 10, letterSpacing: 0, color: Paper.c8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.isCover, required this.onTap, required this.onRemove});

  final PickedPhoto photo;
  final bool isCover;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isCover,
      label: isCover ? 'Ảnh bìa' : 'Chọn làm bìa',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox.square(
          dimension: 84,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(photo.bytes, fit: BoxFit.cover, cacheWidth: 252),
              ),
              if (isCover)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Paper.c8, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text('bìa', style: AppText.label.copyWith(fontSize: 9, letterSpacing: 0, color: Paper.c1)),
                  ),
                ),
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  tooltip: 'Bỏ ảnh này',
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(backgroundColor: Paper.c1.withValues(alpha: .85)),
                  icon: const Icon(Icons.close, size: 14, color: Paper.c8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
