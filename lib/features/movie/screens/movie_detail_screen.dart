import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/movie.dart';

class MovieDetailScreen extends StatelessWidget {
  const MovieDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Movie) {
      return Scaffold(
        appBar: AppBar(title: const Text('Movie Detail')),
        body: const ErrorState(
          title: 'Movie not found',
          message: 'Please return home and select a movie again.',
        ),
      );
    }

    final movie = args;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: isWide ? 320 : 200,
                  pinned: true,
                  title: Text(movie.title),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(imageUrl: movie.posterUrl),
                        const DecoratedBox(
                          decoration: BoxDecoration(color: Color(0xDD0B0D12)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: Padding(
                        padding: EdgeInsets.all(
                          isWide ? AppSpacing.xxl : AppSpacing.lg,
                        ),
                        child: _MovieDetailContent(
                          movie: movie,
                          isWide: isWide,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      // Always reachable, so the poster and synopsis never push it off screen.
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: AppButton(
            label: 'Select Showtime',
            leadingIcon: Icons.event_seat_outlined,
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.showtime,
              arguments: movie,
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieDetailContent extends StatelessWidget {
  const _MovieDetailContent({required this.movie, required this.isWide});

  final Movie movie;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Poster beside the facts keeps the title and details on the first
        // screen of a phone.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(
              imageUrl: movie.posterUrl,
              width: isWide ? 220 : 116,
              height: isWide ? 330 : 174,
              borderRadius: AppRadius.borderRadiusLg,
            ),
            SizedBox(width: isWide ? AppSpacing.xxl : AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.title,
                    style: isWide
                        ? AppTextStyles.display
                        : AppTextStyles.heading2,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      if (movie.releaseYear.isNotEmpty)
                        _InfoPill(label: movie.releaseYear),
                      _InfoPill(label: movie.durationText),
                      if (movie.language.isNotEmpty)
                        _InfoPill(label: movie.language),
                    ],
                  ),
                  if (movie.genre.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(movie.genre, style: AppTextStyles.title),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (movie.description.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          const Text('Synopsis', style: AppTextStyles.caption),
          const SizedBox(height: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(movie.description, style: AppTextStyles.body),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.borderRadiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Text(label, style: AppTextStyles.caption),
      ),
    );
  }
}
