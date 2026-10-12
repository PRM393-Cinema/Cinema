# Cinema FE — Mobile cinema booking app

Flutter app for customers: browse the movies now showing, pick a showtime and seats, hold the seats for 10 minutes, pay with PayOS, and view or cancel bookings. Everything comes from the Cinema API Gateway (`Cinema_BE`, port 5000).

Staff and admins manage the cinema on the **admin website**, a second web app in this project (`lib/main_admin.dart`, see below). The customer app (web and mobile) is for customers only: a staff or admin account signed in there is shown a link to the admin website.

## Requirements

- Flutter 3.38 or newer (Dart 3.13).
- Windows: turn on **Developer Mode** (Settings → System → For developers). Flutter needs symlinks for plugins (`flutter_secure_storage`, `url_launcher`); without it `flutter pub get` and `flutter run` stop with "Building with plugins requires symlink support".
- The backend running: `docker compose up -d` in `Cinema_BE` (see `Cinema_BE/docs/DOCKER.md`, which also lists the seed accounts).

## Run

```sh
flutter run -d chrome
```

| Target                                        | Command                                                       | Backend address used                                               |
| --------------------------------------------- | ------------------------------------------------------------- | ------------------------------------------------------------------ |
| Chrome / Edge                                 | `flutter run -d chrome`                                       | `http://localhost:5000`                                            |
| Windows desktop                               | `flutter run -d windows`                                      | `http://localhost:5000`                                            |
| Android emulator                              | `flutter run`                                                 | `http://10.0.2.2:5000` (the emulator's alias for the host machine) |
| Physical phone, or backend on another machine | `flutter run --dart-define=API_BASE_URL=http://<LAN IP>:5000` | the given address                                                  |

### Admin website

Built for a computer screen: navigation on the left (a menu button on windows narrower than 640 px) and the page on the right.

```sh
flutter run -d chrome -t lib/main_admin.dart
```

| Account | Sections |
| ------- | -------- |
| Staff   | Dashboard, Operations (bookings, showtimes, rooms and seats, payments, refunds), Profile |
| Admin   | The staff sections, plus Movies (add, edit, stop showing, show again), Rooms (add with a seat layout, rename, delete a room without showtimes, open the seat map) and Accounts |

Customer accounts are pointed to the customer site, and the sign-in page has no sign-up. To run both apps at once so that their links point to each other, give them fixed ports:

```sh
flutter run -d chrome --web-port 5500 --dart-define=ADMIN_URL=http://localhost:5501/
```

```sh
flutter run -d chrome -t lib/main_admin.dart --web-port 5501 --dart-define=CUSTOMER_URL=http://localhost:5500/
```

## Build for the web

The responsive Flutter web app uses the same customer flows and API as mobile.
Build it for deployment with an HTTPS API endpoint:

```sh
flutter build web --release --dart-define=API_BASE_URL=https://<API host>
```

The static site is written to `build/web`. If it is hosted under a path instead
of the domain root, pass the matching `--base-href=/path/` option.

The admin website goes to `admin/` inside the customer site (`--output` takes an
absolute path). The customer site links to `<site>/admin/` and the admin website
back to `<site>/`:

```powershell
flutter build web --release -t lib/main_admin.dart --base-href /admin/ --output "$PWD\build\web\admin" --dart-define=API_BASE_URL=https://<API host>
```

Configure the
backend CORS policy to allow the deployed web origin: set
`Cors__AllowedOrigins__0=https://<web host>` on the gateway (an empty list
allows every origin, which is only meant for local development).

Every screen has its own URL, for example `#/movies/7`, `#/showtimes/12/seats`
and `#/bookings/34/payment`. Refreshing the page or opening a shared link shows
the same screen: it loads the movie, showtime or booking by id, with the home
page underneath for the back button. Pages that need an account ask the
customer to sign in first and then continue. Only the chosen seats are kept in
memory, so a refreshed booking summary returns to the seat map.

- Debug and profile Android builds allow plain HTTP (`android/app/src/debug/AndroidManifest.xml`). Release builds should talk to an HTTPS backend.
- A physical phone must be on the same network as the backend machine; the gateway listens on port 5000 for the LAN.

## Booking and PayOS payment

1. **Confirm Booking** calls `POST /api/v1/bookings`: the booking is `PENDING` and the seats are held for 10 minutes.
2. **Pay with PayOS** calls `POST /api/v1/payments/payos/checkout` and opens the returned `checkoutUrl`.
   - Web: the PayOS page replaces the app. After paying or cancelling, PayOS redirects back to the app, which verifies the payment (`POST /api/v1/payments/payos/{orderCode}/verify`) and shows the result.
   - Android / Windows: the PayOS page opens in the browser. When the user comes back, the app verifies the payment; it also checks the booking status every 5 seconds and verifies with PayOS every 30 seconds.
   - Outside web, PayOS returns to the gateway root page by default. Use `--dart-define=PAYMENT_RETURN_URL=https://...` for another page.
3. To test without paying, send a signed PayOS webhook with `scripts/payos-webhook.ps1` in `Cinema_BE` (`docs/PAYOS.md`, section 5). The payment screen picks up the confirmed booking automatically.

Customers can cancel an unpaid booking at any time, and a paid one up to 2 hours before the show for a full refund; the refund status is shown on the booking detail.

## Project structure

```text
lib/
  admin/      AdminApp and AdminRouter: the admin website (lib/main_admin.dart)
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

Pull requests that change `Cinema_Mobile/` run the same checks on CI, plus a
build of both websites (`.github/workflows/flutter.yml`). Tests run on Linux,
where file names are case-sensitive: an import must match the file name exactly.
