# CosmoQ IEEE reporting evidence ledger

Inspection date: 2026-10-28 (Asia/Saigon).
Main repository: `55642353331f7119c16d4fef05f54bfc559cae8b`.
DB submodule: `e455d297c76b14e3fd6aa8c0af4bb11f77ec6a2b`.

The user waived the missing DIKE PDF and confirmed Flutter Web/shared backend and Flutter Mobile/shared backend as the report scopes. The database submodule was successfully initialized. Neither paper treats specification text or seed rows as runtime evidence.

## Status interpretation

A = implemented and source verified (runtime proof is claimed only where explicitly recorded); B = partial; C = mocked/simulated; D = configured/integrated but end-to-end unverified; E = planned/TODO; F = not found. The status applies to the stated evidence scope, not to a blanket product acceptance claim.

## Claim-to-source map

| Claim | Evidence status | Source and first matching line |
|---|---|---|
| Architecture and real dependencies | A: implemented/source verified | `Cinema_Mobile/lib/app/app_dependencies.dart:23` |
| Customer entry point and restore | A | `Cinema_Mobile/lib/main.dart:10` |
| Admin entry point | A | `Cinema_Mobile/lib/main_admin.dart:9` |
| Customer route contracts | A | `Cinema_Mobile/lib/app/routes/app_routes.dart:3` |
| Customer route guards and ID loading | A | `Cinema_Mobile/lib/app/routes/app_router.dart:52` |
| Staff/admin guards | A | `Cinema_Mobile/lib/admin/admin_router.dart:32` |
| Observable session and inherited state | A | `Cinema_Mobile/lib/core/session/session_state.dart:5` |
| Session-driven redirect | A | `Cinema_Mobile/lib/app/session_app.dart:49` |
| HTTP errors, timeout, token retry | A | `Cinema_Mobile/lib/core/network/api_client.dart:10` |
| Android emulator and return URL defaults | A | `Cinema_Mobile/lib/core/network/api_config.dart:3` |
| Secure-storage API calls; native behavior untested | A source; D device operation | `Cinema_Mobile/lib/data/storage/auth_token_storage.dart:19` |
| Concurrent refresh and session race handling | A | `Cinema_Mobile/lib/data/storage/token_manager.dart:11` |
| Home search and notification count | A | `Cinema_Mobile/lib/features/home/screens/home_screen.dart:47` |
| Catalog composition and seven-day window | A | `Cinema_Mobile/lib/data/repositories/catalog_repository.dart:81` |
| Five-second seat polling | A | `Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart:51` |
| Checkout polling and resumption | A source; D live checkout | `Cinema_Mobile/lib/features/payment/screens/payment_screen.dart:130` |
| Shared responsive breakpoint | A | `Cinema_Mobile/lib/core/utils/layout.dart:8` |
| Local responsive constraints | A | `Cinema_Mobile/lib/core/widgets/responsive_columns.dart:8` |
| Wide customer navigation frame | A | `Cinema_Mobile/lib/app/customer_frame.dart:91` |
| QR display, not proof of ticket signature | A source; D device rendering | `Cinema_Mobile/lib/features/booking/widgets/ticket_qr_card.dart:52` |
| Ticket share and calendar fallback | A source; D native plugin operation | `Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart:65` |
| Native trailer launch | A source; D external application | `Cinema_Mobile/lib/core/widgets/trailer_player_native.dart:9` |
| Conditional browser trailer branch | A | `Cinema_Mobile/lib/core/widgets/trailer_player.dart:1` |
| Staff QR camera and lookup | A source; D physical scanner | `Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart:28` |
| Web print implementation | A source; D browser print operation | `Cinema_Mobile/lib/features/staff/widgets/ticket_print_web.dart:13` |
| Android network declaration | A config; D release deployment | `Cinema_Mobile/android/app/src/main/AndroidManifest.xml:3` |
| iOS camera purpose | A config; D permission/device execution | `Cinema_Mobile/ios/Runner/Info.plist:9` |
| JWT construction and secure random refresh token | A | `Cinema_BE/AuthService/AuthService/Service/JwtService.cs:21` |
| BCrypt, refresh rotation, logout | A | `Cinema_BE/AuthService/AuthService/Service/AuthService.cs:70` |
| Account input constraints | A | `Cinema_BE/AuthService/AuthService/Helpers/AccountValidation.cs:15` |
| Gateway JWT/CORS/rate limiting | A | `Cinema_BE/ApiGateway/ApiGateway/Program.cs:89` |
| Account lock/current role status | A | `Cinema_BE/ApiGateway/ApiGateway/Middleware/AccountStatusMiddleware.cs:10` |
| Movie browsing service | A | `Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs:96` |
| Showtime availability, room membership, sweetbox | A | `Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs:36` |
| Seat pricing algorithm | A | `Cinema_BE/MovieService/MovieService/Helpers/SeatPrices.cs:15` |
| Customer ownership and identity replacement | A | `Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:164` |
| Hold transaction, server pricing, refund-pending logic | A source; D full runtime | `Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs:24` |
| Reservation row locking | A | `Cinema_BE/BookingService/BookingService/Repositories/Impl/SeatReservationRepository.cs:128` |
| Reservation mapping and uniqueness listing | A | `Cinema_BE/BookingService/BookingService/Data/BookingDbContext.cs:268` |
| PayOS adapter | D: integrated; live provider not executed | `Cinema_BE/BookingService/BookingService/Clients/Implementations/PayOsClient.cs:29` |
| Webhook and payment confirmation | A source; D provider operation | `Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs:529` |
| Signature algorithm | A; isolated tests passed | `Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs:34` |
| Promotion cap and rounding | A | `Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs:9` |
| Loyalty constants and point arithmetic | A | `Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs:7` |
| Loyalty redemption and balance checks | A | `Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs:94` |
| Review requires owned checked-in booking | A | `Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs:91` |
| Refund transfer confirmation | A source; D actual staff transfer | `Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs:143` |
| Outbox confirmations and publication markers | A source; D broker runtime | `Cinema_BE/BookingService/BookingService/Messaging/OutboxPublisherWorker.cs:211` |
| Event email handler and retry limits | A source; D SMTP operation | `Cinema_BE/BookingService/BookingService/Messaging/Handlers/NotificationEventHandler.cs:108` |
| In-app notification read state | A | `Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart:83` |
| Service registrations, database contexts, workers | A | `Cinema_BE/BookingService/BookingService/Program.cs:200` |
| Six-database Compose topology | A configuration; D deployed runtime | `Cinema_BE/docker-compose.yml:43` |
| Database initialization | A script; not executed | `Cinema_BE/docker/postgres/init-databases.sh:14` |
| Script migration execution | A script; not executed | `Cinema_BE/docker/postgres/migrate.sh:5` |
| Auth schema and declared keys | A SQL | `Project-Cinema-DB/cinema_auth_db.sql:1` |
| Movie schema | A SQL | `Project-Cinema-DB/cinema_movie_db.sql:1` |
| Room, seat, showtime SQL FKs | A SQL | `Project-Cinema-DB/cinema_showtime_db.sql:1` |
| Booking, reservations, snapshots, SQL FKs | A SQL | `Project-Cinema-DB/cinema_booking_db.sql:1` |
| Payment/refund SQL FK and seed labels | A SQL; seed is not live payment evidence | `Project-Cinema-DB/cinema_payment_db.sql:1` |
| Notification records/dedup/read fields | A SQL | `Project-Cinema-DB/cinema_notification_db.sql:1` |
| Additional review schema | A SQL | `Cinema_BE/docker/postgres/migrations/2026-10-28_cinema_movie_reviews.sql:5` |
| Testcontainers and fake external services | C: mocked integration dependencies | `Cinema_BE/BookingService/BookingService.Tests/Infrastructure/BookingApiFactory.cs:31` |
| Signature fixture versus external provider | A unit assertions; not live integration | `Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs:34` |
| Flutter workflow fakes | C: test substitutes | `Cinema_Mobile/test/support/fakes.dart:25` |
| Phone/wide viewport tests | A tests; pass in 209-case run | `Cinema_Mobile/test/web_layout_test.dart:21` |
| Customer booking widget tests | A tests; mocked repositories | `Cinema_Mobile/test/booking_flow_test.dart:32` |
| Flutter CI pin and two browser builds | A configuration; not CI execution evidence | `.github/workflows/flutter.yml:33` |
| Backend CI matrix | A configuration; not CI execution evidence | `.github/workflows/ci.yml:27` |

