import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/top_notice.dart';
import '../../../data/models/movie.dart';
import '../../../data/models/paged_result.dart';
import '../../../data/services/movie_service.dart';
import '../widgets/admin_page.dart';

String _error(Object error) => error is ApiException
    ? error.message
    : 'Unable to complete the request. Please try again.';

class AdminMoviesScreen extends StatefulWidget {
  const AdminMoviesScreen({required this.service, super.key});
  final MovieService service;
  @override
  State<AdminMoviesScreen> createState() => _AdminMoviesScreenState();
}

class _AdminMoviesScreenState extends State<AdminMoviesScreen> {
  final _search = TextEditingController();
  PagedResult<Movie>? _result;
  int _page = 1;
  bool _loading = false;
  bool _updating = false;
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

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final result = await widget.service.getMovies(
        keyword: _search.text,
        page: _page,
      );
      if (mounted) setState(() => _result = result);
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Movie? movie]) async {
    await Navigator.pushNamed(
      context,
      movie == null
          ? AppRoutes.adminCreateMovie
          : AppRoutes.adminEditMovie(movie.id),
    );
    if (mounted) _load();
  }

  Future<void> _delete(Movie movie) async {
    if (_updating || _loading || movie.status == 'INACTIVE') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete movie?'),
        content: Text(
          '"${movie.title}" will be marked INACTIVE and hidden from customer listings. Its data will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    try {
      await widget.service.deleteMovie(movie.id);
      if (!mounted) return;
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        'Movie deactivated.',
      );
      await _load();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  Future<void> _activate(Movie movie) async {
    if (_updating || _loading) return;
    setState(() {
      _updating = true;
      _message = null;
    });
    try {
      await widget.service.activateMovie(movie.id);
      if (!mounted) return;
      showTopNotice(Overlay.of(context, rootOverlay: true), 'Movie activated.');
      await _load();
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: 'Manage movies',
    selectedIndex: 2,
    child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: centeredPadding(
          context,
          AppSpacing.lg,
        ).copyWith(bottom: 112 + MediaQuery.viewPaddingOf(context).bottom),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          AppButton(
            label: 'Create movie',
            onPressed: _loading || _updating ? null : () => _edit(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: 'Search movies',
                  controller: _search,
                  enabled: !_loading && !_updating,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              IconButton(
                tooltip: 'Search movies',
                icon: const Icon(Icons.search_rounded),
                onPressed: _loading || _updating
                    ? null
                    : () {
                        _page = 1;
                        _load();
                      },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Inactive movies remain here for administration and are hidden from customer listings.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (_message != null)
            ErrorState(
              title: 'Unable to complete request',
              message: _message!,
              onRetry: _load,
            ),
          if (_loading)
            const LoadingState(message: 'Loading movies...')
          else if (_result != null) ...[
            if (_result!.items.isEmpty)
              const Text('No movies found.', style: AppTextStyles.body),
            for (final movie in _result!.items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CinemaPanel(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movie.title, style: AppTextStyles.title),
                            Text(
                              '${movie.durationText} · ${movie.status}',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit ${movie.title}',
                        onPressed: _updating ? null : () => _edit(movie),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: movie.status == 'INACTIVE'
                            ? 'Activate ${movie.title}'
                            : 'Delete ${movie.title}',
                        onPressed: _updating
                            ? null
                            : () => movie.status == 'INACTIVE'
                                  ? _activate(movie)
                                  : _delete(movie),
                        icon: Icon(
                          movie.status == 'INACTIVE'
                              ? Icons.play_circle_outline
                              : Icons.delete_outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _updating || _page <= 1
                      ? null
                      : () {
                          _page--;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  'Page $_page of ${_result!.totalPages == 0 ? 1 : _result!.totalPages}',
                  style: AppTextStyles.bodySmall,
                ),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _updating || _page >= _result!.totalPages
                      ? null
                      : () {
                          _page++;
                          _load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class AdminMovieEditorScreen extends StatefulWidget {
  const AdminMovieEditorScreen({
    required this.service,
    this.movieId,
    super.key,
  });
  final MovieService service;
  final int? movieId;
  @override
  State<AdminMovieEditorScreen> createState() => _AdminMovieEditorScreenState();
}

class _AdminMovieEditorScreenState extends State<AdminMovieEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _fields = {
    for (final name in [
      'title',
      'description',
      'durationMinutes',
      'genre',
      'language',
      'posterUrl',
      'trailerUrl',
    ])
      name: TextEditingController(),
  };
  DateTime _releaseDate = DateUtils.dateOnly(DateTime.now());
  bool _loading = false;
  bool _saving = false;
  bool _loaded = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fields['durationMinutes']!.text = '60';
    _loaded = widget.movieId == null;
    if (widget.movieId != null) _load();
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final movie = await widget.service.getMovie(widget.movieId!);
      if (!mounted) return;
      final values = {
        'title': movie.title,
        'description': movie.description,
        'durationMinutes': '${movie.durationMinutes}',
        'genre': movie.genre,
        'language': movie.language,
        'posterUrl': movie.posterUrl,
        'trailerUrl': movie.trailerUrl,
      };
      for (final entry in values.entries) {
        _fields[entry.key]!.text = entry.value;
      }
      setState(() {
        _releaseDate = movie.releaseDate ?? _releaseDate;
        _loaded = true;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_loaded || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _message = null;
    });
    final body = <String, Object?>{
      for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      'releaseDate': _releaseDate.toIso8601String(),
    };
    body['durationMinutes'] = int.parse(
      _fields['durationMinutes']!.text.trim(),
    );
    try {
      if (widget.movieId == null) {
        await widget.service.createMovie(body);
      } else {
        await widget.service.updateMovie(widget.movieId!, body);
      }
      if (!mounted) return;
      showTopNotice(
        Overlay.of(context, rootOverlay: true),
        widget.movieId == null ? 'Movie created.' : 'Movie updated.',
      );
      Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AdminPage(
    title: widget.movieId == null ? 'Create movie' : 'Edit movie',
    selectedIndex: 2,
    child: _loading
        ? const LoadingState(message: 'Loading movie...')
        : ListView(
            padding: centeredPadding(
              context,
              AppSpacing.lg,
            ).copyWith(bottom: 112 + MediaQuery.viewPaddingOf(context).bottom),
            children: [
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (name, label) in [
                      ('title', 'Title'),
                      ('description', 'Description'),
                      ('durationMinutes', 'Duration (minutes)'),
                      ('genre', 'Genre'),
                      ('language', 'Language'),
                      ('posterUrl', 'Poster URL'),
                      ('trailerUrl', 'Trailer URL'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppTextField(
                          key: Key('movie_$name'),
                          label: label,
                          controller: _fields[name],
                          enabled: !_saving,
                          maxLines: name == 'description' ? 4 : 1,
                          keyboardType: name == 'durationMinutes'
                              ? TextInputType.number
                              : name.endsWith('Url')
                              ? TextInputType.url
                              : TextInputType.text,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (name == 'title' && text.isEmpty) {
                              return 'Enter a movie title.';
                            }
                            if (name == 'durationMinutes' &&
                                ((int.tryParse(text) ?? 0) < 1 ||
                                    (int.tryParse(text) ?? 0) > 2147483647)) {
                              return 'Enter a positive duration in minutes.';
                            }
                            if (name.endsWith('Url') && text.isNotEmpty) {
                              final uri = Uri.tryParse(text);
                              if (uri == null ||
                                  !['http', 'https'].contains(uri.scheme) ||
                                  uri.host.isEmpty) {
                                return 'Enter an HTTP or HTTPS URL.';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                    AppButton.secondary(
                      label:
                          'Release date: ${_releaseDate.toIso8601String().split('T').first}',
                      onPressed: _saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _releaseDate,
                                firstDate: DateTime(1),
                                lastDate: DateTime(9999, 12, 31),
                              );
                              if (date != null && mounted) {
                                setState(() => _releaseDate = date);
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (_message != null)
                      ErrorState(
                        title: 'Unable to save movie',
                        message: _message!,
                        onRetry: widget.movieId == null ? null : _load,
                      ),
                    AppButton(
                      label: 'Save movie',
                      isLoading: _saving,
                      onPressed: _saving || !_loaded ? null : _save,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.secondary(
                      label: 'Cancel',
                      onPressed: _saving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
  );
}
