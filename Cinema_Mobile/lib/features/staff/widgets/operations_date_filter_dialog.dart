import 'package:flutter/material.dart';

class OperationsDateFilterDialog extends StatefulWidget {
  const OperationsDateFilterDialog({this.initialRange, super.key});

  final DateTimeRange? initialRange;

  @override
  State<OperationsDateFilterDialog> createState() =>
      _OperationsDateFilterDialogState();
}

class _OperationsDateFilterDialogState
    extends State<OperationsDateFilterDialog> {
  final _form = GlobalKey<FormState>();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _first = DateTime(2020);
  final _last = DateTime(2100);
  bool _initialized = false;

  MaterialLocalizations get _dates => MaterialLocalizations.of(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final today = DateUtils.dateOnly(DateTime.now());
    _setRange(
      widget.initialRange?.start ?? today,
      widget.initialRange?.end ?? today,
    );
  }

  void _setRange(DateTime start, DateTime end) {
    _from.text = _dates.formatCompactDate(start);
    _to.text = _dates.formatCompactDate(end);
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  String? _validate(String? text, {required bool end}) {
    final date = _dates.parseCompactDate(text ?? '');
    if (date == null) return 'Enter a valid date';
    if (date.isBefore(_first) || date.isAfter(_last)) {
      return 'Use a date between 2020 and 2100';
    }
    final start = _dates.parseCompactDate(_from.text);
    if (end && start != null && date.isBefore(start)) {
      return 'End date must be on or after start';
    }
    return null;
  }

  Future<void> _pick(TextEditingController controller) async {
    final parsed = _dates.parseCompactDate(controller.text);
    final initial = parsed ?? DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      barrierDismissible: false,
      initialDate: initial.isBefore(_first)
          ? _first
          : initial.isAfter(_last)
          ? _last
          : initial,
      firstDate: _first,
      lastDate: _last,
    );
    if (date != null && mounted) {
      controller.text = _dates.formatCompactDate(date);
    }
  }

  void _apply() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      DateTimeRange(
        start: _dates.parseCompactDate(_from.text)!,
        end: _dates.parseCompactDate(_to.text)!,
      ),
    );
  }

  Widget _field(TextEditingController controller, {required bool end}) =>
      TextFormField(
        key: Key(end ? 'dateFilterTo' : 'dateFilterFrom'),
        controller: controller,
        keyboardType: TextInputType.datetime,
        textInputAction: end ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: end ? (_) => _apply() : null,
        validator: (text) => _validate(text, end: end),
        decoration: InputDecoration(
          labelText: end ? 'To date' : 'From date',
          hintText: _dates.dateHelpText,
          errorMaxLines: 2,
          suffixIcon: IconButton(
            tooltip: end ? 'Choose end date' : 'Choose start date',
            onPressed: () => _pick(controller),
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateUtils.dateOnly(DateTime.now());
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        key: const Key('operationsDateRangePopup'),
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter by date',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a range to filter bookings and showtimes.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final (label, start) in [
                            ('Today', today),
                            (
                              'Last 7 days',
                              today.subtract(const Duration(days: 6)),
                            ),
                            ('This month', DateTime(today.year, today.month)),
                          ])
                            OutlinedButton(
                              onPressed: () {
                                _setRange(start, today);
                                _form.currentState!.validate();
                              },
                              child: Text(label),
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final from = _field(_from, end: false);
                          final to = _field(_to, end: true);
                          if (constraints.maxWidth < 380 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                            return Column(
                              children: [from, const SizedBox(height: 16), to],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: from),
                              const SizedBox(width: 16),
                              Expanded(child: to),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Both dates are included. Changes apply only when saved.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OverflowBar(
                spacing: 8,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(onPressed: _apply, child: const Text('Apply')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