## Feature boundaries and limitations

- No independent Web source repository was found; the user confirmed that Web means the Flutter browser builds. Both reports explain their shared source/backend without making the other client a major section.
- F: SignalR/WebSocket seat push, FCM/APNs native push, certificate pinning, device attestation, automatic provider banking refunds, and active VNPAY/MOMO adapters were not established. These are not reported as implemented.
- Calendar support is a generated Google Calendar URL, not native calendar synchronization. Ticket QR use does not establish cryptographic ticket signatures.
- No performance, usability, coverage, production deployment, live payment, or real email delivery outcome was measured.
- Docker daemon was unavailable; no container-dependent integration suite or SQL migration execution is claimed. Backend integration fixtures also fake MovieService, PayOS, and SMTP unless specifically testing the RabbitMQ container path.
- Four MovieService nullable warnings remain. Flutter analysis has one informational lint, not a zero-finding result.
- A first Flutter no-restore check encountered missing package cache entries. `flutter pub get` restored already declared dependencies; the final suite passed 209 cases. Generated platform registrants were restored to their clean pre-task HEAD content; no app source or manifest changes are part of the deliverables.

## Executed verification

| Command | Observed result |
|---|---|
| `git submodule update --init --recursive` | Success; DB snapshot above |
| `dotnet test Cinema_BE/BookingService/BookingService.Tests/BookingService.Tests.csproj --no-restore --filter FullyQualifiedName~.Unit.` | 17 passed, zero failed/skipped |
| `dotnet test Cinema_BE/ApiGateway/ApiGateway.Tests/ApiGateway.Tests.csproj --no-restore` | 21 passed, zero failed/skipped |
| `dotnet build Cinema_BE/AuthService/AuthService/AuthService.csproj` | Success, zero errors/warnings |
| `dotnet build Cinema_BE/MovieService/MovieService/MovieService.csproj` | Success, zero errors, four nullable warnings |
| `flutter analyze --no-pub` | 1 info at `lib/core/utils/trailer_url.dart:12:5`; no errors/warnings |
| `flutter test --no-pub --reporter expanded` | All 209 tests passed after dependency restoration |
| `docker info --format ...` | Daemon pipe not found; container checks blocked |

Full Flutter command output is retained in `ieee-verification/`. Backend results were observed directly from command output; the table is a transcription, not a fabricated raw log.

Both customer and admin Flutter Web release builds succeeded. Commands used `--no-pub --no-web-resources-cdn`; the admin target was `lib/main_admin.dart`, with `/admin/` base href and isolated `build/ieee-admin-verification` output. Raw build outputs are in `ieee-verification/`. Native release builds remain not executed.

## Presentation revision after visual comparison

The user authorized revising both reports after supplying `D:/Downloads/Downloads/Dike.pdf`. That paper informed visual hierarchy only. The CosmoQ reports retain the same citation-key sets, nine numbered sections, original verification results, and source-equivalent listing tokens. The architecture was redrawn as a two-column vector figure with explicit service/database ownership and integration bindings; selected prose was reorganized without introducing new system capabilities. Final outputs: Web 7 pages, Mobile 8 pages. All 15 pages were rendered and visually inspected. Final TeX logs contain no overfull boxes, undefined citations/references, missing glyphs, or font substitution warnings. No application source was modified and no application tests were rerun for this layout-only revision.
