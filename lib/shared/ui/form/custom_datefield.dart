import 'package:flutter/material.dart';
import 'package:marc/shared/ui/form/custom_textfield.dart';

/// Medan tarikh (optional + masa) dengan label luar.
///
/// Ketuk buka `showDatePicker`; [includeTime] sambung `showTimePicker`.
/// Boleh dipakai dalam [Form] melalui [validator].
class CustomDateField extends StatelessWidget {
  const CustomDateField({
    super.key,
    required this.label,
    this.value,
    this.onChanged,
    this.hint,
    this.includeTime = false,
    this.format,
    this.validator,
    this.firstDate,
    this.lastDate,
    this.canClear = false,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final String? hint;
  final bool includeTime;
  final String Function(DateTime)? format;
  final FormFieldValidator<DateTime?>? validator;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool canClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime?>(
      initialValue: value,
      validator: (v) => validator?.call(value ?? v),
      builder: (field) {
        final current = value ?? field.value;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final empty = current == null;
        final display = current == null
            ? (hint ?? '')
            : (format != null
                  ? format!(current)
                  : _defaultFormat(current, includeTime: includeTime));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FormFieldLabel(label, enabled: enabled),
            InkWell(
              onTap: enabled ? () => _pick(context, field, current) : null,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: empty,
                decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  errorText: field.errorText,
                  suffixIcon: canClear && current != null && enabled
                      ? IconButton(
                          tooltip: 'Kosongkan',
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () {
                            field.didChange(null);
                            onChanged?.call(null);
                          },
                        )
                      : Icon(
                          Icons.event_outlined,
                          size: 20,
                          color: enabled
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface.withValues(alpha: 0.38),
                        ),
                ),
                child: Text(
                  display,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: empty
                        ? scheme.onSurfaceVariant
                        : (enabled
                              ? scheme.onSurface
                              : scheme.onSurface.withValues(alpha: 0.38)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pick(
    BuildContext context,
    FormFieldState<DateTime?> field,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 50);
    final last = lastDate ?? DateTime(now.year + 20);
    var initial = current ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !context.mounted) return;

    var picked = DateTime(date.year, date.month, date.day);
    if (includeTime) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(current ?? initial),
      );
      if (time == null || !context.mounted) return;
      picked = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    field.didChange(picked);
    onChanged?.call(picked);
  }
}

String _defaultFormat(DateTime dt, {required bool includeTime}) {
  const months = [
    'Jan',
    'Feb',
    'Mac',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ogo',
    'Sep',
    'Okt',
    'Nov',
    'Dis',
  ];
  final local = dt.toLocal();
  final date = '${local.day} ${months[local.month - 1]} ${local.year}';
  if (!includeTime) return date;
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$date, $h:$m';
}
