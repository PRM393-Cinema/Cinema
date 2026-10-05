import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class NotificationDetailScreen extends StatelessWidget {
  const NotificationDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification Detail')),
      body: const Center(
        child: Text('Notification Detail', style: AppTextStyles.heading1),
      ),
    );
  }
}
