import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/layout.dart';
import '../../../core/widgets/app_network_image.dart';
import '../../../core/widgets/cinema_page.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/concession.dart';
import '../../../data/repositories/booking_repository.dart';

class SnackDetailScreen extends StatefulWidget {
  const SnackDetailScreen({
    required this.repository,
    required this.itemId,
    super.key,
  });

  final BookingRepository repository;
  final int itemId;

  @override
  State<SnackDetailScreen> createState() => _SnackDetailScreenState();
}

class _SnackDetailScreenState extends State<SnackDetailScreen> {
  late var _menu = widget.repository.getConcessions();

  @override
  Widget build(BuildContext context) => CinemaPage(
    title: 'Bắp nước',
    child: FutureBuilder<List<ConcessionItem>>(
      future: _menu,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ErrorState(
            title: 'Không tải được menu',
            message: 'Vui lòng thử lại.',
            onRetry: () => setState(() {
              _menu = widget.repository.getConcessions();
            }),
          );
        }
        final item = snapshot.data
            ?.where((item) => item.id == widget.itemId && item.active)
            .firstOrNull;
        if (item == null) {
          return const Center(child: Text('Món này hiện không còn bán.'));
        }
        return ListView(
          padding: widthPadding(context, AppSpacing.lg, PageWidth.form),
          children: [
            if (item.imageUrl.isNotEmpty) ...[
              AppNetworkImage(imageUrl: item.imageUrl, height: 240),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.sm),
            Text(formatVnd(item.price)),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(item.description),
            ],
            const SizedBox(height: AppSpacing.lg),
            const Text('Bạn có thể thêm món này khi đặt vé.'),
          ],
        );
      },
    ),
  );
}
