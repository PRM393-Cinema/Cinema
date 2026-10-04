import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class NotificationListScreen extends StatelessWidget {
  const NotificationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: Text('Notifications', style: AppTextStyles.heading1),
      ),
    );
  }
}
