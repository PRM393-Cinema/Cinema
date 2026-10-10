import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/booking.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../widgets/staff_feedback.dart';

class StaffNotificationScreen extends StatefulWidget {
  const StaffNotificationScreen({
    required this.service,
    required this.bookingId,
    super.key,
  });
  final StaffService service;
  final int bookingId;
  @override
  State<StaffNotificationScreen> createState() =>
      _StaffNotificationScreenState();
}

class _StaffNotificationScreenState extends State<StaffNotificationScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _subject = TextEditingController();
  final _content = TextEditingController();
  Booking? _booking;
  int? _notificationId;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _email.dispose();
    _subject.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final booking = await widget.service.booking(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = booking;
        _email.text = booking.customerEmail ?? '';
        _subject.text = 'Booking ${booking.bookingCode}';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _booking == null || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      if (!await staffConfirm(
            context,
            'Send notification?',
            'Send this message to ${_email.text.trim()} for ${_booking!.bookingCode}?',
          ) ||
          !mounted) {
        return;
      }

      if (_notificationId == null) {
        final notification = await widget.service.createNotification(
          _booking!,
          _email.text.trim(),
          _subject.text.trim(),
          const HtmlEscape()
              .convert(_content.text.trim())
              .replaceAll('\n', '<br>'),
        );
        if (!mounted) return;
        setState(() => _notificationId = notification.id);
      }
      final notification = await widget.service.sendNotification(
        _notificationId!,
      );
      if (notification.status != 'SENT') {
        throw const FormatException(
          'The notification was not sent. Please retry.',
        );
      }
      if (!mounted) return;
      await staffSuccess(context, 'Customer notification sent.');
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Customer notification',
    staffMode: true,
    selectedIndex: 1,
    child: _loading
        ? const LoadingState(message: 'Loading booking...')
        : _booking == null
        ? ErrorState(
            title: 'Unable to load booking',
            message: _error ?? 'Please try again.',
            onRetry: _load,
          )
        : SingleChildScrollView(
            padding: staffPadding(context),
            child: CinemaPanel(
              surfaceOpacity: 0.8,
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_booking!.bookingCode, style: AppTextStyles.title),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Customer email',
                      controller: _email,
                      enabled: !_sending && _notificationId == null,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(v?.trim() ?? '')
                          ? null
                          : 'Enter a valid email.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Subject',
                      controller: _subject,
                      enabled: !_sending && _notificationId == null,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required.' : null,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Message',
                      controller: _content,
                      enabled: !_sending && _notificationId == null,
                      maxLines: 5,
                      validator: (v) =>
                          (v?.trim().isEmpty ?? true) ? 'Required.' : null,
                    ),
                    if (_notificationId != null)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          'Notification saved. Retry sends this same message.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: _notificationId == null
                          ? 'Send notification'
                          : 'Retry sending',
                      useGradient: true,
                      isLoading: _sending,
                      onPressed: _sending ? null : _send,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
