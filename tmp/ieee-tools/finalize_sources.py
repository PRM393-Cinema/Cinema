from pathlib import Path
import subprocess, json, shutil, re, sys
ROOT=Path(__file__).resolve().parents[2]

# Flutter package restoration regenerates these tracked files. They were clean
# before this task. Restore their exact HEAD bytes without touching the index.
generated=[
'Cinema_Mobile/linux/flutter/generated_plugin_registrant.cc',
'Cinema_Mobile/linux/flutter/generated_plugin_registrant.h',
'Cinema_Mobile/linux/flutter/generated_plugins.cmake',
'Cinema_Mobile/macos/Flutter/GeneratedPluginRegistrant.swift',
'Cinema_Mobile/windows/flutter/generated_plugin_registrant.cc',
'Cinema_Mobile/windows/flutter/generated_plugin_registrant.h',
'Cinema_Mobile/windows/flutter/generated_plugins.cmake']
if '--restore-generated' in sys.argv:
    for name in generated:
        (ROOT/name).write_bytes(subprocess.check_output(['git','show','HEAD:'+name],cwd=ROOT))

for kind in ('web','mobile'):
    p=ROOT/'docs'/('ieee-'+kind)
    t=(p/'main.tex').read_text(encoding='utf-8')
    t=t.replace(r'\code{/my-bookings}',r'\code{/bookings}')
    t=t.replace('minimum height=7mm,text width=25mm', 'minimum height=7mm,inner sep=2pt,text width=22mm')
    marker=r'\input{verification-table}'
    result=r'''\input{verification-table}

After restoring the existing declared Flutter dependencies, the full
\code{flutter test --no-pub --reporter expanded} run passed 209 tests.
\code{flutter analyze --no-pub} reported one informational finding,
\code{curly\_braces\_in\_flow\_control\_structures}, in
\code{trailer\_url.dart:12}; no analysis errors or warnings remained.
The analyzer was therefore not a clean zero-finding run. The earlier
no-restore attempt failed because locally cached QR/sharing packages were
missing, and is not counted as a passed test run. No application source
was changed to obtain the restored-package result.
'''
    if 'After restoring the existing declared Flutter dependencies' not in t:
        t=t.replace(marker,result)
    (p/'main.tex').write_text(t,encoding='utf-8')
    table=(p/'verification-table.tex').read_text(encoding='utf-8')
    table=table.replace('Flutter analysis and widget suite & See final client-verification paragraph; package restoration required',
                        'Flutter analysis & 1 informational lint; no errors/warnings')
    if 'PASS: 209 tests' not in table:
        table=table.replace(r'PostgreSQL/RabbitMQ integration suites',r'Flutter unit/widget suite & PASS: 209 tests after package restore\\'+ '\n'+r'PostgreSQL/RabbitMQ integration suites')
    (p/'verification-table.tex').write_text(table,encoding='utf-8')
    abstract=t.split(r'\begin{abstract}')[1].split(r'\end{abstract}')[0]
    print(kind, 'abstract words',len(abstract.split()))

e=ROOT/'docs'/'ieee-verification'
e.mkdir(exist_ok=True)
for name in ('flutter-analyze.txt','flutter-test.txt'):
    shutil.copyfile(ROOT/'tmp'/'ieee-tools'/name,e/name)

