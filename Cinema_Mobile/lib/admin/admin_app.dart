import 'package:flutter/material.dart';

import '../app/session_app.dart';
import '../core/session/session_state.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/staff_service.dart';
import 'admin_router.dart';

// Admin website for staff and admins, built for a computer screen and served
// from /admin/ next to the customer site.
class AdminApp extends StatelessWidget {
  const AdminApp({
    required this.authRepository,
    required this.catalogRepository,
    required this.staffService,
    this.initialRoute,
    super.key,
  });

  final AuthRepository authRepository;
  final CatalogRepository catalogRepository;
  final StaffService staffService;
  final String? initialRoute;

  @override
  Widget build(BuildContext context) {
    final router = AdminRouter(
      authRepository: authRepository,
      catalogRepository: catalogRepository,
      staffService: staffService,
      session: SessionProvider.of(context),
    );

    return SessionApp(
      title: 'CosmoQ Admin',
      initialRoute: initialRoute,
      onGenerateRoute: router.onGenerateRoute,
      onGenerateInitialRoutes: router.onGenerateInitialRoutes,
    );
  }
}
