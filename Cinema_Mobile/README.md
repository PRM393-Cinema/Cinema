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

Customer accounts are pointed to the customer site, and the sign-in page has no sign-up.

### Run both websites on port 5174 (local preview)

From `Cinema_Mobile`, build both entry points and serve the combined folder:

```powershell
flutter build web --release
flutter build web --release -t lib/main_admin.dart --base-href /admin/ --output "$PWD\build\web\admin"
python -m http.server 5174 --directory build/web
```

Open the customer site at `http://localhost:5174/` and the staff/admin site at
`http://localhost:5174/admin/`. Keep the backend running on port 5000. Stop any
older server on 5174 before starting this server. Rebuild both entry points after
source changes; this static preview does not hot reload.

### Optional: separate Flutter development servers

In VS Code, choose **Cinema Web (customer + admin, separate dev ports)** to start
two independent Flutter servers in release mode with their links configured.
Release mode avoids the extra work that debug mode adds to theme animations.

Or run these commands in two terminals:

```sh
flutter run --release -d edge --web-port 5174 --dart-define=ADMIN_URL=http://localhost:5175/
```

```sh
flutter run --release -d edge -t lib/main_admin.dart --web-port 5175 --dart-define=CUSTOMER_URL=http://localhost:5174/
```

Open the customer site at `http://localhost:5174/` and the admin site at
`http://localhost:5175/`. Without `ADMIN_URL`, the customer app uses `/admin/`
on its own server. That path requires a separate admin build, as described
below; `flutter run` only serves the entry point it was given. The two local
ports have separate browser storage, so sign in again on the admin site.

## Build for the web

The responsive Flutter web app uses the same customer flows and API as mobile.
Windows at least 900 px wide get the website layout: navigation at the top
instead of the tab bar, and pages in columns (seat map with the order summary,
booking details with payment and actions on the right). Narrower windows and
phones get the app layout. The breakpoint and page widths are in
`lib/core/utils/layout.dart`.
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

### Hosting where services sleep (Render free plan)

Free Render services sleep after 15 minutes without requests and take up to a
minute to start. A request the gateway forwards does not wake a sleeping
service, but a request from the browser or phone does. Pass the services'
health pages with `WAKE_UP_URLS` (comma separated, on both builds above):

```powershell
--dart-define=WAKE_UP_URLS=https://<auth>/health,https://<movie>/health,https://<booking>/health,https://<gateway>/health
```

The app then pings them when it starts, and while a service starts (the
gateway answers 502/503/504 or does not answer) it shows "Starting the
server…" and retries for about a minute instead of failing. Reads are retried;
other requests only after a 503, which means no service received them. Without
`WAKE_UP_URLS`, as with a local backend, nothing is pinged or retried
(`lib/core/network/server_wake_up.dart`).

Every screen has its own URL, for example `#/movies/7`, `#/showtimes/12/seats`
and `#/bookings/34/payment`. Refreshing the page or opening a shared link shows
the same screen: it loads the movie, showtime or booking by id, with the home
page underneath for the back button. Pages that need an account ask the
customer to sign in first and then continue. Only the chosen seats are kept in
memory, so a refreshed booking summary returns to the seat map.

- Debug and profile Android builds allow plain HTTP (`android/app/src/debug/AndroidManifest.xml`). Release builds should talk to an HTTPS backend.
- A physical phone must be on the same network as the backend machine; the gateway listens on port 5000 for the LAN.

## Cinema AI

Customer pages have a floating **Cinema AI** chat launcher on desktop and mobile.
The icon expands on desktop hover or keyboard focus and opens an inline chat panel.
The conversation stays available when minimized or changing pages. The history button
reopens saved chats after reload; New chat preserves previous conversations, and each
chat can be deleted with confirmation. Up to 20 chats (60 messages each) are stored
locally per account/guest; there is no cross-device sync. It answers
movie/showtime questions using live search tools. After sign-in it can look up your
membership, bookings, payments, highest paid bill and spending, or prepare a ticket
proposal. Review and explicitly confirm before any seat hold; payment stays in PayOS.
Requested account facts are sent via OpenRouter to the model provider.
Configure the OpenRouter key only in the backend; see
[Cinema AI setup](../Cinema_BE/docs/CINEMA_AI.md). No key is bundled in Flutter.

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

The staff dashboard uses compact KPI tiles and live shift charts. The bar chart
shows sold, held and checked-in seats for showtimes starting today; checked-in seats
are a subset of sold seats, not an additional ticket category. The donut shows the
share of today's scheduled showtimes with at least one sold/held seat. No activity
renders zero values and empty charts rather than sample data.

Now showing, Up next and Just finished use compact side-by-side lists on wide
screens and stack on small screens. The board still spans the current 12-hour
window on either side of now, including overnight shows; next/finished show up to
three entries each. All showtimes today opens the existing searchable daily list.
Opening a row still shows seats/customers. Data and the one-minute refresh cycle
use existing staff APIs; no revenue permission or new chart dependency is added.
The shared Today widget also appears on the admin dashboard. Chart empty/data states,
both themes, text scaling and existing dashboard flows have focused tests.
Chart panels stretch to equal height on desktop. The three bars share one baseline;
each number sits immediately above its bar, including zero-height bars.

Demo verification (November 4, 2026): Staff and Admin signed in on the running local
site, loaded/reloaded their dashboards and switched both themes without API/page errors.
Chart values matched daily API aggregates. Staff's one-minute automatic refresh ran
successfully. Admin could access account/revenue APIs; Staff received 403 for both,
and Customer received 403 for account, revenue and showtime statistics APIs. The run
was read-only apart from login: no bookings, payments or notifications were created.
Current daily aggregates were zero; non-zero column heights, shared baseline and panel
alignment were verified in widget tests (33 dashboard/admin/chart tests passed).
This checks the exercised demo flows, not production load or real payment settlement.

Customer notification badges refresh automatically every 30 seconds while the app
is visible and the customer is signed in. The open Notifications list refreshes
silently on the same cycle, including notifications added, read or deleted in another
tab. Background tabs pause checks; returning to the app refreshes immediately.
Network failures keep the last known data and retry on the next cycle. Requests
do not overlap, and responses from previous sessions are ignored. This uses the
existing authenticated REST APIs (near-real-time polling, not server push).
Each active customer tab makes up to 2 unread-count requests per minute, plus
list requests while Notifications is open; replace polling with push for larger traffic.
The refresh tests cover incoming/read/deleted items, offline recovery, background/resume,
guest/login/logout, and rejection of delayed responses after logout. The full Flutter
suite passed (518 tests) for this update; no notification API or backend permission changed.

```sh
flutter analyze
```

```sh
flutter test
```

Pull requests that change `Cinema_Mobile/` run the same checks on CI, plus a
build of both websites (`.github/workflows/flutter.yml`). Tests run on Linux,
where file names are case-sensitive: an import must match the file name exactly.
