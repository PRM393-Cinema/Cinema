import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
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
import '../../../data/models/paged_result.dart';
import '../../../data/models/room.dart';
import '../../../data/services/staff_service.dart';
import '../../staff/widgets/staff_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_pager.dart';

// Seat rows are lettered A to Z.
const _maxRows = 26;
const _maxSeatsPerRow = 30;

// Admin: add rooms with their seats, rename them and delete the ones without
// showtimes. Seat types are changed on the room's seat map.
class AdminRoomsScreen extends StatefulWidget {
  const AdminRoomsScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<AdminRoomsScreen> createState() => _AdminRoomsScreenState();
}

class _AdminRoomsScreenState extends State<AdminRoomsScreen> {
  final _search = TextEditingController();
  PagedResult<Room>? _result;
  String? _message;
  bool _loading = false;
  int? _busyId;

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
      final result = await widget.service.rooms(
        page: page,
        keyword: _search.text.trim(),
      );
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notice(String message) =>
      showTopNotice(Overlay.of(context, rootOverlay: true), message);

  Future<void> _add() async {
    final room = await showDialog<Room>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomFormDialog(service: widget.service),
    );
    if (room == null || !mounted) return;
    _notice('Added ${room.name} with ${room.totalSeats} seats.');
    await _load();
  }

  Future<void> _openSeatMap(Room room) async {
    await Navigator.pushNamed(context, AppRoutes.staffRecord('rooms', room.id));
    if (mounted) await _load(page: _result?.pageNumber ?? 1);
  }

  Future<void> _rename(Room room) async {
    final name = await staffInput(
      context,
      'Rename room',
      'Room name',
      initial: room.name,
      maxLength: 100,
    );
    if (name == null || name == room.name || !mounted) return;
    await _run(room, () async {
      final renamed = await widget.service.renameRoom(room, name);
      return 'Renamed ${room.name} to ${renamed.name}.';
    });
  }

  Future<void> _delete(Room room) async {
    final confirmed = await staffConfirm(
      context,
      'Delete room',
      'Delete ${room.name} and its ${room.totalSeats} seats? A room with '
          'showtimes cannot be deleted.',
    );
    if (!confirmed || !mounted) return;
    final page = _result?.pageNumber ?? 1;
    final lastOnPage = (_result?.items.length ?? 0) == 1;
    await _run(room, () async {
      await widget.service.deleteRoom(room.id);
      return 'Deleted ${room.name}.';
    }, page: lastOnPage && page > 1 ? page - 1 : page);
  }

  // Runs one change on a room, then shows its result and reloads the list.
  Future<void> _run(
    Room room,
    Future<String> Function() change, {
    int? page,
  }) async {
    setState(() => _busyId = room.id);
    try {
      final message = await change();
      if (!mounted) return;
      _notice(message);
      await _load(page: page ?? _result?.pageNumber ?? 1);
    } on Object catch (error) {
      if (mounted) _notice(staffError(error));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final busy = _loading || _busyId != null;

    return AdminPage(
      section: AdminSection.rooms,
      title: 'Rooms',
      child: RefreshIndicator(
        onRefresh: () => _load(page: result?.pageNumber ?? 1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: centeredPadding(context, AppSpacing.lg),
          children: [
            AppButton(
              key: const Key('addRoomButton'),
              label: 'Add room',
              leadingIcon: Icons.add_rounded,
              useGradient: true,
              onPressed: busy ? null : _add,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    key: const Key('roomSearchField'),
                    label: 'Search rooms',
                    controller: _search,
                    enabled: !busy,
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'Search rooms',
                  onPressed: busy ? null : () => _load(),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingState(message: 'Loading rooms...')
            else if (_message != null)
              ErrorState(
                title: 'Unable to load rooms',
                message: _message!,
                onRetry: () => _load(page: result?.pageNumber ?? 1),
              )
            else if (result != null) ...[
              Text(
                formatCount(result.totalCount, 'room'),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              if (result.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'No matching rooms.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              for (final room in result.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RoomCard(
                    room: room,
                    busy: _busyId == room.id,
                    onSeatMap: busy ? null : () => _openSeatMap(room),
                    onRename: busy ? null : () => _rename(room),
                    onDelete: busy ? null : () => _delete(room),
                  ),
                ),
              if (result.totalPages > 1)
                AdminPager(
                  page: result.pageNumber,
                  totalPages: result.totalPages,
                  onOpen: busy ? null : (page) => _load(page: page),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.room,
    required this.busy,
    required this.onSeatMap,
    required this.onRename,
    required this.onDelete,
  });

  final Room room;
  final bool busy;
  final VoidCallback? onSeatMap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => CinemaPanel(
    surfaceOpacity: 0.8,
    child: Row(
      children: [
        const Icon(Icons.meeting_room_outlined, color: AppColors.primary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(room.name, style: AppTextStyles.title),
              const SizedBox(height: AppSpacing.xs),
              Text('${room.totalSeats} seats', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
        if (busy)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else ...[
          IconButton(
            key: Key('roomSeats-${room.id}'),
            tooltip: 'Seat map',
            icon: const Icon(Icons.event_seat_outlined),
            onPressed: onSeatMap,
          ),
          IconButton(
            key: Key('renameRoom-${room.id}'),
            tooltip: 'Rename',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onRename,
          ),
          IconButton(
            key: Key('deleteRoom-${room.id}'),
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ],
    ),
  );
}

class _RoomFormDialog extends StatefulWidget {
  const _RoomFormDialog({required this.service});

  final StaffService service;

  @override
  State<_RoomFormDialog> createState() => _RoomFormDialogState();
}

class _RoomFormDialogState extends State<_RoomFormDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rows = TextEditingController(text: '8');
  final _seatsPerRow = TextEditingController(text: '10');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _rows.dispose();
    _seatsPerRow.dispose();
    super.dispose();
  }

  int? _count(TextEditingController controller, int max) {
    final value = int.tryParse(controller.text.trim());
    return value == null || value < 1 || value > max ? null : value;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final rows = _count(_rows, _maxRows)!;
    final seatsPerRow = _count(_seatsPerRow, _maxSeatsPerRow)!;
    try {
      final room = await widget.service.createRoom(
        name: _name.text,
        rows: rows,
        seatsPerRow: seatsPerRow,
      );
      try {
        await widget.service.generateSeats(room.id, rows, seatsPerRow);
      } on Object {
        // A room without seats cannot be booked: remove it so the admin can
        // try again with the same name.
        try {
          await widget.service.deleteRoom(room.id);
        } on Object {
          // It stays in the list without seats; the original error is shown.
        }
        rethrow;
      }
      if (mounted) Navigator.pop(context, room);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = staffError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _count(_rows, _maxRows);
    final seatsPerRow = _count(_seatsPerRow, _maxSeatsPerRow);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: CinemaPanel(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add room', style: AppTextStyles.heading2),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const Key('roomNameField'),
                    label: 'Room name',
                    controller: _name,
                    enabled: !_saving,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Required.';
                      if (text.length > 100) return 'Maximum 100 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: AppTextField(
                          key: const Key('roomRowsField'),
                          label: 'Rows (A-Z)',
                          controller: _rows,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (_) => _count(_rows, _maxRows) == null
                              ? 'Enter 1 to $_maxRows.'
                              : null,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppTextField(
                          key: const Key('roomSeatsPerRowField'),
                          label: 'Seats per row',
                          controller: _seatsPerRow,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          validator: (_) =>
                              _count(_seatsPerRow, _maxSeatsPerRow) == null
                              ? 'Enter 1 to $_maxSeatsPerRow.'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    rows != null && seatsPerRow != null
                        ? '${rows * seatsPerRow} standard seats. Change seat '
                              'types on the seat map afterwards.'
                        : 'Enter the rows and seats per row.',
                    key: const Key('roomSeatTotal'),
                    style: AppTextStyles.caption,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      key: const Key('roomFormError'),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
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
                          key: const Key('saveRoomButton'),
                          label: 'Add room',
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
