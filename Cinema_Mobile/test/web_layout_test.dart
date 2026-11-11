import 'dart:convert';

import 'package:cinema_fe/app/customer_frame.dart';
import 'package:cinema_fe/app/routes/app_routes.dart';
import 'package:cinema_fe/app/theme/app_colors.dart';
import 'package:cinema_fe/core/utils/formatters.dart';
import 'package:cinema_fe/core/network/api_client.dart';
import 'package:cinema_fe/core/session/session_state.dart';
import 'package:cinema_fe/core/widgets/app_button.dart';
import 'package:cinema_fe/core/widgets/cinema_account_widgets.dart';
import 'package:cinema_fe/core/widgets/cinema_background.dart';
import 'package:cinema_fe/data/models/auth_response.dart';
import 'package:cinema_fe/data/models/booking.dart';
import 'package:cinema_fe/data/services/staff_service.dart';
import 'package:cinema_fe/features/admin/widgets/admin_catalog_layout.dart';
import 'package:cinema_fe/features/auth/screens/login_screen.dart';
import 'package:cinema_fe/features/booking/screens/my_bookings_screen.dart';
import 'package:cinema_fe/features/booking/screens/booking_detail_screen.dart';
import 'package:cinema_fe/features/notification/screens/notification_list_screen.dart';
import 'package:cinema_fe/features/review/screens/my_ratings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fakes.dart';
import 'support/fixtures.dart';
import 'support/test_app.dart';

const _computer = Size(1440, 900);
const _phone = Size(390, 844);

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

