import 'package:flutter/material.dart';

import '../add/sheet_frame.dart';
import '../data/journal_store.dart';
import '../data/models.dart';
import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Add or edit an anniversary. The start day ("ngày bắt đầu yêu") only lets
/// its date change; it can't be renamed, made one-off or deleted.
class AnniversarySheet extends StatefulWidget {
  const AnniversarySheet({super.key, required this.store, this.anniversary, this.moments = const [], this.onOpenMoment});

  final JournalStore store;

  /// null to add a new one.
  final Anniversary? anniversary;

  /// Moments tagged with it, newest first.
  final List<Moment> moments;
  final ValueChanged<Moment>? onOpenMoment;

  @override
  State<AnniversarySheet> createState() => _AnniversarySheetState();
}

class _AnniversarySheetState extends State<AnniversarySheet> {
  late final _title = TextEditingController(text: widget.anniversary?.title ?? '');
  late var _date = widget.anniversary?.date ?? DateUtils.dateOnly(DateTime.now());
  late var _yearly = widget.anniversary?.yearly ?? true;
  var _saving = false;
  String? _error;

  bool get _isStart => widget.anniversary?.isStart ?? false;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'chưa lưu được, thử lại nha ($e)';
      });
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Paper.c1,
        content: Text(
          'Xoá “${widget.anniversary!.title}”?'
          '${widget.moments.isEmpty ? '' : ' ${widget.moments.length} kỷ niệm gắn với ngày này vẫn còn nguyên, chỉ bỏ nhãn.'}',
        ),
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
    if (sure ?? false) await _run(() => widget.store.deleteAnniversary(widget.anniversary!.id));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.anniversary != null;
    return SheetFrame(
      title: editing ? 'Sửa ngày kỷ niệm' : 'Thêm ngày kỷ niệm',
      action: 'Lưu',
      onAction: _title.text.trim().isEmpty
          ? null
          : () => _run(
                () => widget.store.saveAnniversary(id: widget.anniversary?.id, title: _title.text, date: _date, yearly: _yearly),
              ),
      status: _saving ? 'đang lưu…' : null,
      error: _error,
      children: [
        if (!_isStart) ...[
          const FieldLabel('tên'),
          TextField(
            controller: _title,
            enabled: !_saving,
            textCapitalization: TextCapitalization.sentences,
            style: AppText.title.copyWith(fontSize: 18),
            decoration: const InputDecoration(hintText: 'Ví dụ: sinh nhật Xuka'),
          ),
          const SizedBox(height: Space.s4),
        ],
        const FieldLabel('ngày'),
        IgnorePointer(
          ignoring: _saving,
          child: DateField(date: _date, allowFuture: !_isStart, onChanged: (d) => setState(() => _date = DateUtils.dateOnly(d))),
        ),
        if (!_isStart) ...[
          const SizedBox(height: Space.s2),
          SwitchListTile(
            value: _yearly,
            onChanged: _saving ? null : (v) => setState(() => _yearly = v),
            contentPadding: EdgeInsets.zero,
            activeThumbColor: Paper.c8,
            title: Text('lặp lại hằng năm', style: AppText.body.copyWith(fontSize: 14, fontWeight: FontWeight.w400)),
          ),
        ],
        if (widget.moments.isNotEmpty) ...[
          const SizedBox(height: Space.s4),
          FieldLabel('${widget.moments.length} KỶ NIỆM ĐÃ LƯU'),
          for (final m in widget.moments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(m.title, style: AppText.title.copyWith(fontSize: 15)),
              subtitle: Text(dotDate(m.date), style: AppText.script.copyWith(fontSize: 15)),
              trailing: const Icon(Icons.chevron_right, color: Paper.c7),
              onTap: widget.onOpenMoment == null ? null : () => widget.onOpenMoment!(m),
            ),
        ],
        if (editing && !_isStart) ...[
          const SizedBox(height: Space.s5),
          TextButton(
            onPressed: _saving ? null : _delete,
            style: TextButton.styleFrom(foregroundColor: Sakura.c7),
            child: const Text('Xoá ngày này'),
          ),
        ],
      ],
    );
  }
}
