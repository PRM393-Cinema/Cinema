# Cinema FE — Mobile cinema booking app

Flutter app for customers: browse the movies now showing, pick a showtime and seats, hold the seats for 10 minutes, pay with PayOS, and view or cancel bookings. Everything comes from the Cinema API Gateway (`Cinema_BE`, port 5000).

## Requirements

- Flutter 3.38 or newer (Dart 3.13).
- Windows: turn on **Developer Mode** (Settings → System → For developers). Flutter needs symlinks for plugins (`flutter_secure_storage`, `url_launcher`); without it `flutter pub get` and `flutter run` stop with "Building with plugins requires symlink support".
- The backend running: `docker compose up -d` in `Cinema_BE` (see `Cinema_BE/docs/DOCKER.md`, which also lists the seed accounts).

## Run

```sh
flutter run -d chrome
```

| Target | Command | Backend address used |
|---|---|---|
| Chrome / Edge | `flutter run -d chrome` | `http://localhost:5000` |
| Windows desktop | `flutter run -d windows` | `http://localhost:5000` |
| Android emulator | `flutter run` | `http://10.0.2.2:5000` (the emulator's alias for the host machine) |
| Physical phone, or backend on another machine | `flutter run --dart-define=API_BASE_URL=http://<LAN IP>:5000` | the given address |

- Debug and profile Android builds allow plain HTTP (`android/app/src/debug/AndroidManifest.xml`). Release builds should talk to an HTTPS backend.
- A physical phone must be on the same network as the backend machine; the gateway listens on port 5000 for the LAN.

## Booking and PayOS payment

1. **Confirm Booking** calls `POST /api/v1/bookings`: the booking is `PENDING` and the seats are held for 10 minutes.
2. **Pay with PayOS** calls `POST /api/v1/payments/payos/checkout` and opens the returned `checkoutUrl`.
   - Web: the PayOS page replaces the app. After paying or cancelling, PayOS redirects back to the app, which verifies the payment (`POST /api/v1/payments/payos/{orderCode}/verify`) and shows the result.
   - Android / Windows: the PayOS page opens in the browser. When the user comes back, the app verifies the payment; it also checks the booking status every 5 seconds, and **I have paid** verifies on demand.
   - Outside web, PayOS returns to the gateway root page by default. Use `--dart-define=PAYMENT_RETURN_URL=https://...` for another page.
3. To test without paying, send a signed PayOS webhook with `scripts/payos-webhook.ps1` in `Cinema_BE` (`docs/PAYOS.md`, section 5). The payment screen picks up the confirmed booking automatically.

Customers can cancel an unpaid booking at any time, and a paid one up to 2 hours before the show for a full refund; the refund status is shown on the booking detail.

## Project structure

```text
lib/
  app/        CinemaApp, routes, theme, AppDependencies (wires the repositories)
  core/       network (ApiClient with token refresh), session, utils, shared widgets
  data/       models (match the backend DTOs), services (HTTP calls),
              repositories (used by the screens), storage (tokens)
  features/   screens grouped by feature
test/         unit and widget tests with fake repositories (test/support)
```

Access tokens last an hour. `ApiClient` renews them with the refresh token on the first 401 and repeats the request; when the refresh token is rejected the user is signed out.

## Checks

```sh
flutter analyze
```

```sh
flutter test
```
