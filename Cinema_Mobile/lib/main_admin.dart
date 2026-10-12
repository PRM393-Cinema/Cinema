import 'package:flutter/material.dart';

import 'admin/admin_app.dart';
import 'app/app_dependencies.dart';
import 'core/session/session_state.dart';
import 'data/models/auth_response.dart';

// Admin website: flutter run -d chrome -t lib/main_admin.dart
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
      child: AdminApp(
        authRepository: dependencies.authRepository,
        catalogRepository: dependencies.catalogRepository,
        staffService: dependencies.staffService,
      ),
    ),
  );
}
