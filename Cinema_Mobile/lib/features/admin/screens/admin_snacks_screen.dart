import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/concession.dart';
import '../../../data/services/staff_service.dart';
import '../../staff/widgets/staff_feedback.dart';
import '../widgets/admin_page.dart';

// Admin: the snacks and drinks menu sold with tickets. Items are never
// deleted: a stopped item disappears from the app and orders keep it.
class AdminSnacksScreen extends StatefulWidget {
  const AdminSnacksScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<AdminSnacksScreen> createState() => _AdminSnacksScreenState();
}

class _AdminSnacksScreenState extends State<AdminSnacksScreen> {
  List<ConcessionItem>? _items;
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
      final items = await widget.service.concessions(includeInactive: true);
      if (mounted) setState(() => _items = items);
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([ConcessionItem? item]) async {
    final saved = await showDialog<ConcessionItem>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SnackFormDialog(service: widget.service, item: item),
    );
    if (saved == null || !mounted) return;
    showTopNotice(
      Overlay.of(context, rootOverlay: true),
      item == null ? '${saved.name} added.' : '${saved.name} saved.',
    );
    await _load();
  }

  Future<void> _setActive(ConcessionItem item, bool active) async {
    setState(() => _busyId = item.id);
    try {
      await widget.service.saveConcession(
        id: item.id,
        name: item.name,
        price: item.price,
        description: item.description,
        imageUrl: item.imageUrl,
        sortOrder: item.sortOrder,
        active: active,
      );
      if (mounted) {
        showTopNotice(
          Overlay.of(context, rootOverlay: true),
          active ? '${item.name} is on sale again.' : '${item.name} stopped.',
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
    final items = _items;
    final busy = _loading || _busyId != null;
    return AdminPage(
      title: 'Snacks & drinks',
      section: AdminSection.snacks,
      child: ListView(
        padding: pagePadding(context, AppSpacing.lg),
        children: [
          const Text(
            'The menu customers and the counter add to tickets. Prices of '
            'orders already made do not change.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Add item',
              leadingIcon: Icons.add_rounded,
              useGradient: true,
              onPressed: busy ? null : () => _edit(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading && items == null)
            const LoadingState(message: 'Loading the menu...')
          else if (_message != null && items == null)
            ErrorState(
              title: 'Unable to load the menu',
              message: _message!,
              onRetry: _load,
            )
          else if (items != null) ...[
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
            if (items.isEmpty)
              const Text('No items yet.', style: AppTextStyles.bodySmall),
            CardColumns(
              runSpacing: 0,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _SnackCard(
                      item: item,
                      busy: _busyId == item.id,
                      onEdit: busy ? null : () => _edit(item),
                      onSetActive: busy
                          ? null
                          : (active) => _setActive(item, active),
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

class _SnackCard extends StatelessWidget {
  const _SnackCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onSetActive,
  });

  final ConcessionItem item;
  final bool busy;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onSetActive;

  @override
  Widget build(BuildContext context) {
    return CinemaPanel(
      key: ValueKey('adminSnack-${item.id}'),
      surfaceOpacity: 0.8,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl.isEmpty
                ? Container(
                    width: 56,
                    height: 56,
                    color: AppColors.surfaceSoft,
                    child: const Icon(
                      Icons.fastfood_outlined,
                      color: AppColors.accent,
                    ),
                  )
                : AppNetworkImage(
                    imageUrl: item.imageUrl,
                    width: 56,
                    height: 56,
                  ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.title),
                if (item.description.isNotEmpty)
                  Text(item.description, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      formatVnd(item.price),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    StatusBadge(
                      label: item.active ? 'On sale' : 'Stopped',
                      variant: item.active
                          ? StatusBadgeVariant.success
                          : StatusBadgeVariant.neutral,
                    ),
                  ],
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
              key: ValueKey('editSnack-${item.id}'),
              tooltip: 'Edit ${item.name}',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            Switch(
              key: ValueKey('snackActive-${item.id}'),
              value: item.active,
              onChanged: onSetActive,
            ),
          ],
        ],
      ),
    );
  }
}

class _SnackFormDialog extends StatefulWidget {
  const _SnackFormDialog({required this.service, this.item});
  final StaffService service;
  final ConcessionItem? item;
  @override
  State<_SnackFormDialog> createState() => _SnackFormDialogState();
}

class _SnackFormDialogState extends State<_SnackFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?.name);
  late final _price = TextEditingController(
    text: widget.item == null ? '' : widget.item!.price.round().toString(),
  );
  late final _description = TextEditingController(
    text: widget.item?.description,
  );
  late final _image = TextEditingController(text: widget.item?.imageUrl);
  late final _order = TextEditingController(
    text: '${widget.item?.sortOrder ?? 0}',
  );
  late bool _active = widget.item?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _price, _description, _image, _order]) {
      controller.dispose();
    }
    super.dispose();
  }

  double? get _priceValue =>
      double.tryParse(_price.text.replaceAll(RegExp(r'[^0-9]'), ''));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.service.saveConcession(
        id: widget.item?.id,
        name: _name.text,
        price: _priceValue!,
        description: _description.text,
        imageUrl: _image.text,
        sortOrder: int.tryParse(_order.text.trim()) ?? 0,
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: CinemaPanel(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.item == null ? 'Add item' : 'Edit item',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const Key('snackNameField'),
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
                    key: const Key('snackPriceField'),
                    label: 'Price (₫)',
                    controller: _price,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                    validator: (_) {
                      final price = _priceValue;
                      return price == null || price < 1000 || price > 10000000
                          ? 'Enter 1,000 to 10,000,000.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('snackDescriptionField'),
                    label: 'Description (optional)',
                    controller: _description,
                    enabled: !_saving,
                    validator: (value) => (value?.trim().length ?? 0) > 255
                        ? 'Use at most 255 characters.'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('snackImageField'),
                    label: 'Image link (optional)',
                    controller: _image,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('snackOrderField'),
                    label: 'Order on the menu',
                    controller: _order,
                    enabled: !_saving,
                    keyboardType: TextInputType.number,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('On sale'),
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
                          key: const Key('saveSnack'),
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
