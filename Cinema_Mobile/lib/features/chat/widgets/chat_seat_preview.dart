import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../data/models/seat.dart';
import '../../../data/models/showtime.dart';
import '../../seat/widgets/customer_seat_map.dart';

typedef ChatSeatPreviewData = ({Showtime showtime, ShowtimeSeatsData map});

class ChatSeatPreview extends StatelessWidget {
  const ChatSeatPreview({
    required this.details,
    required this.onOpen,
    super.key,
  });

  final Future<ChatSeatPreviewData>? details;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => FutureBuilder<ChatSeatPreviewData>(
    future: details,
    builder: (context, snapshot) {
      final colors = AppPalette.of(context);
      final preview = snapshot.data;
      final label = details == null
          ? 'Đăng nhập để xem sơ đồ ghế'
          : 'Mở sơ đồ ghế';
      final loading = snapshot.connectionState == ConnectionState.waiting;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: colors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: MergeSemantics(
            child: Semantics(
              button: true,
              label: preview == null
                  ? null
                  : '${preview.map.seats.length} ghế, phòng ${preview.showtime.roomId}',
              child: InkWell(
                onTap: onOpen,
                child: Column(
                  children: [
                    if (loading ||
                        (preview != null && preview.map.seats.isNotEmpty))
                      SizedBox(
                        height: 184,
                        width: double.infinity,
                        child: loading
                            ? const Center(child: CircularProgressIndicator())
                            : ExcludeSemantics(
                                child: CustomerSeatMap(
                                  data: preview!.map,
                                  showtime: preview.showtime,
                                  selectedSeatIds: const {},
                                  compact: true,
                                  preview: true,
                                ),
                              ),
                      ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(label)),
                            Icon(Icons.chevron_right, color: colors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
