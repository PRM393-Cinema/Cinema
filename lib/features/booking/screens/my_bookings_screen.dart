import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: const Center(
        child: Text('My Bookings', style: AppTextStyles.heading1),
      ),
    );
  }
}
