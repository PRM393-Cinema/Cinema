# SOFTWARE REQUIREMENTS SPECIFICATION (SRS)

## CosmoQ Cinema: ticket booking and cinema management system

| Item | Value |
|---|---|
| Version | 2.0 (consolidated) |
| Date | 26 October 2026 |
| Course | PRM393 |
| Status | Describes the system as built on the `dev` branch (after PR #18) |
| Supersedes | SRS 1.0 (`Cinema_BE/Cinema_Microservice_SRS_Complete.md`, the initial design) |
| Vietnamese version | [SRS_VI.md](SRS_VI.md) (same structure, same requirement IDs) |

### Revision history

| Version | Changes |
|---|---|
| 1.0 | Initial design: six planned microservices and the core requirements for movies, rooms and seats, showtimes, bookings, payments and notifications. |
| 2.0 | Consolidated from the system as built: three business services and a gateway; email verification with OTP and account locking; seat types with prices per type; refunds with staff approval; counter sales (cash, bank transfer, walk-in guests); QR check-in; operations dashboards; monitoring; testing. |

---

## 1. Introduction

### 1.1 Purpose

This document specifies the functional and non-functional requirements, business rules, user roles and interfaces of CosmoQ Cinema. It is the shared reference for development, testing, demos and grading. Every requirement has an ID so it can be traced to code, tests and technical documents.

### 1.2 Product scope

CosmoQ Cinema has three parts:

- **Customer app** (Flutter: Android, web, Windows): browse movies and showtimes, choose seats, hold them for 10 minutes, pay through PayOS, show the ticket with its QR code, cancel tickets and request refunds, read notifications and the payment history.
- **Admin website** (Flutter web, same code base): staff sell tickets at the counter, take payment, check customers in, manage showtimes and seat maps, and handle refunds; admins also manage movies, rooms and accounts and see revenue.
- **Microservice backend** (ASP.NET Core 8): an API Gateway and three business services, each owning its databases and exchanging events through RabbitMQ.

### 1.3 Terms and abbreviations

| Term | Meaning |
|---|---|
| Booking / ticket | A reservation of one or more seats for one showtime. Booking code format: `BK-yyyyMMddHHmmss-xxxxxx`. |
| Seat hold | Seats locked for a `PENDING` booking for 10 minutes while it waits for payment. |
| Walk-in guest | A customer who buys at the counter without an account; the booking has no `userId`. |
| Sweetbox | A couple seat: an odd seat paired with the even seat to its right in the same row (1-2, 3-4…). |
| OTP | A 6-digit code sent by email to verify an email address or reset a password. |
| JWT | JSON Web Token; the access token lasts 60 minutes. |
| Refresh token | Token that renews a session; lasts 7 days and is rotated on every use. |
| PayOS | Vietnamese payment gateway for bank transfers through VietQR. |
| Outbox | Table that stores events in the same transaction as the data; events are sent to RabbitMQ after commit. |
| DLQ | Dead-letter queue: holds messages that still fail after 3 attempts. |
| RBAC | Role-based access control (Customer, Staff, Admin). |

### 1.4 References

| Document | Content |
|---|---|
| [README.md](../README.md) | Setup and repository layout |
| [DEMO.md](../DEMO.md) | Demo preparation and script |
| [Cinema_BE/docs/DOCKER.md](../Cinema_BE/docs/DOCKER.md) | Running the backend with Docker, ports, seed accounts |
| [Cinema_BE/docs/EMAIL_SETUP.md](../Cinema_BE/docs/EMAIL_SETUP.md) | Email, OTP, account field rules |
| [Cinema_BE/docs/PAYOS.md](../Cinema_BE/docs/PAYOS.md) | Payment, webhook, refunds |
| [Cinema_BE/docs/MESSAGING.md](../Cinema_BE/docs/MESSAGING.md) | RabbitMQ events, outbox, idempotency |
| [Cinema_BE/docs/MONITORING.md](../Cinema_BE/docs/MONITORING.md) | Metrics, traces, logs |
| [Cinema_BE/docs/TESTING.md](../Cinema_BE/docs/TESTING.md) | Automated tests and CI |
| [Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md](../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md) | All 101 endpoints and the screens that use them |
| [Cinema_Mobile/docs/STAFF_WORKSPACE.md](../Cinema_Mobile/docs/STAFF_WORKSPACE.md) | Admin website operations |
| `Resource/PRM393.docx` | Course requirements: permission matrix, required technical components |

---

## 2. Overall description

### 2.1 Architecture

```text
 Customer app (Android / web / Windows)      Admin website (Staff / Admin)
                    \                         /
                     \   HTTPS / REST + JWT  /
                      v                     v
            +-----------------------------------------+
            |  API Gateway (YARP)  :5000              |
            |  JWT, route authorization, rate limits, |
            |  locked-account check, CorrelationId    |
            +-----------------------------------------+
                 |                |                 |
                 v                v                 v
          AuthService       MovieService      BookingService ---> PayOS (VietQR, webhook)
          :5100             :5168             :5063           ---> SMTP (Gmail)
          auth_db           movie_db          booking_db
                            showtime_db       payment_db
                                              notification_db
                 \                |                 /
                  +------ RabbitMQ (cinema.events) +
          PostgreSQL 17 (one database per data area)
          Prometheus, Grafana, Jaeger (optional monitoring)
```

### 2.2 Components

| Component | Responsibility | Data |
|---|---|---|
| API Gateway | Single entry point for clients; 24 routes; checks JWTs and route permissions; rate limits; checks for locked accounts and changed roles on every request; service health checks | None |
| AuthService | Registration, OTP, sign-in, refresh tokens, password reset, account and role management | `cinema_auth_db`: users, roles, users_roles, refresh_tokens, otp_codes |
| MovieService | Movies; rooms, seats and seat types; showtimes and prices per seat type; publishes showtime cancellations | `cinema_movie_db`: movies. `cinema_showtime_db`: rooms, seats, showtimes, outbox |
| BookingService | Bookings, seat holds, check-in; PayOS and cash payments; refunds; email notifications | `cinema_booking_db`: bookings, booking_seats, seat_reservations, outbox. `cinema_payment_db`: payments, refunds, outbox. `cinema_notification_db`: notifications |
| RabbitMQ | Asynchronous events between services (exchange `cinema.events`) | Queues and DLQs |
| Flutter app | Customer app (`lib/main.dart`) and admin website (`lib/main_admin.dart`) | Tokens in secure storage |
| Monitoring | Prometheus (metrics), Grafana (dashboard), Jaeger (traces) | In memory / volumes |

### 2.3 Users

| Role | Description | Where |
|---|---|---|
| Guest (signed out) | Browses movies, showtimes and prices | Customer app |
| Customer | Books, pays, manages own tickets and payments | Customer app |
| Walk-in guest | Buys at the counter without an account; gets the ticket by email (if given), on paper or as a QR code on screen | Through staff |
| Staff | Sells tickets, takes payment, checks customers in, manages showtimes and seat maps, handles refunds, sends notifications | Admin website; the phone app only for QR check-in |
| Admin | Everything Staff can do, plus movies, rooms, accounts, revenue and manual refunds | Admin website |
| System | Hold-expiry job, event handling, PayOS webhook | Backend |

An account can have several roles. A Staff or Admin account signed in to the customer app is pointed to the admin website and offered **Check in tickets**. A Customer account opening the admin website is pointed back to the customer site.

### 2.4 Operating environment

- Backend: .NET 8, PostgreSQL 17, RabbitMQ 4, run with Docker Compose (`docker compose up -d --build`), time zone `Asia/Ho_Chi_Minh`.
- Clients: Flutter 3.38+ (Dart 3.13). The customer app runs on Android, browsers (Chrome / Edge) and Windows. The admin website runs in a desktop browser.
- The Android emulator reaches the gateway at `http://10.0.2.2:5000`; a physical phone uses `--dart-define=API_BASE_URL=http://<host IP>:5000`.
- Browser cameras only work on `localhost` or HTTPS.

### 2.5 Design constraints

- **C-01** Clients only call the API Gateway; services and PostgreSQL listen on `127.0.0.1` only.
- **C-02** Each service owns its databases; there are no foreign keys across databases. Cross-service references (userId, showtimeId, seatId…) are checked through APIs or events.
- **C-03** Service structure: Controller → Service → Repository, DTOs, validators, a global exception handler.
- **C-04** Secrets (`.env`) are never committed; the team shares them encrypted with SOPS + age (`secrets.enc.env`).
- **C-05** Containers and seed data use Vietnam local time.

### 2.6 Assumptions and dependencies

- PayOS and SMTP (Gmail App Password) are external services. Without PayOS keys only PayOS payments fail; without SMTP no real email is sent (OTP codes are written to the log in Development).
- The PayOS webhook needs a public address (a tunnel when running locally). Without the webhook the app still confirms payments by asking PayOS (verify).
- The PayOS account is shared by several environments (each developer's machine, Docker) and PayOS refuses repeated order codes, so order codes are generated not to repeat across environments (FR-PAY-01).

### 2.7 Out of scope

- Changing a password with the current password; editing the profile.
- Push notifications and read/unread notification state.
- Automatic refunds through the payment gateway (PayOS has no refund API).
- Accounting, HR, inventory; dedicated POS hardware; Kubernetes, service mesh.

---

## 3. Business rules

| ID | Rule |
|---|---|
| BR-01 | Customer accounts must verify their email with an OTP before signing in. Accounts created by an Admin need no OTP. |
| BR-02 | Every protected API uses JWT; both the gateway and the service check it. |
| BR-03 | Access depends on the role; Customers cannot use management APIs. |
| BR-04 | Each seat belongs to one room and its position (row + number) is unique in that room. |
| BR-05 | A showtime belongs to one movie and one room, and starts before it ends. |
| BR-06 | A room never has two showtimes at overlapping times (409). |
| BR-07 | A seat of a showtime belongs to at most one active booking (held or sold). |
| BR-08 | A booking has one showtime and its seats, and belongs to a customer account, except walk-in tickets sold at the counter. |
| BR-09 | A payment belongs to a booking; booking and payment states only change as shown in section 7. |
| BR-10 | A PayOS webhook must carry a valid HMAC-SHA256 signature before any of its data is used. |
| BR-11 | Events are written to the outbox in the same transaction as the data and are sent only after commit. |
| BR-12 | Calls to other services or PayOS use limited retries and a circuit breaker. |
| BR-13 | An email failure or a stopped RabbitMQ never breaks a booking or payment. |
| BR-14 | Seats are held for 10 minutes; an unpaid booking then becomes `EXPIRED` and its seats are released. |
| BR-15 | Seat price: the showtime price is the standard seat price; VIP adds 20% and sweetbox 30% per seat; the surcharge is rounded to 1,000 VND. The server computes prices and never takes them from the client. |
| BR-16 | Sweetbox seats are always booked, changed and sold as a pair. |
| BR-17 | A customer can cancel a paid ticket for a 100% refund until 2 hours before the show; later they must contact the cinema. Staff and Admin can cancel at any time. |
| BR-18 | A payment has at most one refund request. Refunds are paid by manual bank transfer and recorded with the transfer reference. |
| BR-19 | When a showtime is cancelled, all its active bookings are cancelled; paid ones get a refund request. |
| BR-20 | Late payment (booking already expired): if the seats are still free the ticket is confirmed; if they were sold to someone else, a 100% refund request is created. |
| BR-21 | Only `CONFIRMED` tickets can be checked in, once each, from 3 hours before to 2 hours after the start time. |
| BR-22 | Cash taken must cover the total. If the booking has an unpaid bank-transfer QR, its PayOS link is cancelled before the cash is recorded; if the customer already transferred, cash is refused. |
| BR-23 | Cash and bank transfers both create payment records, so both count in revenue and refunds in the same way. |
| BR-24 | Locking an account or changing its roles takes effect on the next request, even while the old token is still valid. |
| BR-25 | The system never reveals which emails are registered: forgot-password always returns 200, and a wrong email or password gets the same message. |
| BR-26 | Stopping a movie only sets it `INACTIVE`; nothing is deleted and existing tickets stay. A room with showtimes cannot be deleted and its seat map cannot be changed. |

---

## 4. Functional requirements

Priority: **H** (must have), **M** (important), **L** (nice to have).

### 4.1 Authentication and sessions

| ID | Requirement | Priority |
|---|---|---|
| FR-AUTH-01 | Customers register with email, password, full name and an optional phone number. The system sends a verification OTP and issues no token yet. | H |
| FR-AUTH-02 | Sign in with email and password to get an access token (JWT, 60 minutes) and a refresh token (7 days). An unverified email gets 403 `EMAIL_NOT_VERIFIED`. | H |
| FR-AUTH-03 | The JWT carries the userId, email and roles. | H |
| FR-AUTH-04 | The gateway and services check the JWT signature, expiry, issuer and audience before protected APIs. | H |
| FR-AUTH-05 | APIs are authorized by role Customer / Staff / Admin (policies `StaffOrAdmin`, `AdminOnly`, and signed-in by default). | H |
| FR-AUTH-06 | A missing or invalid token gets 401; a signed-in user without the role gets 403. | H |
| FR-AUTH-07 | Email verification with a 6-digit OTP: expires after 5 minutes, at most 5 attempts, 60 seconds between sends, a new code replaces the old one. Verification must include the registered password; on success the user is signed in and gets a welcome email. | H |
| FR-AUTH-08 | Registering again with an unverified email replaces the old details and sends a new code. A verified email is reported as already registered. | M |
| FR-AUTH-09 | Forgot password: an OTP is emailed (the API always returns 200); setting a new password with the OTP revokes every refresh token and marks the email as verified. | H |
| FR-AUTH-10 | Renew the session with the refresh token (rotated; the old one stops working); signing out revokes the refresh token. The app renews automatically when the access token expires. | H |
| FR-AUTH-11 | Show the current account (`GET /api/v1/auth/me`). | M |
| FR-AUTH-12 | The gateway checks the account on every protected request: locked returns 401 `ACCOUNT_LOCKED`; changed roles return 403 `ROLE_CHANGED`; an unreachable AuthService returns 503. The customer app shows the reason and returns to sign-in. | H |
| FR-AUTH-13 | The app and the API check account fields the same way (registration, sign-in, forgot / reset password, accounts created by Admin): email required, at most 150 characters, a domain with a suffix of at least 2 letters, no spaces; a new password of 6–72 characters counted in UTF-8 bytes; full name required, at most 150 characters; phone optional, 8–15 digits, at most 20 characters. Mistakes return 400 with an error per field. The sign-up form asks for the password twice. | H |
| FR-AUTH-14 | Registration, sign-in, OTP, refresh and forgot / reset password are limited to 10 requests per minute per IP; beyond that the API returns 429 with `Retry-After`. | M |
| FR-AUTH-15 | Staff/Admin find a customer account by phone number (digits only; spaces, dots and dashes are ignored) to sell tickets and give points at the counter. Fewer than 8 or more than 15 digits is refused (400); customers get 403. | M |

### 4.2 Account management (Admin)

| ID | Requirement | Priority |
|---|---|---|
| FR-USER-01 | List accounts: search, filter by role and status, paging. | H |
| FR-USER-02 | Show an account. | H |
| FR-USER-03 | Create an account with one or more roles; no OTP needed. | H |
| FR-USER-04 | Change roles: old refresh tokens are revoked and the user must sign in again; saving the same roles keeps the session. | H |
| FR-USER-05 | Lock / unlock an account; an Admin cannot lock their own account. | H |
| FR-USER-06 | List roles (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). | M |

### 4.3 Movies

| ID | Requirement | Priority |
|---|---|---|
| FR-MOV-01 | List movies with paging (Admin). | H |
| FR-MOV-02 | Movie details: title, description, duration, genre, language, release date, poster, trailer, status. | H |
| FR-MOV-03 | Search movies by title. | M |
| FR-MOV-04 | Filter movies by status; the customer home page only shows `ACTIVE` movies. | H |
| FR-MOV-05 | Admin adds a movie. | H |
| FR-MOV-06 | Admin edits a movie, including bringing a stopped movie back (**Show again**). | H |
| FR-MOV-07 | Admin stops a movie (**Stop showing**): it becomes `INACTIVE` and disappears from the customer app; its data and tickets stay. | H |
| FR-MOV-08 | The customer app opens the movie trailer (`trailerUrl`). | L |
| FR-MOV-09 | Film classification under the Cinema Law 2022: P (all ages), K (under 13 with a parent or guardian), T13, T16, T18. Admins pick it when adding / editing a movie (P by default). The rating shows on movie cards, movie details, the booking summary, the counter sale screen and check-in. For anything but P the customer must confirm before the seats are held; at check-in staff are reminded to check ID. | H |
| FR-MOV-10 | The customer home has two tabs: **Now showing** (ACTIVE movies already released or without a release date, newest first) and **Coming soon** (ACTIVE movies released after today, earliest first, the release date on the poster). Movies can be filtered by genre (chips built from the genres of the movies on offer) and searched by title through the API, ignoring case. A movie coming soon shows its release date; without showtimes the page says they will be added closer to the release. | M |
| FR-MOV-11 | Movies have a **director** and **main cast** (optional, at most 150 / 500 characters). Admins fill them in when adding / editing a movie; the movie page shows them. | L |
| FR-MOV-12 | **Movie reviews**: customers whose ticket was checked in (they watched the movie) rate it 1–5 stars with a comment (at most 1,000 characters) from the ticket page. One review per customer per movie: sending again edits it, and it can be deleted. A ticket not checked in is refused (400) with the reason; someone else's ticket is treated as missing (404). The movie page shows everyone the average, the count per star and the newest reviews; the reviewer name is the account's full name (or a masked email). Admins remove unsuitable reviews from Admin → Movies → Reviews. | M |

### 4.4 Rooms and seats

| ID | Requirement | Priority |
|---|---|---|
| FR-ROOM-01 | List rooms and search them by name (Staff/Admin). | H |
| FR-ROOM-02 | Room details with the seat map by row, coloured by seat type. | H |
| FR-ROOM-03 | Admin creates a room from rows × seats per row; its seats are created at once. | H |
| FR-ROOM-04 | Admin renames a room; its seats stay. | M |
| FR-ROOM-05 | Admin deletes a room without showtimes (with its seats); a room with showtimes is refused. | M |
| FR-SEAT-01 | Generate a standard seat map for an empty room (Staff/Admin). | H |
| FR-SEAT-02 | Show one seat. | L |
| FR-SEAT-03 | Get the seat map of a room (signed-in users). | H |
| FR-SEAT-04 | Admin deletes a seat (API only). | L |
| FR-SEAT-05 | Change one seat's type: NORMAL / VIP / SWEETBOX. A sweetbox changes with its pair; a seat without a pair cannot become a sweetbox. | H |
| FR-SEAT-06 | Change many seats at once on the map: pick a type, then click, drag across seats or click a row letter to change the whole row. A row with an unpaired seat returns 400. | M |
| FR-SEAT-07 | Admin changes a room's seat count: new seats fill the last row, then new rows (up to row Z); removing takes the last seats; a leftover half sweetbox becomes standard. | M |
| FR-SEAT-08 | Seats cannot be generated, retyped or recounted in a room that has showtimes (sold tickets stay correct). | H |
| FR-SEAT-09 | Seat maps on the admin website refresh every 5 seconds when someone else changes them. | L |

### 4.5 Showtimes

| ID | Requirement | Priority |
|---|---|---|
| FR-SHOW-01 | List showtimes with paging and filters. | H |
| FR-SHOW-02 | Staff/Admin create a showtime: movie, room, start, end, standard seat price, status. | H |
| FR-SHOW-03 | Showtime details with `seatPrices`: the price of one seat of each type. | H |
| FR-SHOW-04 | Staff/Admin edit a showtime; overlaps are still checked. | H |
| FR-SHOW-05 | Staff/Admin cancel a showtime (status `CANCELLED`, not deleted); its tickets are cancelled and refunded as in BR-19. | H |
| FR-SHOW-06 | Get showtimes open for sale (`OPEN`, not started). | H |
| FR-SHOW-07 | Get showtimes of a movie. | M |
| FR-SHOW-08 | Get open showtimes of a movie; the customer app shows those in the next 7 days. | H |
| FR-SHOW-09 | Find showtimes in a time range (Staff/Admin). | H |
| FR-SHOW-10 | Open / close sales of a showtime (`OPEN` ↔ `CLOSED`). | M |
| FR-SHOW-11 | Overlapping showtimes in one room return 409. | H |
| FR-SHOW-12 | Staff see a showtime's seat map (free / awaiting payment / sold / checked in), open a ticket by clicking its seat, and see the customer list (email, seats, booking code, check-in time); refreshed every 5 seconds. | M |
| FR-SHOW-13 | Every showtime has a **format: 2D, 3D or IMAX** (2D by default, kept when left out on edit, anything else refused with 400). The stored price is the standard seat at 2D; 3D adds 20,000 VND and IMAX 40,000 VND to the standard seat before the VIP / sweetbox surcharges. Seat prices shown to customers and charged by BookingService include it. The app names the format next to the room (e.g. "Room 1 · IMAX"). | M |

### 4.6 Bookings

| ID | Requirement | Priority |
|---|---|---|
| FR-BOOK-01 | Create a booking from a showtime and seats: the showtime must be `OPEN` and not started, with at least one seat and no duplicates. The server takes the show time, movie title and prices from MovieService. The booking is `PENDING` and holds the seats for 10 minutes. | H |
| FR-BOOK-02 | Show a booking: to its owner or to Staff/Admin. | H |
| FR-BOOK-03 | Staff/Admin list bookings and filter by status and creation date. | H |
| FR-BOOK-04 | Customers see their own tickets in **Active** and **History**. | H |
| FR-BOOK-05 | Confirm a booking after a successful payment (see 4.7 and 4.9). | H |
| FR-BOOK-06 | Cancel a booking: an unpaid one is cancelled and its seats released; a paid one follows BR-17. A customer cancelling a paid ticket creates a refund request: the booking becomes `REFUND_PENDING` and keeps its seats until staff handle it. | H |
| FR-BOOK-07 | Get the held / sold seats of a showtime. | H |
| FR-BOOK-08 | A seat held or sold by another booking returns 409. | H |
| FR-BOOK-09 | Sweetbox seats must be booked as a full pair (the server refuses half a pair). | H |
| FR-BOOK-10 | A background job runs every 30 seconds, marks bookings past their hold `EXPIRED` and releases their seats. | H |
| FR-BOOK-11 | The seat picker refreshes every 5 seconds; a selected seat taken by someone else is unselected and the customer is told. | M |
| FR-BOOK-12 | Ticket statistics per showtime for Staff/Admin: bookings, seats sold, seats held, checked in (by a list of ids or by a start-time range of at most 31 days). | M |
| FR-BOOK-13 | **Snacks with tickets**: customers (booking summary) and the counter (sale screen) pick items from the menu, 1–20 of each, at most 10 different items. Prices come from the menu on sale; the snacks are part of the total, so payment, revenue and refunds include them. The order keeps the name and price at the time of purchase. Snacks show on the ticket, the payment page, the ticket email and the printed ticket. Stopped items are refused (400). | M |
| FR-BOOK-14 | Admins manage the snacks menu (Admin → Snacks): add, edit name / price / description / image / order, stop or resume selling (items are never deleted). Customers only see items on sale. | M |
| FR-BOOK-15 | **Promotions**: only the ticket price is discounted (never snacks), by a percentage (optionally capped) or an amount, at most 90% of the tickets, rounded down to 1,000 VND. Conditions: running period, day of the week of the show, minimum tickets, maximum uses. A promotion without a code applies by itself (the biggest discount wins); a promo code typed by the customer or the counter replaces it — one promotion per booking. A wrong or unusable code is refused (400) with the reason. The server works the discount out again when the booking is made; a use is only counted once the ticket is paid. The discount shows on the ticket, the payment page, the ticket email and the printed ticket. | M |
| FR-BOOK-17 | **Member points**: customers with an account earn points once a ticket is paid, on the amount actually paid and by tier: Member 5%, VIP (from 2,000,000 VND spent) 7%, VVIP (from 5,000,000 VND) 10%; 1 point = 1,000 VND. When booking (app or counter) points can pay at most 50% of the price (after promotions). An unpaid hold that expires or is cancelled gives the used points back; a paid ticket that is cancelled or refunded gives the used points back, takes the earned points back and lowers the total spent. Walk-in guests have no points. Customers see their member card (points, tier, what is left to the next tier, history) on the account page. | M |
| FR-BOOK-18 | Admins see customers with their points, tier and total spent (Admin → Members), open the history and add or take away points with a reason (never below zero). The counter sees the card of a customer found by phone. | M |
| FR-BOOK-16 | Admins manage promotions (Admin → Promotions): add, edit, pause / resume (never deleted), see how often each was used. Promo codes are unique (409). Guests only see the automatic promotions that are running. | M |

### 4.7 Payments (PayOS)

| ID | Requirement | Priority |
|---|---|---|
| FR-PAY-01 | Create a PayOS payment link for a `PENDING` booking. One payment per booking; asking again returns the existing link. The PayOS order code is the booking id × 1,000,000 plus the six random digits that end the booking code: stable per booking and never repeating an order of another environment on the shared PayOS account. The link expires with the seat hold. | H |
| FR-PAY-02 | Verify a payment by order code (or booking id): paid at PayOS means payment `SUCCESS` and booking `CONFIRMED`; cancelled on the PayOS page means payment `FAILED`, booking `CANCELLED` and seats released at once. Calling it again is safe. | H |
| FR-PAY-03 | Show a payment: to the ticket owner or to Staff/Admin. | H |
| FR-PAY-04 | Customers see their payment history. | M |
| FR-PAY-05 | Show the payments of a booking. | M |
| FR-PAY-06 | Refunds: see section 4.8. | H |
| FR-PAY-07 | Receive the PayOS webhook: check the HMAC-SHA256 signature (400 when wrong); an unknown order or wrong amount returns 200 and is ignored; a repeated webhook confirms and emails nothing twice. The payer's account (number, name, bank) is stored for refunds. | H |
| FR-PAY-08 | Late payment follows BR-20. | M |
| FR-PAY-09 | Staff/Admin list payments and re-verify a pending PayOS payment. | M |
| FR-PAY-10 | Admin sees revenue for a period: payments received, revenue (`SUCCESS` + `REFUND_PENDING`), amount refunded (`REFUNDED`). | M |
| FR-PAY-11 | While open, the app's payment page checks the booking every 5 seconds and asks PayOS every 30 seconds; there is no "I have paid" button. | M |

### 4.8 Cancellations and refunds

| ID | Requirement | Priority |
|---|---|---|
| FR-REF-01 | A refund request (`PENDING`) is created when: a customer cancels a paid ticket in time; Staff/Admin cancel a paid ticket; a showtime is cancelled; a late payment lost its seats; an Admin refunds a payment manually. The payment becomes `REFUND_PENDING` and the customer gets an email. | H |
| FR-REF-02 | Staff/Admin list refund requests (filter by status) and see their details: amount, reason, payer account. | H |
| FR-REF-03 | After transferring the money, staff record the transfer reference: refund `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` with seats released, and an email with the reference. | H |
| FR-REF-04 | Staff reject a request (reason required, only while `PENDING`): the payment returns to `SUCCESS` and the booking to `CONFIRMED` with its seats; the customer sees the reason on the ticket and gets an email. Refunds of tickets the cinema cancelled cannot be rejected. | H |
| FR-REF-05 | A rejected request is reopened if the cinema later cancels the ticket or the showtime. | M |
| FR-REF-06 | Customers see the refund status of their ticket. | M |
| FR-REF-07 | Each payment has only one refund request, even when an event is delivered again. | H |

### 4.9 Counter sales

| ID | Requirement | Priority |
|---|---|---|
| FR-POS-01 | Staff/Admin sell tickets to a **walk-in guest** (no account; email and phone optional) or a **member** (account ID + email, or found by phone number; members use and earn points): choose a movie, a showtime in the next 7 days and seats on the map (sweetbox in pairs, priced by type). | H |
| FR-POS-02 | After the seats are held, the **Take payment** screen shows the ticket, the customer, the total, the hold countdown and an optional email for the ticket. | H |
| FR-POS-03 | **Cash**: enter the cash received (with round-amount buttons); the screen shows the change and refuses less than the total. The server records a `CASH` payment as `SUCCESS` (reference `CASH-<booking code>`) and confirms the ticket. | H |
| FR-POS-04 | **Bank transfer**: show the PayOS VietQR for the customer's banking app (for a link made earlier, a QR code of its checkout page); the screen checks every 3 seconds and switches to paid when the money arrives. | H |
| FR-POS-05 | Switching from bank transfer to cash follows BR-22: the PayOS link is cancelled and that payment becomes `FAILED`; if the customer already transferred, cash returns 409. | H |
| FR-POS-06 | An email given at the counter is saved on the booking, so later cancellation and refund emails reach the customer too. | M |
| FR-POS-07 | After payment: the ticket QR code; **Print ticket** (web, 80 mm receipt paper); **Check in now** when the show starts within 3 hours; **Sell another ticket**. Without an email, print the ticket or let the customer photograph the QR code. | H |
| FR-POS-08 | Paid tickets have **Show ticket** on their booking page, to print again or check in. | M |

### 4.10 Check-in at the cinema

| ID | Requirement | Priority |
|---|---|---|
| FR-CHK-01 | A paid ticket has a QR code holding its booking code, shown in the customer app, in the confirmation email and on the printed ticket. | H |
| FR-CHK-02 | Staff/Admin look a ticket up by code (case-insensitive): movie, time, room, seats, total, status. | H |
| FR-CHK-03 | Check-in follows BR-21; otherwise 409 with the reason (unpaid, cancelled, refund pending, too early, too late, already checked in at a given time). When two counters scan the same ticket, the second gets 409. | H |
| FR-CHK-04 | Scan the QR code with a phone camera (app), a laptop webcam or USB camera (admin website), or type the code / use a handheld scanner (code + Enter). | H |
| FR-CHK-05 | The check-in time shows on the customer's ticket, the booking page, the seat map and the showtime's customer list. | M |

### 4.11 Notifications and email

| ID | Requirement | Priority |
|---|---|---|
| FR-NOTI-01 | Customers see their notifications and details and open the related ticket. Admins see all notifications. | M |
| FR-NOTI-02 | Staff/Admin write an email notification to a ticket's customer (walk-in guests with an email included). | M |
| FR-NOTI-03 | Send a notification; a failure is stored as `FAILED` with the error, and the same notification can be sent again. | M |
| FR-NOTI-04 | Show a notification. | M |
| FR-NOTI-05 | Delete a notification: the recipient deletes their own, an Admin any (API only). | L |
| FR-NOTI-06 | Emails sent from events: ticket confirmed (with an inline QR image), ticket cancelled, ticket expired, refund requested, refund rejected, refund completed. Each event is emailed exactly once. Tickets without an email are skipped. | H |
| FR-NOTI-07 | AuthService emails OTP codes (verification, password reset) and a welcome email. | H |

### 4.12 Dashboards and reports

| ID | Requirement | Priority |
|---|---|---|
| FR-DASH-01 | **Today** block (Staff and Admin): bookings made today; today's showtimes with bookings (x / total); tickets for today's shows; how many checked in. | M |
| FR-DASH-02 | Showtime board: **Now showing** (every show playing, watching now = checked in, tickets sold / capacity, time left); **Up next** (next 3 shows: booked, awaiting payment, checked in early); **Just finished** (last 3 shows: tickets sold, people who came). Clicking a show opens its seat map and customer list. Refreshes every minute. | M |
| FR-DASH-03 | The Staff dashboard has **Needs attention**: unpaid bookings and pending refund requests; shortcuts to **Sell tickets** and **Check in**. | M |
| FR-DASH-04 | The Admin dashboard: this month's bookings and revenue, amount refunded, movies now showing, today's showtimes, account statistics (total, active, locked). Each part loads on its own, so one failure does not break the others. | M |

---

## 5. User interface requirements

### 5.1 Customer app (Android, web, Windows)

| Screen | Functions |
|---|---|
| Home | Movies now showing, search box (filters the loaded list) |
| Movie details | Movie information, trailer, showtimes for the next 7 days by day, with room and price |
| Seat picker | Map by row, colour per type, price legend, sweetbox in pairs, total, auto refresh |
| Booking summary | Movie, showtime, seats, total → hold seats |
| Payment / result | Hold countdown, **Pay with PayOS** / **Continue with PayOS**, automatic result checks |
| My tickets | Active / History tabs; ticket page with QR code, check-in time, cancel / request refund, refund status and rejection reason |
| Notifications | List, details, open the related ticket |
| Payment history | Transactions and their status |
| Account | Profile, change password through OTP, sign out |
| Sign in / sign up / OTP / forgot password | Forms checked field by field (FR-AUTH-13), resend countdown |
| Staff on a phone | Pointer to the admin website and **Check in tickets** (camera QR scanner) |

### 5.2 Admin website

Navigation on the left; on windows narrower than 640 px it opens from a menu button. Staff: **Dashboard / Operations / Check-in / Profile**. Admins also get **Movies / Rooms / Accounts**.

| Screen | Roles | Functions |
|---|---|---|
| Dashboard | Staff, Admin | FR-DASH-01..04 |
| Operations | Staff, Admin | Bookings / Showtimes / Rooms / Payments / Refunds with filters and paging |
| Sell tickets, Take payment | Staff, Admin | FR-POS-01..08 |
| Check-in | Staff, Admin | FR-CHK-01..05 |
| Booking / payment / refund details | Staff, Admin | Cancel, check in, take payment, verify PayOS, record / reject refunds, notify the customer |
| Showtimes | Staff, Admin | Create, edit, open / close sales, cancel, seat map and customer list |
| Room seat map | Staff, Admin | Change one seat or paint many; Admin changes the seat count |
| Movies | Admin | Add, edit (also director and cast), stop / show again, filter, search; see and remove a movie's reviews |
| Rooms | Admin | Add a room as rows × seats, rename, delete, open the seat map |
| Snacks | Admin | Snacks menu: add, edit, stop / resume selling |
| Promotions | Admin | Automatic deals and promo codes: add, edit, pause / resume, see uses |
| Members | Admin | Customers with points, tier and total spent; points history; add / take away points |
| Accounts | Admin | Search, filter, paging, details, create, change roles, lock / unlock |
| Profile | Staff, Admin | Profile, change password through OTP, sign out |

### 5.3 General

- **UI-01** Dark theme with cyan accents, one component set for the app and the admin website.
- **UI-02** Input mistakes show right under the field; server errors show the server's message (`detail` or `errors`).
- **UI-03** Every list has loading, error-with-retry and empty states.
- **UI-04** Important changes (cancel a ticket, take cash, refund, lock an account) ask for confirmation.
- **UI-05** Layouts adapt to phones, tablets and desktops; the page never scrolls sideways.
- **UI-06** Web routes keep the record id in the URL, so reloading opens the same record.

---

## 6. Main workflows

### 6.1 Registration and email verification
1. The customer registers → AuthService creates an unverified account and emails an OTP.
2. The customer enters the OTP with the password → the account is verified, tokens are issued, a welcome email is sent.
3. Signing in before verifying → 403 `EMAIL_NOT_VERIFIED` → the app opens the OTP screen; a new code can be requested after 60 seconds.

### 6.2 Online booking and payment
1. The customer picks a movie → showtime → seats → confirms: booking `PENDING`, seats held for 10 minutes, event `booking.created`.
2. The app creates a PayOS link → the customer pays with a banking app.
3. PayOS calls the webhook (or the app calls verify) → payment `SUCCESS`, booking `CONFIRMED`, event `booking.confirmed`.
4. A consumer emails the ticket with its QR code. The ticket appears under **Active**.
5. Unpaid after 10 minutes → the job sets `EXPIRED`, releases the seats, marks the payment `FAILED` and emails the customer.

### 6.3 Cancellation and refund
1. The customer cancels a paid ticket (≥ 2 hours before) → booking `REFUND_PENDING`, event `booking.refund_requested` → refund request created, payment `REFUND_PENDING`, email.
2. Staff open **Operations → Refunds** and transfer the money outside the system.
3. Staff record the transfer reference → `COMPLETED` / `REFUNDED`, booking `CANCELLED`, seats released, email. Or they reject it with a reason → the booking returns to `CONFIRMED`.

### 6.4 Counter sale
1. Staff open **Sell tickets** → walk-in guest / member → movie, showtime, seats → seats held.
2. **Take payment**: cash (enter the amount, see the change, confirm) or bank transfer (VietQR, confirmed automatically).
3. The ticket is `CONFIRMED` with a payment record; emailed if an email was given; printed or shown as a QR code; **Check in now** if the show is about to start.

### 6.5 Check-in
1. The customer shows the QR code (app, email, printed ticket) → staff scan it with a camera / webcam / scanner or type the code.
2. The ticket details appear → **Check in** → the check-in time is stored; the dashboard counts the customer as watching.

### 6.6 Showtime cancellation
1. Staff cancel a showtime → MovieService writes `showtime.cancelled` to its outbox.
2. BookingService cancels every active ticket of that showtime; paid tickets get refund requests; customers are emailed.

### 6.7 Account lock / role change
1. An Admin locks an account or changes its roles. A role change revokes the old refresh tokens; a locked account can no longer sign in or renew its session.
2. That user's next request through the gateway gets 401 `ACCOUNT_LOCKED` or 403 `ROLE_CHANGED` → the app shows the reason and returns to sign-in.

---

## 7. States

### 7.1 Booking
| From | To | When |
|---|---|---|
| — | `PENDING` | Booking created, seats held for 10 minutes |
| `PENDING` | `CONFIRMED` | Payment succeeded (PayOS, cash) |
| `PENDING` | `EXPIRED` | Hold ran out |
| `PENDING` | `CANCELLED` | Customer / staff cancel, customer cancels on the PayOS page, showtime cancelled |
| `EXPIRED` | `CONFIRMED` | Late payment while the seats are still free |
| `CONFIRMED` | `REFUND_PENDING` | Customer cancels in time (seats kept) |
| `REFUND_PENDING` | `CANCELLED` | Staff record the refund (seats released) |
| `REFUND_PENDING` | `CONFIRMED` | Staff reject the refund |
| `CONFIRMED` | `CANCELLED` | Staff/Admin cancel, showtime cancelled (refund created) |

Check-in is the `checkedInAt` attribute of a `CONFIRMED` ticket, not a separate state.

### 7.2 Payment
`PENDING` → `SUCCESS` / `FAILED`; `FAILED` → `SUCCESS` (PayOS reports payment after the expiry job); `SUCCESS` → `REFUND_PENDING` → `REFUNDED`; `REFUND_PENDING` → `SUCCESS` (refund rejected). Methods: `PAYOS`, `CASH`.

### 7.3 Refund
`PENDING` → `COMPLETED` / `REJECTED`; `REJECTED` → `PENDING` (the cinema cancels the ticket later).

### 7.4 Others
| Object | States |
|---|---|
| Showtime | `OPEN` ↔ `CLOSED`; `OPEN` / `CLOSED` → `CANCELLED` (final) |
| Movie | `ACTIVE` ↔ `INACTIVE` |
| Notification | `PENDING` → `SENT` / `FAILED`; `FAILED` → `SENT` (resent) |
| Account | Unverified → verified; active ↔ locked |

---

## 8. Permission matrix

| Function | Guest | Customer | Staff | Admin |
|---|:-:|:-:|:-:|:-:|
| Register / sign in | ✓ | ✓ | ✓ | ✓ |
| View movies and open showtimes | ✓ | ✓ | ✓ | ✓ |
| Add / edit / stop movies | | | | ✓ |
| Create / edit / open-close / cancel showtimes | | | ✓ | ✓ |
| View rooms; generate seats, change seat types | | | ✓ | ✓ |
| Create / rename / delete rooms; change seat count; delete seats | | | | ✓ |
| Book for oneself, view / cancel own tickets | | ✓ | ✓ | ✓ |
| Pay own tickets with PayOS | | ✓ | ✓ | ✓ |
| Counter sales (walk-in / member), cash, transfer QR | | | ✓ | ✓ |
| View all tickets and payments; check in | | | ✓ | ✓ |
| Record / reject refunds | | | ✓ | ✓ |
| Manual refund of a payment | | | | ✓ |
| Write and send notifications to customers | | | ✓ | ✓ |
| View own / everyone's notifications | | ✓ / | ✓ / | ✓ / ✓ |
| View revenue | | | | ✓ |
| Manage accounts and roles | | | | ✓ |

**Compared with the matrix in the course brief (`PRM393.docx`):**

| Difference | Brief | System | Reason |
|---|---|---|---|
| Create / update movies | Staff, Admin | Admin only | The catalogue is shared data, so only administrators change it; staff focus on operations |
| Manage rooms | Staff, Admin | Staff view rooms and change seat types; only Admin creates / deletes rooms | Protects seat maps that already have tickets |
| Create booking, payment | Customer only | Customer, plus Staff/Admin at the counter | Added requirement: selling to people who come to the cinema |
| Refund | Admin only | Staff record / reject; Admin also refunds manually | Refunds are daily counter work |

---

## 9. Data

| Database | Main tables | Notes |
|---|---|---|
| `cinema_auth_db` | `users`, `roles`, `users_roles`, `refresh_tokens`, `otp_codes` | Passwords and OTP codes stored only as BCrypt hashes; unique email |
| `cinema_movie_db` | `movies` | Status `ACTIVE` / `INACTIVE`; rating `age_rating` P / K / T13 / T16 / T18; `director`, `cast_members` |
| `cinema_showtime_db` | `rooms`, `seats`, `showtimes`, `outbox_messages` | Seat unique by (room, row, number); seat type NORMAL / VIP / SWEETBOX; showtime format 2D / 3D / IMAX |
| `cinema_booking_db` | `bookings`, `booking_seats`, `seat_reservations`, `concession_items`, `booking_concessions`, `promotions`, `loyalty_accounts`, `loyalty_transactions`, `movie_reviews`, `outbox_messages` | `user_id` NULL for walk-in guests; `customer_email`, `customer_phone`, `checked_in_at`, `expires_at` |
| `cinema_payment_db` | `payments`, `refunds`, `outbox_messages` | Method `PAYOS` / `CASH`; payer account kept for refunds |
| `cinema_notification_db` | `notifications` | Unique by `event_id` so nothing is sent twice |

- Schemas and seed data live in the **Project-Cinema-DB** repository: dumps for new databases and a `migrations/` folder for existing ones (safe to run more than once).
- The seed has demo accounts, sample movies, Standard / IMAX rooms with different seat maps, and a one-month schedule for every movie now showing (a migration adds more when it runs out).

---

## 10. External interfaces

### 10.1 API

- 101 business endpoints, REST/JSON, through the gateway at `http://<host>:5000`. Full list: [MOBILE_UI_ENDPOINTS.md](../Cinema_Mobile/docs/MOBILE_UI_ENDPOINTS.md).

| Group | Prefix | Endpoints |
|---|---|---|
| Authentication, accounts, roles | `/api/v1/auth` | 16 |
| Movies | `/api/v1/movies` | 9 |
| Rooms, seats | `/api/rooms`, `/api/seats` | 13 |
| Showtimes | `/api/showtimes` | 11 |
| Bookings, check-in | `/api/v1/bookings` | 13 |
| Payments, refunds | `/api/v1/payments` | 17 |
| Notifications | `/api/v1/notifications` | 6 |
| Snacks | `/api/v1/concessions` | 3 |
| Promotions | `/api/v1/promotions` | 4 |
| Member points | `/api/v1/loyalty` | 4 |
| Movie reviews | `/api/v1/reviews` | 5 |

- Lists are paged (`page` / `size` or `pageNumber` / `pageSize`), at most 50 records per page, sorted with `sortBy` / `sortDir`.
- Errors follow ProblemDetails: `title`, `status`, `detail`, `errors` (per field), `errorCode` (business code).
- Every service exposes Swagger (`/swagger`), `/health`, `/health/live` and `/metrics`.

### 10.2 PayOS
- Create, look up and cancel payment links through the merchant API; the webhook `POST /api/v1/payments/payos/webhook` is signed with the Checksum Key.
- A new link also returns its VietQR string (`qrCode`) for the counter screen.

### 10.3 Email (SMTP)
- Gmail SMTP on port 587, TLS, App Password; 10-second timeout.
- Ticket emails embed the QR image (`cid:`) so it shows directly in Gmail / Outlook; user-entered text is HTML-encoded.

### 10.4 RabbitMQ
| Event | Published by | Handled by |
|---|---|---|
| `booking.created`, `booking.confirmed`, `booking.cancelled`, `booking.expired`, `booking.refund_requested` | BookingService | Emails; fail / cancel unpaid payments; create refund requests |
| `payment.created`, `payment.succeeded`, `payment.failed`, `payment.refund_requested`, `payment.refund_rejected`, `payment.refunded` | BookingService | Emails to the customer |
| `showtime.cancelled` | MovieService | Cancels the showtime's tickets |

---

## 11. Non-functional requirements

| ID | Category | Requirement |
|---|---|---|
| NFR-SEC-01 | Security | Passwords and OTP codes are hashed with BCrypt; responses never include stack traces or internal errors. |
| NFR-SEC-02 | Security | JWTs are signed with a secret of at least 32 characters; access tokens last 60 minutes; refresh tokens last 7 days, rotate, and are revoked on sign-out, password reset and role change. |
| NFR-SEC-03 | Security | Authorization is checked at the gateway (per route) and in the service (per record, e.g. only one's own tickets). |
| NFR-SEC-04 | Security | Rate limits: 100 requests per minute per IP for all APIs, 10 for authentication APIs. |
| NFR-SEC-05 | Security | Only the gateway is reachable from the network; services, PostgreSQL, RabbitMQ and monitoring listen on `127.0.0.1`. |
| NFR-SEC-06 | Security | Secrets are not in the source code; they are shared with SOPS + age. |
| NFR-SEC-07 | Security | The server validates every input (DataAnnotations + validators); clients validate first to report mistakes early. |
| NFR-PERF-01 | Performance | Every list is paged, at most 50 records. |
| NFR-PERF-02 | Performance | Holding seats, confirming tickets and taking payment lock the booking row (`SELECT … FOR UPDATE`) in a transaction, so seats are never sold twice and money is never taken twice under concurrent use. |
| NFR-REL-01 | Reliability | Calls to MovieService / PayOS retry transient errors at most twice (creating a PayOS link is never retried); a circuit breaker opens for 15 seconds after repeated failures and returns 503 at once. |
| NFR-REL-02 | Reliability | Outbox: no event is lost while RabbitMQ is down; it is sent when RabbitMQ is back. |
| NFR-REL-03 | Reliability | Consumers are idempotent; failing messages are retried 3 times and then moved to a DLQ. |
| NFR-REL-04 | Reliability | The gateway checks each service's `/health/live` every 10 seconds and returns 503 at once for a dead service. |
| NFR-OBS-01 | Observability | Prometheus metrics for HTTP, runtime and business events (bookings, payments, refunds, outbox); Grafana dashboard "Cinema - Tổng quan". |
| NFR-OBS-02 | Observability | OpenTelemetry traces to Jaeger across the gateway, services, SQL, PayOS and RabbitMQ. |
| NFR-OBS-03 | Observability | Logs carry TraceId, SpanId and CorrelationId; every response has an `X-Correlation-ID` header. |
| NFR-MAINT-01 | Maintainability | Layered services, DTOs, validators and a global exception handler everywhere; documentation in `docs/`. |
| NFR-MAINT-02 | Maintainability | GitHub Actions runs the backend tests and `flutter analyze` / `flutter test` / web builds for every pull request into `dev` / `main`. |
| NFR-DEP-01 | Deployment | One command, `docker compose up -d --build`, runs the whole backend; monitoring through the `monitoring` profile. |
| NFR-USE-01 | Usability | The customer app supports Android, web and Windows; the admin website is designed for desktops and still works on narrow screens. |
| NFR-COMP-01 | Compatibility | Web cameras need `localhost` or HTTPS; a real deployment must use HTTPS. |

---

## 12. Error handling

| HTTP | Meaning | Examples |
|---|---|---|
| 400 | Invalid data | Bad email format, no seats, wrong OTP (with attempts left), not enough cash |
| 401 | Not authenticated | Missing / invalid / expired token; `ACCOUNT_LOCKED` |
| 403 | Not allowed | A customer calling a staff API; `EMAIL_NOT_VERIFIED`; `ROLE_CHANGED` |
| 404 | Not found | Movie, showtime, booking or booking code does not exist |
| 409 | State conflict | Seat already held; room schedule overlap; ticket already checked in; booking already paid; cancelling too late |
| 429 | Too many requests | Rate limit exceeded; OTP requested too soon (with `Retry-After`) |
| 500 | Unexpected error | Logged as an error with the stack trace; the response reveals no details |
| 503 | Service unavailable | Dependency down / circuit open; PayOS not configured; OTP email could not be sent |

---

## 13. Testing and acceptance

### 13.1 Automated tests

| Part | Tests | Main coverage |
|---|---|---|
| AuthService | 28 | Registration, OTP and OTP lockout, sign-in, refresh rotation, sign-out, account locking, role changes, field validation |
| ApiGateway | 21 | Blocks tokens of locked accounts and changed roles before forwarding, never forwards when the account check fails, 503 when AuthService does not answer |
| MovieService | 24 | Showtimes, overlaps, cancellation and its event, seats, sweetbox pairs, seat counts, prices per seat type |
| BookingService | 71 | Bookings, seat holds, webhook, expiry, late payment, refunds, real RabbitMQ, authorization, check-in, statistics, revenue, counter sales |
| Flutter | 195 | Widget tests of customer and admin screens, validators, payment flow, check-in, counter |

Backend integration tests run against real PostgreSQL and RabbitMQ (Testcontainers); PayOS, MovieService and SMTP are replaced by fakes.

### 13.2 Acceptance criteria

1. A customer can register, verify the OTP, sign in and receive a JWT.
2. Each role can only call the APIs it is allowed; account locks and role changes take effect at once.
3. Customers can see movies, showtimes, free seats and prices per seat type.
4. A seat can never belong to two active bookings of the same showtime.
5. Bookings and payments are always in a valid state from section 7.
6. PayOS webhooks are signature-checked before any update.
7. When PayOS or MovieService fails, the API returns 503 quickly and nothing hangs.
8. RabbitMQ events are published and handled; repeated messages never send emails or refunds twice.
9. Ticket (with QR), cancellation, expiry and refund emails follow their events.
10. Staff can sell at the counter for cash or by bank transfer, and that money appears in revenue.
11. Staff can check tickets in by QR within the allowed window, once per ticket.
12. Refunds complete the full cycle: request → recorded / rejected → email.
13. The whole backend runs with Docker Compose; every service has Swagger, health checks and metrics.

---

## 14. Known limitations and future work

| Limitation | Impact | Way forward |
|---|---|---|
| PayOS has no refund API | Refunds are manual bank transfers | Integrate a gateway with a refund API if needed |
| No password change with the current password, no profile editing | Password changes use the OTP flow | Add the endpoints |
| Notifications have no read state or push | Customers must open the app to see them | Add read state and FCM |
| The customer ticket list loads the first page (50 tickets) | Customers with very many tickets do not see the oldest | Load more on scroll |

---

## Appendix A. Mapping from SRS 1.0

Comments in the code and technical documents may cite section numbers of version 1.0:

| Version 1.0 | Version 2.0 |
|---|---|
| §4 Business Rules (BR 1–13) | Section 3 (BR-01..BR-13 keep their meaning, BR-14..BR-26 added) |
| §5 System Architecture | Sections 2.1, 2.2 (the six planned services became three business services) |
| §6 Functional Requirements | Section 4 (old FR IDs kept, new ones added) |
| §8 Core Business Workflows | Section 6 |
| §9 Role & Permission Matrix | Section 8 |
| §11 Non-Functional Requirements | Section 11 |
| §12 Error Handling | Section 12 |
| §13.1 RabbitMQ, §13.2 Circuit Breaker | Section 10.4, NFR-REL-01..03 |
| §14 Payment – PayOS | Sections 4.7, 4.8, 10.2 |
| §18 Testing Scope, §19 Acceptance Criteria | Section 13 |

## Appendix B. Demo environment

| Component | Address |
|---|---|
| API Gateway | `http://localhost:5000` (Android emulator: `http://10.0.2.2:5000`) |
| Customer app (web) | `http://localhost:8080` |
| Admin website | `http://localhost:8081` |
| Swagger | Auth `:5100`, Movie `:5168`, Booking `:5063` (`/swagger`) |
| RabbitMQ | `http://localhost:15672` |
| Grafana / Prometheus / Jaeger | `:3000` / `:9090` / `:16686` |

Seed accounts (password `123456`): `admin@cinema.com` (Admin), `nhanvien1@cinema.com` (Staff), `khachhang1@gmail.com` (Customer).
