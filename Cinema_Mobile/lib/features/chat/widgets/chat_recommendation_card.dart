import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/widgets/app_network_image.dart';

typedef ChatRecommendation = ({
  String title,
  String imageUrl,
  String price,
  String description,
});

class ChatRecommendationCard extends StatelessWidget {
  const ChatRecommendationCard({
    required this.details,
    required this.movie,
    required this.onOpen,
    super.key,
  });

  final Future<ChatRecommendation?> details;
  final bool movie;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<ChatRecommendation?>(
    future: details,
    builder: (context, snapshot) {
      final item = snapshot.data;
      if (item == null) return const SizedBox.shrink();
      final colors = AppPalette.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (movie || item.imageUrl.isNotEmpty)
                  ExcludeSemantics(
                    child: AppNetworkImage(
                      imageUrl: item.imageUrl,
                      width: 56,
                      height: movie ? 80 : 56,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                else
                  SizedBox.square(
                    dimension: 56,
                    child: Icon(Icons.fastfood_outlined, color: colors.primary),
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (item.price.isNotEmpty)
                        Text(
                          item.price,
                          style: TextStyle(color: colors.primary),
                        ),
                      if (item.description.isNotEmpty)
                        Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        onPressed: onOpen,
                        child: Text(movie ? 'Xem lịch chiếu' : 'Xem combo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
