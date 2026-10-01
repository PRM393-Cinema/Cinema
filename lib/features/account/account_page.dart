import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/cinema_api.dart';
import '../../shared/widgets.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({
    super.key,
    required this.user,
    required this.onAuthenticate,
    required this.onSignOut,
  });
  final Map<String, dynamic>? user;
  final Future<Map<String, dynamic>?> Function() onAuthenticate;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Tài khoản', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 24),
        if (user == null) ...[
          const CinemaBrandMark(size: 68),
          const SizedBox(height: 20),
          Text(
            'Một buổi tối đáng nhớ\nbắt đầu từ đây.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Đăng nhập để đặt ghế và lưu vé ngay trên điện thoại.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CinemaColors.muted),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onAuthenticate,
            child: const Text('Đăng nhập / Tạo tài khoản'),
          ),
        ] else ...[
          Row(
            children: [
              const CinemaBrandMark(size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['fullName']?.toString().trim().isNotEmpty == true
                          ? user!['fullName'].toString()
                          : 'Thành viên Ciné',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?['email']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: CinemaColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _AccountRow(
            icon: Icons.confirmation_number_outlined,
            title: 'Vé của tôi',
            subtitle: 'Lịch sử đặt chỗ',
            onTap: () =>
                showSnack(context, 'Mở mục “Vé của tôi” ở thanh điều hướng.'),
          ),
          const Divider(height: 1, color: CinemaColors.line),
          _AccountRow(
            icon: Icons.help_outline,
            title: 'Trợ giúp',
            subtitle: 'Liên hệ quầy vé tại rạp',
            onTap: () =>
                showSnack(context, 'Nhân viên rạp sẵn sàng hỗ trợ bạn.'),
          ),
          const Divider(height: 1, color: CinemaColors.line),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('Đăng xuất?'),
                content: const Text('Bạn có thể đăng nhập lại bất cứ lúc nào.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Ở lại'),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext);
                      await onSignOut();
                    },
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: CinemaColors.ink,
              side: const BorderSide(color: CinemaColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.api});
  final CinemaApi api;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _register = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate() || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = _register
          ? await widget.api.register(
              email: _email.text.trim(),
              password: _password.text,
              fullName: _name.text.trim(),
              phone: _phone.text.trim(),
            )
          : await widget.api.login(_email.text.trim(), _password.text);
      if (mounted) Navigator.pop(context, user);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
    ),
    body: SafeArea(
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            children: [
              const CinemaBrandMark(size: 56),
              const SizedBox(height: 22),
              Text(
                _register ? 'Tạo tài khoản' : 'Chào mừng trở lại',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _register
                    ? 'Lưu lựa chọn ghế và vé của bạn.'
                    : 'Đăng nhập để tiếp tục đặt vé.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: CinemaColors.muted),
              ),
              const SizedBox(height: 26),
              if (_register) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (value) => value == null || value.trim().length < 2
                      ? 'Nhập họ tên của bạn.'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(value.trim())
                    ? 'Nhập email hợp lệ.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: _register
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: _register
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                onFieldSubmitted: (_) {
                  if (!_register) _submit();
                },
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.length < 8
                    ? 'Mật khẩu cần ít nhất 8 ký tự.'
                    : null,
              ),
              if (_register) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    hintText: 'Không bắt buộc',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _InlineError(_error!),
              ],
              const SizedBox(height: 22),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_register ? 'Tạo tài khoản' : 'Đăng nhập'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _error = null;
                      }),
                child: Text(
                  _register
                      ? 'Đã có tài khoản? Đăng nhập'
                      : 'Chưa có tài khoản? Tạo mới',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 8,
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: CinemaColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: CinemaColors.line),
      ),
      child: Icon(icon, color: CinemaColors.ink, size: 20),
    ),
    title: Text(
      title,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(fontWeight: FontWeight.w600),
    ),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(Icons.chevron_right, color: CinemaColors.muted),
    onTap: onTap,
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEFEC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      message,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: const Color(0xFF9E3829)),
    ),
  );
}
