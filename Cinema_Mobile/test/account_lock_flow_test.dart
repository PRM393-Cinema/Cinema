import 'dart:async';
import 'dart:convert';

import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/repositories/auth_repository.dart';
import 'package:cinema_fe/data/services/auth_service.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/data/storage/auth_token_storage.dart';
import 'package:cinema_fe/data/storage/token_manager.dart';
import 'package:cinema_fe/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fixtures.dart';
import 'support/test_app.dart';

const lockedMessage = 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.';
const roleMessage = 'Vai trò tài khoản đã thay đổi. Vui lòng đăng nhập lại.';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final (errorCode, message) in [
    ('ACCOUNT_LOCKED', lockedMessage),
    (null, lockedMessage),
    ('ROLE_CHANGED', roleMessage),
  ]) {
    testWidgets('Account change opens login ($errorCode)', (tester) async {
      final session = SessionState();
      final storage = SecureAuthTokenStorage();
      await storage.save(authResponseFixture);
      final respond = Completer<void>();
      final manager = TokenManager(
        storage: storage,
        refreshSession: (_) async => throw StateError('Must not refresh'),
        onSessionExpired: (message) => session.clear(message: message),
      );
      final client = ApiClient(
        tokenProvider: manager,
        httpClient: MockClient((request) async {
          await respond.future;
          return _json(403, {'detail': message, 'errorCode': ?errorCode});
        }),
      );
      final staffUser = AuthUser.fromJson({
        ...customerUser.toJson(),
        'roles': ['ROLE_STAFF'],
      });
      await tester.pumpWidget(
        buildTestApp(
          session: session,
          authenticated: true,
          user: staffUser,
          staffService: StaffService(client: client),
          initialRoute: AppRoutes.staffDashboard,
        ),
      );
      await tester.pump();
      expect(find.text('Staff dashboard'), findsOneWidget);

      respond.complete();
      await pumpRoute(tester);

      expect(session.isAuthenticated, isFalse);
      expect(session.user, isNull);
      expect(await storage.readAccessToken(), isNull);
      expect(await storage.readRefreshToken(), isNull);
      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      final notice = find.byKey(const Key('topNotice'));
      expect(notice, findsOneWidget);
      expect(tester.getTopLeft(notice).dy, lessThan(100));
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Staff dashboard'), findsNothing);
      expect(find.text('Unable to load dashboard'), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final status in [401, 403]) {
    testWidgets('Locked login shows the account notice (HTTP $status)', (
      tester,
    ) async {
      final storage = SecureAuthTokenStorage();
      final session = SessionState();
      final client = ApiClient(
        httpClient: MockClient(
          (_) async => _json(status, {
            'detail': status == 401
                ? 'Tài khoản đã bị vô hiệu hóa.'
                : lockedMessage,
            if (status == 403) 'errorCode': 'ACCOUNT_LOCKED',
          }),
        ),
      );
      await tester.pumpWidget(
        buildTestApp(
          session: session,
          authRepository: RemoteAuthRepository(
            service: AuthService(client: client),
            storage: storage,
          ),
          initialRoute: AppRoutes.login,
        ),
      );
      await pumpRoute(tester);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('loginEmailField')),
          matching: find.byType(EditableText),
        ),
        customerUser.email,
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('loginPasswordField')),
          matching: find.byType(EditableText),
        ),
        'Secret@123',
      );
      await tester.ensureVisible(find.byType(AppButton).first);
      await tester.tap(find.byType(AppButton).first);
      await pumpRoute(tester);

      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
      expect(find.text(lockedMessage), findsOneWidget);
      expect(find.byKey(const Key('topNotice')), findsOneWidget);
      expect(find.text('Invalid email or password.'), findsNothing);
      expect(
        find.text('Please verify your email before signing in.'),
        findsNothing,
      );
      expect(session.isAuthenticated, isFalse);
      expect(await storage.readAccessToken(), isNull);
    });
  }

  for (final (role, dashboard) in [
    ('ROLE_STAFF', 'Staff dashboard'),
    ('ROLE_ADMIN', 'Dashboard'),
  ]) {
    testWidgets(
      'Changed customer role opens $dashboard after signing in again',
      (tester) async {
        final session = SessionState();
        final storage = SecureAuthTokenStorage();
        await storage.save(authResponseFixture);
        final newUser = AuthUser.fromJson({
          ...customerUser.toJson(),
          'roles': [role],
        });
        var mustSignIn = true;
        late final AuthService authService;
        final manager = TokenManager(
          storage: storage,
          refreshSession: (token) => authService.refresh(token),
          onSessionExpired: (message) => session.clear(message: message),
        );
        final client = ApiClient(
          tokenProvider: manager,
          httpClient: MockClient((request) async {
            if (request.url.path == '/api/v1/auth/login') {
              mustSignIn = false;
              return _json(200, {
                'accessToken': 'new-role-token',
                'refreshToken': 'new-refresh-token',
                'tokenType': 'Bearer',
                'expiresAt': DateTime.now()
                    .add(const Duration(hours: 1))
                    .toIso8601String(),
                'user': newUser.toJson(),
              });
            }
            if (mustSignIn) {
              return _json(403, {
                'errorCode': 'ROLE_CHANGED',
                'detail': roleMessage,
              });
            }
            if (request.url.path == '/api/v1/auth/me') {
              return _json(200, newUser.toJson());
            }
            return _json(200, {
              'items': [],
              'totalCount': 0,
              'pageNumber': 1,
              'pageSize': 10,
              'totalPages': 0,
            });
          }),
        );
        authService = AuthService(client: client);
        await tester.pumpWidget(
          buildTestApp(
            session: session,
            authenticated: true,
            user: customerUser,
            authRepository: RemoteAuthRepository(
              service: authService,
              storage: storage,
            ),
            staffService: StaffService(client: client),
            initialRoute: AppRoutes.profile,
          ),
        );
        await pumpRoute(tester);
        expect(session.isAuthenticated, isFalse);
        expect(find.text(roleMessage), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('loginEmailField')),
            matching: find.byType(EditableText),
          ),
          customerUser.email,
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('loginPasswordField')),
            matching: find.byType(EditableText),
          ),
          'Secret@123',
        );
        await tester.ensureVisible(find.byType(AppButton).first);
        await tester.tap(find.byType(AppButton).first);
        await pumpRoute(tester);

        expect(session.isAuthenticated, isTrue);
        expect(session.user?.roles, [role]);
        expect(find.text(dashboard), findsWidgets);
        expect(find.byKey(const Key('loginTitle')), findsNothing);
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.text('Đăng nhập thành công.'),
          role == 'ROLE_ADMIN' ? findsOneWidget : findsNothing,
        );
      },
    );
  }
}

http.Response _json(int status, Object body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