final _header = find.byKey(const Key('webHeader'));

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  for (final width in [375.0, 1440.0]) {
    testWidgets('Movie detail header follows mobile layout at $width', (
      tester,
    ) async {
      _useWindow(tester, Size(width, 900));
      await tester.pumpWidget(
        buildTestApp(initialRoute: AppRoutes.movieDetail(1)),
      );
      await pumpRoute(tester);
      expect(
        find.text('Movie Detail'),
        width >= 900 ? findsNothing : findsOneWidget,
      );
      expect(find.text('Inception'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('Customer website on a computer', () {
    testWidgets('Header builds before the navigator overlay is attached', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      final routes = RouteTracker()..current.value = AppRoutes.home;
      final session = SessionState()..setAuthenticated(customerUser);
      addTearDown(routes.current.dispose);
      addTearDown(session.dispose);
      await tester.pumpWidget(
        SessionProvider(
          sessionState: session,
          child: MaterialApp(
            home: CustomerFrame(
              routes: routes,
              onSignOut: () {},
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      expect(routes.navigator, isNull);
      expect(_header, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('webHeaderAccount')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home scrolls behind the floating navigation', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(buildTestApp(authenticated: true));
      await pumpRoute(tester);
      final header = tester.getRect(_header);
      final scroll = find.byKey(const Key('homeScrollView'));
      expect(tester.getRect(scroll).top, 0);
      expect(
        tester.getRect(find.text('Your next cinema night')).top,
        greaterThanOrEqualTo(header.bottom),
      );
      await tester.drag(scroll, const Offset(0, -200));
      await pumpRoute(tester);
      expect(tester.getRect(_header), header);
      expect(
        tester
            .getRect(find.byKey(const Key('desktopFeaturedMovie')))
            .overlaps(header),
        isTrue,
      );
      expect(
        find
            .descendant(of: _header, matching: find.text('Movies'))
            .hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in [960.0, 1440.0, 1920.0]) {
      testWidgets('Desktop home fits a compact hero and search at $width', (
        tester,
      ) async {
        _useWindow(tester, Size(width, 900));
        await tester.pumpWidget(buildTestApp());
        await pumpRoute(tester);
        final hero = find.byKey(const Key('desktopFeaturedMovie'));
        final search = find.byKey(const Key('movieSearchField'));
        expect(hero, findsOneWidget);
        expect(find.text('Experience Premium Cinema'), findsNothing);
        expect(tester.getRect(hero).bottom, lessThan(650));
        expect(
          tester.getSize(find.byKey(const Key('homeScrollView'))).width,
          width,
        );
        expect(
          tester.getRect(search).top,
          greaterThan(tester.getRect(hero).bottom),
        );
        expect(
          (tester.getRect(search).center.dy -
                  tester
                      .getRect(find.byKey(const Key('showingFilter')))
                      .center
                      .dy)
              .abs(),
          lessThan(2),
        );
        expect(
          find.byKey(const Key('showingFilter')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.enterText(
          find.descendant(of: search, matching: find.byType(TextField)),
          'missing-film',
        );
        await tester.pump(const Duration(milliseconds: 400));
        await pumpRoute(tester);
        expect(hero, findsNothing);
        expect(find.text('No movies found'), findsOneWidget);
        expect(
          tester
              .widget<TextField>(
                find.descendant(of: search, matching: find.byType(TextField)),
              )
              .controller!
              .text,
          'missing-film',
        );
      });
    }

    testWidgets('Navigation is at the top, without the tab bar', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [bookingFixture()],
          ),
        ),
      );
      await pumpRoute(tester);

      expect(_header, findsOneWidget);
      expect(tester.widget<Material>(_header).color, Colors.transparent);
      final navGroup = tester.widget<Container>(
        find.byKey(const Key('webHeaderNavGroup')),
      );
      expect(
        (navGroup.decoration! as BoxDecoration).color,
        isNot(Colors.transparent),
      );
      for (final label in [
        'Movies',
        'My tickets',
        'Ratings',
        'Notifications',
      ]) {
        final container = tester.widget<Container>(
          find
              .ancestor(
                of: find.descendant(of: _header, matching: find.text(label)),
                matching: find.byType(Container),
              )
              .first,
        );
        expect(
          (container.decoration! as BoxDecoration).color,
          label == 'Movies'
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        );
      }
      final backdrop = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is CinemaBackdrop,
      );
      expect(backdrop, findsNWidgets(2));
      expect(tester.getRect(backdrop.first).top, 0);
      expect(tester.getSize(backdrop.first), _computer);
      final homeScaffold = find
          .descendant(
            of: find.byKey(const Key('webFrameBackground')),
            matching: find.byType(Scaffold),
          )
          .first;
      expect(
        Theme.of(tester.element(homeScaffold)).scaffoldBackgroundColor,
        Colors.transparent,
      );
      expect(
        tester
            .widget<ColoredBox>(find.byKey(const Key('webFrameBackground')))
            .color,
        AppColors.background,
      );
      expect(
        tester.getRect(find.byKey(const Key('webHeaderNavGroup'))).center.dx,
        closeTo(_computer.width / 2, 1),
      );
      Border linkBorder(String label) =>
          (tester
                          .widget<Container>(
                            find
                                .ancestor(
                                  of: find.descendant(
                                    of: _header,
                                    matching: find.text(label),
                                  ),
                                  matching: find.byType(Container),
                                )
                                .first,
                          )
                          .decoration!
                      as BoxDecoration)
                  .border!
              as Border;
      expect(linkBorder('Movies').isUniform, isTrue);
      expect(linkBorder('Movies').top.color, AppColors.primary);
      expect(linkBorder('My tickets').top.color, Colors.transparent);
      expect(find.byType(CinemaNavigationBar), findsNothing);
      expect(
        find.descendant(of: _header, matching: find.text('Movies')),
        findsOneWidget,
      );
      expect(find.text(customerUser.displayName), findsOneWidget);

      await tester.tap(
        find.descendant(of: _header, matching: find.text('My tickets')),
      );
      await pumpRoute(tester);
      expect(find.text('My Bookings'), findsNothing);
      expect(_header, findsOneWidget);
      expect(backdrop, findsNWidgets(2));
      expect(tester.getSize(backdrop.first), _computer);
      expect(linkBorder('My tickets').top.color, AppColors.primary);
      expect(linkBorder('Movies').top.color, Colors.transparent);

      await tester.tap(find.byKey(const Key('webHeaderAccount')));
      await pumpRoute(tester);
      expect(find.text('Payment history'), findsOneWidget);
      await tester.tap(find.text('Account settings'));
      await pumpRoute(tester);
      expect(find.text('Account settings'), findsOneWidget);
    });

    testWidgets('Guests can sign in or sign up from the top bar', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(buildTestApp());
      await pumpRoute(tester);

      expect(find.byKey(const Key('webHeaderRegister')), findsOneWidget);
      for (final label in [
        'Movies',
        'My tickets',
        'Ratings',
        'Notifications',
      ]) {
        expect(
          find.descendant(of: _header, matching: find.text(label)),
          findsOneWidget,
        );
      }

      await tester.tap(find.byKey(const Key('webHeaderSignIn')));
      await pumpRoute(tester);
      // Sign-in pages keep their own full-screen design.
      expect(find.byKey(const Key('loginTitle')), findsOneWidget);
      expect(_header, findsNothing);
    });

    for (final destination in [
      ('My tickets', AppRoutes.myBookings, MyBookingsScreen),
      ('Ratings', AppRoutes.myRatings, MyRatingsScreen),
      ('Notifications', AppRoutes.notifications, NotificationListScreen),
    ]) {
      testWidgets('Guest header opens ${destination.$1} after login', (
        tester,
      ) async {
        _useWindow(tester, _computer);
        final session = SessionState();
        addTearDown(session.dispose);
        await tester.pumpWidget(buildTestApp(session: session));
        await pumpRoute(tester);
        await tester.tap(
          find.descendant(of: _header, matching: find.text(destination.$1)),
        );
        await pumpRoute(tester);
        expect(find.byKey(const Key('loginTitle')), findsOneWidget);
        expect(session.isAuthenticated, isFalse);
        expect(find.byType(destination.$3), findsNothing);
        expect(
          ModalRoute.of(tester.element(find.byType(LoginScreen)))!
              .settings
              .arguments,
          containsPair('pendingRoute', destination.$2),
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('loginEmailField')),
            matching: find.byType(TextFormField),
          ),
          'khachhang1@gmail.com',
        );
        await tester.enterText(
          find.descendant(
            of: find.byKey(const Key('loginPasswordField')),
            matching: find.byType(TextFormField),
          ),
          '123456',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        final signIn = find.byType(AppButton).first;
        await tester.ensureVisible(signIn);
        await tester.tap(signIn);
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await pumpRoute(tester);
        expect(session.isAuthenticated, isTrue);
        expect(find.byType(destination.$3), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Seat map with the order summary next to it', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.seatSelection(11),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Your seats'), findsOneWidget);
      expect(find.text('Choose your seats on the map.'), findsOneWidget);
      await tester.tap(find.text('3').first);
      await tester.pump();
      expect(find.text('A3'), findsOneWidget);
      // Each chosen seat with its price, then the total.
      expect(find.text(formatVnd(90000)), findsNWidgets(2));

      final summary = tester.getTopLeft(find.text('Your seats'));
      final screen = tester.getTopLeft(find.text('SCREEN'));
      expect(summary.dx, greaterThan(screen.dx));
    });

    for (final light in [false, true]) {
      testWidgets(
        'Booking detail keeps the shared website background: $light',
        (tester) async {
          FlutterSecureStorage.setMockInitialValues({
            'appearance.theme': light ? 'light' : 'dark',
          });
          _useWindow(tester, _computer);
          await tester.pumpWidget(
            buildTestApp(
              authenticated: true,
              initialRoute: AppRoutes.bookingDetail(101),
              bookingRepository: FakeBookingRepository(
                bookings: [bookingFixture()],
              ),
            ),
          );
          await pumpRoute(tester);
          final scaffold = tester.widget<Scaffold>(
            find.descendant(
              of: find.byType(BookingDetailScreen),
              matching: find.byType(Scaffold),
            ),
          );
          expect(scaffold.backgroundColor, Colors.transparent);
          expect(find.byType(CinemaBackdropTransition), findsOneWidget);
          expect(find.byKey(const Key('bookingInformation')), findsOneWidget);
          expect(find.byTooltip('Back'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('Booking details in two columns', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          bookingRepository: FakeBookingRepository(
            bookings: [
              bookingFixture(status: BookingStatus.confirmed, paymentId: 501),
            ],
          ),
          initialRoute: AppRoutes.bookingDetail(101),
        ),
      );
      await pumpRoute(tester);

      // The main column holds booking, seats and timeline; finances sit beside it.
      final booking = tester.getTopLeft(find.text('Your booking'));
      final qr = tester.getTopLeft(find.text('Your ticket'));
      final payment = tester.getTopLeft(find.text('Payment Summary'));
      expect(qr.dx, closeTo(booking.dx, 32));
      expect(qr.dy, greaterThan(booking.dy));
      expect(payment.dx, greaterThan(booking.dx + 400));
      expect((payment.dy - booking.dy).abs(), lessThan(40));
      final timeline = tester.getTopLeft(find.text('Timeline'));
      expect(timeline.dx, closeTo(qr.dx, 12));
      expect(timeline.dy, lessThan(qr.dy));
      expect(find.text('Request refund'), findsOneWidget);
    });

    for (final width in [600.0, 900.0, 1200.0]) {
      testWidgets('Paid booking reflows at effective zoom width $width', (
        tester,
      ) async {
        _useWindow(tester, Size(width, 900));
        await tester.pumpWidget(
          buildTestApp(
            authenticated: true,
            bookingRepository: FakeBookingRepository(
              bookings: [
                bookingFixture(status: BookingStatus.confirmed, paymentId: 501),
              ],
            ),
            initialRoute: AppRoutes.bookingDetail(101),
          ),
        );
        await pumpRoute(tester);
        expect(find.text('Payment Summary'), findsOneWidget);
        expect(find.text('Timeline'), findsOneWidget);
        expect(find.text('Request refund'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Staff accounts get no customer navigation', (tester) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          user: AuthUser.fromJson({
            ...customerUser.toJson(),
            'roles': ['ROLE_STAFF'],
          }),
        ),
      );
      await pumpRoute(tester);

      expect(find.byKey(const Key('managementAccountTitle')), findsOneWidget);
      expect(_header, findsNothing);
    });
  });

  group('Customer app on a phone', () {
    testWidgets('Tab bar at the bottom, no website navigation', (tester) async {
      _useWindow(tester, _phone);
      await tester.pumpWidget(buildTestApp(authenticated: true));
      await pumpRoute(tester);

      expect(_header, findsNothing);
      expect(find.byType(CinemaNavigationBar), findsOneWidget);
    });

    testWidgets('Seat map with the total in a bottom bar', (tester) async {
      _useWindow(tester, _phone);
      await tester.pumpWidget(
        buildTestApp(
          authenticated: true,
          initialRoute: AppRoutes.seatSelection(11),
        ),
      );
      await pumpRoute(tester);

      expect(find.text('Your seats'), findsNothing);
      expect(find.text('0 seat(s)'), findsOneWidget);
    });
  });

  group('Admin website', () {
    testWidgets('Pages line up with their title next to the navigation', (
      tester,
    ) async {
      _useWindow(tester, _computer);
      await tester.pumpWidget(
        buildAdminTestApp(
          authenticated: true,
          user: AuthUser.fromJson({
            ...customerUser.toJson(),
            'roles': ['ROLE_ADMIN'],
          }),
          staffService: _rooms(),
          initialRoute: AppRoutes.adminRooms,
        ),
      );
      await pumpRoute(tester);

      // Title, toolbar and table share the left edge next to the navigation;
      // the add button ends the toolbar at the table's right edge.
      final title = tester.getRect(find.text('Rooms').last);
      final toolbar = tester.getRect(find.byType(AdminCatalogToolbar));
      final table = tester.getRect(find.byKey(const Key('adminRoomsTable')));
      final add = tester.getRect(find.byKey(const Key('addRoomButton')));
      expect(toolbar.left, title.left);
      expect(table.left, title.left);
      expect(add.right, table.right);

      // Rooms are table rows on a computer.
      final first = tester.getTopLeft(find.text('Room 1'));
      final second = tester.getTopLeft(find.text('Room 2'));
      expect(second.dx, first.dx);
      expect(second.dy, greaterThan(first.dy));
    });
  });
}

StaffService _rooms() => StaffService(
  client: ApiClient(
    httpClient: MockClient((request) async {
      final items = request.url.path.startsWith('/api/rooms')
          ? [
              for (var id = 1; id <= 4; id++)
                {'id': id, 'name': 'Room $id', 'totalSeats': 40},
            ]
          : <Object>[];
      return http.Response(
        jsonEncode({
          'items': items,
          'pageNumber': 1,
          'pageSize': 10,
          'totalCount': items.length,
          'totalPages': 1,
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  ),
);
