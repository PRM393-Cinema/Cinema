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
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/movie_draft.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/services/staff_service.dart';
import '../../staff/widgets/staff_feedback.dart';
import '../../../core/widgets/responsive_columns.dart';
import '../widgets/admin_layout.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_pager.dart';
import '../../../core/widgets/age_rating_badge.dart';

const _showing = 'ACTIVE';
const _stopped = 'INACTIVE';

// Admin: add and edit movies, stop showing them and show them again. A stopped
// movie keeps its bookings; customers no longer see it.
class AdminMoviesScreen extends StatefulWidget {
  const AdminMoviesScreen({required this.service, super.key});
  final StaffService service;
  @override
  State<AdminMoviesScreen> createState() => _AdminMoviesScreenState();
}

class _AdminMoviesScreenState extends State<AdminMoviesScreen> {
  final _search = TextEditingController();
  PagedResult<Movie>? _result;
  String? _status;
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
      final result = await widget.service.catalogMovies(
        page: page,
        keyword: _search.text,
        status: _status,
      );
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) setState(() => _message = staffError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // The API searches every movie, so a search clears the status filter and a
  // filter clears the search.
  void _searchMovies() {
    setState(() => _status = null);
    _load();
  }

  void _filter(String? status) {
    _search.clear();
    setState(() => _status = status);
    _load();
  }

  void _notice(String message) =>
      showTopNotice(Overlay.of(context, rootOverlay: true), message);

  Future<void> _edit([Movie? movie]) async {
    final saved = await showDialog<Movie>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MovieFormDialog(service: widget.service, movie: movie),
    );
    if (saved == null || !mounted) return;
    _notice(movie == null ? 'Added ${saved.title}.' : 'Saved ${saved.title}.');
    await _load(page: movie == null ? 1 : _result?.pageNumber ?? 1);
  }

  Future<void> _setShowing(Movie movie, {required bool showing}) async {
    final confirmed = await staffConfirm(
      context,
      showing ? 'Show movie again' : 'Stop showing movie',
      showing
          ? 'Customers will see ${movie.title} again.'
          : 'Customers will no longer see ${movie.title}. Its bookings are '
                'kept, and you can show it again later.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = movie.id);
    try {
      if (showing) {
        await widget.service.updateMovie(
          movie.id,
          MovieDraft.fromMovie(movie),
          status: _showing,
        );
      } else {
        await widget.service.stopShowingMovie(movie.id);
      }
      if (!mounted) return;
      _notice(
        showing
            ? '${movie.title} is showing again.'
            : '${movie.title} is no longer showing.',
      );
      await _load(page: _result?.pageNumber ?? 1);
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
      section: AdminSection.movies,
      title: 'Movies',
      child: RefreshIndicator(
        onRefresh: () => _load(page: result?.pageNumber ?? 1),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: pagePadding(context, AppSpacing.lg),
          children: [
            AdminControls(
              children: [
                AppButton(
                  key: const Key('addMovieButton'),
                  label: 'Add movie',
                  leadingIcon: Icons.add_rounded,
                  useGradient: true,
                  onPressed: busy ? null : () => _edit(),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        key: const Key('movieSearchField'),
                        label: 'Search titles',
                        controller: _search,
                        enabled: !busy,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Search movies',
                      onPressed: busy ? null : _searchMovies,
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButton<String>(
                  key: const Key('movieStatusFilter'),
                  isExpanded: true,
                  value: _status ?? 'all',
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All movies')),
                    DropdownMenuItem(value: _showing, child: Text('Showing')),
                    DropdownMenuItem(value: _stopped, child: Text('Stopped')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => _filter(value == 'all' ? null : value),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_loading)
              const LoadingState(message: 'Loading movies...')
            else if (_message != null)
              ErrorState(
                title: 'Unable to load movies',
                message: _message!,
                onRetry: () => _load(page: result?.pageNumber ?? 1),
              )
            else if (result != null) ...[
              Text(
                formatCount(result.totalCount, 'movie'),
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: AppSpacing.md),
              if (result.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    'No matching movies.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              CardColumns(
                runSpacing: 0,
                children: [
                  for (final movie in result.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _MovieCard(
                        movie: movie,
                        busy: _busyId == movie.id,
                        onEdit: busy ? null : () => _edit(movie),
                        onSetShowing: busy
                            ? null
                            : (showing) => _setShowing(movie, showing: showing),
                      ),
                    ),
                ],
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

class _MovieCard extends StatelessWidget {
  const _MovieCard({
    required this.movie,
    required this.busy,
    required this.onEdit,
    required this.onSetShowing,
  });

  final Movie movie;
  final bool busy;
  final VoidCallback? onEdit;
  final ValueChanged<bool>? onSetShowing;

  @override
  Widget build(BuildContext context) {
    final showing = movie.status.toUpperCase() == _showing;
    final release = movie.releaseDate;
    final details = [
      if (movie.genre.isNotEmpty) movie.genre,
      movie.durationText,
      if (release != null) formatDate(release),
    ].join(' · ');

    return CinemaPanel(
      surfaceOpacity: 0.8,
      child: Row(
        children: [
          AppNetworkImage(
            imageUrl: movie.posterUrl,
            width: 56,
            height: 80,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AgeRatingBadge(rating: movie.ageRating),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        movie.title,
                        style: AppTextStyles.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(details, style: AppTextStyles.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                StatusBadge(
                  label: showing ? 'Showing' : 'Stopped',
                  variant: showing
                      ? StatusBadgeVariant.success
                      : StatusBadgeVariant.neutral,
                ),
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
              key: Key('editMovie-${movie.id}'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              key: Key('toggleMovie-${movie.id}'),
              tooltip: showing ? 'Stop showing' : 'Show again',
              icon: Icon(
                showing
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: showing ? AppColors.error : AppColors.success,
              ),
              onPressed: onSetShowing == null
                  ? null
                  : () => onSetShowing!(!showing),
            ),
          ],
        ],
      ),
    );
  }
}

// Two fields side by side, one under the other when the form is narrow (a
// phone-width window), so values are not cut off.
class _FieldPair extends StatelessWidget {
  const _FieldPair({required this.first, required this.second});

  static const _sideBySideFrom = 420.0;

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < _sideBySideFrom
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              first,
              const SizedBox(height: AppSpacing.md),
              second,
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: first),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: second),
            ],
          ),
  );
}

// A date shown like the text fields around it; tapping opens the picker.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        enabled: onTap != null,
        suffixIcon: const Icon(Icons.event_outlined),
      ),
      child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}

class _MovieFormDialog extends StatefulWidget {
  const _MovieFormDialog({required this.service, this.movie});

  final StaffService service;
  final Movie? movie;

  @override
  State<_MovieFormDialog> createState() => _MovieFormDialogState();
}

class _MovieFormDialogState extends State<_MovieFormDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.movie?.title);
  late final _duration = TextEditingController(
    text: widget.movie == null ? '' : '${widget.movie!.durationMinutes}',
  );
  late final _genre = TextEditingController(text: widget.movie?.genre);
  late final _language = TextEditingController(text: widget.movie?.language);
  late final _description = TextEditingController(
    text: widget.movie?.description,
  );
  late final _poster = TextEditingController(text: widget.movie?.posterUrl);
  late final _trailer = TextEditingController(text: widget.movie?.trailerUrl);
  late DateTime _releaseDate =
      widget.movie?.releaseDate ?? DateUtils.dateOnly(DateTime.now());
  late AgeRating _ageRating = widget.movie?.ageRating ?? AgeRating.p;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _title,
      _duration,
      _genre,
      _language,
      _description,
      _poster,
      _trailer,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateTime(1900);
    final last = DateTime(DateTime.now().year + 5, 12, 31);
    final picked = await showDatePicker(
      context: context,
      initialDate: _releaseDate.isBefore(first)
          ? first
          : _releaseDate.isAfter(last)
          ? last
          : _releaseDate,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _releaseDate = picked);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = MovieDraft(
      title: _title.text,
      durationMinutes: int.parse(_duration.text.trim()),
      releaseDate: _releaseDate,
      description: _description.text,
      genre: _genre.text,
      language: _language.text,
      posterUrl: _poster.text,
      trailerUrl: _trailer.text,
      ageRating: _ageRating,
    );
    try {
      final movie = widget.movie;
      final saved = movie == null
          ? await widget.service.createMovie(draft)
          : await widget.service.updateMovie(movie.id, draft);
      if (mounted) Navigator.pop(context, saved);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = staffError(error);
      });
    }
  }

  static String? _required(String? value, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Required.';
    if (text.length > maxLength) return 'Maximum $maxLength characters.';
    return null;
  }

  static String? _minutes(String? value) {
    final minutes = int.tryParse(value?.trim() ?? '');
    return minutes == null || minutes < 1 || minutes > 600
        ? 'Enter 1 to 600 minutes.'
        : null;
  }

  static String? _link(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final valid =
        uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
    return valid ? null : 'Enter a link starting with http:// or https://.';
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.movie != null;

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
                    editing ? 'Edit movie' : 'Add movie',
                    style: AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppTextField(
                    key: const Key('movieTitleField'),
                    label: 'Title',
                    controller: _title,
                    enabled: !_saving,
                    validator: (value) => _required(value, 200),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldPair(
                    first: AppTextField(
                      key: const Key('movieDurationField'),
                      label: 'Duration (minutes)',
                      controller: _duration,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      validator: _minutes,
                    ),
                    second: _DateField(
                      key: const Key('movieReleaseDateField'),
                      label: 'Release date',
                      value: formatDate(_releaseDate),
                      onTap: _saving ? null : _pickDate,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<AgeRating>(
                    key: const Key('movieAgeRatingField'),
                    initialValue: _ageRating,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Age rating'),
                    items: [
                      for (final rating in AgeRating.values)
                        DropdownMenuItem(
                          value: rating,
                          child: Row(
                            children: [
                              AgeRatingBadge(rating: rating),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  rating.meaning,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: _saving
                        ? null
                        : (rating) => setState(
                            () => _ageRating = rating ?? AgeRating.p,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _FieldPair(
                    first: AppTextField(
                      key: const Key('movieGenreField'),
                      label: 'Genre',
                      controller: _genre,
                      enabled: !_saving,
                    ),
                    second: AppTextField(
                      key: const Key('movieLanguageField'),
                      label: 'Language',
                      controller: _language,
                      enabled: !_saving,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('movieDescriptionField'),
                    label: 'Description',
                    controller: _description,
                    enabled: !_saving,
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('moviePosterField'),
                    label: 'Poster link',
                    controller: _poster,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    validator: _link,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    key: const Key('movieTrailerField'),
                    label: 'Trailer link',
                    controller: _trailer,
                    enabled: !_saving,
                    keyboardType: TextInputType.url,
                    validator: _link,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      key: const Key('movieFormError'),
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
                          key: const Key('saveMovieButton'),
                          label: editing ? 'Save' : 'Add movie',
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
