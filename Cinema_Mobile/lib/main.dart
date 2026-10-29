import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_dependencies.dart';
import 'core/session/session_state.dart';
import 'data/models/auth_response.dart';
import 'features/payment/payment_args.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionState = SessionState();
  final dependencies = AppDependencies.remote(session: sessionState);

  AuthUser? user;
  try {
    user = await dependencies.authRepository.restoreSession();
  } on Object {
    // Unreadable secure storage: start signed out.
    user = null;
  }
  if (user != null) {
    sessionState.setAuthenticated(user);
  }

  runApp(
    SessionProvider(
      sessionState: sessionState,
      child: CinemaApp(
        authRepository: dependencies.authRepository,
        catalogRepository: dependencies.catalogRepository,
        bookingRepository: dependencies.bookingRepository,
        staffService: dependencies.staffService,
        // On web PayOS redirects back to the app with the order in the URL.
        paymentReturn: kIsWeb ? PayOsReturn.fromUri(Uri.base) : null,
      ),
    ),
  );
}
