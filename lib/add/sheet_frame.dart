import 'package:flutter/material.dart';

import '../data/vi_format.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Opens [sheet] as the paper bottom sheet from the add designs.
Future<void> showPaperSheet(BuildContext context, Widget sheet) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Paper.c1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => sheet,
    );

/// "huỷ · title · action" header over a scrolling body. While [status] is set
/// the sheet is busy: both buttons are off and the status shows instead.
class SheetFrame extends StatelessWidget {
  const SheetFrame({
    super.key,
    required this.title,
    required this.action,
    required this.onAction,
    required this.children,
    this.status,
    this.error,
  });

  final String title;
  final String action;

  /// null disables the action.
  final VoidCallback? onAction;
  final List<Widget> children;
  final String? status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final busy = status != null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Paper.c7),
                  child: const Text('huỷ'),
                ),
                Expanded(child: Text(title, textAlign: TextAlign.center, style: AppText.title.copyWith(fontSize: 18))),
                FilledButton(
                  onPressed: busy ? null : onAction,
                  style: FilledButton.styleFrom(backgroundColor: Paper.c8, foregroundColor: Paper.c1, minimumSize: const Size(0, 44)),
                  child: Text(action),
                ),
              ],
            ),
          ),
          if (busy) ...[
            const SizedBox(height: Space.s2),
            Text(status!, style: AppText.script.copyWith(fontSize: 16)),
            const Padding(padding: EdgeInsets.fromLTRB(20, 6, 20, 0), child: LinearProgressIndicator(color: Sakura.c6, backgroundColor: Paper.c4)),
          ],
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(error!, style: AppText.body.copyWith(fontSize: 13, color: Sakura.c7)),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small grey label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text, style: AppText.label.copyWith(fontSize: 11, letterSpacing: 0, fontWeight: FontWeight.w400)),
      );
}

/// A date in script that opens the picker when tapped.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.date, required this.onChanged, this.label = 'ngày'});

  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Paper.c3,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(1990),
            lastDate: DateTime.now(),
            helpText: label,
          );
          // Keep the time of day, so same-day photos stay in shooting order.
          if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day, date.hour, date.minute, date.second));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(child: Text(dotDate(date), style: AppText.script.copyWith(fontSize: 18))),
              Text('đổi', style: AppText.label.copyWith(fontSize: 12, letterSpacing: 0, color: Paper.c8)),
            ],
          ),
        ),
      ),
    );
  }
}