evidence = [
('Architecture and real dependencies','A: implemented/source verified','Cinema_Mobile/lib/app/app_dependencies.dart','factory AppDependencies.remote'),
('Customer entry point and restore','A','Cinema_Mobile/lib/main.dart','void main'),
('Admin entry point','A','Cinema_Mobile/lib/main_admin.dart','void main'),
('Customer route contracts','A','Cinema_Mobile/lib/app/routes/app_routes.dart','abstract final class AppRoutes'),
('Customer route guards and ID loading','A','Cinema_Mobile/lib/app/routes/app_router.dart','Route<dynamic> onGenerateRoute'),
('Staff/admin guards','A','Cinema_Mobile/lib/admin/admin_router.dart','enum _Access'),
('Observable session and inherited state','A','Cinema_Mobile/lib/core/session/session_state.dart','class SessionState'),
('Session-driven redirect','A','Cinema_Mobile/lib/app/session_app.dart','pushNamedAndRemoveUntil'),
('HTTP errors, timeout, token retry','A','Cinema_Mobile/lib/core/network/api_client.dart','class ApiClient'),
('Android emulator and return URL defaults','A','Cinema_Mobile/lib/core/network/api_config.dart','abstract final class ApiConfig'),
('Secure-storage API calls; native behavior untested','A source; D device operation','Cinema_Mobile/lib/data/storage/auth_token_storage.dart','class SecureAuthTokenStorage'),
('Concurrent refresh and session race handling','A','Cinema_Mobile/lib/data/storage/token_manager.dart','class TokenManager'),
('Home search and notification count','A','Cinema_Mobile/lib/features/home/screens/home_screen.dart','searchDelay'),
('Catalog composition and seven-day window','A','Cinema_Mobile/lib/data/repositories/catalog_repository.dart','static const showtimeWindow'),
('Five-second seat polling','A','Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart','static const _liveInterval'),
('Checkout polling and resumption','A source; D live checkout','Cinema_Mobile/lib/features/payment/screens/payment_screen.dart','didChangeAppLifecycleState'),
('Shared responsive breakpoint','A','Cinema_Mobile/lib/core/utils/layout.dart','desktopBreakpoint'),
('Local responsive constraints','A','Cinema_Mobile/lib/core/widgets/responsive_columns.dart','class ResponsiveColumns'),
('Wide customer navigation frame','A','Cinema_Mobile/lib/app/customer_frame.dart','class CustomerFrame'),
('QR display, not proof of ticket signature','A source; D device rendering','Cinema_Mobile/lib/features/booking/widgets/ticket_qr_card.dart','QrImageView'),
('Ticket share and calendar fallback','A source; D native plugin operation','Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart','fallbackLength'),
('Native trailer launch','A source; D external application','Cinema_Mobile/lib/core/widgets/trailer_player_native.dart','LaunchMode.externalApplication'),
('Conditional browser trailer branch','A','Cinema_Mobile/lib/core/widgets/trailer_player.dart','export'),
('Staff QR camera and lookup','A source; D physical scanner','Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart','cameraScanSupported'),
('Web print implementation','A source; D browser print operation','Cinema_Mobile/lib/features/staff/widgets/ticket_print_web.dart','print'),
('Android network declaration','A config; D release deployment','Cinema_Mobile/android/app/src/main/AndroidManifest.xml','android.permission.INTERNET'),
('iOS camera purpose','A config; D permission/device execution','Cinema_Mobile/ios/Runner/Info.plist','NSCameraUsageDescription'),
('JWT construction and secure random refresh token','A','Cinema_BE/AuthService/AuthService/Service/JwtService.cs','GenerateAccessToken'),
('BCrypt, refresh rotation, logout','A','Cinema_BE/AuthService/AuthService/Service/AuthService.cs','BCrypt'),
('Account input constraints','A','Cinema_BE/AuthService/AuthService/Helpers/AccountValidation.cs','BCrypt'),
('Gateway JWT/CORS/rate limiting','A','Cinema_BE/ApiGateway/ApiGateway/Program.cs','AddRateLimiter'),
('Account lock/current role status','A','Cinema_BE/ApiGateway/ApiGateway/Middleware/AccountStatusMiddleware.cs','class AccountStatusMiddleware'),
('Movie browsing service','A','Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs','BrowseAsync'),
('Showtime availability, room membership, sweetbox','A','Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs','GetSeatsForBookingAsync'),
('Seat pricing algorithm','A','Cinema_BE/MovieService/MovieService/Helpers/SeatPrices.cs','public static decimal For'),
('Customer ownership and identity replacement','A','Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs','request.UserId = User.GetCurrentUserId'),
('Hold transaction, server pricing, refund-pending logic','A source; D full runtime','Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs','HoldDuration'),
('Reservation row locking','A','Cinema_BE/BookingService/BookingService/Repositories/Impl/SeatReservationRepository.cs','FOR UPDATE'),
('Reservation mapping and uniqueness listing','A','Cinema_BE/BookingService/BookingService/Data/BookingDbContext.cs','uq_seat_per_showtime'),
('PayOS adapter','D: integrated; live provider not executed','Cinema_BE/BookingService/BookingService/Clients/Implementations/PayOsClient.cs','CreatePaymentLinkAsync'),
('Webhook and payment confirmation','A source; D provider operation','Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs','HandlePayOsWebhookAsync'),
('Signature algorithm','A; isolated tests passed','Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs','public static bool IsValid'),
('Promotion cap and rounding','A','Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs','MaxShareOfTickets'),
('Loyalty constants and point arithmetic','A','Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs','PointValue'),
('Loyalty redemption and balance checks','A','Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs','RedeemAsync'),
('Review requires owned checked-in booking','A','Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs','CheckedInAt'),
('Refund transfer confirmation','A source; D actual staff transfer','Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs','Complete'),
('Outbox confirmations and publication markers','A source; D broker runtime','Cinema_BE/BookingService/BookingService/Messaging/OutboxPublisherWorker.cs','publisherConfirmationsEnabled'),
('Event email handler and retry limits','A source; D SMTP operation','Cinema_BE/BookingService/BookingService/Messaging/Handlers/NotificationEventHandler.cs','ExternalServiceException'),
('In-app notification read state','A','Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart','markAllNotificationsRead'),
('Service registrations, database contexts, workers','A','Cinema_BE/BookingService/BookingService/Program.cs','AddHostedService'),
('Six-database Compose topology','A configuration; D deployed runtime','Cinema_BE/docker-compose.yml','postgres:17-alpine'),
('Database initialization','A script; not executed','Cinema_BE/docker/postgres/init-databases.sh','CREATE DATABASE'),
('Script migration execution','A script; not executed','Cinema_BE/docker/postgres/migrate.sh','for file'),
('Auth schema and declared keys','A SQL','Project-Cinema-DB/cinema_auth_db.sql','CREATE TABLE users'),
('Movie schema','A SQL','Project-Cinema-DB/cinema_movie_db.sql','CREATE TABLE movies'),
('Room, seat, showtime SQL FKs','A SQL','Project-Cinema-DB/cinema_showtime_db.sql','CREATE TABLE rooms'),
('Booking, reservations, snapshots, SQL FKs','A SQL','Project-Cinema-DB/cinema_booking_db.sql','CREATE TABLE bookings'),
('Payment/refund SQL FK and seed labels','A SQL; seed is not live payment evidence','Project-Cinema-DB/cinema_payment_db.sql','CREATE TABLE payments'),
('Notification records/dedup/read fields','A SQL','Project-Cinema-DB/cinema_notification_db.sql','CREATE TABLE notifications'),
('Additional review schema','A SQL','Cinema_BE/docker/postgres/migrations/2026-10-28_cinema_movie_reviews.sql','CREATE TABLE IF NOT EXISTS movie_reviews'),
('Testcontainers and fake external services','C: mocked integration dependencies','Cinema_BE/BookingService/BookingService.Tests/Infrastructure/BookingApiFactory.cs','public FakePayOsClient'),
('Signature fixture versus external provider','A unit assertions; not live integration','Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs','Create_MatchesPayOsDocumentationExample'),
('Flutter workflow fakes','C: test substitutes','Cinema_Mobile/test/support/fakes.dart','Fake'),
('Phone/wide viewport tests','A tests; pass in 209-case run','Cinema_Mobile/test/web_layout_test.dart','Size(390, 844)'),
('Customer booking widget tests','A tests; mocked repositories','Cinema_Mobile/test/booking_flow_test.dart','FakeCatalogRepository'),
('Flutter CI pin and two browser builds','A configuration; not CI execution evidence','\.github/workflows/flutter.yml'.lstrip('\\'),'flutter-version'),
('Backend CI matrix','A configuration; not CI execution evidence','.github/workflows/ci.yml','matrix:'),
]
lines=['# CosmoQ IEEE reporting evidence ledger','',
'Inspection date: 2026-10-28 (Asia/Saigon).',
'Main repository: `'+subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()+'`.',
'DB submodule: `'+subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT/'Project-Cinema-DB',text=True).strip()+'`.',
'',
'The user waived the missing DIKE PDF and confirmed Flutter Web/shared backend and Flutter Mobile/shared backend as the report scopes. The database submodule was successfully initialized. Neither paper treats specification text or seed rows as runtime evidence.',
'',
'## Status interpretation',
'',
'A = implemented and source verified (runtime proof is claimed only where explicitly recorded); B = partial; C = mocked/simulated; D = configured/integrated but end-to-end unverified; E = planned/TODO; F = not found. The status applies to the stated evidence scope, not to a blanket product acceptance claim.',
'',
'## Claim-to-source map',
'',
'| Claim | Evidence status | Source and first matching line |',
'|---|---|---|']
for claim,status,name,needle in evidence:
    path=ROOT/name
    assert path.exists(),name
    txt=path.read_text(encoding='utf-8-sig',errors='replace').splitlines()
    matches=[i+1 for i,line in enumerate(txt) if needle in line]
    assert matches,(name,needle)
    lines.append(f'| {claim} | {status} | `{name}:{matches[0]}` |')
