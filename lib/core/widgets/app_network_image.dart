import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl.isEmpty
        ? _ImageFallback(width: width, height: height)
        : Image.network(
            imageUrl,
            width: width,
            height: height,
            fit: fit,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return _ImageLoading(width: width, height: height);
            },
            errorBuilder: (_, _, _) =>
                _ImageFallback(width: width, height: height),
          );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

class _ImageLoading extends StatelessWidget {
  const _ImageLoading({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceSoft,
      alignment: Alignment.center,
      child: const SizedBox.square(
        dimension: AppSpacing.xl,
        child: CircularProgressIndicator(strokeWidth: AppSpacing.xs),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, color: AppColors.textSecondary),
    );
  }
}
