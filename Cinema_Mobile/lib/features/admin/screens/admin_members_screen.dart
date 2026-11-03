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
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/models/loyalty.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/staff_service.dart';
import '../../profile/widgets/membership_card.dart';
import '../../staff/widgets/staff_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_catalog_layout.dart';
import '../widgets/admin_pager.dart';

// Admin: customer accounts with their points and tier. Open a member to see
// the history of their points and add or take away points with a reason.
class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({
    required this.repository,
    required this.service,
    super.key,
  });

  final AuthRepository repository;
  final StaffService service;

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  final _search = TextEditingController();
  PagedResult<AuthUser>? _result;
  Map<int, LoyaltyCard> _cards = const {};
  bool _loading = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await widget.repository.users(
        page: page,
        keyword: _search.text.trim(),
        role: 'ROLE_CUSTOMER',
      );
      final cards = result.items.isEmpty
          ? const <LoyaltyCard>[]
          : await widget.service.loyaltyAccounts([
              for (final user in result.items) user.userId,
            ]);
      if (!mounted) return;
      setState(() {
        _result = result;
        _cards = {for (final card in cards) card.userId: card};
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(AuthUser user) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _MemberDialog(user: user, service: widget.service),
    );
    if (changed == true && mounted) {
      await _load(page: _result?.pageNumber ?? 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return AdminPage(
      title: 'Members',
      section: AdminSection.members,
      child: ListView(
        padding: pagePadding(context, AppSpacing.lg),
        children: [
          const Text(
            'Customers earn points on paid tickets: 5% back as a Member, 7% '
            'as VIP (from 2.000.000 ₫ spent), 10% as VVIP (from 5.000.000 ₫). '
            '1 point = 1.000 ₫, and points pay at most half of a booking.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AdminCatalogToolbar(
            action: AppButton.secondary(
              key: const Key('refreshMembers'),
              label: 'Refresh',
              leadingIcon: Icons.refresh,
              onPressed: _loading
                  ? null
                  : () => _load(page: result?.pageNumber ?? 1),
            ),
            search: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: const Key('memberSearch'),
                    label: 'Search name, email or phone',
                    controller: _search,
                    enabled: !_loading,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                IconButton(
                  key: const Key('searchMembers'),
                  tooltip: 'Search members',
                  onPressed: _loading ? null : () => _load(),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading && result == null)
            const LoadingState(message: 'Loading members...')
          else if (_message != null && result == null)
            ErrorState(
              title: 'Unable to load members',
              message: _message!,
              onRetry: _load,
            )
          else if (result != null) ...[
            Text(
              formatCount(result.totalCount, 'member'),
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  _message!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppPalette.of(context).error,
                  ),
                ),
              ),
            if (result.items.isEmpty)
              const Text('No members found.', style: AppTextStyles.bodySmall),
            if (result.items.isNotEmpty && isCatalogDesktop(context))
              AdminCatalogTable(
                key: const Key('adminMembersTable'),
                columns: const [
                  DataColumn(label: Text('Member')),
                  DataColumn(label: Text('Contact')),
                  DataColumn(label: Text('Tier')),
                  DataColumn(label: Text('Points'), numeric: true),
                  DataColumn(label: Text('Lifetime spend'), numeric: true),
                  DataColumn(label: Text('Action')),
                ],
                rows: [
                  for (final user in result.items)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Text(
                              user.displayName,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 230,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.email),
                                if (user.phone != null)
                                  Text(
                                    user.phone!,
                                    style: AppTextStyles.caption,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          _cards[user.userId] == null
                              ? const Text('—')
                              : TierBadge(tier: _cards[user.userId]!.tier),
                        ),
                        DataCell(
                          Text(
                            _cards[user.userId] == null
                                ? '—'
                                : '${_cards[user.userId]!.points} pts',
                          ),
                        ),
                        DataCell(
                          Text(
                            _cards[user.userId] == null
                                ? '—'
                                : formatVnd(_cards[user.userId]!.lifetimeSpend),
                          ),
                        ),
                        DataCell(
                          TextButton(
                            key: ValueKey('member-${user.userId}'),
                            onPressed: _loading ? null : () => _open(user),
                            child: const Text('View member'),
                          ),
                        ),
                      ],
                    ),
                ],
              )
            else
              for (final user in result.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _MemberRow(
                    user: user,
                    card: _cards[user.userId],
                    onOpen: _loading ? null : () => _open(user),
                  ),
                ),
            if (result.totalPages > 1)
              AdminPager(
                page: result.pageNumber,
                totalPages: result.totalPages,
                onOpen: _loading ? null : (page) => _load(page: page),
              ),
          ],
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.user,
    required this.card,
    required this.onOpen,
  });

  final AuthUser user;
  final LoyaltyCard? card;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    return InkWell(
      key: ValueKey('member-${user.userId}'),
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: CinemaPanel(
        surfaceOpacity: 0.8,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: AppTextStyles.title),
                  Text(
                    [user.email, ?user.phone].join(' · '),
                    style: AppTextStyles.bodySmall,
                  ),
                  if (card != null)
                    Text(
                      'Spent ${formatVnd(card.lifetimeSpend)}',
                      style: AppTextStyles.bodySmall,
                    ),
                ],
              ),
            ),
            if (card != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TierBadge(tier: card.tier),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${card.points} pts',
                    style: AppTextStyles.title.copyWith(
                      color: AppPalette.of(context).primary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

// A member's card and history, with a form to add or take away points.
class _MemberDialog extends StatefulWidget {
  const _MemberDialog({required this.user, required this.service});

  final AuthUser user;
  final StaffService service;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  final _form = GlobalKey<FormState>();
  final _points = TextEditingController();
  final _note = TextEditingController();
  LoyaltyCard? _card;
  String? _error;
  bool _saving = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _points.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final card = await widget.service.loyalty(widget.user.userId);
      if (mounted) setState(() => _card = card);
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    }
  }

  int? get _pointsValue =>
      int.tryParse(_points.text.trim().replaceAll('+', ''));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final card = await widget.service.adjustPoints(
        widget.user.userId,
        points: _pointsValue!,
        note: _note.text.trim(),
      );
      if (!mounted) return;
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        '${widget.user.displayName} now has ${card.points} points.',
      );
      _points.clear();
      _note.clear();
      setState(() {
        _card = card;
        _changed = true;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: CinemaPanel(
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.user.displayName, style: AppTextStyles.heading2),
                  Text(widget.user.email, style: AppTextStyles.bodySmall),
                  const SizedBox(height: AppSpacing.lg),
                  if (card == null && _error == null)
                    const LoadingState(message: 'Loading points...')
                  else if (card != null)
                    MembershipCard(card: card, historySize: 20),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('Change points', style: AppTextStyles.title),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    key: const Key('adjustPointsField'),
                    label: 'Points (e.g. 50 or -20)',
                    controller: _points,
                    enabled: !_saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    validator: (_) {
                      final points = _pointsValue;
                      return points == null || points == 0
                          ? 'Enter the points to add or take away.'
                          : null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('adjustNoteField'),
                    label: 'Reason',
                    controller: _note,
                    enabled: !_saving,
                    validator: (value) {
                      final note = value?.trim() ?? '';
                      if (note.isEmpty) return 'Enter a reason.';
                      return note.length > 255
                          ? 'Use at most 255 characters.'
                          : null;
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppPalette.of(context).error,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: 'Close',
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, _changed),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppButton(
                          key: const Key('saveAdjustPoints'),
                          label: 'Save',
                          useGradient: true,
                          isLoading: _saving,
                          onPressed: _saving || card == null ? null : _save,
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