lines += ['', '## Feature boundaries and limitations', '',
'- No independent Web source repository was found; the user confirmed that Web means the Flutter browser builds. Both reports explain their shared source/backend without making the other client a major section.',
'- F: SignalR/WebSocket seat push, FCM/APNs native push, certificate pinning, device attestation, automatic provider banking refunds, and active VNPAY/MOMO adapters were not established. These are not reported as implemented.',
'- Calendar support is a generated Google Calendar URL, not native calendar synchronization. Ticket QR use does not establish cryptographic ticket signatures.',
'- No performance, usability, coverage, production deployment, live payment, or real email delivery outcome was measured.',
'- Docker daemon was unavailable; no container-dependent integration suite or SQL migration execution is claimed. Backend integration fixtures also fake MovieService, PayOS, and SMTP unless specifically testing the RabbitMQ container path.',
'- Four MovieService nullable warnings remain. Flutter analysis has one informational lint, not a zero-finding result.',
'- A first Flutter no-restore check encountered missing package cache entries. `flutter pub get` restored already declared dependencies; the final suite passed 209 cases. Generated platform registrants were restored to their clean pre-task HEAD content; no app source or manifest changes are part of the deliverables.',
'', '## Executed verification', '',
'| Command | Observed result |', '|---|---|',
'| `git submodule update --init --recursive` | Success; DB snapshot above |',
'| `dotnet test Cinema_BE/BookingService/BookingService.Tests/BookingService.Tests.csproj --no-restore --filter FullyQualifiedName~.Unit.` | 17 passed, zero failed/skipped |',
'| `dotnet test Cinema_BE/ApiGateway/ApiGateway.Tests/ApiGateway.Tests.csproj --no-restore` | 21 passed, zero failed/skipped |',
'| `dotnet build Cinema_BE/AuthService/AuthService/AuthService.csproj` | Success, zero errors/warnings |',
'| `dotnet build Cinema_BE/MovieService/MovieService/MovieService.csproj` | Success, zero errors, four nullable warnings |',
'| `flutter analyze --no-pub` | 1 info at `lib/core/utils/trailer_url.dart:12:5`; no errors/warnings |',
'| `flutter test --no-pub --reporter expanded` | All 209 tests passed after dependency restoration |',
'| `docker info --format ...` | Daemon pipe not found; container checks blocked |',
'', 'Full Flutter command output is retained in `ieee-verification/`. Backend results were observed directly from command output; the table is a transcription, not a fabricated raw log.',
]
(ROOT/'docs'/'ieee-evidence.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Finalized sources and evidence ledger.')
