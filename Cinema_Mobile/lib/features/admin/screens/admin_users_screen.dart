import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_state.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/auth_response.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../auth/widgets/auth_success_dialog.dart';

String _error(Object error) => error is ApiException
    ? error.message
    : 'Unable to complete the request. Please try again.';
String _roleName(String role) => switch (role) {
  'ROLE_ADMIN' => 'Admin',
  'ROLE_STAFF' => 'Staff',
  'ROLE_CUSTOMER' => 'Customer',
  _ => role,
};

Future<void> _saved(BuildContext context, String message) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Account updated',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) => Material(
        type: MaterialType.transparency,
        child: AuthSuccessDialog(
          title: 'Done',
          message: message,
          footer: 'Account management',
        ),
      ),
      transitionBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({required this.repository, super.key});
  final AuthRepository repository;
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _search = TextEditingController();
  PagedResult<AuthUser>? _result;
  List<String> _roles = [];
  String? _role;
  String _status = 'all';
  String? _message;
  bool _loading = false;

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
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final roles = _roles.isEmpty ? await widget.repository.roles() : _roles;
      if (!mounted) return;
      final result = await widget.repository.users(
        page: page,
        keyword: _search.text.trim(),
        role: _role,
        enabled: _status == 'all' ? null : _status == 'active',
      );
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _result = result;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String route) async {
    await Navigator.pushNamed(context, route);
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Manage accounts',
    child: RefreshIndicator(
      onRefresh: () => _load(page: _result?.pageNumber ?? 1),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: centeredPadding(context, AppSpacing.lg),
        children: [
          AppButton(
            label: 'Create account',
            leadingIcon: Icons.person_add_alt_1_rounded,
            useGradient: true,
            onPressed: _loading ? null : () => _open(AppRoutes.adminCreateUser),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Search name or email',
                  controller: _search,
                  enabled: !_loading,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Search accounts',
                onPressed: _loading ? null : () => _load(),
                icon: const Icon(Icons.search_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _role ?? 'all',
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All roles'),
                    ),
                    for (final role in _roles)
                      DropdownMenuItem(
                        value: role,
                        child: Text(_roleName(role)),
                      ),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _role = value == 'all' ? null : value);
                          _load();
                        },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All statuses')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'locked', child: Text('Locked')),
                  ],
                  onChanged: _loading
                      ? null
                      : (value) {
                          setState(() => _status = value!);
                          _load();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            const LoadingState(message: 'Loading accounts...')
          else if (_message != null)
            ErrorState(
              title: 'Unable to load accounts',
              message: _message!,
              onRetry: () => _load(page: _result?.pageNumber ?? 1),
            )
          else ...[
            Text(
              '${_result?.totalCount ?? 0} accounts',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            if (_result?.items.isEmpty ?? true)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No matching accounts.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
              ),
            for (final user in _result?.items ?? <AuthUser>[])
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _open(AppRoutes.adminUser(user.userId)),
                  child: CinemaPanel(
                    surfaceOpacity: 0.8,
                    child: Row(
                      children: [
                        Icon(
                          user.enabled
                              ? Icons.person_outline_rounded
                              : Icons.person_off_outlined,
                          color: user.enabled
                              ? AppColors.primary
                              : AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user.displayName,
                                style: AppTextStyles.title,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(user.email, style: AppTextStyles.bodySmall),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                '${user.roles.map(_roleName).join(', ')} · ${user.enabled ? 'Active' : 'Locked'}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if ((_result?.totalPages ?? 0) > 1)
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Previous',
                      onPressed: _result!.pageNumber > 1
                          ? () => _load(page: _result!.pageNumber - 1)
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      '${_result!.pageNumber}/${_result!.totalPages}',
                      style: AppTextStyles.caption,
                    ),
                  ),
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Next',
                      onPressed: _result!.pageNumber < _result!.totalPages
                          ? () => _load(page: _result!.pageNumber + 1)
                          : null,
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    ),
  );
}

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({
    required this.repository,
    required this.userId,
    super.key,
  });
  final AuthRepository repository;
  final int userId;
  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  AuthUser? _user;
  List<String> _roles = [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  String? _message;
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
      final user = await widget.repository.getUser(widget.userId);
      final roles = await widget.repository.roles();
      if (!mounted) return;
      setState(() {
        _user = user;
        _roles = roles;
        _selected = user.roles.toSet();
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(Future<AuthUser> Function() action, String message) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final user = await action();
      if (!mounted) return;
      setState(() {
        _user = user;
        _selected = user.roles.toSet();
      });
      final session = SessionProvider.of(context);
      if (session.user?.userId == user.userId) {
        session.setAuthenticated(await widget.repository.currentUser());
        if (!mounted) return;
      }
      await _saved(context, message);
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleStatus() async {
    final user = _user!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: CinemaPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                user.enabled ? Icons.lock_outline : Icons.lock_open_outlined,
                color: AppColors.primary,
                size: 40,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                user.enabled ? 'Lock this account?' : 'Unlock this account?',
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                user.email,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx, false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: AppButton(
                      label: 'Confirm',
                      useGradient: true,
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed == true && mounted) {
      await _save(
        () => widget.repository.updateUserStatus(user.userId, !user.enabled),
        user.enabled ? 'Account locked.' : 'Account unlocked.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = SessionProvider.of(context).user?.userId == widget.userId;
    final user = _user;
    return CinemaPage(
      title: 'Account details',
      child: _loading
          ? const LoadingState(message: 'Loading account...')
          : user == null
          ? ErrorState(
              title: 'Unable to load account',
              message: _message ?? 'Please try again.',
              onRetry: _load,
            )
          : RefreshIndicator(
              onRefresh: _saving ? () async {} : _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: centeredPadding(context, AppSpacing.lg),
                children: [
                  CinemaPanel(
                    surfaceOpacity: 0.8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.displayName, style: AppTextStyles.heading2),
                        const SizedBox(height: AppSpacing.md),
                        SelectableText(user.email, style: AppTextStyles.body),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Phone: ${user.phone ?? 'Not provided'}',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Joined: ${formatDate(user.createdAt)}',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Email verified: ${user.emailVerified ? 'Yes' : 'No'}',
                          style: AppTextStyles.bodySmall,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          user.enabled ? 'Active' : 'Locked',
                          style: AppTextStyles.body.copyWith(
                            color: user.enabled
                                ? AppColors.primary
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CinemaPanel(
                    surfaceOpacity: 0.8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Roles', style: AppTextStyles.title),
                        _RolePicker(
                          roles: _roles,
                          selected: _selected,
                          disabled: _saving,
                          keepAdmin: self,
                          onChanged: (roles) =>
                              setState(() => _selected = roles),
                        ),
                        if (self)
                          const Text(
                            'You cannot remove your own Admin role or lock this account.',
                            style: AppTextStyles.caption,
                          ),
                        const SizedBox(height: AppSpacing.md),
                        AppButton(
                          label: 'Save roles',
                          useGradient: true,
                          isLoading: _saving,
                          onPressed: _saving || _selected.isEmpty
                              ? null
                              : () => _save(
                                  () => widget.repository.updateUserRoles(
                                    user.userId,
                                    _selected.toList(),
                                  ),
                                  'Account roles updated.',
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Role changes take effect after the user signs in again or refreshes their session.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.secondary(
                    label: user.enabled ? 'Lock account' : 'Unlock account',
                    leadingIcon: user.enabled
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    onPressed: self || _saving ? null : _toggleStatus,
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        _message!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class AdminCreateUserScreen extends StatefulWidget {
  const AdminCreateUserScreen({required this.repository, super.key});
  final AuthRepository repository;
  @override
  State<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends State<AdminCreateUserScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  List<String> _roles = [];
  Set<String> _selected = {};
  bool _loading = true;
  bool _saving = false;
  bool _obscure = true;
  String? _message;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final roles = await widget.repository.roles();
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _selected = roles.contains('ROLE_CUSTOMER') ? {'ROLE_CUSTOMER'} : {};
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_saving ||
        !(_form.currentState?.validate() ?? false) ||
        _selected.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final user = await widget.repository.createUser(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        roles: _selected.toList(),
      );
      if (!mounted) return;
      _password.clear();
      await _saved(context, 'Account created. It can sign in immediately.');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, AppRoutes.adminUser(user.userId));
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Create account',
    child: _loading
        ? const LoadingState(message: 'Loading roles...')
        : _roles.isEmpty
        ? ErrorState(
            title: 'Unable to load roles',
            message: _message ?? 'No roles available.',
            onRetry: _load,
          )
        : SingleChildScrollView(
            padding: centeredPadding(context, AppSpacing.lg),
            child: CinemaPanel(
              surfaceOpacity: 0.8,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('New account', style: AppTextStyles.heading2),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Created by Admin. Email verification is not required.',
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppTextField(
                      label: 'Full name',
                      controller: _name,
                      enabled: !_saving,
                      validator: (v) => (v?.trim().isEmpty ?? true)
                          ? 'Enter a name.'
                          : v!.trim().length > 150
                          ? 'Maximum 150 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Email',
                      controller: _email,
                      enabled: !_saving,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Enter a valid email.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Password',
                      controller: _password,
                      enabled: !_saving,
                      obscureText: _obscure,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Show password' : 'Hide password',
                        onPressed: _saving
                            ? null
                            : () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      validator: (v) => (v?.length ?? 0) < 6
                          ? 'Use at least 6 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Phone (optional)',
                      controller: _phone,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v?.trim().length ?? 0) > 20
                          ? 'Maximum 20 characters.'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Text('Roles', style: AppTextStyles.title),
                    _RolePicker(
                      roles: _roles,
                      selected: _selected,
                      disabled: _saving,
                      onChanged: (roles) => setState(() => _selected = roles),
                    ),
                    if (_selected.isEmpty)
                      Text(
                        'Select at least one role.',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          _message!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Create account',
                      useGradient: true,
                      isLoading: _saving,
                      onPressed: _saving || _selected.isEmpty ? null : _create,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.roles,
    required this.selected,
    required this.onChanged,
    this.disabled = false,
    this.keepAdmin = false,
  });
  final List<String> roles;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool disabled;
  final bool keepAdmin;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final role in roles)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(_roleName(role), style: AppTextStyles.body),
          value: selected.contains(role),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: disabled || (keepAdmin && role == 'ROLE_ADMIN')
              ? null
              : (value) {
                  final updated = {...selected};
                  if (value == true) {
                    updated.add(role);
                  } else {
                    updated.remove(role);
                  }
                  onChanged(updated);
                },
        ),
    ],
  );
}
