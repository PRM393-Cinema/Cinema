import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/promotion.dart';
import '../../../data/services/staff_service.dart';
import '../../staff/widgets/staff_feedback.dart';
import '../widgets/admin_page.dart';

// Admin: discounts on the ticket price. A promotion without a code applies by
// itself to bookings that qualify; one with a code needs the customer to type
// it. Promotions are never deleted: a stopped one no longer applies.
class AdminPromotionsScreen extends StatefulWidget {
  const AdminPromotionsScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<AdminPromotionsScreen> createState() => _AdminPromotionsScreenState();
}

class _AdminPromotionsScreenState extends State<AdminPromotionsScreen> {
  List<Promotion>? _promotions;
  String? _message;
  bool _loading = false;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final promotions = await widget.service.promotions();
      if (mounted) setState(() => _promotions = promotions);
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Promotion? promotion]) async {
    final saved = await showDialog<Promotion>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _PromotionFormDialog(service: widget.service, promotion: promotion),
    );
    if (saved == null || !mounted) return;
    showTopNotice(
      Overlay.of(context, rootOverlay: true),
      promotion == null ? '${saved.name} added.' : '${saved.name} saved.',
    );
    await _load();
  }

  Future<void> _setActive(Promotion promotion, bool active) async {
    setState(() => _busyId = promotion.id);
    try {
      await _save(widget.service, promotion, active: active);
      if (mounted) {
        showTopNotice(
          Overlay.of(context, rootOverlay: true),
          active
              ? '${promotion.name} is running again.'
              : '${promotion.name} stopped.',
        );
      }
      await _load();
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final promotions = _promotions;
    final busy = _loading || _busyId != null;
    return AdminPage(
      title: 'Promotions',
      section: AdminSection.promotions,
      child: ListView(
        padding: pagePadding(context, AppSpacing.lg),
        children: [
          const Text(
            'Discounts on tickets (not snacks). Without a code a promotion '
            'applies by itself; with a code the customer types it. One '
            'promotion per booking, and a use is counted once it is paid.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Add promotion',
              leadingIcon: Icons.add_rounded,
              useGradient: true,
              onPressed: busy ? null : () => _edit(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading && promotions == null)
            const LoadingState(message: 'Loading promotions...')
          else if (_message != null && promotions == null)
            ErrorState(
              title: 'Unable to load promotions',
              message: _message!,
              onRetry: _load,
            )
          else if (promotions != null) ...[
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _message!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            if (promotions.isEmpty)
              const Text('No promotions yet.', style: AppTextStyles.bodySmall),
            CardColumns(
              runSpacing: 0,
              children: [
                for (final promotion in promotions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _PromotionCard(
                      promotion: promotion,
                      busy: _busyId == promotion.id,
                      onEdit: busy ? null : () => _edit(promotion),
                      onSetActive: busy
                          ? null
                          : (active) => _setActive(promotion, active),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Saves [promotion] unchanged except for [active].
Future<Promotion> _save(
  StaffService service,
  Promotion promotion, {
  required bool active,
}) => service.savePromotion(
  id: promotion.id,
  code: promotion.code ?? '',
  name: promotion.name,
  description: promotion.description,
  discountType: promotion.discountType,
  discountValue: promotion.discountValue,
  maxDiscount: promotion.maxDiscount,
  minTickets: promotion.minTickets,
  daysOfWeek: promotion.daysOfWeek,
  startsAt: promotion.startsAt,
  endsAt: promotion.endsAt,
  usageLimit: promotion.usageLimit,
  active: active,
);

class _PromotionCard extends StatelessWidget {
  const _PromotionCard({
    required this.promotion,
    required this.busy,
    required this.onEdit,
    required this.onSetActive,
  });

  final Promotion promotion;
  final bool busy;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onSetActive;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (label, variant) = !promotion.active
        ? ('Stopped', StatusBadgeVariant.neutral)
        : promotion.isEnded(now)
        ? ('Ended', StatusBadgeVariant.neutral)
        : promotion.startsAt != null && promotion.startsAt!.isAfter(now)
        ? ('Scheduled', StatusBadgeVariant.warning)
        : ('Running', StatusBadgeVariant.success);
    final limit = promotion.usageLimit;
    return CinemaPanel(
      key: ValueKey('adminPromotion-${promotion.id}'),
      surfaceOpacity: 0.8,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(promotion.name, style: AppTextStyles.title),
                    StatusBadge(label: label, variant: variant),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  promotion.code == null
                      ? 'Automatic'
                      : 'Code ${promotion.code}',
                  style: AppTextStyles.body.copyWith(color: AppColors.accent),
                ),
                Text(
                  promotion.discountText,
                  style: AppTextStyles.body.copyWith(color: AppColors.primary),
                ),
                Text(promotion.conditionsText, style: AppTextStyles.bodySmall),
                Text(
                  limit == null
                      ? 'Used ${promotion.usedCount} times'
                      : 'Used ${promotion.usedCount} / $limit',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            IconButton(
              key: ValueKey('editPromotion-${promotion.id}'),
              tooltip: 'Edit ${promotion.name}',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            Switch(
              key: ValueKey('promotionActive-${promotion.id}'),
              value: promotion.active,
              onChanged: onSetActive,
            ),
          ],
        ],
      ),
    );
  }
}

class _PromotionFormDialog extends StatefulWidget {
  const _PromotionFormDialog({required this.service, this.promotion});
  final StaffService service;
  final Promotion? promotion;
  @override
  State<_PromotionFormDialog> createState() => _PromotionFormDialogState();
}

class _PromotionFormDialogState extends State<_PromotionFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.promotion?.code);
  late final _name = TextEditingController(text: widget.promotion?.name);
  late final _description = TextEditingController(
    text: widget.promotion?.description,
  );
  late final _value = TextEditingController(
    text: widget.promotion == null
        ? ''
        : widget.promotion!.discountValue.round().toString(),
  );
  late final _max = TextEditingController(
    text: widget.promotion?.maxDiscount?.round().toString(),
  );
  late final _minTickets = TextEditingController(
    text: '${widget.promotion?.minTickets ?? 1}',
  );
  late final _limit = TextEditingController(
    text: widget.promotion?.usageLimit?.toString(),
  );
  late String _type = widget.promotion?.discountType ?? 'PERCENT';
  late final _days = {...?widget.promotion?.daysOfWeek};
  late DateTime? _startsAt = widget.promotion?.startsAt;
  late DateTime? _endsAt = widget.promotion?.endsAt;
  late bool _active = widget.promotion?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _description,
      _value,
      _max,
      _minTickets,
      _limit,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  static double? _number(String text) =>
      double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));

  bool get _percent => _type == 'PERCENT';

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final current = start ? _startsAt : _endsAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _startsAt = picked;
      } else {
        // Until the end of that day.
        _endsAt = picked.add(const Duration(hours: 23, minutes: 59));
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_startsAt != null && _endsAt != null && !_endsAt!.isAfter(_startsAt!)) {
      setState(() => _error = 'The end must be after the start.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final limit = _number(_limit.text);
      final max = _number(_max.text);
      final saved = await widget.service.savePromotion(
        id: widget.promotion?.id,
        code: _code.text,
        name: _name.text,
        description: _description.text,
        discountType: _type,
        discountValue: _number(_value.text)!,
        maxDiscount: _percent ? max : null,
        minTickets: _number(_minTickets.text)?.round() ?? 1,
        daysOfWeek: _days.toList()..sort(),
        startsAt: _startsAt,
        endsAt: _endsAt,
        usageLimit: limit?.round(),
        active: _active,
      );
      if (mounted) Navigator.pop(context, saved);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = staffError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStyle = AppTextStyles.bodySmall.copyWith(
      color: AppColors.textPrimary,
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CinemaPanel(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.promotion == null
                        ? 'Add promotion'
                        : 'Edit promotion',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const Key('promotionNameField'),
                    label: 'Name',
                    controller: _name,
                    enabled: !_saving,
                    validator: (value) {
                      final name = value?.trim() ?? '';
                      if (name.isEmpty) return 'Enter a name.';
                      return name.length > 100
                          ? 'Use at most 100 characters.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('promotionCodeField'),
                    label: 'Promo code (empty: applies automatically)',
                    hint: 'e.g. WELCOME10',
                    controller: _code,
                    enabled: !_saving,
                    validator: (value) {
                      final code = value?.trim() ?? '';
                      return code.isEmpty ||
                              RegExp(r'^[A-Za-z0-9_-]{3,30}$').hasMatch(code)
                          ? null
                          : 'Use 3 to 30 letters, digits, - or _.';
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('promotionDescriptionField'),
                    label: 'Description (optional)',
                    controller: _description,
                    enabled: !_saving,
                    validator: (value) => (value?.trim().length ?? 0) > 255
                        ? 'Use at most 255 characters.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedButton<String>(
                    key: const Key('promotionTypeField'),
                    segments: const [
                      ButtonSegment(value: 'PERCENT', label: Text('Percent')),
                      ButtonSegment(value: 'AMOUNT', label: Text('Amount')),
                    ],
                    selected: {_type},
                    onSelectionChanged: _saving
                        ? null
                        : (value) => setState(() => _type = value.single),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('promotionValueField'),
                    label: _percent ? 'Discount (%)' : 'Discount (₫)',
                    controller: _value,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final number = _number(value ?? '');
                      if (_percent) {
                        return number == null || number < 1 || number > 90
                            ? 'Enter 1 to 90.'
                            : null;
                      }
                      return number == null ||
                              number < 1000 ||
                              number > 10000000
                          ? 'Enter 1,000 to 10,000,000.'
                          : null;
                    },
                  ),
                  if (_percent) ...[
                    const SizedBox(height: AppSpacing.md),
                    AppTextField(
                      key: const Key('promotionMaxField'),
                      label: 'Up to (₫, optional)',
                      controller: _max,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) return null;
                        final number = _number(value!);
                        return number == null ||
                                number < 1000 ||
                                number > 10000000
                            ? 'Enter 1,000 to 10,000,000.'
                            : null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('promotionMinTicketsField'),
                    label: 'From how many tickets',
                    controller: _minTickets,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final number = _number(value ?? '');
                      return number == null || number < 1 || number > 20
                          ? 'Enter 1 to 20.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Show days (none: every day)',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final (index, name) in Promotion.dayNames.indexed)
                        FilterChip(
                          key: ValueKey('promotionDay-${index + 1}'),
                          label: Text(name),
                          selected: _days.contains(index + 1),
                          onSelected: _saving
                              ? null
                              : (selected) => setState(
                                  () => selected
                                      ? _days.add(index + 1)
                                      : _days.remove(index + 1),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: _DateButton(
                          key: const Key('promotionStartsAt'),
                          label: 'Starts',
                          value: _startsAt,
                          style: dateStyle,
                          onPick: _saving ? null : () => _pickDate(start: true),
                          onClear: _saving
                              ? null
                              : () => setState(() => _startsAt = null),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _DateButton(
                          key: const Key('promotionEndsAt'),
                          label: 'Ends',
                          value: _endsAt,
                          style: dateStyle,
                          onPick: _saving
                              ? null
                              : () => _pickDate(start: false),
                          onClear: _saving
                              ? null
                              : () => setState(() => _endsAt = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('promotionLimitField'),
                    label: 'Uses allowed (optional)',
                    controller: _limit,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if ((value ?? '').trim().isEmpty) return null;
                      final number = _number(value!);
                      return number == null || number < 1
                          ? 'Enter at least 1.'
                          : null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Running'),
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Cancel',
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          key: const Key('savePromotion'),
                          label: 'Save',
                          useGradient: true,
                          isLoading: _saving,
                          onPressed: _saving ? null : _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// An optional date: tap to pick, × to clear.
class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.style,
    required this.onPick,
    required this.onClear,
    super.key,
  });

  final String label;
  final DateTime? value;
  final TextStyle style;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPick,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: ${value == null ? 'any time' : formatDate(value!)}',
              style: style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value != null)
            InkWell(
              onTap: onClear,
              child: const Icon(Icons.close_rounded, size: 18),
            ),
        ],
      ),
    );
  }
}
