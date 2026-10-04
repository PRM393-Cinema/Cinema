import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/routes/app_routes.dart';
import 'core/session/session_state.dart';
import 'data/storage/auth_token_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final sessionState = SessionState();
  final tokenStorage = SecureAuthTokenStorage();
  
  final expiresAt = await tokenStorage.readExpiresAt();
  if (expiresAt != null && expiresAt.isAfter(DateTime.now())) {
    sessionState.setAuthenticated();
  }

  runApp(
    SessionProvider(
      sessionState: sessionState,
      child: CinemaApp(
        initialRoute: sessionState.isAuthenticated ? AppRoutes.home : AppRoutes.welcome,
      ),
    ),
  );
}
