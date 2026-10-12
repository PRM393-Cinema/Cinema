import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/room.dart';
import '../../../data/models/showtime.dart';
import '../../../data/services/staff_service.dart';
import '../../admin/widgets/admin_page.dart';
import '../widgets/staff_feedback.dart';

class StaffShowtimeEditorScreen extends StatefulWidget {
  const StaffShowtimeEditorScreen({required this.service, this.id, super.key});
  final StaffService service;
  final int? id;
  @override
  State<StaffShowtimeEditorScreen> createState() =>
      _StaffShowtimeEditorScreenState();
}

class _StaffShowtimeEditorScreenState extends State<StaffShowtimeEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController();
  List<Movie> _movies = [];
  List<Room> _rooms = [];
  int? _movie;
  int? _room;
  DateTime? _start;
  DateTime? _end;
  String _status = 'OPEN';
  bool _loading = true;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var movies = await widget.service.movies();
      final allMovies = [...movies.items];
      for (var page = 2; page <= movies.totalPages; page++) {
        movies = await widget.service.movies(page: page);
        allMovies.addAll(movies.items);
      }
      var rooms = await widget.service.rooms();
      final allRooms = [...rooms.items];
      for (var page = 2; page <= rooms.totalPages; page++) {
        rooms = await widget.service.rooms(page: page);
        allRooms.addAll(rooms.items);
      }
      final Showtime? show = widget.id == null
          ? null
          : await widget.service.showtime(widget.id!);
      if (!mounted) return;
      setState(() {
        _movies = allMovies;
        _rooms = allRooms;
        _movie = show?.movieId;
        _room = show?.roomId;
        _start = show?.startTime;
        _end = show?.endTime;
        _status = show?.status ?? 'OPEN';
        _price.text = show?.price.toStringAsFixed(0) ?? '';
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(bool start) async {
    final initial = (start ? _start : _end) ?? _start ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: initial,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      final value = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_start == null || _end == null || !_end!.isAfter(_start!)) {
      setState(
        () => _error = 'Choose a start and end time; end must be after start.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final show = await widget.service.saveShowtime(
        id: widget.id,
        movieId: _movie!,
        roomId: _room!,
        start: _start!,
        end: _end!,
        price: double.parse(_price.text.trim()),
        status: _status,
      );
      if (!mounted) return;
      await staffSuccess(context, 'Showtime saved.');
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.staffRecord('showtimes', show.id),
        );
      }
    } on Object catch (error) {
      if (mounted) setState(() => _error = staffError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: widget.id == null ? 'Create showtime' : 'Edit showtime',
    staffMode: true,
    selectedIndex: 1,
    child: _loading
        ? const LoadingState(message: 'Loading movies and rooms...')
        : _movies.isEmpty || _rooms.isEmpty
        ? ErrorState(
            title: 'Movies and rooms required',
            message: _error ?? 'Ask Admin to create a movie and room first.',
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
                    DropdownButtonFormField<int>(
                      initialValue: _movie,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Movie'),
                      items: [
                        for (final movie in _movies)
                          DropdownMenuItem(
                            value: movie.id,
                            child: Text(
                              movie.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      validator: (v) => v == null ? 'Choose a movie.' : null,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _movie = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<int>(
                      initialValue: _room,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Room'),
                      items: [
                        for (final room in _rooms)
                          DropdownMenuItem(
                            value: room.id,
                            child: Text(room.name),
                          ),
                      ],
                      validator: (v) => v == null ? 'Choose a room.' : null,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _room = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton.secondary(
                      label: _start == null
                          ? 'Choose start time'
                          : formatDateTime(_start!),
                      onPressed: _saving ? null : () => _pick(true),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.secondary(
                      label: _end == null
                          ? 'Choose end time'
                          : formatDateTime(_end!),
                      onPressed: _saving ? null : () => _pick(false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Price (VND)',
                      controller: _price,
                      enabled: !_saving,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) {
                        final price = double.tryParse(v?.trim() ?? '');
                        return price == null || !price.isFinite || price < 0
                            ? 'Enter a non-negative price.'
                            : null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final status in [
                          'OPEN',
                          'CLOSED',
                          if (_status == 'CANCELLED') 'CANCELLED',
                        ])
                          DropdownMenuItem(value: status, child: Text(status)),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _status = v!),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.lg),
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xl),
                    AppButton(
                      label: 'Save showtime',
                      useGradient: true,
                      isLoading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
  );
}
