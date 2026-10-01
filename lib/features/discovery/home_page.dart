import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/cinema_api.dart';
import '../../shared/widgets.dart';
import 'movie_detail_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.onAuthenticate,
    required this.onBookingCreated,
  });
  final CinemaApi api;
  final Future<Map<String, dynamic>?> Function() onAuthenticate;
  final VoidCallback onBookingCreated;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _search = TextEditingController();
  List<Movie> _movies = [];
  bool _loading = true;
  String? _error;

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

  Future<void> _load({String? keyword}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final movies = await widget.api.movies(keyword: keyword);
      if (mounted)
        setState(
          () => _movies = movies
              .where(
                (m) => m.status.isEmpty || m.status.toUpperCase() == 'ACTIVE',
              )
              .toList(),
        );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openMovie(Movie movie) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => MovieDetailPage(
        api: widget.api,
        movie: movie,
        onAuthenticate: widget.onAuthenticate,
        onBookingCreated: widget.onBookingCreated,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final featured = _movies.isEmpty ? null : _movies.first;
    final rest = featured == null ? <Movie>[] : _movies.skip(1).toList();
    return SafeArea(
      child: RefreshIndicator(
        color: CinemaColors.gold,
        onRefresh: () => _load(keyword: _search.text),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: _BrandHeader()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Tối nay,\nchọn phim hay.',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
              sliver: SliverToBoxAdapter(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => _load(keyword: value),
                  decoration: InputDecoration(
                    hintText: 'Tìm phim bạn muốn xem',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: CinemaColors.muted,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                      icon: const Icon(Icons.close, size: 20),
                    ),
                  ),
                ),
              ),
            ),
            if (_loading && _movies.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: CinemaColors.gold),
                ),
              )
            else if (_error != null && _movies.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageState(
                  title: 'Chưa tải được phim',
                  detail: _error!,
                  action: 'Thử lại',
                  onAction: () => _load(),
                ),
              )
            else if (_movies.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: MessageState(
                  title: 'Chưa có phim phù hợp',
                  detail: 'Thử tên phim khác hoặc xóa từ khóa tìm kiếm.',
                ),
              )
            else ...[
              if (featured != null)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _FeaturedMovie(
                      movie: featured,
                      onTap: () => _openMovie(featured),
                    ),
                  ),
                ),
              if (rest.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 0, 8),
                  sliver: SliverToBoxAdapter(
                    child: SectionHeading(
                      title: 'Đang chiếu',
                      subtitle: '${_movies.length} phim',
                    ),
                  ),
                ),
              if (rest.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 250,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: rest.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (_, index) => _MoviePoster(
                        movie: rest[index],
                        onTap: () => _openMovie(rest[index]),
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverToBoxAdapter(child: _CinemaNote()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeaturedMovie extends StatelessWidget {
  const _FeaturedMovie({required this.movie, required this.onTap});
  final Movie movie;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Xem phim ${movie.title}',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 208,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CinemaPoster(
                url: movie.posterUrl,
                width: double.infinity,
                height: 208,
                radius: 0,
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xE6000000)],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const StatusTag(
                      text: 'PHIM NỔI BẬT',
                      color: CinemaColors.gold,
                      dark: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (movie.genre.isNotEmpty)
                          Flexible(
                            child: Text(
                              movie.genre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _MoviePoster extends StatelessWidget {
  const _MoviePoster({required this.movie, required this.onTap});
  final Movie movie;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 132,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CinemaPoster(
            url: movie.posterUrl,
            width: 132,
            height: 178,
            radius: 14,
          ),
          const SizedBox(height: 9),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            movie.genre.isEmpty ? 'Đang chiếu' : movie.genre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const CinemaBrandMark(size: 38),
      const SizedBox(width: 10),
      Text(
        'CINÉ',
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(letterSpacing: 2.4, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _CinemaNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EDE5),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        const Icon(Icons.stars_outlined, color: CinemaColors.gold),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Chọn chỗ ngồi yêu thích trước khi suất chiếu kín chỗ.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: CinemaColors.ink),
          ),
        ),
      ],
    ),
  );
}
