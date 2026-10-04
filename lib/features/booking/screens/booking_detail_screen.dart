import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class BookingDetailScreen extends StatelessWidget {
  const BookingDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Detail')),
      body: const Center(
        child: Text('Booking Detail', style: AppTextStyles.heading1),
      ),
    );
  }
}
