import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

class PaymentResultScreen extends StatelessWidget {
  const PaymentResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment Result')),
      body: const Center(
        child: Text('Payment Result', style: AppTextStyles.heading1),
      ),
    );
  }
}
