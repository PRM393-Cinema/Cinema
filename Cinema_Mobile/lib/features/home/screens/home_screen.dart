import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/theme_switch.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/cinema_background.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/cinema_account_widgets.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/paginated_cards.dart';
import '../../../core/widgets/scroll_reveal.dart';
import '../../../data/models/movie.dart';
import '../../../data/repositories/catalog_repository.dart';
import '../../movie/widgets/movie_preview_card.dart';
import '../../../core/session/session_state.dart';
import '../../../core/widgets/age_rating_badge.dart';
import '../../../data/repositories/booking_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.catalogRepository,
    this.bookingRepository,
    super.key,
  });

  final CatalogRepository catalogRepository;

  // Signed in: loads how many notifications are unread for the bell.
  final BookingRepository? bookingRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Searching waits until the customer stops typing.
  static const searchDelay = Duration(milliseconds: 350);

  final _glassBackgroundKey = GlobalKey();
  String _query = '';
  bool _comingSoon = false;
  String? _genre;
  List<String> _genres = const [];
  List<Movie> _movies = const [];
  bool _isLoading = true;
  bool _hasLoaded = false;
  String? _errorMessage;
  Timer? _searchTimer;

  // Only the newest answer counts when filters change quickly.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _loadMovies();
    _loadGenres();
  }

  bool _countedUnread = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_countedUnread) return;
    _countedUnread = true;
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final session = SessionProvider.of(context);
    final bookings = widget.bookingRepository;
    if (bookings == null || !session.isAuthenticated) return;
    try {
      session.setUnreadNotifications(
        await bookings.getUnreadNotificationCount(),
      );
    } on Object {
      // The bell works without the badge.
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await widget.catalogRepository.getGenres();
      if (mounted) setState(() => _genres = genres);
    } on Object {
      // The movies still show without the genre filter.
    }
  }

  Future<void> _loadMovies() async {
    final request = ++_request;
    setState(() {
      _isLoading = !_hasLoaded;
      _errorMessage = null;
    });

    try {
      final query = _query.trim();
      final movies = await widget.catalogRepository.browseMovies(
        comingSoon: _comingSoon,
        genre: _genre,
        keyword: query.isEmpty ? null : query,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _movies = movies;
        _isLoading = false;
        _hasLoaded = true;
      });
    } on ApiException catch (error) {
      _showError(request, error.message);
    } on FormatException {
      _showError(request, 'The server returned an invalid response.');
    } on Object {
      _showError(request, 'Something went wrong. Please try again.');
    }
  }

  void _showError(int request, String message) {
    if (!mounted || request != _request) return;
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
  }

  void _search(String value) {
    _query = value;
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, _loadMovies);
  }

  void _showTab(bool comingSoon) {
    if (comingSoon == _comingSoon) return;
    setState(() => _comingSoon = comingSoon);
    _loadMovies();
  }

  void _filterGenre(String? genre) {
    if (genre == _genre) return;
    setState(() => _genre = genre);
    _loadMovies();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMovies = _movies;
    // The big banner shows the newest movie when nothing is filtered.
    final featuredMovie =
        !_comingSoon &&
            _genre == null &&
            _query.trim().isEmpty &&
            visibleMovies.isNotEmpty
        ? visibleMovies.first
        : null;
    final session = SessionProvider.of(context);

    final desktop = isDesktopLayout(context);

    return Scaffold(
      extendBody: true,
      // The website shows its own navigation bar at the top.
      appBar: desktop
          ? null
          : AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'COSMO',
                      style: TextStyle(color: AppPalette.of(context).primary),
                    ),
                    TextSpan(text: 'Q'),
                  ],
                ),
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  shadows: AppPalette.of(context).isLight
                      ? null
                      : [
                          Shadow(
                            color: AppPalette.of(context).primary
                                .withValues(alpha: 0.55),
                            blurRadius: 10,
                          ),
                        ],
                ),
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
              actions: session.isAuthenticated
                  ? [
                      const ThemeSwitch(),
                      IconButton(
                        tooltip: 'My bookings',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.myBookings),
                        icon: const Icon(Icons.confirmation_number_outlined),
                      ),
                      IconButton(
                        key: const Key('myRatings'),
                        tooltip: 'My ratings',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.myRatings),
                        icon: const Icon(Icons.star_outline_rounded),
                      ),
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notifications,
                        ),
                        icon: Badge(
                          key: const Key('unreadBadge'),
                          isLabelVisible: session.unreadNotifications > 0,
                          label: Text('${session.unreadNotifications}'),
                          child: const Icon(Icons.notifications_none_outlined),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Profile',
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.profile),
                        icon: const Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ]
                  : [
                      const ThemeSwitch(),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.login),
                        style: TextButton.styleFrom(
                          foregroundColor: AppPalette.of(context).textPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                          ),
                        ),
                        child: const Text(
                          'Sign in',
                          style: AppTextStyles.button,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
            ),
      body: CinemaGlassBackground(
        key: _glassBackgroundKey,
        child: CinemaBackground(
          child: SafeArea(
            bottom: false,
            child: _buildBody(featuredMovie, visibleMovies),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('openCinemaChat'),
        tooltip: 'Ask Cinema AI',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.chat),
        backgroundColor: AppPalette.of(context).primary,
        foregroundColor: AppPalette.of(context).onPrimary,
        elevation: 2,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text('Cinema AI'),
      ),
      bottomNavigationBar: desktop
          ? null
          : CinemaNavigationBar(
              selectedIndex: 0,
              backgroundKey: _glassBackgroundKey,
            ),
    );
  }

  Widget _buildBody(Movie? featuredMovie, List<Movie> visibleMovies) {
    if (_isLoading) {
      return const LoadingState(message: 'Loading movies...');
    }

    if (_errorMessage != null && !_hasLoaded) {
      return ErrorState(
        title: 'Unable to load movies',
        message: _errorMessage!,
        onRetry: _loadMovies,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMovies,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return ListView(
            key: const Key('homeScrollView'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                centeredPadding(
                  context,
                  AppSpacing.lg,
                  maxWidth: pageMaxWidth,
                ).copyWith(
                  top: isWide
                      ? webHeaderHeight + AppSpacing.xxl
                      : AppSpacing.lg,
                  bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
                ),
            children: [
              if (!isWide) ...[
                _HomeHeader(isWide: isWide),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (isWide)
                const Text(
                  'Your next cinema night',
                  style: AppTextStyles.heading1,
                )
              else
                AppTextField(
                  key: const Key('movieSearchField'),
                  label: 'Search movies',
                  hint: 'Search by title',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: _search,
                ),
              const SizedBox(height: AppSpacing.xxl),
              if (featuredMovie != null && isWide) ...[
                ScrollReveal(
                  child: _FeaturedCarousel(
                    movies: visibleMovies,
                    onOpen: _openMovie,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              ScrollReveal(
                key: const Key('homeFiltersReveal'),
                child: Wrap(
                  key: const Key('homeFilters'),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.md,
                  children: [
                    if (isWide)
                      SizedBox(
                        width:
                            constraints.maxWidth.clamp(
                              0,
                              pageMaxWidth + 2 * AppSpacing.lg,
                            ) -
                            2 * AppSpacing.lg -
                            220 -
                            (_genres.isNotEmpty ? 280 + AppSpacing.md : 0) -
                            AppSpacing.md,
                        child: AppTextField(
                          key: const Key('movieSearchField'),
                          label: 'Search movies',
                          hint: 'Search by title',
                          prefixIcon: const Icon(Icons.search),
                          onChanged: _search,
                        ),
                      ),
                    SizedBox(
                      width: constraints.maxWidth < 600
                          ? (constraints.maxWidth -
                                    2 * AppSpacing.lg -
                                    AppSpacing.md) /
                                2
                          : 220,
                      child: _HomeFilter<bool>(
                        key: const Key('showingFilter'),
                        label: 'Showing',
                        icon: Icons.movie_outlined,
                        value: _comingSoon,
                        options: const [
                          (false, 'Now showing'),
                          (true, 'Coming soon'),
                        ],
                        onSelected: _showTab,
                      ),
                    ),
                    if (_genres.isNotEmpty)
                      SizedBox(
                        width: constraints.maxWidth < 600
                            ? (constraints.maxWidth -
                                      2 * AppSpacing.lg -
                                      AppSpacing.md) /
                                  2
                            : 280,
                        child: _HomeFilter<String>(
                          key: const Key('genreFilter'),
                          label: 'Genre',
                          icon: Icons.filter_list_rounded,
                          value: _genre ?? '',
                          options: [
                            ('', 'All genres'),
                            for (final genre in _genres) (genre, genre),
                          ],
                          onSelected: (value) =>
                              _filterGenre(value.isEmpty ? null : value),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      _comingSoon ? 'Coming Soon' : 'Now Showing',
                      style: AppTextStyles.heading2,
                    ),
                  ),
                  if (isWide)
                    Text(
                      '${visibleMovies.length} films',
                      style: AppTextStyles.caption.copyWith(
                        color: AppPalette.of(context).textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_errorMessage != null)
                ErrorState(
                  title: 'Unable to load movies',
                  message: _errorMessage!,
                  onRetry: _loadMovies,
                )
              else if (visibleMovies.isEmpty)
                _genre == null && _query.trim().isEmpty
                    ? EmptyState(
                        icon: Icons.movie_outlined,
                        title: _comingSoon
                            ? 'Nothing announced yet'
                            : 'No movies showing',
                        message: 'Please check back later.',
                      )
                    : const EmptyState(
                        icon: Icons.search_off_outlined,
                        title: 'No movies found',
                        message: 'Try another title or genre.',
                      )
              else
                _MovieGrid(movies: visibleMovies, onMovieTap: _openMovie),
            ],
          );
        },
      ),
    );
  }

  void _openMovie(Movie movie) {
    Navigator.pushNamed(
      context,
      AppRoutes.movieDetail(movie.id),
      arguments: movie,
    );
  }
}

class _HomeFilter<T> extends StatelessWidget {
  const _HomeFilter({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onSelected,
    super.key,
  });
  final String label;
  final IconData icon;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final selectedLabel = options
          .firstWhere((option) => option.$1 == value)
          .$2;
      return Theme(
        data: Theme.of(context).copyWith(
          focusColor: AppPalette.of(context).primary.withValues(alpha: 0.1),
          hoverColor: AppPalette.of(context).primary.withValues(alpha: 0.06),
        ),
        child: PopupMenuButton<T>(
          tooltip: 'Filter by ${label.toLowerCase()}',
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          color: AppPalette.of(context).surfaceSoft,
          surfaceTintColor: Colors.transparent,
          constraints: BoxConstraints(
            minWidth: constraints.maxWidth,
            maxWidth: constraints.maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.45,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.borderRadiusMd,
            side: BorderSide(color: AppPalette.of(context).border),
          ),
          onSelected: onSelected,
          itemBuilder: (_) => [
            for (final (option, text) in options)
              PopupMenuItem<T>(
                value: option,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Semantics(
                  selected: option == value,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          text,
                          style: AppTextStyles.body.copyWith(
                            color: option == value
                                ? AppPalette.of(context).primary
                                : AppPalette.of(context).textPrimary,
                            fontWeight: option == value
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (option == value) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Icon(
                          Icons.check_rounded,
                          color: AppPalette.of(context).primary,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 32),
              prefixIcon: Icon(icon, size: 20),
              suffixIconConstraints: const BoxConstraints(minWidth: 28),
              suffixIcon: const Icon(Icons.expand_more_rounded, size: 20),
            ),
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body,
              semanticsLabel: '$label: $selectedLabel',
            ),
          ),
        ),
      );
    },
  );
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.isWide});
  final bool isWide;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(vertical: isWide ? 48 : 28),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppPalette.of(context).primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppPalette.of(context).primary.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            'Experience Premium Cinema',
            style: AppTextStyles.caption.copyWith(
              color: AppPalette.of(context).primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Step Into '),
              TextSpan(
                text: 'CosmoQ',
                style: TextStyle(
                  color: AppPalette.of(context).primary,
                  shadows: AppPalette.of(context).isLight
                      ? null
                      : [
                          Shadow(
                            color: AppPalette.of(context).primary
                                .withValues(alpha: 0.4),
                            blurRadius: 14,
                          ),
                        ],
                ),
              ),
              const TextSpan(text: ' Cinema'),
            ],
          ),
          style: AppTextStyles.heading1.copyWith(
            fontSize: isWide ? 42 : 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Discover the ultimate film screening technology. High-contrast projection, '
            'Dolby Atmos audio, and luxury reclining seats. Book your tickets below.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Container(
          width: 56,
          height: 2,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: AppPalette.of(context).isLight
                ? AppPalette.of(context).border
                : null,
            gradient: AppPalette.of(context).isLight
                ? null
                : LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppPalette.of(context).primary,
                      Colors.transparent,
                    ],
                  ),
            boxShadow: AppPalette.of(context).isLight
                ? null
                : [
                    BoxShadow(
                      color: AppPalette.of(context).primary
                          .withValues(alpha: 0.2),
                      blurRadius: 10,
                    ),
                  ],
          ),
        ),
      ],
    ),
  );
}

