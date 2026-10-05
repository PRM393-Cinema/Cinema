import 'package:flutter/material.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_text_styles.dart';

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Payment', style: AppTextStyles.heading1),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.paymentResult),
              child: const Text('View Payment Result'),
            ),
          ],
        ),
      ),
    );
  }
}
