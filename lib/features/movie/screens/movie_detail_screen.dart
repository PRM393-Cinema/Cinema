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
      appBar: AppBar(title: Text(movie.title)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Padding(
                    padding: EdgeInsets.all(
                      isWide ? AppSpacing.xxl : AppSpacing.lg,
                    ),
                    child: _MovieDetailContent(movie: movie, isWide: isWide),
                  ),
                ),
              ),
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
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
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
    final synopsis = movie.description.isEmpty
        ? null
        : _Synopsis(description: movie.description);

    // Poster beside the facts keeps the title and details on the first
    // screen. Wide screens also put the synopsis in that column.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                  _MovieFacts(movie: movie, isWide: isWide),
                  if (isWide && synopsis != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    synopsis,
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!isWide && synopsis != null) ...[
          const SizedBox(height: AppSpacing.xl),
          synopsis,
        ],
      ],
    );
  }
}

class _MovieFacts extends StatelessWidget {
  const _MovieFacts({required this.movie, required this.isWide});

  final Movie movie;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          movie.title,
          style: isWide ? AppTextStyles.display : AppTextStyles.heading2,
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (movie.releaseYear.isNotEmpty)
              _InfoPill(label: movie.releaseYear),
            _InfoPill(label: movie.durationText),
            if (movie.language.isNotEmpty) _InfoPill(label: movie.language),
          ],
        ),
        if (movie.genre.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(movie.genre, style: AppTextStyles.title),
        ],
      ],
    );
  }
}

class _Synopsis extends StatelessWidget {
  const _Synopsis({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Synopsis', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(description, style: AppTextStyles.body),
        ),
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