class _FeaturedCarousel extends StatefulWidget {
  const _FeaturedCarousel({required this.movies, required this.onOpen});
  final List<Movie> movies;
  final ValueChanged<Movie> onOpen;

  @override
  State<_FeaturedCarousel> createState() => _FeaturedCarouselState();
}

class _FeaturedCarouselState extends State<_FeaturedCarousel>
    with WidgetsBindingObserver {
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _focused = false;
  bool _dragging = false;
  bool _resumed = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.movies.length < 2 ||
        _focused ||
        _dragging ||
        !_resumed ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != false) _move(1);
      _schedule();
    });
  }

  void _move(int direction) {
    if (!_pages.hasClients) return;
    final next = (_index + direction) % widget.movies.length;
    if (MediaQuery.disableAnimationsOf(context) || (next - _index).abs() > 1) {
      _pages.jumpToPage(next);
    } else {
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _FeaturedCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.movies.length) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, _) {
      _focused = true;
      _schedule();
      return KeyEventResult.ignored;
    },
    onFocusChange: (value) {
      _focused = value;
      _schedule();
    },
    child: Listener(
      onPointerDown: (_) {
        _dragging = true;
        _schedule();
      },
      onPointerUp: (_) {
        _dragging = false;
        _focused = false;
        _schedule();
      },
      onPointerCancel: (_) {
        _dragging = false;
        _focused = false;
        _schedule();
      },
      child: SizedBox(
        key: const Key('featuredCarousel'),
        height: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 420 : 320,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: widget.movies.length,
              onPageChanged: (index) {
                setState(() => _index = index);
                _schedule();
              },
              itemBuilder: (_, index) => _FeaturedMovie(
                movie: widget.movies[index],
                isWide: true,
                onTap: () => widget.onOpen(widget.movies[index]),
              ),
            ),
            if (widget.movies.length > 1)
              for (final direction in [-1, 1])
                Align(
                  alignment: direction < 0
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: IconButton(
                      tooltip: direction < 0
                          ? 'Previous featured movie'
                          : 'Next featured movie',
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(
                          Size.square(48),
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              AppPalette.of(context).isLight &&
                                  direction > 0 &&
                                  states.any(
                                    (state) => const {
                                      WidgetState.hovered,
                                      WidgetState.focused,
                                      WidgetState.pressed,
                                    }.contains(state),
                                  )
                              ? Colors.black.withValues(alpha: 0.48)
                              : Colors.transparent,
                        ),
                        overlayColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.focused)
                              ? AppPalette.of(context).primary
                                    .withValues(alpha: 0.12)
                              : Colors.transparent,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) =>
                              (AppPalette.of(context).isLight && direction > 0
                                      ? Colors.white
                                      : AppPalette.of(context).textPrimary)
                                  .withValues(
                                    alpha:
                                        states.any(
                                          (state) => const {
                                            WidgetState.hovered,
                                            WidgetState.focused,
                                            WidgetState.pressed,
                                          }.contains(state),
                                        )
                                        ? 1
                                        : 0.25,
                                  ),
                        ),
                        animationDuration:
                            MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                      ),
                      onPressed: () => _move(direction),
                      icon: Icon(
                        direction < 0
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    ),
  );
}

