import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../../seat/widgets/seat_item.dart';
import '../widgets/staff_feedback.dart';

class StaffCreateBookingScreen extends StatefulWidget {
  const StaffCreateBookingScreen({
    required this.service,
    required this.catalog,
    super.key,
  });
  final StaffService service;
  final CatalogRepository catalog;
  @override
  State<StaffCreateBookingScreen> createState() =>
      _StaffCreateBookingScreenState();
}

class _StaffCreateBookingScreenState extends State<StaffCreateBookingScreen> {
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _email = TextEditingController();
  final _show = TextEditingController();
  Showtime? _showtime;
  ShowtimeSeatsData? _map;
  final _selected = <int>{};
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _user.dispose();
    _email.dispose();
    _show.dispose();
    super.dispose();
  }

  String? _id(String? value) =>
      (int.tryParse(value?.trim() ?? '') ?? 0) > 0 ? null : 'Enter a valid ID.';
  Future<void> _loadSeats() async {
    final id = int.tryParse(_show.text.trim());
    if (id == null || id <= 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _selected.clear();
      _map = null;
      _showtime = null;
    });
    try {
      final show = await widget.catalog.getShowtime(id);
      if (!show.isOpen || !show.startTime.isAfter(DateTime.now())) {
        throw const FormatException('Select an upcoming OPEN showtime.');
      }
      final map = await widget.catalog.getSeatMap(show);
      if (mounted) {
        setState(() {
          _showtime = show;
          _map = map;
        });
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (_busy ||
        !_form.currentState!.validate() ||
        _showtime == null ||
        _selected.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await staffConfirm(
            context,
            'Hold seats for customer?',
            'Create a booking for customer #${_user.text.trim()} with tickets sent to ${_email.text.trim()}. Seats are held for 10 minutes; payment is still required.',
          ) ||
          !mounted) {
        return;
      }

      final booking = await widget.service.createBooking(
        userId: int.parse(_user.text.trim()),
        email: _email.text.trim(),
        showtimeId: _showtime!.id,
        seats: _selected.toList(),
      );
      if (!mounted) return;
      await staffSuccess(
        context,
        'Booking created. Complete payment before the hold expires.',
      );
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.staffRecord('bookings', booking.id),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Book for customer',
    staffMode: true,
    selectedIndex: 1,
    child: SingleChildScrollView(
      padding: staffPadding(context),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CinemaPanel(
              surfaceOpacity: 0.8,
              child: Column(
                children: [
                  const Text(
                    'Use the customer’s account ID and email, not the staff account.',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Customer account ID',
                    controller: _user,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    validator: _id,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Customer email',
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value?.trim() ?? '') &&
                            (value?.trim().length ?? 0) <= 150
                        ? null
                        : 'Enter a valid email.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    label: 'Showtime ID',
                    controller: _show,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    validator: _id,
                    onChanged: (_) => setState(() {
                      _showtime = null;
                      _map = null;
                      _selected.clear();
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton.secondary(
                    label: 'Load available seats',
                    isLoading: _busy,
                    onPressed: _busy ? null : _loadSeats,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_showtime != null && _map != null) ...[
              Text(
                '${_showtime!.roomLabel} · ${formatDateTime(_showtime!.startTime)}',
                style: AppTextStyles.title,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final seat in _map!.seats)
                    Semantics(
                      label: 'Seat ${seat.label}, ${seat.type}',
                      child: SeatItem(
                        label: seat.label,
                        state:
                            _map!.statusOf(seat) !=
                                SeatReservationStatus.available
                            ? SeatItemState.booked
                            : _selected.contains(seat.id)
                            ? SeatItemState.selected
                            : SeatItemState.available,
                        onTap: _busy
                            ? null
                            : () => setState(() {
                                if (!_selected.add(seat.id)) {
                                  _selected.remove(seat.id);
                                }
                              }),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '${_selected.length} seat(s) selected. Final prices are calculated by the server.',
                style: AppTextStyles.bodySmall,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Create booking',
              useGradient: true,
              isLoading: _busy,
              onPressed: _busy || _selected.isEmpty ? null : _create,
            ),
          ],
        ),
      ),
    ),
  );
}