class _FeaturedMovie extends StatelessWidget {
  const _FeaturedMovie({
    required this.movie,
    required this.isWide,
    required this.onTap,
  });

  final Movie movie;
  final bool isWide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return SizedBox(
        key: const Key('desktopFeaturedMovie'),
        child: SizedBox(
          height: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 420 : 320,
          child: Row(
            children: [
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 72,
                    vertical: AppSpacing.xl,
                  ),
                  child: SingleChildScrollView(
                    child: _FeaturedMovieContent(movie: movie, onTap: onTap),
                  ),
                ),
              ),
              Expanded(
                flex: 5,
                child: RepaintBoundary(
                  child: Stack(
                    key: const Key('featuredPoster'),
                    fit: StackFit.expand,
                    children: [
                      // Fade alpha instead of painting theme colors over the art.
                      for (final blurred in [true, false])
                        ShaderMask(
                          blendMode: BlendMode.dstIn,
                          shaderCallback: (bounds) => LinearGradient(
                            colors: const [
                              Colors.transparent,
                              Colors.transparent,
                              Colors.white,
                              Colors.white,
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: [
                              0,
                              0.02,
                              blurred ? 0.07 : 0.13,
                              blurred ? 0.93 : 0.91,
                              0.98,
                              1,
                            ],
                          ).createShader(bounds),
                          child: ShaderMask(
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: const [
                                Colors.transparent,
                                Colors.transparent,
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                                Colors.transparent,
                              ],
                              stops: [
                                0,
                                0.025,
                                blurred ? 0.06 : 0.10,
                                blurred ? 0.94 : 0.90,
                                0.975,
                                1,
                              ],
                            ).createShader(bounds),
                            child: Opacity(
                              opacity: blurred ? 0.35 : 1,
                              // Keep image pixels inside the mask at fractional DPR.
                              child: Padding(
                                padding: const EdgeInsets.all(2),
                                child: ClipRect(
                                  child: ImageFiltered(
                                    key: ValueKey(
                                      blurred
                                          ? 'featuredPosterBackdrop'
                                          : 'featuredPosterForeground',
                                    ),
                                    enabled: blurred,
                                    imageFilter: ui.ImageFilter.blur(
                                      sigmaX: 18,
                                      sigmaY: 18,
                                    ),
                                    child: AppNetworkImage(
                                      imageUrl: movie.posterUrl,
                                      webHtmlElementStrategy:
                                          WebHtmlElementStrategy.never,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: AppRadius.borderRadiusLg,
        child: SizedBox(
          height: isWide ? 480 : 520,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(imageUrl: movie.posterUrl),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppPalette.of(context).background.withValues(alpha: 0.6),
                      AppPalette.of(context).background,
                    ],
                    stops: const [0.4, 0.8, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: AppSpacing.xl,
                right: AppSpacing.xl,
                bottom: AppSpacing.xl,
                child: _FeaturedMovieContent(movie: movie, onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedMovieContent extends StatelessWidget {
  const _FeaturedMovieContent({required this.movie, required this.onTap});

  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.of(context).primary
                .withValues(alpha: AppPalette.of(context).isLight ? 0.08 : 0.2),
            borderRadius: AppRadius.borderRadiusSm,
            border: Border.all(
              color: AppPalette.of(context).primary.withValues(
                alpha: AppPalette.of(context).isLight ? 0.2 : 0.5,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Text(
              'FEATURED',
              style: AppTextStyles.caption.copyWith(
                color: AppPalette.of(context).primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          movie.title,
          style: AppTextStyles.display.copyWith(
            color: AppPalette.of(context).textPrimary,
            fontSize: 38,
            height: 1.15,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            AgeRatingBadge(rating: movie.ageRating),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                '${movie.genre} • ${movie.durationText}',
                style: AppTextStyles.body.copyWith(
                  color: AppPalette.of(context).textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (isDesktopLayout(context)) ...[
          Text(
            movie.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              height: 1.5,
              color: AppPalette.of(context).isLight
                  ? AppPalette.of(context).textSecondary
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktopLayout(context) ? 380 : double.infinity,
          ),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Book Now',
                  onPressed: onTap, // Tap the same route
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton.secondary(
                  label: 'View Details',
                  onPressed: onTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieGrid extends StatefulWidget {
  const _MovieGrid({required this.movies, required this.onMovieTap});

  final List<Movie> movies;
  final ValueChanged<Movie> onMovieTap;

  @override
  State<_MovieGrid> createState() => _MovieGridState();
}

class _MovieGridState extends State<_MovieGrid> with WidgetsBindingObserver {
  final _active = ValueNotifier<int?>(null);
  ScrollPosition? _scroll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scroll) {
      _scroll?.removeListener(_onScroll);
      _scroll = position;
      _scroll?.addListener(_onScroll);
    }
  }

  @override
  void didUpdateWidget(covariant _MovieGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    _active.value = null;
  }

  void _onScroll() {
    _active.value = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _active.value = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scroll?.removeListener(_onScroll);
    _active.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedCards(
      itemCount: widget.movies.length,
      mobileColumns: 2,
      resetKey: Object.hashAll(widget.movies.map((movie) => movie.id)),
      itemBuilder: (context, index) {
        final movie = widget.movies[index];
        return SizedBox(
          height: 340,
          child: MoviePreviewCard(
            key: ValueKey(movie.id),
            movie: movie,
            active: _active,
            onOpen: () => widget.onMovieTap(movie),
          ),
        );
      },
    );
  }
}
