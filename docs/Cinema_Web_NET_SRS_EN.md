# SOFTWARE REQUIREMENTS SPECIFICATION

# Cinema — Web .NET

| Item | Value |
| --- | --- |
| Version | 3.0 |
| Baseline date | 2026-10-28 (Asia/Saigon) |
| Language | English |
| Evidence status | Static code/document baseline; runtime verification not performed |
| Paired document | [Cinema_Web_NET_SRS_VI.md](Cinema_Web_NET_SRS_VI.md) |

## 1. Introduction

CosmoQ Cinema is one cinema booking and management system with multiple clients. This course-specific SRS refines consolidated SRS 2.0 using the current checkout; it does not define a second independent product. Executable routes/controllers/services/models take precedence over dated prose. SRS 1.0 is historical intent.

H = mandatory; M = important; L = optional. Implemented means source exists, not that integration tests passed. Each EN/VI pair uses identical IDs, scope, priority and criteria; neither language is a summary.

## 2. Purpose

Provide the contract for development, test-case design, acceptance and course defence. Each FR identifies actors, conditions, trigger, flow, exceptions, result and acceptance criteria, and traces to use cases, screens, APIs and source/test evidence.

## 3. Scope

Include customer browser screens, Staff/Admin browser workspace and the shared ASP.NET Core 8 backend for authentication, catalogue, scheduling, bookings, payments/refunds and notifications. Customer web is included because main.dart is built for browsers as well as native devices.

Technology boundary: no MVC .cshtml, Razor/Blazor .razor or separate .NET UI project is present. “Web .NET” names the course scope: ASP.NET Core REST plus its existing Flutter Web clients. A mandatory .NET-rendered UI is [TO BE CONFIRMED], not implemented evidence.

## 4. Overall Description

```text
Flutter main.dart (customer web) + main_admin.dart (admin web)
                | REST/JSON + JWT
        ApiGateway / YARP :5000
          |           |             |
     AuthService  MovieService  BookingService
       :5100        :5168          :5063
          |           |             |
       PostgreSQL (6 databases) + RabbitMQ/outbox
                                | PayOS + SMTP
```

Three business services replace the initial six-service design: AuthService owns identity; MovieService owns movie/room/seat/showtime; BookingService owns bookings, concessions, promotions, loyalty, reviews, payment/refund and notifications. Cross-database references are logical IDs, not foreign keys.

## 5. Product Perspective

| Area | Responsibility |
| --- | --- |
| Shared core | Identity/RBAC/ownership; pricing; seat concurrency; financial states; PayOS verification; refunds; events and data integrity |
| Web workspace | Counter/cash/printing; movie/room/showtime/account/menu/promotion/member administration; refund settlement; operations/revenue |
| Native behaviour | External trailer, device share sheet, phone camera check-in, emulator/LAN gateway address and payment verification on resume |
| Shared presentation | Customer web/native share Dart widgets and repositories; preview/printing is platform conditional |

## 6. User Classes / Actors

| Actor | Responsibility |
| --- | --- |
| Guest | Public catalogue/showtimes; start account flows |
| Customer | Own profile, tickets, payment, refund state, notifications, reviews and points |
| Staff/Admin | Staff operate sales/schedule/admission/refund; Admin also controls master data/users/revenue |
| Walk-in guest | Counter-sale beneficiary through staff, not a signed-in mobile actor |
| PayOS / SMTP / workers | External settlement/messages; expire holds and exchange committed events |

## 7. Role & Permission

| Operation | Guest | Customer | Staff | Admin |
| --- | --- | --- | --- | --- |
| Browse public movies/showtimes | ✓ | ✓ | ✓ | ✓ |
| Own customer booking/payment/profile/review | — | ✓ | Role landing | Role landing |
| Lookup/check in tickets | — | — | ✓ | ✓ |
| Counter/cash, schedules, seat types, refund settlement | — | — | ✓ | ✓ |
| Movies, rooms, accounts, menu, promotions, members, revenue | — | — | — | ✓ |

UI guards control navigation; controller policies and record-ownership checks are authoritative. Accounts may hold multiple roles. Customer accounts in the admin entry see a customer-site notice; management accounts in the customer entry see management guidance/check-in.

## 8. Business Rules

| ID | Rule |
| --- | --- |
| WEB-BR-01 | Customer accounts must verify their email with an OTP before signing in. Accounts created by an Admin need no OTP. |
| WEB-BR-02 | Every protected API uses JWT; both the gateway and the service check it. |
| WEB-BR-03 | Access depends on the role; Customers cannot use management APIs. |
| WEB-BR-04 | Each seat belongs to one room and its position (row + number) is unique in that room. |
| WEB-BR-05 | A showtime belongs to one movie and one room, and starts before it ends. |
| WEB-BR-06 | A room never has two showtimes at overlapping times (409). |
| WEB-BR-07 | A seat of a showtime belongs to at most one active booking (held or sold). |
| WEB-BR-08 | A booking has one showtime and its seats, and belongs to a customer account, except walk-in tickets sold at the counter. |
| WEB-BR-09 | A payment belongs to a booking; booking/payment/refund transitions must follow the state contract in section 15. |
| WEB-BR-10 | A PayOS webhook must carry a valid HMAC-SHA256 signature before any of its data is used. |
| WEB-BR-11 | Events are written to the outbox in the same transaction as the data and are sent only after commit. |
| WEB-BR-12 | Calls to other services or PayOS use limited retries and a circuit breaker. |
| WEB-BR-13 | An email failure or a stopped RabbitMQ never breaks a booking or payment. |
| WEB-BR-14 | Seats are held for 10 minutes; an unpaid booking then becomes `EXPIRED` and its seats are released. |
| WEB-BR-15 | Seat price: the showtime price is the standard seat price; VIP adds 20% and sweetbox 30% per seat; the surcharge is rounded to 1,000 VND. The server computes prices and never takes them from the client. |
| WEB-BR-16 | Sweetbox seats are always booked, changed and sold as a pair. |
| WEB-BR-17 | A customer can cancel a paid ticket for a 100% refund until 2 hours before the show; later they must contact the cinema. Staff and Admin can cancel at any time. |
| WEB-BR-18 | A payment has at most one refund request. Refunds are paid by manual bank transfer and recorded with the transfer reference. |
| WEB-BR-19 | When a showtime is cancelled, all its active bookings are cancelled; paid ones get a refund request. |
| WEB-BR-20 | Late payment (booking already expired): if the seats are still free the ticket is confirmed; if they were sold to someone else, a 100% refund request is created. |
| WEB-BR-21 | Only `CONFIRMED` tickets can be checked in, once each, from 3 hours before to 2 hours after the start time. |
| WEB-BR-22 | Cash taken must cover the total. If the booking has an unpaid bank-transfer QR, its PayOS link is cancelled before the cash is recorded; if the customer already transferred, cash is refused. |
| WEB-BR-23 | Cash and bank transfers both create payment records, so both count in revenue and refunds in the same way. |
| WEB-BR-24 | Locking an account or changing its roles takes effect on the next request, even while the old token is still valid. |
| WEB-BR-25 | Forgot-password returns 200 regardless of email existence; incorrect login email/password share a message. Registration/resend may reveal account state, so system-wide non-enumeration is not claimed. |
| WEB-BR-26 | Stopping a movie only sets it `INACTIVE`; nothing is deleted and existing tickets stay. A room with showtimes cannot be deleted and its seat map cannot be changed. |
| WEB-BR-27 | A promotion reduces tickets only, up to 90%, rounded down to 1,000 VND; one best automatic promotion or an entered eligible code applies. Count usage on successful payment. |
| WEB-BR-28 | Point value is 1,000 VND; redeem at most 50% after promotion; MEMBER/VIP/VVIP spend thresholds are 0/2,000,000/5,000,000 VND and earn rates 5/7/10%. Reverse/release point effects according to booking cancellation/expiry/refund. |
| WEB-BR-29 | A booking has at most ten distinct active concession items, quantity 1–20 each; persist purchase-time name and unit price, and include them in payment and refund totals. |
| WEB-BR-30 | Format price adds 0/20,000/40,000 VND for 2D/3D/IMAX before type surcharges; NORMAL/VIP/SWEETBOX prices are returned by the server. |

External-operator rules specify shared-backend effects, not additional phone screens. Time limits are current defaults and may be overridden by deployment configuration.

## 9. Functional Requirements

AC-01 verifies the exact stated behaviour; AC-02 verifies applicable rejection/permission paths. Apply only actions specified by the individual FR; the wider use case supplies context. Criteria are specifications, not recorded test results.

### WEB-FR-AUTH-01 — Register

| Field | Specification |
| --- | --- |
| Name | Register |
| Description | Customers register with email, password, full name and an optional phone number. The system sends a verification OTP and issues no token yet. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Register” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Customers register with email, password, full name and an optional phone number. The system sends a verification OTP and issues no token yet. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | An unverified registration and OTP delivery outcome are recorded; no access/refresh tokens are issued before verification. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-01-AC-01** — Given the preconditions/trigger, verify: Customers register with email, password, full name and an optional phone number. The system sends a verification OTP and issues no token yet. **WEB-FR-AUTH-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-REGISTER; WEB-API-033 |

### WEB-FR-AUTH-02 — Sign in

| Field | Specification |
| --- | --- |
| Name | Sign in |
| Description | Sign in with email and password to get an access token (JWT, 60 minutes) and a refresh token (7 days). An unverified email gets 403 `EMAIL_NOT_VERIFIED`. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Sign in” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Sign in with email and password to get an access token (JWT, 60 minutes) and a refresh token (7 days). An unverified email gets 403 `EMAIL_NOT_VERIFIED`. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | Successful verified authentication stores the returned user/tokens and selects the allowed role landing; failure grants no session. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-02-AC-01** — Given the preconditions/trigger, verify: Sign in with email and password to get an access token (JWT, 60 minutes) and a refresh token (7 days). An unverified email gets 403 `EMAIL_NOT_VERIFIED`. **WEB-FR-AUTH-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-027 |

### WEB-FR-AUTH-03 — JWT claims

| Field | Specification |
| --- | --- |
| Name | JWT claims |
| Description | The JWT carries the userId, email and roles. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “JWT claims” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The JWT carries the userId, email and roles. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-03-AC-01** — Given the preconditions/trigger, verify: The JWT carries the userId, email and roles. **WEB-FR-AUTH-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-027, WEB-API-032 |

### WEB-FR-AUTH-04 — Validate JWT

| Field | Specification |
| --- | --- |
| Name | Validate JWT |
| Description | The gateway and services check the JWT signature, expiry, issuer and audience before protected APIs. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Validate JWT” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The gateway and services check the JWT signature, expiry, issuer and audience before protected APIs. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-04-AC-01** — Given the preconditions/trigger, verify: The gateway and services check the JWT signature, expiry, issuer and audience before protected APIs. **WEB-FR-AUTH-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; ; WEB-API-029 |

### WEB-FR-AUTH-05 — Authorize roles

| Field | Specification |
| --- | --- |
| Name | Authorize roles |
| Description | APIs are authorized by role Customer / Staff / Admin (policies `StaffOrAdmin`, `AdminOnly`, and signed-in by default). |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Authorize roles” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: APIs are authorized by role Customer / Staff / Admin (policies `StaffOrAdmin`, `AdminOnly`, and signed-in by default). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-05-AC-01** — Given the preconditions/trigger, verify: APIs are authorized by role Customer / Staff / Admin (policies `StaffOrAdmin`, `AdminOnly`, and signed-in by default). **WEB-FR-AUTH-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-STAFF-ONLY; WEB-API-029 |

### WEB-FR-AUTH-06 — Unauthenticated and forbidden responses

| Field | Specification |
| --- | --- |
| Name | Unauthenticated and forbidden responses |
| Description | A missing or invalid token gets 401; a signed-in user without the role gets 403. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Unauthenticated and forbidden responses” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A missing or invalid token gets 401; a signed-in user without the role gets 403. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-06-AC-01** — Given the preconditions/trigger, verify: A missing or invalid token gets 401; a signed-in user without the role gets 403. **WEB-FR-AUTH-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-029 |

### WEB-FR-AUTH-07 — Verify email OTP

| Field | Specification |
| --- | --- |
| Name | Verify email OTP |
| Description | Email verification with a 6-digit OTP: expires after 5 minutes, at most 5 attempts, 60 seconds between sends, a new code replaces the old one. Verification must include the registered password; on success the user is signed in and gets a welcome email. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Verify email OTP” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Email verification with a 6-digit OTP: expires after 5 minutes, at most 5 attempts, 60 seconds between sends, a new code replaces the old one. Verification must include the registered password; on success the user is signed in and gets a welcome email. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | Successful verified authentication stores the returned user/tokens and selects the allowed role landing; failure grants no session. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-07-AC-01** — Given the preconditions/trigger, verify: Email verification with a 6-digit OTP: expires after 5 minutes, at most 5 attempts, 60 seconds between sends, a new code replaces the old one. Verification must include the registered password; on success the user is signed in and gets a welcome email. **WEB-FR-AUTH-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-VERIFY; WEB-API-034, WEB-API-042 |

### WEB-FR-AUTH-08 — Repeat unverified registration

| Field | Specification |
| --- | --- |
| Name | Repeat unverified registration |
| Description | Registering again with an unverified email replaces the old details and sends a new code. A verified email is reported as already registered. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Repeat unverified registration” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Registering again with an unverified email replaces the old details and sends a new code. A verified email is reported as already registered. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | An unverified registration and OTP delivery outcome are recorded; no access/refresh tokens are issued before verification. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-08-AC-01** — Given the preconditions/trigger, verify: Registering again with an unverified email replaces the old details and sends a new code. A verified email is reported as already registered. **WEB-FR-AUTH-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-REGISTER, WEB-SCR-VERIFY; WEB-API-033 |

### WEB-FR-AUTH-09 — Recover password

| Field | Specification |
| --- | --- |
| Name | Recover password |
| Description | Forgot password: an OTP is emailed (the API always returns 200); setting a new password with the OTP revokes every refresh token and marks the email as verified. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Recover password” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Forgot password: an OTP is emailed (the API always returns 200); setting a new password with the OTP revokes every refresh token and marks the email as verified. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-09-AC-01** — Given the preconditions/trigger, verify: Forgot password: an OTP is emailed (the API always returns 200); setting a new password with the OTP revokes every refresh token and marks the email as verified. **WEB-FR-AUTH-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-FORGOT, WEB-SCR-RESET; WEB-API-026, WEB-API-035 |

### WEB-FR-AUTH-10 — Refresh and sign out

| Field | Specification |
| --- | --- |
| Name | Refresh and sign out |
| Description | Renew the session with the refresh token (rotated; the old one stops working); signing out revokes the refresh token. The app renews automatically when the access token expires. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Refresh and sign out” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Renew the session with the refresh token (rotated; the old one stops working); signing out revokes the refresh token. The app renews automatically when the access token expires. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-10-AC-01** — Given the preconditions/trigger, verify: Renew the session with the refresh token (rotated; the old one stops working); signing out revokes the refresh token. The app renews automatically when the access token expires. **WEB-FR-AUTH-10-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-028, WEB-API-032 |

### WEB-FR-AUTH-11 — Current account

| Field | Specification |
| --- | --- |
| Name | Current account |
| Description | Show the current account (`GET /api/v1/auth/me`). |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Current account” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show the current account (`GET /api/v1/auth/me`). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-11-AC-01** — Given the preconditions/trigger, verify: Show the current account (`GET /api/v1/auth/me`). **WEB-FR-AUTH-11-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-029 |

### WEB-FR-AUTH-12 — Lock and role-change enforcement

| Field | Specification |
| --- | --- |
| Name | Lock and role-change enforcement |
| Description | The gateway checks the account on every protected request: locked returns 401 `ACCOUNT_LOCKED`; changed roles return 403 `ROLE_CHANGED`; an unreachable AuthService returns 503. The customer app shows the reason and returns to sign-in. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Lock and role-change enforcement” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The gateway checks the account on every protected request: locked returns 401 `ACCOUNT_LOCKED`; changed roles return 403 `ROLE_CHANGED`; an unreachable AuthService returns 503. The customer app shows the reason and returns to sign-in. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-12-AC-01** — Given the preconditions/trigger, verify: The gateway checks the account on every protected request: locked returns 401 `ACCOUNT_LOCKED`; changed roles return 403 `ROLE_CHANGED`; an unreachable AuthService returns 503. The customer app shows the reason and returns to sign-in. **WEB-FR-AUTH-12-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN; WEB-API-029 |

### WEB-FR-AUTH-13 — Account field validation

| Field | Specification |
| --- | --- |
| Name | Account field validation |
| Description | The app and the API check account fields the same way (registration, sign-in, forgot / reset password, accounts created by Admin): email required, at most 150 characters, a domain with a suffix of at least 2 letters, no spaces; a new password of 6–72 characters counted in UTF-8 bytes; full name required, at most 150 characters; phone optional, 8–15 digits, at most 20 characters. Mistakes return 400 with an error per field. The sign-up form asks for the password twice. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Account field validation” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The app and the API check account fields the same way (registration, sign-in, forgot / reset password, accounts created by Admin): email required, at most 150 characters, a domain with a suffix of at least 2 letters, no spaces; a new password of 6–72 characters counted in UTF-8 bytes; full name required, at most 150 characters; phone optional, 8–15 digits, at most 20 characters. Mistakes return 400 with an error per field. The sign-up form asks for the password twice. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-AUTH-13-AC-01** — Given the preconditions/trigger, verify: The app and the API check account fields the same way (registration, sign-in, forgot / reset password, accounts created by Admin): email required, at most 150 characters, a domain with a suffix of at least 2 letters, no spaces; a new password of 6–72 characters counted in UTF-8 bytes; full name required, at most 150 characters; phone optional, 8–15 digits, at most 20 characters. Mistakes return 400 with an error per field. The sign-up form asks for the password twice. **WEB-FR-AUTH-13-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN, WEB-SCR-REGISTER, WEB-SCR-FORGOT, WEB-SCR-RESET, WEB-SCR-USER-EDITOR; WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-041 |

### WEB-FR-AUTH-14 — Authentication rate limits

| Field | Specification |
| --- | --- |
| Name | Authentication rate limits |
| Description | Registration, sign-in, OTP, refresh and forgot / reset password are limited to 10 requests per minute per IP; beyond that the API returns 429 with `Retry-After`. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Authentication rate limits” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Registration, sign-in, OTP, refresh and forgot / reset password are limited to 10 requests per minute per IP; beyond that the API returns 429 with `Retry-After`. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-14-AC-01** — Given the preconditions/trigger, verify: Registration, sign-in, OTP, refresh and forgot / reset password are limited to 10 requests per minute per IP; beyond that the API returns 429 with `Retry-After`. **WEB-FR-AUTH-14-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart); [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart); [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-VERIFY, WEB-SCR-FORGOT, WEB-SCR-RESET; WEB-API-027, WEB-API-032, WEB-API-034 |

### WEB-FR-AUTH-15 — Find member by phone

| Field | Specification |
| --- | --- |
| Name | Find member by phone |
| Description | Staff/Admin find a customer account by phone number (digits only; spaces, dots and dashes are ignored) to sell tickets and give points at the counter. Fewer than 8 or more than 15 digits is refused (400); customers get 403. |
| Actor | Staff/Admin |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Find member by phone” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin find a customer account by phone number (digits only; spaces, dots and dashes are ignored) to sell tickets and give points at the counter. Fewer than 8 or more than 15 digits is refused (400); customers get 403. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-15-AC-01** — Given the preconditions/trigger, verify: Staff/Admin find a customer account by phone number (digits only; spaces, dots and dashes are ignored) to sell tickets and give points at the counter. Fewer than 8 or more than 15 digits is refused (400); customers get 403. **WEB-FR-AUTH-15-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-COUNTER; WEB-API-030 |

### WEB-FR-AUTH-16 — Edit profile

| Field | Specification |
| --- | --- |
| Name | Edit profile |
| Description | Users **edit their profile** (Account → Edit profile): full name (required, at most 150 characters) and phone (optional, same rules as registration; empty removes it). The email is the sign-in name and cannot change. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Edit profile” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Users **edit their profile** (Account → Edit profile): full name (required, at most 150 characters) and phone (optional, same rules as registration; empty removes it). The email is the sign-in name and cannot change. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-16-AC-01** — Given the preconditions/trigger, verify: Users **edit their profile** (Account → Edit profile): full name (required, at most 150 characters) and phone (optional, same rules as registration; empty removes it). The email is the sign-in name and cannot change. **WEB-FR-AUTH-16-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-031 |

### WEB-FR-AUTH-17 — Change current password

| Field | Specification |
| --- | --- |
| Name | Change current password |
| Description | **Change the password with the current one** (Account → Change password): current password, new password twice. A wrong current password or the same password is refused (400). Afterwards other devices are signed out (refresh tokens revoked) and this device gets new tokens. A forgotten current password leads to the email OTP flow. Limited to 10 requests per minute like sign-in. |
| Actor | Guest; signed-in account; system |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Invoke “Change current password” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Change the password with the current one** (Account → Change password): current password, new password twice. A wrong current password or the same password is refused (400). Afterwards other devices are signed out (refresh tokens revoked) and this device gets new tokens. A forgotten current password leads to the email OTP flow. Limited to 10 requests per minute like sign-in. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-AUTH-17-AC-01** — Given the preconditions/trigger, verify: **Change the password with the current one** (Account → Change password): current password, new password twice. A wrong current password or the same password is refused (400). Afterwards other devices are signed out (refresh tokens revoked) and this device gets new tokens. A forgotten current password leads to the email OTP flow. Limited to 10 requests per minute like sign-in. **WEB-FR-AUTH-17-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE; WEB-API-025 |

### WEB-FR-USER-01 — List accounts

| Field | Specification |
| --- | --- |
| Name | List accounts |
| Description | List accounts: search, filter by role and status, paging. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “List accounts” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: List accounts: search, filter by role and status, paging. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-USER-01-AC-01** — Given the preconditions/trigger, verify: List accounts: search, filter by role and status, paging. **WEB-FR-USER-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-ADMIN-USERS; WEB-API-040 |

### WEB-FR-USER-02 — Account details

| Field | Specification |
| --- | --- |
| Name | Account details |
| Description | Show an account. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Account details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show an account. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-USER-02-AC-01** — Given the preconditions/trigger, verify: Show an account. **WEB-FR-USER-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-039 |

### WEB-FR-USER-03 — Create account

| Field | Specification |
| --- | --- |
| Name | Create account |
| Description | Create an account with one or more roles; no OTP needed. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Create account” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Create an account with one or more roles; no OTP needed. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-USER-03-AC-01** — Given the preconditions/trigger, verify: Create an account with one or more roles; no OTP needed. **WEB-FR-USER-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-041 |

### WEB-FR-USER-04 — Change account roles

| Field | Specification |
| --- | --- |
| Name | Change account roles |
| Description | Change roles: old refresh tokens are revoked and the user must sign in again; saving the same roles keeps the session. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Change account roles” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Change roles: old refresh tokens are revoked and the user must sign in again; saving the same roles keeps the session. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-USER-04-AC-01** — Given the preconditions/trigger, verify: Change roles: old refresh tokens are revoked and the user must sign in again; saving the same roles keeps the session. **WEB-FR-USER-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-037 |

### WEB-FR-USER-05 — Lock and unlock

| Field | Specification |
| --- | --- |
| Name | Lock and unlock |
| Description | Lock / unlock an account; an Admin cannot lock their own account. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Lock and unlock” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Lock / unlock an account; an Admin cannot lock their own account. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-USER-05-AC-01** — Given the preconditions/trigger, verify: Lock / unlock an account; an Admin cannot lock their own account. **WEB-FR-USER-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-USER-EDITOR; WEB-API-038 |

### WEB-FR-USER-06 — List roles

| Field | Specification |
| --- | --- |
| Name | List roles |
| Description | List roles (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “List roles” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: List roles (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-USER-06-AC-01** — Given the preconditions/trigger, verify: List roles (`ROLE_CUSTOMER`, `ROLE_STAFF`, `ROLE_ADMIN`). **WEB-FR-USER-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs](../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart); [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs) |
| Business rules | WEB-BR-03, WEB-BR-24 |
| Use case / screens / APIs | UC-WEB-02; WEB-SCR-ADMIN-USERS, WEB-SCR-USER-EDITOR; WEB-API-036 |

### WEB-FR-MOV-01 — Paged catalogue

| Field | Specification |
| --- | --- |
| Name | Paged catalogue |
| Description | List movies with paging (Admin). |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Paged catalogue” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: List movies with paging (Admin). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-01-AC-01** — Given the preconditions/trigger, verify: List movies with paging (Admin). **WEB-FR-MOV-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-070 |

### WEB-FR-MOV-02 — Movie details

| Field | Specification |
| --- | --- |
| Name | Movie details |
| Description | Movie details: title, description, duration, genre, language, release date, poster, trailer, status. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Movie details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Movie details: title, description, duration, genre, language, release date, poster, trailer, status. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-02-AC-01** — Given the preconditions/trigger, verify: Movie details: title, description, duration, genre, language, release date, poster, trailer, status. **WEB-FR-MOV-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES; WEB-API-064 |

### WEB-FR-MOV-03 — Title search

| Field | Specification |
| --- | --- |
| Name | Title search |
| Description | Search movies by title. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Title search” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Search movies by title. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-MOV-03-AC-01** — Given the preconditions/trigger, verify: Search movies by title. **WEB-FR-MOV-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES; WEB-API-066, WEB-API-068 |

### WEB-FR-MOV-04 — Active catalogue

| Field | Specification |
| --- | --- |
| Name | Active catalogue |
| Description | Filter movies by status; the customer home page only shows `ACTIVE` movies. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Active catalogue” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Filter movies by status; the customer home page only shows `ACTIVE` movies. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-04-AC-01** — Given the preconditions/trigger, verify: Filter movies by status; the customer home page only shows `ACTIVE` movies. **WEB-FR-MOV-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES; WEB-API-066, WEB-API-069 |

### WEB-FR-MOV-05 — Create movie

| Field | Specification |
| --- | --- |
| Name | Create movie |
| Description | Admin adds a movie. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Create movie” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin adds a movie. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-05-AC-01** — Given the preconditions/trigger, verify: Admin adds a movie. **WEB-FR-MOV-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-071 |

### WEB-FR-MOV-06 — Edit and reactivate movie

| Field | Specification |
| --- | --- |
| Name | Edit and reactivate movie |
| Description | Admin edits a movie, including bringing a stopped movie back (**Show again**). |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Edit and reactivate movie” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin edits a movie, including bringing a stopped movie back (**Show again**). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-06-AC-01** — Given the preconditions/trigger, verify: Admin edits a movie, including bringing a stopped movie back (**Show again**). **WEB-FR-MOV-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-065 |

### WEB-FR-MOV-07 — Deactivate movie

| Field | Specification |
| --- | --- |
| Name | Deactivate movie |
| Description | Admin stops a movie (**Stop showing**): it becomes `INACTIVE` and disappears from the customer app; its data and tickets stay. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Deactivate movie” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin stops a movie (**Stop showing**): it becomes `INACTIVE` and disappears from the customer app; its data and tickets stay. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-07-AC-01** — Given the preconditions/trigger, verify: Admin stops a movie (**Stop showing**): it becomes `INACTIVE` and disappears from the customer app; its data and tickets stay. **WEB-FR-MOV-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-ADMIN-MOVIES; WEB-API-063 |

### WEB-FR-MOV-08 — Open trailer

| Field | Specification |
| --- | --- |
| Name | Open trailer |
| Description | The customer app opens the movie trailer (`trailerUrl`). |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Open trailer” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The customer app opens the movie trailer (`trailerUrl`). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | L |
| Acceptance criteria | **WEB-FR-MOV-08-AC-01** — Given the preconditions/trigger, verify: The customer app opens the movie trailer (`trailerUrl`). **WEB-FR-MOV-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-MOVIE; WEB-API-064 |

### WEB-FR-MOV-09 — Age rating

| Field | Specification |
| --- | --- |
| Name | Age rating |
| Description | Support age ratings P, K, T13, T16 and T18. Admin selects a rating (P by default); cards, movie details, booking summary, counter and check-in display it. Before holding seats for a non-P film the customer acknowledges the age condition; staff are reminded to check identity at admission. This specifies implemented labels, not a legal compliance certification. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | A movie is available; changes need Admin; a review needs the owner’s checked-in ticket. |
| Trigger | Invoke “Age rating” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Support age ratings P, K, T13, T16 and T18. Admin selects a rating (P by default); cards, movie details, booking summary, counter and check-in display it. Before holding seats for a non-P film the customer acknowledges the age condition; staff are reminded to check identity at admission. This specifies implemented labels, not a legal compliance certification. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-MOV-09-AC-01** — Given the preconditions/trigger, verify: Support age ratings P, K, T13, T16 and T18. Admin selects a rating (P by default); cards, movie details, booking summary, counter and check-in display it. Before holding seats for a non-P film the customer acknowledges the age condition; staff are reminded to check identity at admission. This specifies implemented labels, not a legal compliance certification. **WEB-FR-MOV-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-SUMMARY, WEB-SCR-CHECKIN, WEB-SCR-ADMIN-MOVIES; WEB-API-064, WEB-API-065, WEB-API-071 |

### WEB-FR-MOV-10 — Now showing and coming soon

| Field | Specification |
| --- | --- |
| Name | Now showing and coming soon |
| Description | The customer home has two tabs: **Now showing** (ACTIVE movies already released or without a release date, newest first) and **Coming soon** (ACTIVE movies released after today, earliest first, the release date on the poster). Movies can be filtered by genre (chips built from the genres of the movies on offer) and searched by title through the API, ignoring case. A movie coming soon shows its release date; without showtimes the page says they will be added closer to the release. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Now showing and coming soon” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The customer home has two tabs: **Now showing** (ACTIVE movies already released or without a release date, newest first) and **Coming soon** (ACTIVE movies released after today, earliest first, the release date on the poster). Movies can be filtered by genre (chips built from the genres of the movies on offer) and searched by title through the API, ignoring case. A movie coming soon shows its release date; without showtimes the page says they will be added closer to the release. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-MOV-10-AC-01** — Given the preconditions/trigger, verify: The customer home has two tabs: **Now showing** (ACTIVE movies already released or without a release date, newest first) and **Coming soon** (ACTIVE movies released after today, earliest first, the release date on the poster). Movies can be filtered by genre (chips built from the genres of the movies on offer) and searched by title through the API, ignoring case. A movie coming soon shows its release date; without showtimes the page says they will be added closer to the release. **WEB-FR-MOV-10-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-HOME; WEB-API-066, WEB-API-067 |

### WEB-FR-MOV-11 — Director and cast

| Field | Specification |
| --- | --- |
| Name | Director and cast |
| Description | Movies have a **director** and **main cast** (optional, at most 150 / 500 characters). Admins fill them in when adding / editing a movie; the movie page shows them. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | The public catalogue is reachable; the movie exists for detail/trailer operations. Empty search results are valid. |
| Trigger | Invoke “Director and cast” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Movies have a **director** and **main cast** (optional, at most 150 / 500 characters). Admins fill them in when adding / editing a movie; the movie page shows them. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | L |
| Acceptance criteria | **WEB-FR-MOV-11-AC-01** — Given the preconditions/trigger, verify: Movies have a **director** and **main cast** (optional, at most 150 / 500 characters). Admins fill them in when adding / editing a movie; the movie page shows them. **WEB-FR-MOV-11-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES; WEB-API-064, WEB-API-065, WEB-API-071 |

### WEB-FR-MOV-12 — Movie reviews

| Field | Specification |
| --- | --- |
| Name | Movie reviews |
| Description | **Movie reviews**: customers whose ticket was checked in (they watched the movie) rate it 1–5 stars with a comment (at most 1,000 characters) from the ticket page. One review per customer per movie: sending again edits it, and it can be deleted. A ticket not checked in is refused (400) with the reason; someone else's ticket is treated as missing (404). The movie page shows everyone the average, the count per star and the newest reviews; the reviewer name is the account's full name (or a masked email). Admins remove unsuitable reviews from Admin → Movies → Reviews. |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Preconditions | A movie is available; changes need Admin; a review needs the owner’s checked-in ticket. |
| Trigger | Invoke “Movie reviews” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Movie reviews**: customers whose ticket was checked in (they watched the movie) rate it 1–5 stars with a comment (at most 1,000 characters) from the ticket page. One review per customer per movie: sending again edits it, and it can be deleted. A ticket not checked in is refused (400) with the reason; someone else's ticket is treated as missing (404). The movie page shows everyone the average, the count per star and the newest reviews; the reviewer name is the account's full name (or a masked email). Admins remove unsuitable reviews from Admin → Movies → Reviews. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-MOV-12-AC-01** — Given the preconditions/trigger, verify: **Movie reviews**: customers whose ticket was checked in (they watched the movie) rate it 1–5 stars with a comment (at most 1,000 characters) from the ticket page. One review per customer per movie: sending again edits it, and it can be deleted. A ticket not checked in is refused (400) with the reason; someone else's ticket is treated as missing (404). The movie page shows everyone the average, the count per star and the newest reviews; the reviewer name is the account's full name (or a masked email). Admins remove unsuitable reviews from Admin → Movies → Reviews. **WEB-FR-MOV-12-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-MOVIE, WEB-SCR-TICKET, WEB-SCR-ADMIN-MOVIES; WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |

### WEB-FR-ROOM-01 — Find rooms

| Field | Specification |
| --- | --- |
| Name | Find rooms |
| Description | List rooms and search them by name (Staff/Admin). |
| Actor | Staff/Admin read; Admin writes |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Invoke “Find rooms” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: List rooms and search them by name (Staff/Admin). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-ROOM-01-AC-01** — Given the preconditions/trigger, verify: List rooms and search them by name (Staff/Admin). **WEB-FR-ROOM-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Business rules | WEB-BR-04, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-04; WEB-SCR-OPERATIONS, WEB-SCR-ADMIN-ROOMS; WEB-API-004, WEB-API-005 |

### WEB-FR-ROOM-02 — Room details

| Field | Specification |
| --- | --- |
| Name | Room details |
| Description | Room details with the seat map by row, coloured by seat type. |
| Actor | Staff/Admin read; Admin writes |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Invoke “Room details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Room details with the seat map by row, coloured by seat type. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-ROOM-02-AC-01** — Given the preconditions/trigger, verify: Room details with the seat map by row, coloured by seat type. **WEB-FR-ROOM-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Business rules | WEB-BR-04, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-04; WEB-SCR-RECORD-ROOMS, WEB-SCR-ADMIN-ROOMS; WEB-API-002, WEB-API-013 |

### WEB-FR-ROOM-03 — Create room and seats

| Field | Specification |
| --- | --- |
| Name | Create room and seats |
| Description | Admin creates a room from rows × seats per row; its seats are created at once. |
| Actor | Staff/Admin read; Admin writes |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Invoke “Create room and seats” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin creates a room from rows × seats per row; its seats are created at once. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-ROOM-03-AC-01** — Given the preconditions/trigger, verify: Admin creates a room from rows × seats per row; its seats are created at once. **WEB-FR-ROOM-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Business rules | WEB-BR-04, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-006, WEB-API-010 |

### WEB-FR-ROOM-04 — Rename room

| Field | Specification |
| --- | --- |
| Name | Rename room |
| Description | Admin renames a room; its seats stay. |
| Actor | Staff/Admin read; Admin writes |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Invoke “Rename room” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin renames a room; its seats stay. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-ROOM-04-AC-01** — Given the preconditions/trigger, verify: Admin renames a room; its seats stay. **WEB-FR-ROOM-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Business rules | WEB-BR-04, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-003 |

### WEB-FR-ROOM-05 — Delete eligible room

| Field | Specification |
| --- | --- |
| Name | Delete eligible room |
| Description | Admin deletes a room without showtimes (with its seats); a room with showtimes is refused. |
| Actor | Staff/Admin read; Admin writes |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Invoke “Delete eligible room” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin deletes a room without showtimes (with its seats); a room with showtimes is refused. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-ROOM-05-AC-01** — Given the preconditions/trigger, verify: Admin deletes a room without showtimes (with its seats); a room with showtimes is refused. **WEB-FR-ROOM-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/RoomService.cs) |
| Business rules | WEB-BR-04, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-04; WEB-SCR-ADMIN-ROOMS; WEB-API-001 |

### WEB-FR-SEAT-01 — Generate seats

| Field | Specification |
| --- | --- |
| Name | Generate seats |
| Description | Generate a standard seat map for an empty room (Staff/Admin). |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Generate seats” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Generate a standard seat map for an empty room (Staff/Admin). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SEAT-01-AC-01** — Given the preconditions/trigger, verify: Generate a standard seat map for an empty room (Staff/Admin). **WEB-FR-SEAT-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-010 |

### WEB-FR-SEAT-02 — Seat details

| Field | Specification |
| --- | --- |
| Name | Seat details |
| Description | Show one seat. |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Seat details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show one seat. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | L |
| Acceptance criteria | **WEB-FR-SEAT-02-AC-01** — Given the preconditions/trigger, verify: Show one seat. **WEB-FR-SEAT-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-009 |

### WEB-FR-SEAT-03 — Read room map

| Field | Specification |
| --- | --- |
| Name | Read room map |
| Description | Get the seat map of a room (signed-in users). |
| Actor | Signed-in Customer reads/selects; Staff/Admin manage types; Admin manages capacity/deletion |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Read room map” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Get the seat map of a room (signed-in users). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SEAT-03-AC-01** — Given the preconditions/trigger, verify: Get the seat map of a room (signed-in users). **WEB-FR-SEAT-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-SEATS, WEB-SCR-RECORD-ROOMS; WEB-API-013 |

### WEB-FR-SEAT-04 — Delete seat API

| Field | Specification |
| --- | --- |
| Name | Delete seat API |
| Description | Admin deletes a seat (API only). |
| Actor | Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Delete seat API” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin deletes a seat (API only). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | L |
| Acceptance criteria | **WEB-FR-SEAT-04-AC-01** — Given the preconditions/trigger, verify: Admin deletes a seat (API only). **WEB-FR-SEAT-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; ; WEB-API-008 |

### WEB-FR-SEAT-05 — Change seat type

| Field | Specification |
| --- | --- |
| Name | Change seat type |
| Description | Change one seat's type: NORMAL / VIP / SWEETBOX. A sweetbox changes with its pair; a seat without a pair cannot become a sweetbox. |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Change seat type” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Change one seat's type: NORMAL / VIP / SWEETBOX. A sweetbox changes with its pair; a seat without a pair cannot become a sweetbox. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SEAT-05-AC-01** — Given the preconditions/trigger, verify: Change one seat's type: NORMAL / VIP / SWEETBOX. A sweetbox changes with its pair; a seat without a pair cannot become a sweetbox. **WEB-FR-SEAT-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-007 |

### WEB-FR-SEAT-06 — Paint seat types

| Field | Specification |
| --- | --- |
| Name | Paint seat types |
| Description | Change many seats at once on the map: pick a type, then click, drag across seats or click a row letter to change the whole row. A row with an unpaired seat returns 400. |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Paint seat types” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Change many seats at once on the map: pick a type, then click, drag across seats or click a row letter to change the whole row. A row with an unpaired seat returns 400. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SEAT-06-AC-01** — Given the preconditions/trigger, verify: Change many seats at once on the map: pick a type, then click, drag across seats or click a row letter to change the whole row. A row with an unpaired seat returns 400. **WEB-FR-SEAT-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-012 |

### WEB-FR-SEAT-07 — Change capacity

| Field | Specification |
| --- | --- |
| Name | Change capacity |
| Description | Admin changes a room's seat count: new seats fill the last row, then new rows (up to row Z); removing takes the last seats; a leftover half sweetbox becomes standard. |
| Actor | Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Change capacity” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin changes a room's seat count: new seats fill the last row, then new rows (up to row Z); removing takes the last seats; a leftover half sweetbox becomes standard. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SEAT-07-AC-01** — Given the preconditions/trigger, verify: Admin changes a room's seat count: new seats fill the last row, then new rows (up to row Z); removing takes the last seats; a leftover half sweetbox becomes standard. **WEB-FR-SEAT-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-011 |

### WEB-FR-SEAT-08 — Protect scheduled rooms

| Field | Specification |
| --- | --- |
| Name | Protect scheduled rooms |
| Description | Seats cannot be generated, retyped or recounted in a room that has showtimes (sold tickets stay correct). |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Protect scheduled rooms” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Seats cannot be generated, retyped or recounted in a room that has showtimes (sold tickets stay correct). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SEAT-08-AC-01** — Given the preconditions/trigger, verify: Seats cannot be generated, retyped or recounted in a room that has showtimes (sold tickets stay correct). **WEB-FR-SEAT-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-007, WEB-API-010, WEB-API-011, WEB-API-012 |

### WEB-FR-SEAT-09 — Refresh management maps

| Field | Specification |
| --- | --- |
| Name | Refresh management maps |
| Description | Seat maps on the admin website refresh every 5 seconds when someone else changes them. |
| Actor | Staff/Admin |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Invoke “Refresh management maps” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Seat maps on the admin website refresh every 5 seconds when someone else changes them. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | L |
| Acceptance criteria | **WEB-FR-SEAT-09-AC-01** — Given the preconditions/trigger, verify: Seat maps on the admin website refresh every 5 seconds when someone else changes them. **WEB-FR-SEAT-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/SeatService.cs); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-05; WEB-SCR-RECORD-ROOMS; WEB-API-013 |

### WEB-FR-SHOW-01 — List showtimes

| Field | Specification |
| --- | --- |
| Name | List showtimes |
| Description | List showtimes with paging and filters. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “List showtimes” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: List showtimes with paging and filters. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-01-AC-01** — Given the preconditions/trigger, verify: List showtimes with paging and filters. **WEB-FR-SHOW-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-OPERATIONS; WEB-API-023 |

### WEB-FR-SHOW-02 — Create showtime

| Field | Specification |
| --- | --- |
| Name | Create showtime |
| Description | Staff/Admin create a showtime: movie, room, start, end, standard seat price, status. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Create showtime” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin create a showtime: movie, room, start, end, standard seat price, status. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-02-AC-01** — Given the preconditions/trigger, verify: Staff/Admin create a showtime: movie, room, start, end, standard seat price, status. **WEB-FR-SHOW-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-024 |

### WEB-FR-SHOW-03 — Showtime and prices

| Field | Specification |
| --- | --- |
| Name | Showtime and prices |
| Description | Showtime details with `seatPrices`: the price of one seat of each type. |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Showtime and prices” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Showtime details with `seatPrices`: the price of one seat of each type. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-03-AC-01** — Given the preconditions/trigger, verify: Showtime details with `seatPrices`: the price of one seat of each type. **WEB-FR-SHOW-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-RECORD-SHOWTIMES; WEB-API-017 |

### WEB-FR-SHOW-04 — Edit showtime

| Field | Specification |
| --- | --- |
| Name | Edit showtime |
| Description | Staff/Admin edit a showtime; overlaps are still checked. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Edit showtime” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin edit a showtime; overlaps are still checked. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-04-AC-01** — Given the preconditions/trigger, verify: Staff/Admin edit a showtime; overlaps are still checked. **WEB-FR-SHOW-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-018 |

### WEB-FR-SHOW-05 — Cancel showtime

| Field | Specification |
| --- | --- |
| Name | Cancel showtime |
| Description | Staff/Admin cancel a showtime (status `CANCELLED`, not deleted); its tickets are cancelled and refunded as in WEB-BR-19. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Cancel showtime” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin cancel a showtime (status `CANCELLED`, not deleted); its tickets are cancelled and refunded as in WEB-BR-19. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-05-AC-01** — Given the preconditions/trigger, verify: Staff/Admin cancel a showtime (status `CANCELLED`, not deleted); its tickets are cancelled and refunded as in WEB-BR-19. **WEB-FR-SHOW-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-016 |

### WEB-FR-SHOW-06 — Open future showtimes

| Field | Specification |
| --- | --- |
| Name | Open future showtimes |
| Description | Get showtimes open for sale (`OPEN`, not started). |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Open future showtimes” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Get showtimes open for sale (`OPEN`, not started). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-06-AC-01** — Given the preconditions/trigger, verify: Get showtimes open for sale (`OPEN`, not started). **WEB-FR-SHOW-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-022 |

### WEB-FR-SHOW-07 — Showtimes by movie

| Field | Specification |
| --- | --- |
| Name | Showtimes by movie |
| Description | Get showtimes of a movie. |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Showtimes by movie” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Get showtimes of a movie. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SHOW-07-AC-01** — Given the preconditions/trigger, verify: Get showtimes of a movie. **WEB-FR-SHOW-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-021 |

### WEB-FR-SHOW-08 — Bookable movie showtimes

| Field | Specification |
| --- | --- |
| Name | Bookable movie showtimes |
| Description | Get open showtimes of a movie; the customer app shows those in the next 7 days. |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Bookable movie showtimes” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Get open showtimes of a movie; the customer app shows those in the next 7 days. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-08-AC-01** — Given the preconditions/trigger, verify: Get open showtimes of a movie; the customer app shows those in the next 7 days. **WEB-FR-SHOW-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-MOVIE; WEB-API-020 |

### WEB-FR-SHOW-09 — Date range search

| Field | Specification |
| --- | --- |
| Name | Date range search |
| Description | Find showtimes in a time range (Staff/Admin). |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Date range search” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Find showtimes in a time range (Staff/Admin). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-09-AC-01** — Given the preconditions/trigger, verify: Find showtimes in a time range (Staff/Admin). **WEB-FR-SHOW-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-OPERATIONS; WEB-API-019 |

### WEB-FR-SHOW-10 — Open and close sales

| Field | Specification |
| --- | --- |
| Name | Open and close sales |
| Description | Open / close sales of a showtime (`OPEN` ↔ `CLOSED`). |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Open and close sales” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Open / close sales of a showtime (`OPEN` ↔ `CLOSED`). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SHOW-10-AC-01** — Given the preconditions/trigger, verify: Open / close sales of a showtime (`OPEN` ↔ `CLOSED`). **WEB-FR-SHOW-10-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-015 |

### WEB-FR-SHOW-11 — Reject overlap

| Field | Specification |
| --- | --- |
| Name | Reject overlap |
| Description | Overlapping showtimes in one room return 409. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Reject overlap” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Overlapping showtimes in one room return 409. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-SHOW-11-AC-01** — Given the preconditions/trigger, verify: Overlapping showtimes in one room return 409. **WEB-FR-SHOW-11-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-SHOW-EDITOR; WEB-API-018, WEB-API-024 |

### WEB-FR-SHOW-12 — Showtime seat/customer map

| Field | Specification |
| --- | --- |
| Name | Showtime seat/customer map |
| Description | Staff see a showtime's seat map (free / awaiting payment / sold / checked in), open a ticket by clicking its seat, and see the customer list (email, seats, booking code, check-in time); refreshed every 5 seconds. |
| Actor | Staff/Admin |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Showtime seat/customer map” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff see a showtime's seat map (free / awaiting payment / sold / checked in), open a ticket by clicking its seat, and see the customer list (email, seats, booking code, check-in time); refreshed every 5 seconds. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SHOW-12-AC-01** — Given the preconditions/trigger, verify: Staff see a showtime's seat map (free / awaiting payment / sold / checked in), open a ticket by clicking its seat, and see the customer list (email, seats, booking code, check-in time); refreshed every 5 seconds. **WEB-FR-SHOW-12-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-RECORD-SHOWTIMES; WEB-API-013, WEB-API-017, WEB-API-050 |

### WEB-FR-SHOW-13 — Screening format

| Field | Specification |
| --- | --- |
| Name | Screening format |
| Description | Every showtime has a **format: 2D, 3D or IMAX** (2D by default, kept when left out on edit, anything else refused with 400). The stored price is the standard seat at 2D; 3D adds 20,000 VND and IMAX 40,000 VND to the standard seat before the VIP / sweetbox surcharges. Seat prices shown to customers and charged by BookingService include it. The app names the format next to the room (e.g. "Room 1 · IMAX"). |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Invoke “Screening format” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Every showtime has a **format: 2D, 3D or IMAX** (2D by default, kept when left out on edit, anything else refused with 400). The stored price is the standard seat at 2D; 3D adds 20,000 VND and IMAX 40,000 VND to the standard seat before the VIP / sweetbox surcharges. Seat prices shown to customers and charged by BookingService include it. The app names the format next to the room (e.g. "Room 1 · IMAX"). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-SHOW-13-AC-01** — Given the preconditions/trigger, verify: Every showtime has a **format: 2D, 3D or IMAX** (2D by default, kept when left out on edit, anything else refused with 400). The stored price is the standard seat at 2D; 3D adds 20,000 VND and IMAX 40,000 VND to the standard seat before the VIP / sweetbox surcharges. Seat prices shown to customers and charged by BookingService include it. The app names the format next to the room (e.g. "Room 1 · IMAX"). **WEB-FR-SHOW-13-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/ShowtimeService.cs) |
| Business rules | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 |
| Use case / screens / APIs | UC-WEB-06; WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-SHOW-EDITOR; WEB-API-017, WEB-API-018, WEB-API-024 |

### WEB-FR-BOOK-01 — Hold booking

| Field | Specification |
| --- | --- |
| Name | Hold booking |
| Description | Create a booking from a showtime and seats: the showtime must be `OPEN` and not started, with at least one seat and no duplicates. The server takes the show time, movie title and prices from MovieService. The booking is `PENDING` and holds the seats for 10 minutes. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Hold booking” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Create a booking from a showtime and seats: the showtime must be `OPEN` and not started, with at least one seat and no duplicates. The server takes the show time, movie title and prices from MovieService. The booking is `PENDING` and holds the seats for 10 minutes. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | One PENDING booking with server total and expiresAt is committed; seats are HELD for ten minutes. A rejected transaction leaves no partial holds or point deduction. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-01-AC-01** — Given the preconditions/trigger, verify: Create a booking from a showtime and seats: the showtime must be `OPEN` and not started, with at least one seat and no duplicates. The server takes the show time, movie title and prices from MovieService. The booking is `PENDING` and holds the seats for 10 minutes. **WEB-FR-BOOK-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SUMMARY; WEB-API-055 |

### WEB-FR-BOOK-02 — Booking details

| Field | Specification |
| --- | --- |
| Name | Booking details |
| Description | Show a booking: to its owner or to Staff/Admin. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | Customer is signed in and owns the relevant ticket; the requested action must be permitted by ticket state and time. Staff access applies only where stated. |
| Trigger | Invoke “Booking details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show a booking: to its owner or to Staff/Admin. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-02-AC-01** — Given the preconditions/trigger, verify: Show a booking: to its owner or to Staff/Admin. **WEB-FR-BOOK-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-RESULT, WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS; WEB-API-046 |

### WEB-FR-BOOK-03 — Management booking search

| Field | Specification |
| --- | --- |
| Name | Management booking search |
| Description | Staff/Admin list bookings and filter by status and creation date. |
| Actor | Staff/Admin |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Management booking search” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin list bookings and filter by status and creation date. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-03-AC-01** — Given the preconditions/trigger, verify: Staff/Admin list bookings and filter by status and creation date. **WEB-FR-BOOK-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-OPERATIONS; WEB-API-048, WEB-API-052, WEB-API-054 |

### WEB-FR-BOOK-04 — Own ticket history

| Field | Specification |
| --- | --- |
| Name | Own ticket history |
| Description | Customers see their own tickets in **Active** and **History**. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | Customer is signed in and owns the relevant ticket; the requested action must be permitted by ticket state and time. Staff access applies only where stated. |
| Trigger | Invoke “Own ticket history” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Customers see their own tickets in **Active** and **History**. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-04-AC-01** — Given the preconditions/trigger, verify: Customers see their own tickets in **Active** and **History**. **WEB-FR-BOOK-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-TICKETS; WEB-API-053 |

### WEB-FR-BOOK-05 — Confirm paid booking

| Field | Specification |
| --- | --- |
| Name | Confirm paid booking |
| Description | Confirm a booking after a successful payment (see PAY and POS). |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Confirm paid booking” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Confirm a booking after a successful payment (see PAY and POS). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-05-AC-01** — Given the preconditions/trigger, verify: Confirm a booking after a successful payment (see PAY and POS). **WEB-FR-BOOK-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-TICKET; WEB-API-086, WEB-API-087, WEB-API-089 |

### WEB-FR-BOOK-06 — Cancel booking

| Field | Specification |
| --- | --- |
| Name | Cancel booking |
| Description | Cancel a booking: an unpaid one is cancelled and its seats released; a paid one follows WEB-BR-17. A customer cancelling a paid ticket creates a refund request: the booking becomes `REFUND_PENDING` and keeps its seats until staff handle it. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | Customer is signed in and owns the relevant ticket; the requested action must be permitted by ticket state and time. Staff access applies only where stated. |
| Trigger | Invoke “Cancel booking” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Cancel a booking: an unpaid one is cancelled and its seats released; a paid one follows WEB-BR-17. A customer cancelling a paid ticket creates a refund request: the booking becomes `REFUND_PENDING` and keeps its seats until staff handle it. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-06-AC-01** — Given the preconditions/trigger, verify: Cancel a booking: an unpaid one is cancelled and its seats released; a paid one follows WEB-BR-17. A customer cancelling a paid ticket creates a refund request: the booking becomes `REFUND_PENDING` and keeps its seats until staff handle it. **WEB-FR-BOOK-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS; WEB-API-043 |

### WEB-FR-BOOK-07 — Occupied seat IDs

| Field | Specification |
| --- | --- |
| Name | Occupied seat IDs |
| Description | Get the held / sold seats of a showtime. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Occupied seat IDs” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Get the held / sold seats of a showtime. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-07-AC-01** — Given the preconditions/trigger, verify: Get the held / sold seats of a showtime. **WEB-FR-BOOK-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SEATS; WEB-API-049 |

### WEB-FR-BOOK-08 — Concurrent seat conflict

| Field | Specification |
| --- | --- |
| Name | Concurrent seat conflict |
| Description | A seat held or sold by another booking returns 409. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Concurrent seat conflict” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A seat held or sold by another booking returns 409. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-08-AC-01** — Given the preconditions/trigger, verify: A seat held or sold by another booking returns 409. **WEB-FR-BOOK-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SEATS; WEB-API-055 |

### WEB-FR-BOOK-09 — Sweetbox pair

| Field | Specification |
| --- | --- |
| Name | Sweetbox pair |
| Description | Sweetbox seats must be booked as a full pair (the server refuses half a pair). |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Sweetbox pair” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Sweetbox seats must be booked as a full pair (the server refuses half a pair). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-09-AC-01** — Given the preconditions/trigger, verify: Sweetbox seats must be booked as a full pair (the server refuses half a pair). **WEB-FR-BOOK-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SEATS, WEB-SCR-SUMMARY; WEB-API-055 |

### WEB-FR-BOOK-10 — Expire unpaid hold

| Field | Specification |
| --- | --- |
| Name | Expire unpaid hold |
| Description | A background job runs every 30 seconds, marks bookings past their hold `EXPIRED` and releases their seats. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Expire unpaid hold” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A background job runs every 30 seconds, marks bookings past their hold `EXPIRED` and releases their seats. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-BOOK-10-AC-01** — Given the preconditions/trigger, verify: A background job runs every 30 seconds, marks bookings past their hold `EXPIRED` and releases their seats. **WEB-FR-BOOK-10-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-PAYMENT; WEB-API-046 |

### WEB-FR-BOOK-11 — Refresh customer map

| Field | Specification |
| --- | --- |
| Name | Refresh customer map |
| Description | The seat picker refreshes every 5 seconds; a selected seat taken by someone else is unselected and the customer is told. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Refresh customer map” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The seat picker refreshes every 5 seconds; a selected seat taken by someone else is unselected and the customer is told. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-11-AC-01** — Given the preconditions/trigger, verify: The seat picker refreshes every 5 seconds; a selected seat taken by someone else is unselected and the customer is told. **WEB-FR-BOOK-11-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SEATS; WEB-API-013, WEB-API-049 |

### WEB-FR-BOOK-12 — Showtime booking statistics

| Field | Specification |
| --- | --- |
| Name | Showtime booking statistics |
| Description | Ticket statistics per showtime for Staff/Admin: bookings, seats sold, seats held, checked in (by a list of ids or by a start-time range of at most 31 days). |
| Actor | Staff/Admin |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Showtime booking statistics” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Ticket statistics per showtime for Staff/Admin: bookings, seats sold, seats held, checked in (by a list of ids or by a start-time range of at most 31 days). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-12-AC-01** — Given the preconditions/trigger, verify: Ticket statistics per showtime for Staff/Admin: bookings, seats sold, seats held, checked in (by a list of ids or by a start-time range of at most 31 days). **WEB-FR-BOOK-12-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-SHOWTIMES; WEB-API-051 |

### WEB-FR-BOOK-13 — Concessions with tickets

| Field | Specification |
| --- | --- |
| Name | Concessions with tickets |
| Description | **Snacks with tickets**: customers (booking summary) and the counter (sale screen) pick items from the menu, 1–20 of each, at most 10 different items. Prices come from the menu on sale; the snacks are part of the total, so payment, revenue and refunds include them. The order keeps the name and price at the time of purchase. Snacks show on the ticket, the payment page, the ticket email and the printed ticket. Stopped items are refused (400). |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Concessions with tickets” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Snacks with tickets**: customers (booking summary) and the counter (sale screen) pick items from the menu, 1–20 of each, at most 10 different items. Prices come from the menu on sale; the snacks are part of the total, so payment, revenue and refunds include them. The order keeps the name and price at the time of purchase. Snacks show on the ticket, the payment page, the ticket email and the printed ticket. Stopped items are refused (400). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-13-AC-01** — Given the preconditions/trigger, verify: **Snacks with tickets**: customers (booking summary) and the counter (sale screen) pick items from the menu, 1–20 of each, at most 10 different items. Prices come from the menu on sale; the snacks are part of the total, so payment, revenue and refunds include them. The order keeps the name and price at the time of purchase. Snacks show on the ticket, the payment page, the ticket email and the printed ticket. Stopped items are refused (400). **WEB-FR-BOOK-13-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER; WEB-API-055, WEB-API-057 |

### WEB-FR-BOOK-14 — Concessions administration

| Field | Specification |
| --- | --- |
| Name | Concessions administration |
| Description | Admins manage the snacks menu (Admin → Snacks): add, edit name / price / description / image / order, stop or resume selling (items are never deleted). Customers only see items on sale. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Concessions administration” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admins manage the snacks menu (Admin → Snacks): add, edit name / price / description / image / order, stop or resume selling (items are never deleted). Customers only see items on sale. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-14-AC-01** — Given the preconditions/trigger, verify: Admins manage the snacks menu (Admin → Snacks): add, edit name / price / description / image / order, stop or resume selling (items are never deleted). Customers only see items on sale. **WEB-FR-BOOK-14-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/ConcessionService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/ConcessionService.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-ADMIN-SNACKS; WEB-API-056, WEB-API-057, WEB-API-058 |

### WEB-FR-BOOK-15 — Promotion and voucher

| Field | Specification |
| --- | --- |
| Name | Promotion and voucher |
| Description | **Promotions**: only the ticket price is discounted (never snacks), by a percentage (optionally capped) or an amount, at most 90% of the tickets, rounded down to 1,000 VND. Conditions: running period, day of the week of the show, minimum tickets, maximum uses. A promotion without a code applies by itself (the biggest discount wins); a promo code typed by the customer or the counter replaces it — one promotion per booking. A wrong or unusable code is refused (400) with the reason. The server works the discount out again when the booking is made; a use is only counted once the ticket is paid. The discount shows on the ticket, the payment page, the ticket email and the printed ticket. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Promotion and voucher” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Promotions**: only the ticket price is discounted (never snacks), by a percentage (optionally capped) or an amount, at most 90% of the tickets, rounded down to 1,000 VND. Conditions: running period, day of the week of the show, minimum tickets, maximum uses. A promotion without a code applies by itself (the biggest discount wins); a promo code typed by the customer or the counter replaces it — one promotion per booking. A wrong or unusable code is refused (400) with the reason. The server works the discount out again when the booking is made; a use is only counted once the ticket is paid. The discount shows on the ticket, the payment page, the ticket email and the printed ticket. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-15-AC-01** — Given the preconditions/trigger, verify: **Promotions**: only the ticket price is discounted (never snacks), by a percentage (optionally capped) or an amount, at most 90% of the tickets, rounded down to 1,000 VND. Conditions: running period, day of the week of the show, minimum tickets, maximum uses. A promotion without a code applies by itself (the biggest discount wins); a promo code typed by the customer or the counter replaces it — one promotion per booking. A wrong or unusable code is refused (400) with the reason. The server works the discount out again when the booking is made; a use is only counted once the ticket is paid. The discount shows on the ticket, the payment page, the ticket email and the printed ticket. **WEB-FR-BOOK-15-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER; WEB-API-055, WEB-API-099 |

### WEB-FR-BOOK-16 — Promotion administration

| Field | Specification |
| --- | --- |
| Name | Promotion administration |
| Description | Admins manage promotions (Admin → Promotions): add, edit, pause / resume (never deleted), see how often each was used. Promo codes are unique (409). Guests only see the automatic promotions that are running. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Promotion administration” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admins manage promotions (Admin → Promotions): add, edit, pause / resume (never deleted), see how often each was used. Promo codes are unique (409). Guests only see the automatic promotions that are running. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-16-AC-01** — Given the preconditions/trigger, verify: Admins manage promotions (Admin → Promotions): add, edit, pause / resume (never deleted), see how often each was used. Promo codes are unique (409). Guests only see the automatic promotions that are running. **WEB-FR-BOOK-16-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PromotionService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PromotionService.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-ADMIN-PROMOTIONS; WEB-API-098, WEB-API-100, WEB-API-101 |

### WEB-FR-BOOK-17 — Membership points

| Field | Specification |
| --- | --- |
| Name | Membership points |
| Description | **Member points**: customers with an account earn points once a ticket is paid, on the amount actually paid and by tier: Member 5%, VIP (from 2,000,000 VND spent) 7%, VVIP (from 5,000,000 VND) 10%; 1 point = 1,000 VND. When booking (app or counter) points can pay at most 50% of the price (after promotions). An unpaid hold that expires or is cancelled gives the used points back; a paid ticket that is cancelled or refunded gives the used points back, takes the earned points back and lowers the total spent. Walk-in guests have no points. Customers see their member card (points, tier, what is left to the next tier, history) on the account page. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Invoke “Membership points” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Member points**: customers with an account earn points once a ticket is paid, on the amount actually paid and by tier: Member 5%, VIP (from 2,000,000 VND spent) 7%, VVIP (from 5,000,000 VND) 10%; 1 point = 1,000 VND. When booking (app or counter) points can pay at most 50% of the price (after promotions). An unpaid hold that expires or is cancelled gives the used points back; a paid ticket that is cancelled or refunded gives the used points back, takes the earned points back and lowers the total spent. Walk-in guests have no points. Customers see their member card (points, tier, what is left to the next tier, history) on the account page. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-17-AC-01** — Given the preconditions/trigger, verify: **Member points**: customers with an account earn points once a ticket is paid, on the amount actually paid and by tier: Member 5%, VIP (from 2,000,000 VND spent) 7%, VVIP (from 5,000,000 VND) 10%; 1 point = 1,000 VND. When booking (app or counter) points can pay at most 50% of the price (after promotions). An unpaid hold that expires or is cancelled gives the used points back; a paid ticket that is cancelled or refunded gives the used points back, takes the earned points back and lowers the total spent. Walk-in guests have no points. Customers see their member card (points, tier, what is left to the next tier, history) on the account page. **WEB-FR-BOOK-17-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-PROFILE, WEB-SCR-COUNTER; WEB-API-055, WEB-API-060 |

### WEB-FR-BOOK-18 — Member administration

| Field | Specification |
| --- | --- |
| Name | Member administration |
| Description | Admins see customers with their points, tier and total spent (Admin → Members), open the history and add or take away points with a reason (never below zero). The counter sees the card of a customer found by phone. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Member administration” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admins see customers with their points, tier and total spent (Admin → Members), open the history and add or take away points with a reason (never below zero). The counter sees the card of a customer found by phone. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-BOOK-18-AC-01** — Given the preconditions/trigger, verify: Admins see customers with their points, tier and total spent (Admin → Members), open the history and add or take away points with a reason (never below zero). The counter sees the card of a customer found by phone. **WEB-FR-BOOK-18-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/LoyaltyService.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-ADMIN-MEMBERS; WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 |

### WEB-FR-BOOK-19 — Share and calendar

| Field | Specification |
| --- | --- |
| Name | Share and calendar |
| Description | Paid tickets have **Share ticket** (movie, show time, seats and ticket code sent to friends through the device's share sheet; copied to the clipboard where the browser cannot share) and **Add to calendar** (a Google Calendar event in Vietnam time ending when the show ends; only for shows still to come). |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | Customer is signed in and owns the relevant ticket; the requested action must be permitted by ticket state and time. Staff access applies only where stated. |
| Trigger | Invoke “Share and calendar” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Paid tickets have **Share ticket** (movie, show time, seats and ticket code sent to friends through the device's share sheet; copied to the clipboard where the browser cannot share) and **Add to calendar** (a Google Calendar event in Vietnam time ending when the show ends; only for shows still to come). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | L |
| Acceptance criteria | **WEB-FR-BOOK-19-AC-01** — Given the preconditions/trigger, verify: Paid tickets have **Share ticket** (movie, show time, seats and ticket code sent to friends through the device's share sheet; copied to the clipboard where the browser cannot share) and **Add to calendar** (a Google Calendar event in Vietnam time ending when the show ends; only for shows still to come). **WEB-FR-BOOK-19-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; WEB-SCR-TICKET; WEB-API-017 |

### WEB-FR-PAY-01 — Create/reuse PayOS link

| Field | Specification |
| --- | --- |
| Name | Create/reuse PayOS link |
| Description | Create a PayOS payment link for a `PENDING` booking. One payment per booking; asking again returns the existing link. The PayOS order code is the booking id × 1,000,000 plus the six random digits that end the booking code: stable per booking and never repeating an order of another environment on the shared PayOS account. The link expires with the seat hold. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Create/reuse PayOS link” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Create a PayOS payment link for a `PENDING` booking. One payment per booking; asking again returns the existing link. The PayOS order code is the booking id × 1,000,000 plus the six random digits that end the booking code: stable per booking and never repeating an order of another environment on the shared PayOS account. The link expires with the seat hold. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-PAY-01-AC-01** — Given the preconditions/trigger, verify: Create a PayOS payment link for a `PENDING` booking. One payment per booking; asking again returns the existing link. The PayOS order code is the booking id × 1,000,000 plus the six random digits that end the booking code: stable per booking and never repeating an order of another environment on the shared PayOS account. The link expires with the seat hold. **WEB-FR-PAY-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-PAYMENT, WEB-SCR-CHECKOUT; WEB-API-088 |

### WEB-FR-PAY-02 — Verify PayOS

| Field | Specification |
| --- | --- |
| Name | Verify PayOS |
| Description | Verify a payment by order code (or booking id): paid at PayOS means payment `SUCCESS` and booking `CONFIRMED`; cancelled on the PayOS page means payment `FAILED`, booking `CANCELLED` and seats released at once. Calling it again is safe. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Verify PayOS” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Verify a payment by order code (or booking id): paid at PayOS means payment `SUCCESS` and booking `CONFIRMED`; cancelled on the PayOS page means payment `FAILED`, booking `CANCELLED` and seats released at once. Calling it again is safe. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-PAY-02-AC-01** — Given the preconditions/trigger, verify: Verify a payment by order code (or booking id): paid at PayOS means payment `SUCCESS` and booking `CONFIRMED`; cancelled on the PayOS page means payment `FAILED`, booking `CANCELLED` and seats released at once. Calling it again is safe. **WEB-FR-PAY-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-CHECKOUT; WEB-API-087 |

### WEB-FR-PAY-03 — Payment details

| Field | Specification |
| --- | --- |
| Name | Payment details |
| Description | Show a payment: to the ticket owner or to Staff/Admin. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Payment details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show a payment: to the ticket owner or to Staff/Admin. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-PAY-03-AC-01** — Given the preconditions/trigger, verify: Show a payment: to the ticket owner or to Staff/Admin. **WEB-FR-PAY-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-TICKET, WEB-SCR-PAYHISTORY, WEB-SCR-RECORD-PAYMENTS; WEB-API-084 |

### WEB-FR-PAY-04 — Own payment history

| Field | Specification |
| --- | --- |
| Name | Own payment history |
| Description | Customers see their payment history. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Own payment history” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Customers see their payment history. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-04-AC-01** — Given the preconditions/trigger, verify: Customers see their payment history. **WEB-FR-PAY-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-PAYHISTORY; WEB-API-095 |

### WEB-FR-PAY-05 — Payments by booking

| Field | Specification |
| --- | --- |
| Name | Payments by booking |
| Description | Show the payments of a booking. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Payments by booking” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show the payments of a booking. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-05-AC-01** — Given the preconditions/trigger, verify: Show the payments of a booking. **WEB-FR-PAY-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-RECORD-PAYMENTS; WEB-API-085 |

### WEB-FR-PAY-06 — Refund access

| Field | Specification |
| --- | --- |
| Name | Refund access |
| Description | The booking owner requests a refund by cancelling an eligible paid booking; Staff/Admin review and complete or reject the manual-refund workflow, and Admin may initiate a manual payment refund through the API. Refund rules and states are specified in the REF requirements. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Refund access” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The booking owner requests a refund by cancelling an eligible paid booking; Staff/Admin review and complete or reject the manual-refund workflow, and Admin may initiate a manual payment refund through the API. Refund rules and states are specified in the REF requirements. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-PAY-06-AC-01** — Given the preconditions/trigger, verify: The booking owner requests a refund by cancelling an eligible paid booking; Staff/Admin review and complete or reject the manual-refund workflow, and Admin may initiate a manual payment refund through the API. Refund rules and states are specified in the REF requirements. **WEB-FR-PAY-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-TICKET; WEB-API-043, WEB-API-082, WEB-API-083 |

### WEB-FR-PAY-07 — Signed webhook

| Field | Specification |
| --- | --- |
| Name | Signed webhook |
| Description | Receive the PayOS webhook: check the HMAC-SHA256 signature (400 when wrong); an unknown order or wrong amount returns 200 and is ignored; a repeated webhook confirms and emails nothing twice. The payer's account (number, name, bank) is stored for refunds. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Signed webhook” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Receive the PayOS webhook: check the HMAC-SHA256 signature (400 when wrong); an unknown order or wrong amount returns 200 and is ignored; a repeated webhook confirms and emails nothing twice. The payer's account (number, name, bank) is stored for refunds. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-PAY-07-AC-01** — Given the preconditions/trigger, verify: Receive the PayOS webhook: check the HMAC-SHA256 signature (400 when wrong); an unknown order or wrong amount returns 200 and is ignored; a repeated webhook confirms and emails nothing twice. The payer's account (number, name, bank) is stored for refunds. **WEB-FR-PAY-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; ; WEB-API-089 |

### WEB-FR-PAY-08 — Late payment

| Field | Specification |
| --- | --- |
| Name | Late payment |
| Description | When PayOS reports payment after the hold expired, confirm the booking only if all seats can be reclaimed; otherwise create a full refund request. Repeated verification/webhook must not duplicate financial effects. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Late payment” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: When PayOS reports payment after the hold expired, confirm the booking only if all seats can be reclaimed; otherwise create a full refund request. Repeated verification/webhook must not duplicate financial effects. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-08-AC-01** — Given the preconditions/trigger, verify: When PayOS reports payment after the hold expired, confirm the booking only if all seats can be reclaimed; otherwise create a full refund request. Repeated verification/webhook must not duplicate financial effects. **WEB-FR-PAY-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-RESULT; WEB-API-087, WEB-API-089 |

### WEB-FR-PAY-09 — Management payments

| Field | Specification |
| --- | --- |
| Name | Management payments |
| Description | Staff/Admin list payments and re-verify a pending PayOS payment. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Management payments” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin list payments and re-verify a pending PayOS payment. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-09-AC-01** — Given the preconditions/trigger, verify: Staff/Admin list payments and re-verify a pending PayOS payment. **WEB-FR-PAY-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-PAYMENTS; WEB-API-087, WEB-API-096 |

### WEB-FR-PAY-10 — Revenue summary

| Field | Specification |
| --- | --- |
| Name | Revenue summary |
| Description | Admin sees revenue for a period: payments received, revenue (`SUCCESS` + `REFUND_PENDING`), amount refunded (`REFUNDED`). |
| Actor | Admin |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Revenue summary” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Admin sees revenue for a period: payments received, revenue (`SUCCESS` + `REFUND_PENDING`), amount refunded (`REFUNDED`). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-10-AC-01** — Given the preconditions/trigger, verify: Admin sees revenue for a period: payments received, revenue (`SUCCESS` + `REFUND_PENDING`), amount refunded (`REFUNDED`). **WEB-FR-PAY-10-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; ; WEB-API-094 |

### WEB-FR-PAY-11 — Automatic payment polling

| Field | Specification |
| --- | --- |
| Name | Automatic payment polling |
| Description | While open, the app's payment page checks the booking every 5 seconds and asks PayOS every 30 seconds; there is no "I have paid" button. |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Invoke “Automatic payment polling” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: While open, the app's payment page checks the booking every 5 seconds and asks PayOS every 30 seconds; there is no "I have paid" button. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-PAY-11-AC-01** — Given the preconditions/trigger, verify: While open, the app's payment page checks the booking every 5 seconds and asks PayOS every 30 seconds; there is no "I have paid" button. **WEB-FR-PAY-11-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/PaymentService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs](../Cinema_BE/BookingService/BookingService/Helpers/PayOsSignature.cs) |
| Business rules | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-08; WEB-SCR-PAYMENT; WEB-API-046, WEB-API-087 |

### WEB-FR-REF-01 — Create refund request

| Field | Specification |
| --- | --- |
| Name | Create refund request |
| Description | A refund request (`PENDING`) is created when: a customer cancels a paid ticket in time; Staff/Admin cancel a paid ticket; a showtime is cancelled; a late payment lost its seats; an Admin refunds a payment manually. The payment becomes `REFUND_PENDING` and the customer gets an email. |
| Actor | Customer requests/reads own refund; Staff/Admin process; system creates requests |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Create refund request” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A refund request (`PENDING`) is created when: a customer cancels a paid ticket in time; Staff/Admin cancel a paid ticket; a showtime is cancelled; a late payment lost its seats; an Admin refunds a payment manually. The payment becomes `REFUND_PENDING` and the customer gets an email. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-REF-01-AC-01** — Given the preconditions/trigger, verify: A refund request (`PENDING`) is created when: a customer cancels a paid ticket in time; Staff/Admin cancel a paid ticket; a showtime is cancelled; a late payment lost its seats; an Admin refunds a payment manually. The payment becomes `REFUND_PENDING` and the customer gets an email. **WEB-FR-REF-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-TICKET; WEB-API-043, WEB-API-083, WEB-API-089 |

### WEB-FR-REF-02 — Management refund list

| Field | Specification |
| --- | --- |
| Name | Management refund list |
| Description | Staff/Admin list refund requests (filter by status) and see their details: amount, reason, payer account. |
| Actor | Staff/Admin |
| Preconditions | A paid booking/payment exists; customer cancellation is at least two hours before start; staff processing requires a pending request. |
| Trigger | Invoke “Management refund list” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin list refund requests (filter by status) and see their details: amount, reason, payer account. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-REF-02-AC-01** — Given the preconditions/trigger, verify: Staff/Admin list refund requests (filter by status) and see their details: amount, reason, payer account. **WEB-FR-REF-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-OPERATIONS, WEB-SCR-RECORD-REFUNDS; WEB-API-092, WEB-API-093 |

### WEB-FR-REF-03 — Record completed transfer

| Field | Specification |
| --- | --- |
| Name | Record completed transfer |
| Description | After transferring the money, staff record the transfer reference: refund `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` with seats released, and an email with the reference. |
| Actor | Staff/Admin |
| Preconditions | A paid booking/payment exists; customer cancellation is at least two hours before start; staff processing requires a pending request. |
| Trigger | Invoke “Record completed transfer” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: After transferring the money, staff record the transfer reference: refund `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` with seats released, and an email with the reference. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-REF-03-AC-01** — Given the preconditions/trigger, verify: After transferring the money, staff record the transfer reference: refund `COMPLETED`, payment `REFUNDED`, booking `CANCELLED` with seats released, and an email with the reference. **WEB-FR-REF-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-090 |

### WEB-FR-REF-04 — Reject refund

| Field | Specification |
| --- | --- |
| Name | Reject refund |
| Description | Staff reject a request (reason required, only while `PENDING`): the payment returns to `SUCCESS` and the booking to `CONFIRMED` with its seats; the customer sees the reason on the ticket and gets an email. Refunds of tickets the cinema cancelled cannot be rejected. |
| Actor | Staff/Admin |
| Preconditions | A paid booking/payment exists; customer cancellation is at least two hours before start; staff processing requires a pending request. |
| Trigger | Invoke “Reject refund” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff reject a request (reason required, only while `PENDING`): the payment returns to `SUCCESS` and the booking to `CONFIRMED` with its seats; the customer sees the reason on the ticket and gets an email. Refunds of tickets the cinema cancelled cannot be rejected. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-REF-04-AC-01** — Given the preconditions/trigger, verify: Staff reject a request (reason required, only while `PENDING`): the payment returns to `SUCCESS` and the booking to `CONFIRMED` with its seats; the customer sees the reason on the ticket and gets an email. Refunds of tickets the cinema cancelled cannot be rejected. **WEB-FR-REF-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-091 |

### WEB-FR-REF-05 — Reopen rejected refund

| Field | Specification |
| --- | --- |
| Name | Reopen rejected refund |
| Description | A rejected request is reopened if the cinema later cancels the ticket or the showtime. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Reopen rejected refund” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A rejected request is reopened if the cinema later cancels the ticket or the showtime. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-REF-05-AC-01** — Given the preconditions/trigger, verify: A rejected request is reopened if the cinema later cancels the ticket or the showtime. **WEB-FR-REF-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-TICKET, WEB-SCR-RECORD-REFUNDS; WEB-API-016, WEB-API-043 |

### WEB-FR-REF-06 — Own refund status

| Field | Specification |
| --- | --- |
| Name | Own refund status |
| Description | Customers see the refund status of their ticket. |
| Actor | Customer requests/reads own refund; Staff/Admin process; system creates requests |
| Preconditions | A paid booking/payment exists; customer cancellation is at least two hours before start; staff processing requires a pending request. |
| Trigger | Invoke “Own refund status” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Customers see the refund status of their ticket. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-REF-06-AC-01** — Given the preconditions/trigger, verify: Customers see the refund status of their ticket. **WEB-FR-REF-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-TICKET, WEB-SCR-RECORD-PAYMENTS; WEB-API-082 |

### WEB-FR-REF-07 — Unique refund per payment

| Field | Specification |
| --- | --- |
| Name | Unique refund per payment |
| Description | Each payment has only one refund request, even when an event is delivered again. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Unique refund per payment” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Each payment has only one refund request, even when an event is delivered again. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-REF-07-AC-01** — Given the preconditions/trigger, verify: Each payment has only one refund request, even when an event is delivered again. **WEB-FR-REF-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/RefundService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs) |
| Business rules | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 |
| Use case / screens / APIs | UC-WEB-09; WEB-SCR-RECORD-REFUNDS; WEB-API-043, WEB-API-082 |

### WEB-FR-POS-01 — Create counter sale

| Field | Specification |
| --- | --- |
| Name | Create counter sale |
| Description | Staff/Admin sell tickets to a **walk-in guest** (no account; email and phone optional) or a **member** (account ID + email, or found by phone number; members use and earn points): choose a movie, a showtime in the next 7 days and seats on the map (sweetbox in pairs, priced by type). |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Create counter sale” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin sell tickets to a **walk-in guest** (no account; email and phone optional) or a **member** (account ID + email, or found by phone number; members use and earn points): choose a movie, a showtime in the next 7 days and seats on the map (sweetbox in pairs, priced by type). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-01-AC-01** — Given the preconditions/trigger, verify: Staff/Admin sell tickets to a **walk-in guest** (no account; email and phone optional) or a **member** (account ID + email, or found by phone number; members use and earn points): choose a movie, a showtime in the next 7 days and seats on the map (sweetbox in pairs, priced by type). **WEB-FR-POS-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs); [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-COUNTER; WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055 |

### WEB-FR-POS-02 — Counter checkout

| Field | Specification |
| --- | --- |
| Name | Counter checkout |
| Description | After the seats are held, the **Take payment** screen shows the ticket, the customer, the total, the hold countdown and an optional email for the ticket. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Counter checkout” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: After the seats are held, the **Take payment** screen shows the ticket, the customer, the total, the hold countdown and an optional email for the ticket. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-02-AC-01** — Given the preconditions/trigger, verify: After the seats are held, the **Take payment** screen shows the ticket, the customer, the total, the hold countdown and an optional email for the ticket. **WEB-FR-POS-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-046 |

### WEB-FR-POS-03 — Cash and change

| Field | Specification |
| --- | --- |
| Name | Cash and change |
| Description | **Cash**: enter the cash received (with round-amount buttons); the screen shows the change and refuses less than the total. The server records a `CASH` payment as `SUCCESS` (reference `CASH-<booking code>`) and confirms the ticket. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Cash and change” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Cash**: enter the cash received (with round-amount buttons); the screen shows the change and refuses less than the total. The server records a `CASH` payment as `SUCCESS` (reference `CASH-<booking code>`) and confirms the ticket. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-03-AC-01** — Given the preconditions/trigger, verify: **Cash**: enter the cash received (with round-amount buttons); the screen shows the change and refuses less than the total. The server records a `CASH` payment as `SUCCESS` (reference `CASH-<booking code>`) and confirms the ticket. **WEB-FR-POS-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-086 |

### WEB-FR-POS-04 — Bank-transfer QR

| Field | Specification |
| --- | --- |
| Name | Bank-transfer QR |
| Description | **Bank transfer**: show the PayOS VietQR for the customer's banking app (for a link made earlier, a QR code of its checkout page); the screen checks every 3 seconds and switches to paid when the money arrives. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Bank-transfer QR” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Bank transfer**: show the PayOS VietQR for the customer's banking app (for a link made earlier, a QR code of its checkout page); the screen checks every 3 seconds and switches to paid when the money arrives. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-04-AC-01** — Given the preconditions/trigger, verify: **Bank transfer**: show the PayOS VietQR for the customer's banking app (for a link made earlier, a QR code of its checkout page); the screen checks every 3 seconds and switches to paid when the money arrives. **WEB-FR-POS-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-087, WEB-API-088 |

### WEB-FR-POS-05 — Switch transfer to cash

| Field | Specification |
| --- | --- |
| Name | Switch transfer to cash |
| Description | Switching from bank transfer to cash follows WEB-BR-22: the PayOS link is cancelled and that payment becomes `FAILED`; if the customer already transferred, cash returns 409. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Switch transfer to cash” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Switching from bank transfer to cash follows WEB-BR-22: the PayOS link is cancelled and that payment becomes `FAILED`; if the customer already transferred, cash returns 409. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-05-AC-01** — Given the preconditions/trigger, verify: Switching from bank transfer to cash follows WEB-BR-22: the PayOS link is cancelled and that payment becomes `FAILED`; if the customer already transferred, cash returns 409. **WEB-FR-POS-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-086 |

### WEB-FR-POS-06 — Retain counter email

| Field | Specification |
| --- | --- |
| Name | Retain counter email |
| Description | An email given at the counter is saved on the booking, so later cancellation and refund emails reach the customer too. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Retain counter email” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: An email given at the counter is saved on the booking, so later cancellation and refund emails reach the customer too. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-POS-06-AC-01** — Given the preconditions/trigger, verify: An email given at the counter is saved on the booking, so later cancellation and refund emails reach the customer too. **WEB-FR-POS-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-055, WEB-API-086 |

### WEB-FR-POS-07 — Print and admit

| Field | Specification |
| --- | --- |
| Name | Print and admit |
| Description | After payment: the ticket QR code; **Print ticket** (web, 80 mm receipt paper); **Check in now** when the show starts within 3 hours; **Sell another ticket**. Without an email, print the ticket or let the customer photograph the QR code. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Print and admit” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: After payment: the ticket QR code; **Print ticket** (web, 80 mm receipt paper); **Check in now** when the show starts within 3 hours; **Sell another ticket**. Without an email, print the ticket or let the customer photograph the QR code. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-POS-07-AC-01** — Given the preconditions/trigger, verify: After payment: the ticket QR code; **Print ticket** (web, 80 mm receipt paper); **Check in now** when the show starts within 3 hours; **Sell another ticket**. Without an email, print the ticket or let the customer photograph the QR code. **WEB-FR-POS-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT; WEB-API-044, WEB-API-046 |

### WEB-FR-POS-08 — Reopen paid ticket

| Field | Specification |
| --- | --- |
| Name | Reopen paid ticket |
| Description | Paid tickets have **Show ticket** on their booking page, to print again or check in. |
| Actor | Staff/Admin |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Invoke “Reopen paid ticket” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Paid tickets have **Show ticket** on their booking page, to print again or check in. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-POS-08-AC-01** — Given the preconditions/trigger, verify: Paid tickets have **Show ticket** on their booking page, to print again or check in. **WEB-FR-POS-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |
| Business rules | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-10; WEB-SCR-CHECKOUT, WEB-SCR-RECORD-BOOKINGS; WEB-API-046 |

### WEB-FR-CHK-01 — Ticket QR

| Field | Specification |
| --- | --- |
| Name | Ticket QR |
| Description | A paid ticket has a QR code holding its booking code, shown in the customer app, in the confirmation email and on the printed ticket. |
| Actor | Customer |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Invoke “Ticket QR” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: A paid ticket has a QR code holding its booking code, shown in the customer app, in the confirmation email and on the printed ticket. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-CHK-01-AC-01** — Given the preconditions/trigger, verify: A paid ticket has a QR code holding its booking code, shown in the customer app, in the confirmation email and on the printed ticket. **WEB-FR-CHK-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Business rules | WEB-BR-21 |
| Use case / screens / APIs | UC-WEB-11; WEB-SCR-TICKET, WEB-SCR-CHECKOUT; WEB-API-046 |

### WEB-FR-CHK-02 — Lookup ticket code

| Field | Specification |
| --- | --- |
| Name | Lookup ticket code |
| Description | Staff/Admin look a ticket up by code (case-insensitive): movie, time, room, seats, total, status. |
| Actor | Staff/Admin |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Invoke “Lookup ticket code” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin look a ticket up by code (case-insensitive): movie, time, room, seats, total, status. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-CHK-02-AC-01** — Given the preconditions/trigger, verify: Staff/Admin look a ticket up by code (case-insensitive): movie, time, room, seats, total, status. **WEB-FR-CHK-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Business rules | WEB-BR-21 |
| Use case / screens / APIs | UC-WEB-11; WEB-SCR-CHECKIN; WEB-API-047 |

### WEB-FR-CHK-03 — Check-in validation

| Field | Specification |
| --- | --- |
| Name | Check-in validation |
| Description | Check-in follows WEB-BR-21; otherwise 409 with the reason (unpaid, cancelled, refund pending, too early, too late, already checked in at a given time). When two counters scan the same ticket, the second gets 409. |
| Actor | Staff/Admin |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Invoke “Check-in validation” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Check-in follows WEB-BR-21; otherwise 409 with the reason (unpaid, cancelled, refund pending, too early, too late, already checked in at a given time). When two counters scan the same ticket, the second gets 409. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | Only one check-in timestamp is stored; check-in is an attribute, not another booking status. |
| Priority | H |
| Acceptance criteria | **WEB-FR-CHK-03-AC-01** — Given the preconditions/trigger, verify: Check-in follows WEB-BR-21; otherwise 409 with the reason (unpaid, cancelled, refund pending, too early, too late, already checked in at a given time). When two counters scan the same ticket, the second gets 409. **WEB-FR-CHK-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Business rules | WEB-BR-21 |
| Use case / screens / APIs | UC-WEB-11; WEB-SCR-CHECKIN, WEB-SCR-CHECKOUT; WEB-API-044 |

### WEB-FR-CHK-04 — Camera/manual scanner

| Field | Specification |
| --- | --- |
| Name | Camera/manual scanner |
| Description | Scan the QR code with a phone camera (app), a laptop webcam or USB camera (admin website), or type the code / use a handheld scanner (code + Enter). |
| Actor | Staff/Admin |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Invoke “Camera/manual scanner” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Scan the QR code with a phone camera (app), a laptop webcam or USB camera (admin website), or type the code / use a handheld scanner (code + Enter). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | Only one check-in timestamp is stored; check-in is an attribute, not another booking status. |
| Priority | H |
| Acceptance criteria | **WEB-FR-CHK-04-AC-01** — Given the preconditions/trigger, verify: Scan the QR code with a phone camera (app), a laptop webcam or USB camera (admin website), or type the code / use a handheld scanner (code + Enter). **WEB-FR-CHK-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Business rules | WEB-BR-21 |
| Use case / screens / APIs | UC-WEB-11; WEB-SCR-CHECKIN; WEB-API-044, WEB-API-047 |

### WEB-FR-CHK-05 — Display check-in time

| Field | Specification |
| --- | --- |
| Name | Display check-in time |
| Description | The check-in time shows on the customer's ticket, the booking page, the seat map and the showtime's customer list. |
| Actor | Staff/Admin |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Invoke “Display check-in time” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The check-in time shows on the customer's ticket, the booking page, the seat map and the showtime's customer list. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-CHK-05-AC-01** — Given the preconditions/trigger, verify: The check-in time shows on the customer's ticket, the booking page, the seat map and the showtime's customer list. **WEB-FR-CHK-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart); [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs](../Cinema_BE/BookingService/BookingService/Configuration/CheckInOptions.cs) |
| Business rules | WEB-BR-21 |
| Use case / screens / APIs | UC-WEB-11; WEB-SCR-TICKET, WEB-SCR-CHECKIN, WEB-SCR-RECORD-BOOKINGS; WEB-API-046, WEB-API-050 |

### WEB-FR-NOTI-01 — Notification history

| Field | Specification |
| --- | --- |
| Name | Notification history |
| Description | Customers see their notifications and details and open the related ticket. Admins see all notifications. |
| Actor | Customer reads own; Staff/Admin send permitted messages; system dispatches events |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Notification history” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Customers see their notifications and details and open the related ticket. Admins see all notifications. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-01-AC-01** — Given the preconditions/trigger, verify: Customers see their notifications and details and open the related ticket. Admins see all notifications. **WEB-FR-NOTI-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; WEB-SCR-NOTIFICATIONS; WEB-API-078, WEB-API-079 |

### WEB-FR-NOTI-02 — Compose booking message

| Field | Specification |
| --- | --- |
| Name | Compose booking message |
| Description | Staff/Admin write an email notification to a ticket's customer (walk-in guests with an email included). |
| Actor | Staff/Admin |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Compose booking message” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Staff/Admin write an email notification to a ticket's customer (walk-in guests with an email included). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-02-AC-01** — Given the preconditions/trigger, verify: Staff/Admin write an email notification to a ticket's customer (walk-in guests with an email included). **WEB-FR-NOTI-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; WEB-SCR-COMPOSE; WEB-API-080 |

### WEB-FR-NOTI-03 — Send/retry message

| Field | Specification |
| --- | --- |
| Name | Send/retry message |
| Description | Send a notification; a failure is stored as `FAILED` with the error, and the same notification can be sent again. |
| Actor | Staff/Admin |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Send/retry message” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Send a notification; a failure is stored as `FAILED` with the error, and the same notification can be sent again. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-03-AC-01** — Given the preconditions/trigger, verify: Send a notification; a failure is stored as `FAILED` with the error, and the same notification can be sent again. **WEB-FR-NOTI-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; WEB-SCR-COMPOSE; WEB-API-073 |

### WEB-FR-NOTI-04 — Notification details

| Field | Specification |
| --- | --- |
| Name | Notification details |
| Description | Show a notification. |
| Actor | Customer reads own; Staff/Admin send permitted messages; system dispatches events |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Notification details” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Show a notification. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-04-AC-01** — Given the preconditions/trigger, verify: Show a notification. **WEB-FR-NOTI-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; WEB-SCR-NOTIFICATION; WEB-API-075 |

### WEB-FR-NOTI-05 — Delete notification API

| Field | Specification |
| --- | --- |
| Name | Delete notification API |
| Description | Delete a notification: the recipient deletes their own, an Admin any (API only). |
| Actor | Customer reads own; Staff/Admin send permitted messages; system dispatches events |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Delete notification API” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Delete a notification: the recipient deletes their own, an Admin any (API only). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | L |
| Acceptance criteria | **WEB-FR-NOTI-05-AC-01** — Given the preconditions/trigger, verify: Delete a notification: the recipient deletes their own, an Admin any (API only). **WEB-FR-NOTI-05-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; ; WEB-API-074 |

### WEB-FR-NOTI-06 — Event emails

| Field | Specification |
| --- | --- |
| Name | Event emails |
| Description | Consume committed booking/payment events to send confirmation with inline QR, cancellation, expiry and refund emails. Deduplicate by event ID and skip tickets without email. Delivery is retryable; SMTP and database commit do not guarantee absolute exactly-once delivery after a crash. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Event emails” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Consume committed booking/payment events to send confirmation with inline QR, cancellation, expiry and refund emails. Deduplicate by event ID and skip tickets without email. Delivery is retryable; SMTP and database commit do not guarantee absolute exactly-once delivery after a crash. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | H |
| Acceptance criteria | **WEB-FR-NOTI-06-AC-01** — Given the preconditions/trigger, verify: Consume committed booking/payment events to send confirmation with inline QR, cancellation, expiry and refund emails. Deduplicate by event ID and skip tickets without email. Delivery is retryable; SMTP and database commit do not guarantee absolute exactly-once delivery after a crash. **WEB-FR-NOTI-06-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; ; WEB-API-078 |

### WEB-FR-NOTI-07 — OTP and welcome email

| Field | Specification |
| --- | --- |
| Name | OTP and welcome email |
| Description | AuthService emails OTP codes (verification, password reset) and a welcome email. |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “OTP and welcome email” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: AuthService emails OTP codes (verification, password reset) and a welcome email. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-NOTI-07-AC-01** — Given the preconditions/trigger, verify: AuthService emails OTP codes (verification, password reset) and a welcome email. **WEB-FR-NOTI-07-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; ; WEB-API-026, WEB-API-033, WEB-API-042 |

### WEB-FR-NOTI-08 — Showtime reminder

| Field | Specification |
| --- | --- |
| Name | Showtime reminder |
| Description | **Showtime reminders**: a background job (every minute, `ShowtimeReminder` settings) emails and records a notification for paid tickets not checked in whose show starts within 2 hours; each ticket once. Tickets bought inside that window are skipped (the customer just got the confirmation). |
| Actor | Shared backend system; customer receives outcome |
| Preconditions | The corresponding committed event, trusted PayOS result or scheduled-worker condition exists; backend processing is configured. No customer session is required for a background worker or signed webhook. |
| Trigger | Invoke “Showtime reminder” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Showtime reminders**: a background job (every minute, `ShowtimeReminder` settings) emails and records a notification for paid tickets not checked in whose show starts within 2 hours; each ticket once. Tickets bought inside that window are skipped (the customer just got the confirmation). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-08-AC-01** — Given the preconditions/trigger, verify: **Showtime reminders**: a background job (every minute, `ShowtimeReminder` settings) emails and records a notification for paid tickets not checked in whose show starts within 2 hours; each ticket once. Tickets bought inside that window are skipped (the customer just got the confirmation). **WEB-FR-NOTI-08-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; ; WEB-API-078 |

### WEB-FR-NOTI-09 — Read/unread notifications

| Field | Specification |
| --- | --- |
| Name | Read/unread notifications |
| Description | **Read / unread**: unopened notifications have a dot and bold title; opening one marks it read; **Mark all read** button. The app bell and the website Notifications link show how many are unread. Only the owner can mark them (403). |
| Actor | Customer reads own; Staff/Admin send permitted messages; system dispatches events |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Invoke “Read/unread notifications” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Read / unread**: unopened notifications have a dot and bold title; opening one marks it read; **Mark all read** button. The app bell and the website Notifications link show how many are unread. Only the owner can mark them (403). 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-NOTI-09-AC-01** — Given the preconditions/trigger, verify: **Read / unread**: unopened notifications have a dot and bold title; opening one marks it read; **Mark all read** button. The app bell and the website Notifications link show how many are unread. Only the owner can mark them (403). **WEB-FR-NOTI-09-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart); [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart); [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs); [Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs](../Cinema_BE/BookingService/BookingService/Workers/ShowtimeReminderWorker.cs) |
| Business rules | WEB-BR-11, WEB-BR-13 |
| Use case / screens / APIs | UC-WEB-12; WEB-SCR-HOME, WEB-SCR-NOTIFICATIONS, WEB-SCR-NOTIFICATION; WEB-API-072, WEB-API-076, WEB-API-077 |

### WEB-FR-DASH-01 — Today totals

| Field | Specification |
| --- | --- |
| Name | Today totals |
| Description | **Today** block (Staff and Admin): bookings made today; today's showtimes with bookings (x / total); tickets for today's shows; how many checked in. |
| Actor | Staff/Admin |
| Preconditions | Management session and source records exist; date ranges use cinema local time. |
| Trigger | Invoke “Today totals” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: **Today** block (Staff and Admin): bookings made today; today's showtimes with bookings (x / total); tickets for today's shows; how many checked in. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show zero/empty periods accurately; a card can show its own error and retry. Staff must not acquire revenue/account APIs by changing the URL. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-DASH-01-AC-01** — Given the preconditions/trigger, verify: **Today** block (Staff and Admin): bookings made today; today's showtimes with bookings (x / total); tickets for today's shows; how many checked in. **WEB-FR-DASH-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Business rules | WEB-BR-09, WEB-BR-23 |
| Use case / screens / APIs | UC-WEB-13; WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH; WEB-API-019, WEB-API-048, WEB-API-051 |

### WEB-FR-DASH-02 — Live showtime board

| Field | Specification |
| --- | --- |
| Name | Live showtime board |
| Description | Showtime board: **Now showing** (every show playing, watching now = checked in, tickets sold / capacity, time left); **Up next** (next 3 shows: booked, awaiting payment, checked in early); **Just finished** (last 3 shows: tickets sold, people who came). Clicking a show opens its seat map and customer list. Refreshes every minute. |
| Actor | Staff/Admin |
| Preconditions | Management session and source records exist; date ranges use cinema local time. |
| Trigger | Invoke “Live showtime board” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Showtime board: **Now showing** (every show playing, watching now = checked in, tickets sold / capacity, time left); **Up next** (next 3 shows: booked, awaiting payment, checked in early); **Just finished** (last 3 shows: tickets sold, people who came). Clicking a show opens its seat map and customer list. Refreshes every minute. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show zero/empty periods accurately; a card can show its own error and retry. Staff must not acquire revenue/account APIs by changing the URL. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-DASH-02-AC-01** — Given the preconditions/trigger, verify: Showtime board: **Now showing** (every show playing, watching now = checked in, tickets sold / capacity, time left); **Up next** (next 3 shows: booked, awaiting payment, checked in early); **Just finished** (last 3 shows: tickets sold, people who came). Clicking a show opens its seat map and customer list. Refreshes every minute. **WEB-FR-DASH-02-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Business rules | WEB-BR-09, WEB-BR-23 |
| Use case / screens / APIs | UC-WEB-13; WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH; WEB-API-019, WEB-API-051 |

### WEB-FR-DASH-03 — Staff attention queue

| Field | Specification |
| --- | --- |
| Name | Staff attention queue |
| Description | The Staff dashboard has **Needs attention**: unpaid bookings and pending refund requests; shortcuts to **Sell tickets** and **Check in**. |
| Actor | Staff/Admin |
| Preconditions | Management session and source records exist; date ranges use cinema local time. |
| Trigger | Invoke “Staff attention queue” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The Staff dashboard has **Needs attention**: unpaid bookings and pending refund requests; shortcuts to **Sell tickets** and **Check in**. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show zero/empty periods accurately; a card can show its own error and retry. Staff must not acquire revenue/account APIs by changing the URL. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-DASH-03-AC-01** — Given the preconditions/trigger, verify: The Staff dashboard has **Needs attention**: unpaid bookings and pending refund requests; shortcuts to **Sell tickets** and **Check in**. **WEB-FR-DASH-03-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart) |
| Business rules | WEB-BR-09, WEB-BR-23 |
| Use case / screens / APIs | UC-WEB-13; WEB-SCR-STAFF-DASH; WEB-API-052, WEB-API-093 |

### WEB-FR-DASH-04 — Admin monthly overview

| Field | Specification |
| --- | --- |
| Name | Admin monthly overview |
| Description | The Admin dashboard: this month's bookings and revenue, amount refunded, movies now showing, today's showtimes, account statistics (total, active, locked). Each part loads on its own, so one failure does not break the others. |
| Actor | Staff/Admin |
| Preconditions | Management session and source records exist; date ranges use cinema local time. |
| Trigger | Invoke “Admin monthly overview” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: The Admin dashboard: this month's bookings and revenue, amount refunded, movies now showing, today's showtimes, account statistics (total, active, locked). Each part loads on its own, so one failure does not break the others. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show zero/empty periods accurately; a card can show its own error and retry. Staff must not acquire revenue/account APIs by changing the URL. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | M |
| Acceptance criteria | **WEB-FR-DASH-04-AC-01** — Given the preconditions/trigger, verify: The Admin dashboard: this month's bookings and revenue, amount refunded, movies now showing, today's showtimes, account statistics (total, active, locked). Each part loads on its own, so one failure does not break the others. **WEB-FR-DASH-04-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs); [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs); [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs); [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |
| Business rules | WEB-BR-09, WEB-BR-23 |
| Use case / screens / APIs | UC-WEB-13; WEB-SCR-ADMIN-DASH; WEB-API-040, WEB-API-048, WEB-API-069, WEB-API-094 |

### WEB-FR-NAV-01 — Route guards and recovery

| Field | Specification |
| --- | --- |
| Name | Route guards and recovery |
| Description | Guard named routes: a signed-out protected destination opens login with its pending route; successful sign-in resumes an allowed destination. Unknown routes fall back to the role landing. A summary lacking its in-memory BookingDraft returns to seat selection. |
| Actor | Guest; signed-in account; system |
| Preconditions | The account form is reachable and gateway/AuthService are configured; no prior signed-in session is required for registration/login/OTP/recovery. SMTP is required when sending a code. |
| Trigger | Invoke “Route guards and recovery” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Guard named routes: a signed-out protected destination opens login with its pending route; successful sign-in resumes an allowed destination. Unknown routes fall back to the role landing. A summary lacking its in-memory BookingDraft returns to seat selection. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | H |
| Acceptance criteria | **WEB-FR-NAV-01-AC-01** — Given the preconditions/trigger, verify: Guard named routes: a signed-out protected destination opens login with its pending route; successful sign-in resumes an allowed destination. Unknown routes fall back to the role landing. A summary lacking its in-memory BookingDraft returns to seat selection. **WEB-FR-NAV-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart); [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart); [Cinema_BE/AuthService/AuthService/Service/AuthService.cs](../Cinema_BE/AuthService/AuthService/Service/AuthService.cs); [Cinema_BE/ApiGateway/ApiGateway/Program.cs](../Cinema_BE/ApiGateway/ApiGateway/Program.cs) |
| Business rules | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 |
| Use case / screens / APIs | UC-WEB-01; WEB-SCR-LOGIN, WEB-SCR-STAFF-ONLY; Client behaviour; no dedicated endpoint |

### WEB-FR-STATE-01 — Loading, error and empty states

| Field | Specification |
| --- | --- |
| Name | Loading, error and empty states |
| Description | Provide loading, error/retry and empty states on data screens; disable repeated submission while a mutation is running and preserve an honest pending/failed result when the network fails. |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Preconditions | A data screen starts loading or a request is in progress. |
| Trigger | Invoke “Loading, error and empty states” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Provide loading, error/retry and empty states on data screens; disable repeated submission while a mutation is running and preserve an honest pending/failed result when the network fails. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | The successful observable result matches this requirement; any specified state change is persisted. Rejection does not grant access or leave an unauthorized partial change. |
| Priority | M |
| Acceptance criteria | **WEB-FR-STATE-01-AC-01** — Given the preconditions/trigger, verify: Provide loading, error/retry and empty states on data screens; disable repeated submission while a mutation is running and preserve an honest pending/failed result when the network fails. **WEB-FR-STATE-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/BookingService.cs); [Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/PromotionRules.cs); [Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs](../Cinema_BE/BookingService/BookingService/Helpers/LoyaltyRules.cs) |
| Business rules | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 |
| Use case / screens / APIs | UC-WEB-07; ; Client behaviour; no dedicated endpoint |

### WEB-FR-MEDIA-01 — Platform-specific movie media

| Field | Specification |
| --- | --- |
| Name | Platform-specific movie media |
| Description | Web movie cards may preview a direct HTTP(S) MP4/WebM after 450 ms hover; stop on pointer exit and fall back to the poster, with a 12-second deadline and reduced-motion support. Native mobile has supportsTrailerPreview=false and opens the full trailer externally. |
| Actor | Admin |
| Preconditions | An Admin session is active; a target record exists for edit/deactivate/adjust operations. |
| Trigger | Invoke “Platform-specific movie media” or its specified backend event/worker. |
| Main flow | 1. Read current input/resource and the applicable session. 2. Execute this operation: Web movie cards may preview a direct HTTP(S) MP4/WebM after 450 ms hover; stop on pointer exit and fall back to the poster, with a 12-second deadline and reduced-motion support. Native mobile has supportsTrailerPreview=false and opens the full trailer externally. 3. Return/render the authoritative result and refresh affected data after success. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The requested authorized data/state is returned or displayed; a read does not alter booking/payment state. Notification read markers are changed only by their separate write operation. |
| Priority | L |
| Acceptance criteria | **WEB-FR-MEDIA-01-AC-01** — Given the preconditions/trigger, verify: Web movie cards may preview a direct HTTP(S) MP4/WebM after 450 ms hover; stop on pointer exit and fall back to the poster, with a 12-second deadline and reduced-motion support. Native mobile has supportsTrailerPreview=false and opens the full trailer externally. **WEB-FR-MEDIA-01-AC-02** — Exercise applicable invalid/unauthorized/conflicting input and verify the stated rejection, no unauthorized changes and no false success. |
| Evidence | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs); [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart); [Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs](../Cinema_BE/MovieService/MovieService/Service/Impl/MovieService.cs); [Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/MovieReviewService.cs) |
| Business rules | WEB-BR-26 |
| Use case / screens / APIs | UC-WEB-03; WEB-SCR-HOME; WEB-API-064 |

## 10. Use Case Specifications

### UC-WEB-01 — Authentication and account session

| Field | Use-case specification |
| --- | --- |
| Actor | Guest; signed-in account; system |
| Goal | Authentication and account session |
| Preconditions | The gateway is configured. Registration/recovery needs SMTP; protected operations require a valid account session. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Enter account fields or request the session operation. 2. Validate fields; submit to AuthService through the gateway. 3. For verification/recovery, enter the emailed OTP; for sign-in/refresh, store returned tokens and user. 4. Route by role and resume an allowed pending destination. |
| Alternative / exception flow | Reject invalid fields (400), bad credentials (401), unverified email (403), stale/incorrect OTP, or resend/rate limits (429). Clear the session for account-lock/role-change responses; show SMTP/dependency failure (503). |
| Postconditions | Only a successful token-issuing operation authenticates the account; rejected requests do not grant access. |
| Requirements / priority | WEB-FR-AUTH-01 (H), WEB-FR-AUTH-02 (H), WEB-FR-AUTH-03 (H), WEB-FR-AUTH-04 (H), WEB-FR-AUTH-05 (H), WEB-FR-AUTH-06 (H), WEB-FR-AUTH-07 (H), WEB-FR-AUTH-08 (M), WEB-FR-AUTH-09 (H), WEB-FR-AUTH-10 (H), WEB-FR-AUTH-11 (M), WEB-FR-AUTH-12 (H), WEB-FR-AUTH-13 (H), WEB-FR-AUTH-14 (M), WEB-FR-AUTH-15 (M), WEB-FR-AUTH-16 (M), WEB-FR-AUTH-17 (M), WEB-FR-NAV-01 (H) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-02 — Account administration

| Field | Use-case specification |
| --- | --- |
| Actor | Admin |
| Goal | Account administration |
| Preconditions | An Admin session is active; the target user exists for changes. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Search/filter the paged accounts or open a record. 2. Create an account, select roles, or change enabled status. 3. Validate and confirm the change. 4. Reload the account and apply session revocation where required. |
| Alternative / exception flow | Reject non-Admin callers; reject invalid fields, duplicate email and self-locking. Saving unchanged roles must not force reauthentication. |
| Postconditions | The saved account/roles/status is visible; locked or changed-role tokens cannot retain previous privileges. |
| Requirements / priority | WEB-FR-USER-01 (H), WEB-FR-USER-02 (H), WEB-FR-USER-03 (H), WEB-FR-USER-04 (H), WEB-FR-USER-05 (H), WEB-FR-USER-06 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-03 — Movie catalogue and reviews

| Field | Use-case specification |
| --- | --- |
| Actor | Guest/Customer for browsing; Admin for catalogue changes and moderation |
| Goal | Movie catalogue and reviews |
| Preconditions | A movie is available; changes need Admin; a review needs the owner’s checked-in ticket. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Browse/search/filter movies or open their details. 2. Load metadata, trailer, reviews and open showtimes; Admin may save metadata or deactivate a film. 3. For a review, load eligibility from the ticket, submit 1–5 stars and at most 1,000 characters, or delete the existing review. 4. Refresh the affected view. |
| Alternative / exception flow | Show empty results for no matching films/showtimes. Review of another user’s ticket returns 404; a ticket not checked in returns 400. Failed media must retain a poster/fallback. |
| Postconditions | The catalogue/review reflects the authoritative response; deactivation preserves existing tickets. |
| Requirements / priority | WEB-FR-MOV-01 (H), WEB-FR-MOV-02 (H), WEB-FR-MOV-03 (M), WEB-FR-MOV-04 (H), WEB-FR-MOV-05 (H), WEB-FR-MOV-06 (H), WEB-FR-MOV-07 (H), WEB-FR-MOV-08 (L), WEB-FR-MOV-09 (H), WEB-FR-MOV-10 (M), WEB-FR-MOV-11 (L), WEB-FR-MOV-12 (M), WEB-FR-MEDIA-01 (L) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-04 — Room management

| Field | Use-case specification |
| --- | --- |
| Actor | Staff/Admin read; Admin writes |
| Goal | Room management |
| Preconditions | A management session is active; layout changes require no showtimes in that room. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Search/list rooms and open the map. 2. Admin enters name and dimensions when creating, or renames/deletes the selected room. 3. Create the room then generate seats; refresh room and seat counts. |
| Alternative / exception flow | Reject invalid capacity, unknown room, forbidden role, and deletion/layout changes when showtimes reference the room. Room creation and seat generation are separate HTTP calls; report failure of the second call. |
| Postconditions | Room data is saved or a permitted room is deleted; existing seat labels survive rename. |
| Requirements / priority | WEB-FR-ROOM-01 (H), WEB-FR-ROOM-02 (H), WEB-FR-ROOM-03 (H), WEB-FR-ROOM-04 (M), WEB-FR-ROOM-05 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-05 — Seat map and availability

| Field | Use-case specification |
| --- | --- |
| Actor | Signed-in Customer reads/selects; Staff/Admin manage types; Admin manages capacity/deletion |
| Goal | Seat map and availability |
| Preconditions | The room/showtime exists. Selecting seats requires sign-in; modifying layout requires management rights and no showtimes. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Load room seats and occupied IDs separately. 2. Display rows, type legend and authoritative prices; select free seats with sweetbox partners. 3. Refresh availability every five seconds; management changes types/capacity only through authorized APIs. |
| Alternative / exception flow | Remove selections newly occupied by another booking and notify the customer. Reject half sweetboxes, invalid room seats and prohibited layout edits. |
| Postconditions | The client shows the refreshed map; selecting seats alone does not reserve them. |
| Requirements / priority | WEB-FR-SEAT-01 (H), WEB-FR-SEAT-02 (L), WEB-FR-SEAT-03 (H), WEB-FR-SEAT-04 (L), WEB-FR-SEAT-05 (H), WEB-FR-SEAT-06 (M), WEB-FR-SEAT-07 (M), WEB-FR-SEAT-08 (H), WEB-FR-SEAT-09 (L) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-06 — Showtimes and prices

| Field | Use-case specification |
| --- | --- |
| Actor | Guest/Customer read public showtimes; Staff/Admin manage |
| Goal | Showtimes and prices |
| Preconditions | Movie and room exist; management changes need Staff/Admin. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Load showtimes by movie/date and select a day. 2. Show room, format, start/end and seat prices. 3. Management saves the schedule or opens/closes/cancels sales. 4. Validate overlap and persist; cancellation publishes an outbox event for affected bookings. |
| Alternative / exception flow | Reject overlap with 409 and invalid time/format with 400; cancelled showtimes are final. Customer selection excludes closed or started shows. |
| Postconditions | The schedule and computed seat prices are authoritative; cancellations propagate asynchronously. |
| Requirements / priority | WEB-FR-SHOW-01 (H), WEB-FR-SHOW-02 (H), WEB-FR-SHOW-03 (H), WEB-FR-SHOW-04 (H), WEB-FR-SHOW-05 (H), WEB-FR-SHOW-06 (H), WEB-FR-SHOW-07 (M), WEB-FR-SHOW-08 (H), WEB-FR-SHOW-09 (H), WEB-FR-SHOW-10 (M), WEB-FR-SHOW-11 (H), WEB-FR-SHOW-12 (M), WEB-FR-SHOW-13 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-07 — Booking, concessions, promotions and loyalty

| Field | Use-case specification |
| --- | --- |
| Actor | Customer owns online bookings; Staff/Admin operate counter and administration |
| Goal | Booking, concessions, promotions and loyalty |
| Preconditions | A signed-in customer has selected an OPEN future showtime and seats; counter guests are represented by Staff/Admin. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Review seats; optionally select active concessions, a promotion code and redeemable points. 2. Confirm age-rating acknowledgement where required. 3. Submit IDs/quantities; the server recalculates all prices, validates pairs, locks reservations and creates a PENDING booking with a ten-minute expiry. 4. Open payment or read/cancel an owned booking according to its state. |
| Alternative / exception flow | A concurrent hold returns 409 and must not charge money or leave partial seats/points. Invalid concessions/code/points return validation errors. Expiry releases seats and restores reserved points. |
| Postconditions | Successful creation returns the persisted booking, breakdown and expiry; unsuccessful creation rolls back its transaction. |
| Requirements / priority | WEB-FR-BOOK-01 (H), WEB-FR-BOOK-02 (H), WEB-FR-BOOK-03 (H), WEB-FR-BOOK-04 (H), WEB-FR-BOOK-05 (H), WEB-FR-BOOK-06 (H), WEB-FR-BOOK-07 (H), WEB-FR-BOOK-08 (H), WEB-FR-BOOK-09 (H), WEB-FR-BOOK-10 (H), WEB-FR-BOOK-11 (M), WEB-FR-BOOK-12 (M), WEB-FR-BOOK-13 (M), WEB-FR-BOOK-14 (M), WEB-FR-BOOK-15 (M), WEB-FR-BOOK-16 (M), WEB-FR-BOOK-17 (M), WEB-FR-BOOK-18 (M), WEB-FR-BOOK-19 (L), WEB-FR-STATE-01 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-08 — Online payment and reconciliation

| Field | Use-case specification |
| --- | --- |
| Actor | Booking owner; Staff/Admin for permitted operations; PayOS/system |
| Goal | Online payment and reconciliation |
| Preconditions | A payable booking exists; PayOS credentials and callback/return settings are configured for live payment. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Request/reuse a PayOS checkout for the booking. 2. Open checkout and display the hold countdown. 3. Query booking every five seconds and verify PayOS every thirty seconds while the customer payment page is active; also reconcile when returning to the app. 4. Signed webhook or verified PayOS data updates payment and booking; load the result from the server. |
| Alternative / exception flow | Never trust redirect query parameters as proof of payment. Handle cancellation, timeout and 503 without showing false success; late payment confirms only if seats can be reclaimed, otherwise creates a refund. |
| Postconditions | Payment status is authoritative; SUCCESS confirms the booking and schedules ticket notification without duplicate business effects. |
| Requirements / priority | WEB-FR-PAY-01 (H), WEB-FR-PAY-02 (H), WEB-FR-PAY-03 (H), WEB-FR-PAY-04 (M), WEB-FR-PAY-05 (M), WEB-FR-PAY-06 (H), WEB-FR-PAY-07 (H), WEB-FR-PAY-08 (M), WEB-FR-PAY-09 (M), WEB-FR-PAY-10 (M), WEB-FR-PAY-11 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-09 — Cancellation and manual refund

| Field | Use-case specification |
| --- | --- |
| Actor | Customer requests/reads own refund; Staff/Admin process; system creates requests |
| Goal | Cancellation and manual refund |
| Preconditions | A paid booking/payment exists; customer cancellation is at least two hours before start; staff processing requires a pending request. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Confirm cancellation and send reason. 2. The backend creates/reuses one refund per payment and notifies the customer. 3. Staff transfer money outside the application then record transfer reference, or reject an eligible request with a reason. 4. Customer reloads the ticket/refund status and reason. |
| Alternative / exception flow | Reject too-late customer cancellation (409), completion without transfer reference and rejection without reason; cinema-cancelled refunds cannot be rejected. Duplicate events must not create another refund. |
| Postconditions | Completion yields COMPLETED/REFUNDED and releases cancelled seats; allowed rejection restores SUCCESS/CONFIRMED; customer-requested pending refunds retain seats. |
| Requirements / priority | WEB-FR-REF-01 (H), WEB-FR-REF-02 (H), WEB-FR-REF-03 (H), WEB-FR-REF-04 (H), WEB-FR-REF-05 (M), WEB-FR-REF-06 (M), WEB-FR-REF-07 (H) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-10 — Counter ticket sale

| Field | Use-case specification |
| --- | --- |
| Actor | Staff/Admin; walk-in guest or member as beneficiary |
| Goal | Counter ticket sale |
| Preconditions | A management session is active; an OPEN future showtime has free seats. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Select walk-in or find a member by phone; choose showtime, seats and optional concessions/promotion/points. 2. Hold seats and open counter checkout. 3. Take sufficient cash and display change, or show VietQR and verify every three seconds. 4. After server confirmation show/print the QR ticket, optionally email it and check in within the permitted window. |
| Alternative / exception flow | Reject insufficient cash; cancel an unpaid PayOS link before switching to cash; if transfer already succeeded return 409. Without email provide print/on-screen QR. |
| Postconditions | A single confirmed ticket and successful payment are recorded and included in reporting. |
| Requirements / priority | WEB-FR-POS-01 (H), WEB-FR-POS-02 (H), WEB-FR-POS-03 (H), WEB-FR-POS-04 (H), WEB-FR-POS-05 (H), WEB-FR-POS-06 (M), WEB-FR-POS-07 (H), WEB-FR-POS-08 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-11 — Ticket lookup and check-in

| Field | Use-case specification |
| --- | --- |
| Actor | Staff/Admin scan and admit; Customer displays their ticket |
| Goal | Ticket lookup and check-in |
| Preconditions | Staff/Admin is signed in; the ticket is CONFIRMED, unused and within 180 minutes before to 120 minutes after start. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Scan QR or type the booking code and press Enter. 2. Lookup ticket; enrich room and age rating when catalogue calls succeed. 3. Check identity/rating as prompted, then explicitly check in. 4. Store checkedInAt, show confirmation and prepare for the next code. |
| Alternative / exception flow | Keep manual entry available if camera is unavailable/denied. Unknown code returns 404; unpaid, cancelled, pending refund, out-of-window or already-used ticket returns 409. Concurrent second check-in fails. Optional metadata failure must not hide the ticket. |
| Postconditions | Only one check-in timestamp is stored; check-in is an attribute, not another booking status. |
| Requirements / priority | WEB-FR-CHK-01 (H), WEB-FR-CHK-02 (H), WEB-FR-CHK-03 (H), WEB-FR-CHK-04 (H), WEB-FR-CHK-05 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-12 — Notifications and transactional email

| Field | Use-case specification |
| --- | --- |
| Actor | Customer reads own; Staff/Admin send permitted messages; system dispatches events |
| Goal | Notifications and transactional email |
| Preconditions | An account session exists for in-app history; SMTP/event processing is configured for actual delivery. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Load notifications and unread count, or create a management message for a booking. 2. Open detail and mark as read, mark all read, or follow the related ticket. 3. The server sends transactional email from committed events and reminder jobs; records SENT/FAILED and delivery error. |
| Alternative / exception flow | Owner checks reject another user’s data; show loading/empty/error-retry states. Sending failure retains FAILED for retry and must not undo payment. Event deduplication reduces duplicates but SMTP plus database commit is not a guaranteed exactly-once transaction. |
| Postconditions | Read state/badge matches the response; successful delivery is recorded separately from booking/payment state. |
| Requirements / priority | WEB-FR-NOTI-01 (M), WEB-FR-NOTI-02 (M), WEB-FR-NOTI-03 (M), WEB-FR-NOTI-04 (M), WEB-FR-NOTI-05 (L), WEB-FR-NOTI-06 (H), WEB-FR-NOTI-07 (H), WEB-FR-NOTI-08 (M), WEB-FR-NOTI-09 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

### UC-WEB-13 — Operations dashboards

| Field | Use-case specification |
| --- | --- |
| Actor | Staff/Admin; revenue and account statistics require Admin |
| Goal | Operations dashboards |
| Preconditions | Management session and source records exist; date ranges use cinema local time. |
| Trigger | Open the relevant screen or invoke the stated operation/event. |
| Main flow | 1. Load today’s bookings, showtimes and check-in statistics. 2. Group now-playing, next three and last three shows; refresh each minute. 3. Open a show to inspect seat/customer details. 4. Admin loads monthly revenue/refunds/accounts independently so one failed card does not erase others. |
| Alternative / exception flow | Show zero/empty periods accurately; a card can show its own error and retry. Staff must not acquire revenue/account APIs by changing the URL. |
| Postconditions | Displayed totals use the documented date and state definitions and link to operational records. |
| Requirements / priority | WEB-FR-DASH-01 (M), WEB-FR-DASH-02 (M), WEB-FR-DASH-03 (M), WEB-FR-DASH-04 (M) |
| Acceptance | Execute AC-01/AC-02 for every included FR with permitted actors. |

## 11. External Interface Requirements

| Interface | Contract |
| --- | --- |
| Client/gateway | REST/JSON UTF-8; Accept application/json; Content-Type application/json for request bodies; Bearer JWT on protected calls. Clients never connect to PostgreSQL or private service ports. |
| PayOS | Checkout URL/VietQR through backend; signed webhook; client verifies server state rather than trusting a redirect. No client card-data collection. |
| SMTP / RabbitMQ | Server-only OTP, ticket/refund delivery and committed events; clients read notification APIs, not the broker. |
| Device/browser | Hash/URL routes; HTTPS/localhost camera; share/clipboard/calendar; 80 mm browser printing; HTML preview with poster fallback. |

## 12. UI / Screen Requirements

Screen IDs represent routed pages or role landings. Scanner overlays, review editors, profile/password dialogs and seat-type painters are components, not invented routes. Related FR/API lists are functional-area associations; §13 gives exact endpoint contracts.

### WEB-SCR-LOGIN — Sign in

| Field | Screen requirement |
| --- | --- |
| Route | `/login` |
| Actor | Guest/all account roles |
| Purpose | Sign in |
| Main components | Email, password, field errors, recovery/register links |
| Actions | Sign in; recover password; register on customer site |
| Navigation | Role landing or pending destination; /forgot-password; /register (customer only) |
| Related FRs | WEB-FR-AUTH-02, WEB-FR-AUTH-03, WEB-FR-AUTH-06, WEB-FR-AUTH-12, WEB-FR-AUTH-13, WEB-FR-NAV-01 |
| Related API area | WEB-API-027, WEB-API-029, WEB-API-032, WEB-API-033, WEB-API-035 |
| Source | [Cinema_Mobile/lib/features/auth/screens/login_screen.dart](../Cinema_Mobile/lib/features/auth/screens/login_screen.dart) |

### WEB-SCR-REGISTER — Registration

| Field | Screen requirement |
| --- | --- |
| Route | `/register` |
| Actor | Guest |
| Purpose | Registration |
| Main components | Name, email, phone, password and confirmation |
| Actions | Validate and register |
| Navigation | /login → /register → /verify-email |
| Related FRs | WEB-FR-AUTH-01, WEB-FR-AUTH-08, WEB-FR-AUTH-13 |
| Related API area | WEB-API-027, WEB-API-033, WEB-API-035 |
| Source | [Cinema_Mobile/lib/features/auth/screens/register_screen.dart](../Cinema_Mobile/lib/features/auth/screens/register_screen.dart) |

### WEB-SCR-VERIFY — Verify email

| Field | Screen requirement |
| --- | --- |
| Route | `/verify-email` |
| Actor | Guest |
| Purpose | Verify email |
| Main components | OTP input; resend countdown; registered password context |
| Actions | Verify or resend |
| Navigation | Registration/login → OTP → role landing |
| Related FRs | WEB-FR-AUTH-07, WEB-FR-AUTH-08, WEB-FR-AUTH-14 |
| Related API area | WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-042 |
| Source | [Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart](../Cinema_Mobile/lib/features/auth/screens/verify_email_screen.dart) |

### WEB-SCR-FORGOT — Forgot password

| Field | Screen requirement |
| --- | --- |
| Route | `/forgot-password` |
| Actor | Guest/account owner |
| Purpose | Forgot password |
| Main components | Email field and submission status |
| Actions | Request reset OTP |
| Navigation | Login/Profile → reset request → /reset-password |
| Related FRs | WEB-FR-AUTH-09, WEB-FR-AUTH-13, WEB-FR-AUTH-14 |
| Related API area | WEB-API-026, WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-035 |
| Source | [Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/forgot_password_screen.dart) |

### WEB-SCR-RESET — Reset password

| Field | Screen requirement |
| --- | --- |
| Route | `/reset-password` |
| Actor | OTP recipient |
| Purpose | Reset password |
| Main components | OTP, new password and confirmation |
| Actions | Reset using emailed code |
| Navigation | Forgot-password → reset → sign-in |
| Related FRs | WEB-FR-AUTH-09, WEB-FR-AUTH-13, WEB-FR-AUTH-14 |
| Related API area | WEB-API-026, WEB-API-027, WEB-API-032, WEB-API-033, WEB-API-034, WEB-API-035 |
| Source | [Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart](../Cinema_Mobile/lib/features/auth/screens/reset_password_screen.dart) |

### WEB-SCR-HOME — Customer home

| Field | Screen requirement |
| --- | --- |
| Route | `/home` |
| Actor | Guest/Customer |
| Purpose | Customer home |
| Main components | Now/soon tabs; search; genre chips; movie cards; account/notification navigation |
| Actions | Search/filter; open movie |
| Navigation | /home → /movies/{id}; customer navigation to bookings, payments, notifications, profile |
| Related FRs | WEB-FR-MOV-03, WEB-FR-MOV-04, WEB-FR-MOV-10, WEB-FR-NOTI-09, WEB-FR-MEDIA-01 |
| Related API area | WEB-API-064, WEB-API-066, WEB-API-067, WEB-API-069, WEB-API-072, WEB-API-076, WEB-API-077 |
| Source | [Cinema_Mobile/lib/features/home/screens/home_screen.dart](../Cinema_Mobile/lib/features/home/screens/home_screen.dart) |

### WEB-SCR-MOVIE — Movie details

| Field | Screen requirement |
| --- | --- |
| Route | `/movies/{id}` |
| Actor | Guest/Customer |
| Purpose | Movie details |
| Main components | Poster, rating, metadata, cast/director, trailer, review summary, seven-day showtimes |
| Actions | Play trailer; select showtime; read reviews |
| Navigation | Home → movie → /showtimes/{id}/seats |
| Related FRs | WEB-FR-MOV-02, WEB-FR-MOV-08, WEB-FR-MOV-09, WEB-FR-MOV-11, WEB-FR-MOV-12, WEB-FR-SHOW-03, WEB-FR-SHOW-06, WEB-FR-SHOW-07, WEB-FR-SHOW-08, WEB-FR-SHOW-13 |
| Related API area | WEB-API-017, WEB-API-020, WEB-API-064, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Source | [Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart](../Cinema_Mobile/lib/features/movie/screens/movie_detail_screen.dart) |

### WEB-SCR-SEATS — Seat selection

| Field | Screen requirement |
| --- | --- |
| Route | `/showtimes/{id}/seats` |
| Actor | Customer |
| Purpose | Seat selection |
| Main components | Rows, type/occupied legend, selection, pair pricing, total |
| Actions | Select/unselect free seats; refresh |
| Navigation | Movie → seats → /showtimes/{id}/summary |
| Related FRs | WEB-FR-SEAT-03, WEB-FR-SHOW-03, WEB-FR-SHOW-13, WEB-FR-BOOK-07, WEB-FR-BOOK-08, WEB-FR-BOOK-09, WEB-FR-BOOK-11 |
| Related API area | WEB-API-013, WEB-API-017, WEB-API-049, WEB-API-055 |
| Source | [Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart](../Cinema_Mobile/lib/features/seat/screens/seat_selection_screen.dart) |

### WEB-SCR-SUMMARY — Booking summary

| Field | Screen requirement |
| --- | --- |
| Route | `/showtimes/{id}/summary` |
| Actor | Customer |
| Purpose | Booking summary |
| Main components | BookingDraft, seats, concessions picker, promotion quote, points, age acknowledgement |
| Actions | Adjust extras; hold seats |
| Navigation | Seats → summary → booking payment; missing draft → seats |
| Related FRs | WEB-FR-MOV-09, WEB-FR-BOOK-01, WEB-FR-BOOK-09, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17 |
| Related API area | WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-064, WEB-API-099 |
| Source | [Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_summary_screen.dart) |

### WEB-SCR-PAYMENT — Payment

| Field | Screen requirement |
| --- | --- |
| Route | `/bookings/{id}/payment` |
| Actor | Customer |
| Purpose | Payment |
| Main components | Booking/price breakdown; expiry countdown; PayOS link; automatic polling |
| Actions | Open/continue PayOS; return and reconcile |
| Navigation | Summary/ticket → payment → external PayOS → result |
| Related FRs | WEB-FR-BOOK-05, WEB-FR-BOOK-10, WEB-FR-PAY-01, WEB-FR-PAY-02, WEB-FR-PAY-11 |
| Related API area | WEB-API-046, WEB-API-087, WEB-API-088 |
| Source | [Cinema_Mobile/lib/features/payment/screens/payment_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_screen.dart) |

### WEB-SCR-RESULT — Payment result

| Field | Screen requirement |
| --- | --- |
| Route | `/bookings/{id}/result` |
| Actor | Customer |
| Purpose | Payment result |
| Main components | Verification/loading, successful/pending/failed result |
| Actions | Reload server result; open ticket |
| Navigation | PayOS/payment → result → /bookings/{id} |
| Related FRs | WEB-FR-BOOK-02, WEB-FR-BOOK-05, WEB-FR-PAY-02, WEB-FR-PAY-08 |
| Related API area | WEB-API-046, WEB-API-087 |
| Source | [Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_result_screen.dart) |

### WEB-SCR-TICKETS — My tickets

| Field | Screen requirement |
| --- | --- |
| Route | `/bookings` |
| Actor | Customer |
| Purpose | My tickets |
| Main components | Active/History tabs, ticket cards, refresh and empty/error states |
| Actions | Open ticket; refresh |
| Navigation | Customer navigation → tickets → /bookings/{id} |
| Related FRs | WEB-FR-BOOK-04 |
| Related API area | WEB-API-053 |
| Source | [Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart](../Cinema_Mobile/lib/features/booking/screens/my_bookings_screen.dart) |

### WEB-SCR-TICKET — Ticket details

| Field | Screen requirement |
| --- | --- |
| Route | `/bookings/{id}` |
| Actor | Customer |
| Purpose | Ticket details |
| Main components | Seats, extras, totals, QR, checkedInAt, cancel/refund, review and share/calendar |
| Actions | Pay pending ticket; cancel/request refund; review after check-in; share/calendar |
| Navigation | Tickets/notification → ticket → payment or return |
| Related FRs | WEB-FR-MOV-12, WEB-FR-BOOK-02, WEB-FR-BOOK-05, WEB-FR-BOOK-06, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17, WEB-FR-BOOK-19, WEB-FR-PAY-03, WEB-FR-PAY-06, WEB-FR-REF-01, WEB-FR-REF-05, WEB-FR-REF-06, WEB-FR-CHK-01, WEB-FR-CHK-05 |
| Related API area | WEB-API-017, WEB-API-043, WEB-API-046, WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-082, WEB-API-087, WEB-API-099, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Source | [Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart](../Cinema_Mobile/lib/features/booking/screens/booking_detail_screen.dart) |

### WEB-SCR-PAYHISTORY — Payment history

| Field | Screen requirement |
| --- | --- |
| Route | `/payments` |
| Actor | Customer |
| Purpose | Payment history |
| Main components | Owned transaction rows, amounts, statuses |
| Actions | Refresh; inspect related booking where provided |
| Navigation | Customer navigation → payments → related ticket |
| Related FRs | WEB-FR-PAY-03, WEB-FR-PAY-04 |
| Related API area | WEB-API-095 |
| Source | [Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart](../Cinema_Mobile/lib/features/payment/screens/payment_history_screen.dart) |

### WEB-SCR-NOTIFICATIONS — Notifications

| Field | Screen requirement |
| --- | --- |
| Route | `/notifications` |
| Actor | Customer |
| Purpose | Notifications |
| Main components | Notification list, unread badge, mark-all-read |
| Actions | Open notification; mark all read |
| Navigation | Customer bell/navigation → /notifications/{id} |
| Related FRs | WEB-FR-NOTI-01, WEB-FR-NOTI-09 |
| Related API area | WEB-API-072, WEB-API-076, WEB-API-077, WEB-API-078 |
| Source | [Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_list_screen.dart) |

### WEB-SCR-NOTIFICATION — Notification details

| Field | Screen requirement |
| --- | --- |
| Route | `/notifications/{id}` |
| Actor | Customer |
| Purpose | Notification details |
| Main components | Subject, content, read state, related booking |
| Actions | Mark read on open; open ticket |
| Navigation | Notifications → detail → /bookings/{id} |
| Related FRs | WEB-FR-NOTI-04, WEB-FR-NOTI-09 |
| Related API area | WEB-API-072, WEB-API-075, WEB-API-076, WEB-API-077 |
| Source | [Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart](../Cinema_Mobile/lib/features/notification/screens/notification_detail_screen.dart) |

### WEB-SCR-PROFILE — Account and membership

| Field | Screen requirement |
| --- | --- |
| Route | `/profile` |
| Actor | Customer |
| Purpose | Account and membership |
| Main components | Identity, edit-profile/password dialogs, membership card/history, logout |
| Actions | Edit name/phone; change/recover password; sign out |
| Navigation | Customer navigation → profile; password recovery → forgot/reset |
| Related FRs | WEB-FR-AUTH-10, WEB-FR-AUTH-11, WEB-FR-AUTH-16, WEB-FR-AUTH-17, WEB-FR-BOOK-17 |
| Related API area | WEB-API-025, WEB-API-028, WEB-API-029, WEB-API-031, WEB-API-032, WEB-API-055, WEB-API-060 |
| Source | [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart) |

### WEB-SCR-CHECKIN — Ticket check-in

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/check-in` |
| Actor | Staff/Admin |
| Purpose | Ticket check-in |
| Main components | Code field; camera scanner overlay; ticket details; age reminder; admission button |
| Actions | Scan/type; lookup; check in once |
| Navigation | Management landing/navigation → check-in → next ticket |
| Related FRs | WEB-FR-MOV-09, WEB-FR-CHK-02, WEB-FR-CHK-03, WEB-FR-CHK-04, WEB-FR-CHK-05 |
| Related API area | WEB-API-044, WEB-API-046, WEB-API-047, WEB-API-050, WEB-API-064, WEB-API-065, WEB-API-071 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_check_in_screen.dart) |

### WEB-SCR-STAFF-DASH — Staff dashboard

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/dashboard` |
| Actor | Staff/Admin |
| Purpose | Staff dashboard |
| Main components | Today totals, live board, pending bookings/refunds |
| Actions | Open operations; sell; check in |
| Navigation | Login → dashboard → operations/counter/check-in |
| Related FRs | WEB-FR-DASH-01, WEB-FR-DASH-02, WEB-FR-DASH-03 |
| Related API area | WEB-API-019, WEB-API-048, WEB-API-051, WEB-API-052, WEB-API-093 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_dashboard_screen.dart) |

### WEB-SCR-ADMIN-DASH — Admin dashboard

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/dashboard` |
| Actor | Admin |
| Purpose | Admin dashboard |
| Main components | Monthly revenue/refunds, today, movie and account cards |
| Actions | Open corresponding management area |
| Navigation | Login → dashboard → administration/operations |
| Related FRs | WEB-FR-DASH-01, WEB-FR-DASH-02, WEB-FR-DASH-04 |
| Related API area | WEB-API-019, WEB-API-040, WEB-API-048, WEB-API-051, WEB-API-069, WEB-API-094 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_dashboard_screen.dart) |

### WEB-SCR-OPERATIONS — Operations workspace

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/operations` |
| Actor | Staff/Admin |
| Purpose | Operations workspace |
| Main components | Bookings/showtimes/rooms/payments/refunds tabs; filters; paging |
| Actions | Filter; open record; sell; create showtime |
| Navigation | Navigation → operations → record/new sale/new showtime |
| Related FRs | WEB-FR-ROOM-01, WEB-FR-SHOW-01, WEB-FR-SHOW-09, WEB-FR-BOOK-03, WEB-FR-BOOK-12, WEB-FR-PAY-09, WEB-FR-REF-02 |
| Related API area | WEB-API-004, WEB-API-005, WEB-API-019, WEB-API-023, WEB-API-048, WEB-API-051, WEB-API-052, WEB-API-054, WEB-API-087, WEB-API-092, WEB-API-093, WEB-API-096 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_operations_screen.dart) |

### WEB-SCR-COUNTER — Counter booking

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/bookings/new` |
| Actor | Staff/Admin |
| Purpose | Counter booking |
| Main components | Guest/member selector, phone lookup, movie/day/showtime/map, extras |
| Actions | Select buyer/seats; quote; hold |
| Navigation | Dashboard/operations → counter → checkout |
| Related FRs | WEB-FR-AUTH-15, WEB-FR-BOOK-13, WEB-FR-BOOK-15, WEB-FR-BOOK-17, WEB-FR-POS-01 |
| Related API area | WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055, WEB-API-057, WEB-API-060, WEB-API-099 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_create_booking_screen.dart) |

### WEB-SCR-CHECKOUT — Counter checkout

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/bookings/{id}/checkout` |
| Actor | Staff/Admin |
| Purpose | Counter checkout |
| Main components | Countdown, email, cash/change, VietQR, paid QR/print |
| Actions | Take cash; verify transfer; print; admit; sell again |
| Navigation | Counter/booking record → checkout → print/check-in/new sale |
| Related FRs | WEB-FR-PAY-01, WEB-FR-PAY-02, WEB-FR-POS-02, WEB-FR-POS-03, WEB-FR-POS-04, WEB-FR-POS-05, WEB-FR-POS-06, WEB-FR-POS-07, WEB-FR-POS-08, WEB-FR-CHK-01, WEB-FR-CHK-03 |
| Related API area | WEB-API-044, WEB-API-046, WEB-API-055, WEB-API-086, WEB-API-087, WEB-API-088 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_counter_checkout_screen.dart) |

### WEB-SCR-RECORD-BOOKINGS — Booking record

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/bookings/{id}` |
| Actor | Staff/Admin |
| Purpose | Booking record |
| Main components | Ticket, payment state, customer and actions |
| Actions | Inspect and execute permitted record actions |
| Navigation | Operations → record → associated records or editor |
| Related FRs | WEB-FR-BOOK-02, WEB-FR-BOOK-06, WEB-FR-POS-08, WEB-FR-CHK-05 |
| Related API area | WEB-API-043, WEB-API-046, WEB-API-050 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-PAYMENTS — Payment record

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/payments/{id}` |
| Actor | Staff/Admin |
| Purpose | Payment record |
| Main components | Amount, method, status, verification and refund |
| Actions | Inspect and execute permitted record actions |
| Navigation | Operations → record → associated records or editor |
| Related FRs | WEB-FR-PAY-03, WEB-FR-PAY-05, WEB-FR-PAY-09, WEB-FR-REF-06 |
| Related API area | WEB-API-082, WEB-API-084, WEB-API-085, WEB-API-087, WEB-API-096 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-REFUNDS — Refund record

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/refunds/{id}` |
| Actor | Staff/Admin |
| Purpose | Refund record |
| Main components | Payer bank, reason, status, transfer reference |
| Actions | Inspect and execute permitted record actions |
| Navigation | Operations → record → associated records or editor |
| Related FRs | WEB-FR-REF-02, WEB-FR-REF-03, WEB-FR-REF-04, WEB-FR-REF-05, WEB-FR-REF-07 |
| Related API area | WEB-API-016, WEB-API-043, WEB-API-082, WEB-API-090, WEB-API-091, WEB-API-092, WEB-API-093 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-SHOWTIMES — Showtime record

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/showtimes/{id}` |
| Actor | Staff/Admin |
| Purpose | Showtime record |
| Main components | Schedule, seat occupancy map, customer list |
| Actions | Inspect and execute permitted record actions |
| Navigation | Operations → record → associated records or editor |
| Related FRs | WEB-FR-SHOW-03, WEB-FR-SHOW-05, WEB-FR-SHOW-10, WEB-FR-SHOW-12, WEB-FR-BOOK-12 |
| Related API area | WEB-API-013, WEB-API-015, WEB-API-016, WEB-API-017, WEB-API-050, WEB-API-051 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-RECORD-ROOMS — Room record

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/rooms/{id}` |
| Actor | Staff/Admin |
| Purpose | Room record |
| Main components | Room metadata, seat map/type painter and capacity |
| Actions | Inspect and execute permitted record actions |
| Navigation | Operations → record → associated records or editor |
| Related FRs | WEB-FR-ROOM-02, WEB-FR-SEAT-01, WEB-FR-SEAT-02, WEB-FR-SEAT-03, WEB-FR-SEAT-05, WEB-FR-SEAT-06, WEB-FR-SEAT-07, WEB-FR-SEAT-08, WEB-FR-SEAT-09 |
| Related API area | WEB-API-002, WEB-API-007, WEB-API-009, WEB-API-010, WEB-API-011, WEB-API-012, WEB-API-013 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_record_screen.dart) |

### WEB-SCR-SHOW-EDITOR — Showtime editor

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/showtimes/new; /staff/showtimes/{id}/edit` |
| Actor | Staff/Admin |
| Purpose | Showtime editor |
| Main components | Movie, room, start/end, format, base price, status |
| Actions | Validate and save |
| Navigation | Operations/showtime record → editor → record |
| Related FRs | WEB-FR-SHOW-02, WEB-FR-SHOW-04, WEB-FR-SHOW-11, WEB-FR-SHOW-13 |
| Related API area | WEB-API-017, WEB-API-018, WEB-API-024 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_showtime_editor_screen.dart) |

### WEB-SCR-COMPOSE — Compose booking email

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/bookings/{id}/notify` |
| Actor | Staff/Admin |
| Purpose | Compose booking email |
| Main components | Recipient email, subject, content, send result |
| Actions | Create and send/retry |
| Navigation | Booking record → notify → record |
| Related FRs | WEB-FR-NOTI-02, WEB-FR-NOTI-03 |
| Related API area | WEB-API-073, WEB-API-080 |
| Source | [Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart](../Cinema_Mobile/lib/features/staff/screens/staff_notification_screen.dart) |

### WEB-SCR-ADMIN-MOVIES — Movies

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/movies` |
| Actor | Admin |
| Purpose | Movies |
| Main components | Search, status, movie editor, reviews dialog |
| Actions | Create/edit; stop/resume; moderate |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-MOV-01, WEB-FR-MOV-02, WEB-FR-MOV-03, WEB-FR-MOV-04, WEB-FR-MOV-05, WEB-FR-MOV-06, WEB-FR-MOV-07, WEB-FR-MOV-09, WEB-FR-MOV-11, WEB-FR-MOV-12 |
| Related API area | WEB-API-063, WEB-API-064, WEB-API-065, WEB-API-066, WEB-API-068, WEB-API-069, WEB-API-070, WEB-API-071, WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_movies_screen.dart) |

### WEB-SCR-ADMIN-ROOMS — Rooms

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/rooms` |
| Actor | Admin |
| Purpose | Rooms |
| Main components | Room list, create/rename dialog, seat-map links |
| Actions | Create/rename/delete; open map |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-ROOM-01, WEB-FR-ROOM-02, WEB-FR-ROOM-03, WEB-FR-ROOM-04, WEB-FR-ROOM-05 |
| Related API area | WEB-API-001, WEB-API-002, WEB-API-003, WEB-API-004, WEB-API-005, WEB-API-006, WEB-API-010, WEB-API-013 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_rooms_screen.dart) |

### WEB-SCR-ADMIN-SNACKS — Snacks

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/snacks` |
| Actor | Admin |
| Purpose | Snacks |
| Main components | Menu item editor, price, active toggle |
| Actions | Create/edit; stop/resume |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-BOOK-14 |
| Related API area | WEB-API-056, WEB-API-057, WEB-API-058 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_snacks_screen.dart) |

### WEB-SCR-ADMIN-PROMOTIONS — Promotions

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/promotions` |
| Actor | Admin |
| Purpose | Promotions |
| Main components | Code/automatic deals, dates, limits, use count |
| Actions | Create/edit; pause/resume |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-BOOK-16 |
| Related API area | WEB-API-098, WEB-API-100, WEB-API-101 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_promotions_screen.dart) |

### WEB-SCR-ADMIN-MEMBERS — Members

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/members` |
| Actor | Admin |
| Purpose | Members |
| Main components | Customer list, points/tier/spend, history/adjust dialog |
| Actions | Find member; adjust with reason |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-BOOK-18 |
| Related API area | WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_members_screen.dart) |

### WEB-SCR-ADMIN-USERS — Accounts

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/users` |
| Actor | Admin |
| Purpose | Accounts |
| Main components | Search, role/status filters, paging |
| Actions | List; create; open account |
| Navigation | Admin navigation → list → editor/details |
| Related FRs | WEB-FR-USER-01, WEB-FR-USER-06 |
| Related API area | WEB-API-036, WEB-API-040 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |

### WEB-SCR-USER-EDITOR — Account create/details

| Field | Screen requirement |
| --- | --- |
| Route | `/admin/users/new; /admin/users/{id}` |
| Actor | Admin |
| Purpose | Account create/details |
| Main components | Identity fields, roles, enabled state |
| Actions | Create; change roles; lock/unlock |
| Navigation | Accounts → new/detail → accounts |
| Related FRs | WEB-FR-AUTH-13, WEB-FR-USER-02, WEB-FR-USER-03, WEB-FR-USER-04, WEB-FR-USER-05, WEB-FR-USER-06 |
| Related API area | WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-036, WEB-API-037, WEB-API-038, WEB-API-039, WEB-API-041 |
| Source | [Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart](../Cinema_Mobile/lib/features/admin/screens/admin_users_screen.dart) |

### WEB-SCR-MGT-PROFILE — Management profile

| Field | Screen requirement |
| --- | --- |
| Route | `/staff/profile; /admin/profile` |
| Actor | Staff/Admin |
| Purpose | Management profile |
| Main components | Identity, edit/password dialogs, sign out |
| Actions | Edit own profile; change password; logout |
| Navigation | Navigation → profile → authentication |
| Related FRs | WEB-FR-AUTH-10, WEB-FR-AUTH-11, WEB-FR-AUTH-16, WEB-FR-AUTH-17 |
| Related API area | WEB-API-025, WEB-API-028, WEB-API-029, WEB-API-031, WEB-API-032 |
| Source | [Cinema_Mobile/lib/features/profile/screens/profile_screen.dart](../Cinema_Mobile/lib/features/profile/screens/profile_screen.dart) |

### WEB-SCR-STAFF-ONLY — Management access notice

| Field | Screen requirement |
| --- | --- |
| Route | `/home (Customer in admin site)` |
| Actor | Customer |
| Purpose | Management access notice |
| Main components | Role explanation and customer site link |
| Actions | Open customer site; sign out |
| Navigation | Customer login to admin entry → notice → customer site |
| Related FRs | WEB-FR-AUTH-05, WEB-FR-NAV-01 |
| Related API area | WEB-API-029 |
| Source | [Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart](../Cinema_Mobile/lib/features/admin/screens/staff_only_screen.dart) |

Web authentication screens are reused between entry points, but admin login disables registration. Profile editing/password changes are dialogs. The phone management landing is selected by role, not a separate administrative URL.

## 13. API Requirements

Endpoints are extracted from controller HTTP attributes, removing :long constraints from parameter notation only. Direct client means matching method/path found in the scoped Dart services; API-only/shared means a controller exists without a detected dedicated client call. Controller policy must be combined with gateway policy and record ownership.

| ID | Method / endpoint | Controller policy | Input contract | Usage / status | Evidence |
| --- | --- | --- | --- | --- | --- |
| WEB-API-001 | `DELETE /api/rooms/{roomId}` | Policy = AuthorizationPolicies.AdminOnly | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:80](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L80) |
| WEB-API-002 | `GET /api/rooms/{roomId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:41](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L41) |
| WEB-API-003 | `PUT /api/rooms/{roomId}` | Policy = AuthorizationPolicies.AdminOnly | Body: RoomRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:67](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L67) |
| WEB-API-004 | `GET /api/rooms/search` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string keyword; Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:91](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L91) |
| WEB-API-005 | `GET /api/rooms` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:24](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L24) |
| WEB-API-006 | `POST /api/rooms` | Policy = AuthorizationPolicies.AdminOnly | Body: RoomRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs:52](../Cinema_BE/MovieService/MovieService/Controllers/RoomsController.cs#L52) |
| WEB-API-007 | `PUT /api/seats/{seatId}/type` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateSeatTypeRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:60](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L60) |
| WEB-API-008 | `DELETE /api/seats/{seatId}` | Policy = AuthorizationPolicies.AdminOnly | — | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:101](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L101) |
| WEB-API-009 | `GET /api/seats/{seatId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:23](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L23) |
| WEB-API-010 | `POST /api/seats/generate` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: GenerateSeatRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:48](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L48) |
| WEB-API-011 | `PUT /api/seats/room/{roomId}/capacity` | Policy = AuthorizationPolicies.AdminOnly | Body: UpdateRoomSeatsRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:88](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L88) |
| WEB-API-012 | `PUT /api/seats/room/{roomId}/types` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateSeatTypeRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:74](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L74) |
| WEB-API-013 | `GET /api/seats/room/{roomId}` | authenticated | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs:36](../Cinema_BE/MovieService/MovieService/Controllers/SeatsController.cs#L36) |
| WEB-API-014 | `POST /api/showtimes/{showtimeId}/seats` | authenticated | Body: List<long> seatIds | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:55](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L55) |
| WEB-API-015 | `PATCH /api/showtimes/{showtimeId}/status` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: UpdateShowtimeStatusRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:108](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L108) |
| WEB-API-016 | `DELETE /api/showtimes/{showtimeId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:97](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L97) |
| WEB-API-017 | `GET /api/showtimes/{showtimeId}` | public | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:41](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L41) |
| WEB-API-018 | `PUT /api/showtimes/{showtimeId}` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: ShowtimeRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:83](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L83) |
| WEB-API-019 | `GET /api/showtimes/date-range` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: DateTime start; Query: DateTime end; Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:180](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L180) |
| WEB-API-020 | `GET /api/showtimes/movie/{movieId}/open` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:160](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L160) |
| WEB-API-021 | `GET /api/showtimes/movie/{movieId}` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:139](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L139) |
| WEB-API-022 | `GET /api/showtimes/open` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:121](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L121) |
| WEB-API-023 | `GET /api/showtimes` | public | Query: int pageNumber; Query: int pageSize; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:23](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L23) |
| WEB-API-024 | `POST /api/showtimes` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: ShowtimeRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs:68](../Cinema_BE/MovieService/MovieService/Controllers/ShowtimesController.cs#L68) |
| WEB-API-025 | `POST /api/v1/auth/change-password` | public | Body: ChangePasswordRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:105](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L105) |
| WEB-API-026 | `POST /api/v1/auth/forgot-password` | public | Body: EmailRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:54](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L54) |
| WEB-API-027 | `POST /api/v1/auth/login` | public | Body: LoginRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:46](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L46) |
| WEB-API-028 | `POST /api/v1/auth/logout` | public | Body: RefreshTokenRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:79](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L79) |
| WEB-API-029 | `GET /api/v1/auth/me` | public | — | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:88](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L88) |
| WEB-API-030 | `GET /api/v1/auth/members` | Roles = "ROLE_STAFF,ROLE_ADMIN" | Query: string? phone | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs:22](../Cinema_BE/AuthService/AuthService/Controllers/MembersController.cs#L22) |
| WEB-API-031 | `PUT /api/v1/auth/me` | public | Body: UpdateProfileRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:97](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L97) |
| WEB-API-032 | `POST /api/v1/auth/refresh` | public | Body: RefreshTokenRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:70](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L70) |
| WEB-API-033 | `POST /api/v1/auth/register` | public | Body: RegisterRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:22](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L22) |
| WEB-API-034 | `POST /api/v1/auth/resend-verification` | public | Body: EmailRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:38](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L38) |
| WEB-API-035 | `POST /api/v1/auth/reset-password` | public | Body: ResetPasswordRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:62](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L62) |
| WEB-API-036 | `GET /api/v1/auth/roles` | Roles = "ROLE_ADMIN" | — | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs:20](../Cinema_BE/AuthService/AuthService/Controllers/RolesController.cs#L20) |
| WEB-API-037 | `PUT /api/v1/auth/users/{id}/roles` | Roles = "ROLE_ADMIN" | Body: UpdateUserRolesRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:51](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L51) |
| WEB-API-038 | `PATCH /api/v1/auth/users/{id}/status` | Roles = "ROLE_ADMIN" | Body: UpdateUserStatusRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:58](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L58) |
| WEB-API-039 | `GET /api/v1/auth/users/{id}` | Roles = "ROLE_ADMIN" | — | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:36](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L36) |
| WEB-API-040 | `GET /api/v1/auth/users` | Roles = "ROLE_ADMIN" | Query: string? keyword; Query: string? role; Query: bool? enabled; Query: int page; Query: int size | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:24](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L24) |
| WEB-API-041 | `POST /api/v1/auth/users` | Roles = "ROLE_ADMIN" | Body: CreateUserRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs:43](../Cinema_BE/AuthService/AuthService/Controllers/UsersController.cs#L43) |
| WEB-API-042 | `POST /api/v1/auth/verify-email` | public | Body: VerifyEmailRequest request | Direct client; implemented | [Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs:30](../Cinema_BE/AuthService/AuthService/Controllers/AuthController.cs#L30) |
| WEB-API-043 | `POST /api/v1/bookings/{id}/cancel` | Policy = AuthorizationPolicies.UserOrStaff | Query: string? reason | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:201](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L201) |
| WEB-API-044 | `POST /api/v1/bookings/{id}/check-in` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L147) |
| WEB-API-045 | `POST /api/v1/bookings/{id}/confirm` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string paymentMethod; Query: string? recipientEmail | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:180](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L180) |
| WEB-API-046 | `GET /api/v1/bookings/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:37](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L37) |
| WEB-API-047 | `GET /api/v1/bookings/code/{bookingCode}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:137](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L137) |
| WEB-API-048 | `GET /api/v1/bookings/date-range` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: DateTime start; Query: DateTime end; Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:84](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L84) |
| WEB-API-049 | `GET /api/v1/bookings/showtime/{showtimeId}/occupied-seats` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:100](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L100) |
| WEB-API-050 | `GET /api/v1/bookings/showtime/{showtimeId}/seats` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:111](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L111) |
| WEB-API-051 | `GET /api/v1/bookings/showtimes/stats` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: List<long>? showtimeIds; Query: DateTime? start; Query: DateTime? end | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:123](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L123) |
| WEB-API-052 | `GET /api/v1/bookings/status/{status}` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:69](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L69) |
| WEB-API-053 | `GET /api/v1/bookings/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L50) |
| WEB-API-054 | `GET /api/v1/bookings` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:23](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L23) |
| WEB-API-055 | `POST /api/v1/bookings` | Policy = AuthorizationPolicies.AnyRole | Body: BookingRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs:156](../Cinema_BE/BookingService/BookingService/Controllers/BookingController.cs#L156) |
| WEB-API-056 | `PUT /api/v1/concessions/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: ConcessionItemRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:41](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L41) |
| WEB-API-057 | `GET /api/v1/concessions` | public | Query: bool includeInactive | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L24) |
| WEB-API-058 | `POST /api/v1/concessions` | Policy = AuthorizationPolicies.AdminOnly | Body: ConcessionItemRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs:33](../Cinema_BE/BookingService/BookingService/Controllers/ConcessionController.cs#L33) |
| WEB-API-059 | `GET /api/v1/loyalty/accounts` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? userIds | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:38](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L38) |
| WEB-API-060 | `GET /api/v1/loyalty/me` | authenticated | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L24) |
| WEB-API-061 | `POST /api/v1/loyalty/users/{userId}/adjust` | Policy = AuthorizationPolicies.AdminOnly | Body: LoyaltyAdjustRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:49](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L49) |
| WEB-API-062 | `GET /api/v1/loyalty/users/{userId}` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs:30](../Cinema_BE/BookingService/BookingService/Controllers/LoyaltyController.cs#L30) |
| WEB-API-063 | `DELETE /api/v1/movies/{id}` | Policy = AuthorizationPolicies.AdminOnly | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:107](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L107) |
| WEB-API-064 | `GET /api/v1/movies/{id}` | public | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:34](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L34) |
| WEB-API-065 | `PUT /api/v1/movies/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: MovieRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:99](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L99) |
| WEB-API-066 | `GET /api/v1/movies/browse` | public | Query: string? when; Query: string? genre; Query: string? keyword; Query: int page; Query: int size | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:57](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L57) |
| WEB-API-067 | `GET /api/v1/movies/genres` | public | — | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:70](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L70) |
| WEB-API-068 | `GET /api/v1/movies/search` | public | Query: string keyword; Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:77](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L77) |
| WEB-API-069 | `GET /api/v1/movies/status/{status}` | public | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:42](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L42) |
| WEB-API-070 | `GET /api/v1/movies` | public | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:22](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L22) |
| WEB-API-071 | `POST /api/v1/movies` | Policy = AuthorizationPolicies.AdminOnly | Body: MovieRequest request | Direct client; implemented | [Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs:90](../Cinema_BE/MovieService/MovieService/Controllers/MoviesController.cs#L90) |
| WEB-API-072 | `PATCH /api/v1/notifications/{id}/read` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:77](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L77) |
| WEB-API-073 | `POST /api/v1/notifications/{id}/send` | Policy = AuthorizationPolicies.StaffOrAdmin | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:104](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L104) |
| WEB-API-074 | `DELETE /api/v1/notifications/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:112](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L112) |
| WEB-API-075 | `GET /api/v1/notifications/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:36](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L36) |
| WEB-API-076 | `POST /api/v1/notifications/read-all` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:89](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L89) |
| WEB-API-077 | `GET /api/v1/notifications/unread-count` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:67](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L67) |
| WEB-API-078 | `GET /api/v1/notifications/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:49](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L49) |
| WEB-API-079 | `GET /api/v1/notifications` | Policy = AuthorizationPolicies.AdminOnly | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L24) |
| WEB-API-080 | `POST /api/v1/notifications` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: NotificationRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs:96](../Cinema_BE/BookingService/BookingService/Controllers/NotificationController.cs#L96) |
| WEB-API-081 | `POST /api/v1/payments/{id}/process` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? recipientEmail | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:186](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L186) |
| WEB-API-082 | `GET /api/v1/payments/{id}/refund` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:208](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L208) |
| WEB-API-083 | `POST /api/v1/payments/{id}/refund` | Policy = AuthorizationPolicies.AdminOnly | Query: string? reason | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:198](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L198) |
| WEB-API-084 | `GET /api/v1/payments/{id}` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:57](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L57) |
| WEB-API-085 | `GET /api/v1/payments/booking/{bookingId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:88](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L88) |
| WEB-API-086 | `POST /api/v1/payments/cash` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: CashPaymentRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:136](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L136) |
| WEB-API-087 | `POST /api/v1/payments/payos/{orderCode}/verify` | Policy = AuthorizationPolicies.AnyRole | Query: string? recipientEmail | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:147](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L147) |
| WEB-API-088 | `POST /api/v1/payments/payos/checkout` | Policy = AuthorizationPolicies.AnyRole | Body: PayOsCreateRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:122](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L122) |
| WEB-API-089 | `POST /api/v1/payments/payos/webhook` | public | Body: JsonElement body | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:172](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L172) |
| WEB-API-090 | `POST /api/v1/payments/refunds/{refundId}/complete` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: CompleteRefundRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:255](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L255) |
| WEB-API-091 | `POST /api/v1/payments/refunds/{refundId}/reject` | Policy = AuthorizationPolicies.StaffOrAdmin | Body: RejectRefundRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:245](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L245) |
| WEB-API-092 | `GET /api/v1/payments/refunds/{refundId}` | Policy = AuthorizationPolicies.AnyRole | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:232](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L232) |
| WEB-API-093 | `GET /api/v1/payments/refunds` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: string? status; Query: int page; Query: int size | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:222](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L222) |
| WEB-API-094 | `GET /api/v1/payments/summary` | Policy = AuthorizationPolicies.AdminOnly | Query: DateTime start; Query: DateTime end | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:46](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L46) |
| WEB-API-095 | `GET /api/v1/payments/user/{userId}` | Policy = AuthorizationPolicies.AnyRole | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:70](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L70) |
| WEB-API-096 | `GET /api/v1/payments` | Policy = AuthorizationPolicies.StaffOrAdmin | Query: int page; Query: int size; Query: string sortBy; Query: string sortDir | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:31](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L31) |
| WEB-API-097 | `POST /api/v1/payments` | Policy = AuthorizationPolicies.AnyRole | Body: PaymentRequest request | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs:110](../Cinema_BE/BookingService/BookingService/Controllers/PaymentController.cs#L110) |
| WEB-API-098 | `PUT /api/v1/promotions/{id}` | Policy = AuthorizationPolicies.AdminOnly | Body: PromotionRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:47](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L47) |
| WEB-API-099 | `POST /api/v1/promotions/quote` | authenticated | Body: PromotionQuoteRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:33](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L33) |
| WEB-API-100 | `GET /api/v1/promotions` | public | Query: bool all | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:24](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L24) |
| WEB-API-101 | `POST /api/v1/promotions` | Policy = AuthorizationPolicies.AdminOnly | Body: PromotionRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs:40](../Cinema_BE/BookingService/BookingService/Controllers/PromotionController.cs#L40) |
| WEB-API-102 | `DELETE /api/v1/reviews/{id}` | authenticated | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:58](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L58) |
| WEB-API-103 | `GET /api/v1/reviews/booking/{bookingId}` | authenticated | — | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:43](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L43) |
| WEB-API-104 | `GET /api/v1/reviews/mine` | authenticated | — | Shared backend/API-only; implemented | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:36](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L36) |
| WEB-API-105 | `GET /api/v1/reviews/movie/{movieId}` | public | Query: int page; Query: int size | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:25](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L25) |
| WEB-API-106 | `POST /api/v1/reviews` | authenticated | Body: MovieReviewRequest request | Direct client; implemented | [Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs:50](../Cinema_BE/BookingService/BookingService/Controllers/MovieReviewController.cs#L50) |

POST /api/showtimes/{showtimeId}/seats is called internally by BookingService with the forwarded token. Its controller permits authenticated callers while the gateway general showtime-write route requires StaffOrAdmin; do not treat it as a Customer client call. PayOS webhook is anonymous to JWT but authenticated by HMAC. Internal calls and webhook remain dependencies, not extra mobile screens.

Pagination is endpoint-specific: page/size for many catalogue/booking/payment APIs; pageNumber/pageSize for declared showtime/room APIs. Paged sizes are capped, usually at 50; genre/menu/seat/loyalty arrays are not all paginated. ApiClient uses a 15-second timeout and UTF-8 JSON/ProblemDetails parsing. Status/result shapes follow current controller DTOs.

### Request field definitions

| DTO | Fields / types | Source |
| --- | --- | --- |
| ChangePasswordRequest | CurrentPassword: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ChangePasswordRequest.cs) |
| CreateUserRequest | Email: string; Password: string; FullName: string; Phone: string?; Roles: List<string> | [Cinema_BE/AuthService/AuthService/DTOs/Request/CreateUserRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/CreateUserRequest.cs) |
| EmailRequest | Email: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/EmailRequest.cs) |
| LoginRequest | Email: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/LoginRequest.cs) |
| RefreshTokenRequest | RefreshToken: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RefreshTokenRequest.cs) |
| RegisterRequest | Email: string; Password: string; FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/RegisterRequest.cs) |
| ResetPasswordRequest | Email: string; Otp: string; NewPassword: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/ResetPasswordRequest.cs) |
| UpdateProfileRequest | FullName: string; Phone: string? | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateProfileRequest.cs) |
| UpdateUserRolesRequest | Roles: List<string> | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserRolesRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserRolesRequest.cs) |
| UpdateUserStatusRequest | Enabled: bool? | [Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserStatusRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/UpdateUserStatusRequest.cs) |
| VerifyEmailRequest | Email: string; Otp: string; Password: string | [Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs](../Cinema_BE/AuthService/AuthService/DTOs/Request/VerifyEmailRequest.cs) |
| BookingRequest | UserId: long?; ShowtimeId: long?; MovieTitle: string?; CustomerEmail: string?; CustomerPhone: string?; ShowTime: DateTime?; Seats: List<SeatRequest>; PromotionCode: string?; UsePoints: int?; Concessions: List<BookingConcessionRequest> | [Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/BookingRequest.cs) |
| CashPaymentRequest | BookingId: long?; AmountReceived: decimal?; RecipientEmail: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/CashPaymentRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/CashPaymentRequest.cs) |
| CompleteRefundRequest | TransactionRef: string?; Note: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/CompleteRefundRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/CompleteRefundRequest.cs) |
| ConcessionItemRequest | Name: string?; Description: string?; Price: decimal?; ImageUrl: string?; Active: bool?; SortOrder: int? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/ConcessionItemRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/ConcessionItemRequest.cs) |
| LoyaltyAdjustRequest | Points: int?; Note: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/LoyaltyAdjustRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/LoyaltyAdjustRequest.cs) |
| MovieReviewRequest | BookingId: long?; Rating: int?; Comment: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/MovieReviewRequest.cs) |
| NotificationRequest | UserId: long?; BookingId: long?; RecipientEmail: string?; Subject: string?; Type: string?; Content: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/NotificationRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/NotificationRequest.cs) |
| PaymentRequest | BookingId: long?; UserId: long?; RecipientEmail: string?; Amount: decimal?; Method: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PaymentRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PaymentRequest.cs) |
| PayOsCreateRequest | BookingId: long?; UserId: long?; Amount: decimal?; Description: string?; ReturnUrl: string?; CancelUrl: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PayOsCreateRequest.cs) |
| PromotionQuoteRequest | ShowtimeId: long?; TicketAmount: decimal; Tickets: int; Code: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionQuoteRequest.cs) |
| PromotionRequest | Code: string?; Name: string?; Description: string?; DiscountType: string?; DiscountValue: decimal?; MaxDiscount: decimal?; MinTickets: int?; DaysOfWeek: List<int>?; StartsAt: DateTime?; EndsAt: DateTime?; UsageLimit: int?; Active: bool? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/PromotionRequest.cs) |
| RejectRefundRequest | Reason: string? | [Cinema_BE/BookingService/BookingService/DTOs/Requests/RejectRefundRequest.cs](../Cinema_BE/BookingService/BookingService/DTOs/Requests/RejectRefundRequest.cs) |
| GenerateSeatRequest | RoomId: long; Rows: int; SeatsPerRow: int; SeatType: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/GenerateSeatRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/GenerateSeatRequest.cs) |
| MovieRequest | Title: string?; Description: string?; DurationMinutes: int; Genre: string?; Language: string?; ReleaseDate: DateTime; PosterUrl: string?; TrailerUrl: string?; PreviewUrl: string?; AgeRating: string?; Director: string?; Cast: string?; Status: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/MovieRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/MovieRequest.cs) |
| RoomRequest | Name: string; TotalSeats: int; Rows: int; SeatsPerRow: int | [Cinema_BE/MovieService/MovieService/DTOs/Request/RoomRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/RoomRequest.cs) |
| ShowtimeRequest | MovieId: long; RoomId: long; StartTime: DateTime; EndTime: DateTime; Price: decimal; Status: string?; Format: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/ShowtimeRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/ShowtimeRequest.cs) |
| UpdateRoomSeatsRequest | TotalSeats: int; SeatsPerRow: int?; SeatType: string? | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateRoomSeatsRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateRoomSeatsRequest.cs) |
| UpdateSeatTypeRequest | SeatIds: List<long>; SeatType: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateSeatTypeRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateSeatTypeRequest.cs) |
| UpdateShowtimeStatusRequest | Status: string | [Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateShowtimeStatusRequest.cs](../Cinema_BE/MovieService/MovieService/DTOs/Request/UpdateShowtimeStatusRequest.cs) |

## 14. Data Requirements

Project-Cinema-DB is uninitialized in this checkout (git submodule status begins with “-”). Its SQL dumps/seed/migrations are unavailable; exact DDL and live migration state are [TO BE CONFIRMED]. This contract uses local EF models/DbContexts and available backend SQL migrations. Model mappings do not prove a live DB has been migrated.

| Database | Entities / tables | Integrity and fields |
| --- | --- | --- |
| cinema_auth_db | User/Role; users, roles, users_roles, refresh_tokens, otp_codes | Unique email/token; BCrypt hashes; role joins; OTP lifetime and token revocation |
| cinema_movie_db | Movie; movies | Title/duration/genre/language/rating/director/cast; poster/trailer/preview; ACTIVE/INACTIVE |
| cinema_showtime_db | Room/Seat/Showtime; rooms, seats, showtimes, outbox_messages | Unique room/row/number; format, time, price; room-local foreign keys |
| cinema_booking_db | Booking, BookingSeat, SeatReservation, ConcessionItem, BookingConcession, Promotion, LoyaltyAccount, LoyaltyTransaction, MovieReview; bookings, booking_seats, seat_reservations, concession_items, booking_concessions, promotions, loyalty_accounts, loyalty_transactions, movie_reviews, outbox_messages | Unique booking code; unique showtime/seat reservation; unique user/movie review; amount snapshots; nullable counter userId; checkedInAt/expiresAt/remindedAt |
| cinema_payment_db | Payment/Refund; payments, refunds, outbox_messages | Booking, amount, method/state, PayOS reference and payer bank; one refund per payment |
| cinema_notification_db | Notification; notifications | Recipient/booking/event; deduplicate event; sentAt/readAt; state and error |

Client persistence is session tokens/user metadata via flutter_secure_storage and in-memory booking drafts, not six local databases. Server decimal totals snapshot seat/concession/discount/point values. Cinema time uses Vietnam local time and timestamp without time zone mappings. Cross-service IDs are application/event-validated logical references.

## 15. Business Workflows

| ID | Workflow |
| --- | --- |
| WEB-WF-01 | Register → verify OTP → role landing; unverified login goes to OTP. A failed recovery never authenticates an account. |
| WEB-WF-02 | Browse → movie → open showtime → seats → summary with extras/code/points/age → create PENDING hold → PayOS → server verify → CONFIRMED + ticket notification. |
| WEB-WF-03 | expiresAt reached → expiry worker (default every 30 seconds) → EXPIRED and release seats/points. Late payment reclaims seats and confirms, or creates full refund. |
| WEB-WF-04 | Paid customer cancellation ≥2 hours before show → REFUND_PENDING with seats retained → web staff manual transfer/record → REFUNDED/CANCELLED. Eligible rejection restores SUCCESS/CONFIRMED. |
| WEB-WF-05 | 1. Scan QR or type the booking code and press Enter. 2. Lookup ticket; enrich room and age rating when catalogue calls succeed. 3. Check identity/rating as prompted, then explicitly check in. 4. Store checkedInAt, show confirmation and prepare for the next code. |
| WEB-WF-06 | 1. Select walk-in or find a member by phone; choose showtime, seats and optional concessions/promotion/points. 2. Hold seats and open counter checkout. 3. Take sufficient cash and display change, or show VietQR and verify every three seconds. 4. After server confirmation show/print the QR ticket, optionally email it and check in within the permitted window. |
| WEB-WF-07 | Cancel showtime → MovieService outbox → BookingService event handler → cancel bookings/create paid refunds → notifications. Propagation is eventual, not one transaction across databases. |

### State contract

| Object | Transitions |
| --- | --- |
| Booking | PENDING → CONFIRMED / CANCELLED / EXPIRED; EXPIRED → CONFIRMED (verified late payment and available seats); CONFIRMED → REFUND_PENDING / CANCELLED; REFUND_PENDING → CONFIRMED / CANCELLED |
| Payment | PENDING → SUCCESS / FAILED; FAILED → SUCCESS (verified late payment); SUCCESS → REFUND_PENDING → REFUNDED; REFUND_PENDING → SUCCESS |
| Refund | PENDING → COMPLETED / REJECTED; REJECTED → PENDING (cinema cancels later) |
| Showtime | OPEN ↔ CLOSED; OPEN/CLOSED → CANCELLED |
| Notification | PENDING → SENT/FAILED; FAILED → SENT; readAt independent of send state |

checkedInAt is an attribute of a confirmed booking, not a separate booking status.

## 16. Authentication & Authorization

Gateway and services validate JWT signature/expiry/issuer/audience. Defaults: access 60 minutes, refresh seven days rotated on use; OTP six digits, five minutes, five attempts, 60-second resend. Admin-created accounts skip registration OTP. Password and OTP values are BCrypt-hashed.

ApiClient renews and retries a protected request once. Protected checks reject ACCOUNT_LOCKED (401), ROLE_CHANGED (403) or unavailable AuthService (503). Public catalogue GETs omit bearer token; a signed-in client probes /auth/me at most once per minute, ignores ordinary availability errors for browsing and expires the session for lock/role-change signals. Logout clears storage/revokes refresh; reset/change password revokes old refresh tokens. Refresh revocation alone does not certify immediate invalidation of every issued access token.

## 17. Error Handling

| Code / condition | Handling |
| --- | --- |
| 400 | Show field/business validation; do not advance |
| 401 | Renew once if possible; otherwise clear session/sign in; retain lock/session reason |
| 403 | Deny role/ownership action; EMAIL_NOT_VERIFIED opens OTP; ROLE_CHANGED signs in again |
| 404 | Show missing record without leaking another owner’s review ticket |
| 409 | Explain seat/state/time conflict and reload before retrying |
| 429 | Respect Retry-After/countdown; preserve inputs |
| 500 / 503 | Show retryable service error; no false booking/payment success |
| Timeout/offline/invalid JSON | Bounded error (15-second client timeout); retry and honest pending/failure state |
| Loading/empty/camera denial | Explicit state without fake records; preserve manual ticket-code entry |

## 18. Non-Functional Requirements

| ID | Requirement | Allocation |
| --- | --- | --- |
| WEB-NFR-SEC-01 | Passwords and OTP codes are hashed with BCrypt; responses never include stack traces or internal errors. | Web/backend |
| WEB-NFR-SEC-02 | JWTs are signed with a secret of at least 32 characters; access tokens last 60 minutes; refresh tokens last 7 days, rotate, and are revoked on sign-out, password reset and role change. | Web/backend |
| WEB-NFR-SEC-03 | Authorization is checked at the gateway (per route) and in the service (per record, e.g. only one's own tickets). | Web/backend |
| WEB-NFR-SEC-04 | Rate limits: 100 requests per minute per IP for all APIs, 10 for authentication APIs. | Web/backend |
| WEB-NFR-SEC-05 | Only the gateway is reachable from the network; services, PostgreSQL, RabbitMQ and monitoring listen on `127.0.0.1`. | Web/backend |
| WEB-NFR-SEC-06 | Secrets are not in the source code; they are shared with SOPS + age. | Web/backend |
| WEB-NFR-SEC-07 | The server validates every input (DataAnnotations + validators); clients validate first to report mistakes early. | Web/backend |
| WEB-NFR-PERF-01 | Paged endpoints cap size, normally 50; genres/seats/menu arrays are exempt. Ticket UI currently loads only the first page. Response-time/concurrent-user SLA is [TO BE CONFIRMED], not a measured guarantee. | Web/backend |
| WEB-NFR-PERF-02 | Holding seats, confirming tickets and taking payment lock the booking row (`SELECT … FOR UPDATE`) in a transaction, so seats are never sold twice and money is never taken twice under concurrent use. | Web/backend |
| WEB-NFR-REL-01 | Calls to MovieService / PayOS retry transient errors at most twice (creating a PayOS link is never retried); a circuit breaker opens for 15 seconds after repeated failures and returns 503 at once. | Web/backend |
| WEB-NFR-REL-02 | Outbox: no event is lost while RabbitMQ is down; it is sent when RabbitMQ is back. | Web/backend |
| WEB-NFR-REL-03 | Consumers are idempotent; failing messages are retried 3 times and then moved to a DLQ. | Web/backend |
| WEB-NFR-REL-04 | The gateway checks each service's `/health/live` every 10 seconds and returns 503 at once for a dead service. | Web/backend |
| WEB-NFR-OBS-01 | Prometheus metrics for HTTP, runtime and business events (bookings, payments, refunds, outbox); Grafana dashboard "Cinema - Tổng quan". | Web/backend |
| WEB-NFR-OBS-02 | OpenTelemetry traces to Jaeger across the gateway, services, SQL, PayOS and RabbitMQ. | Web/backend |
| WEB-NFR-OBS-03 | Logs carry TraceId, SpanId and CorrelationId; every response has an `X-Correlation-ID` header. | Web/backend |
| WEB-NFR-MAINT-01 | Layered services, DTOs, validators and a global exception handler everywhere; documentation in `docs/`. | Web/backend |
| WEB-NFR-MAINT-02 | CI declares .NET tests, Flutter analyze/test and customer/admin web builds. Current Flutter workflow pins 3.47.4, superseding older prose; no current successful CI run is asserted. | Web/backend |
| WEB-NFR-DEP-01 | One command, `docker compose up -d --build`, runs the whole backend; monitoring through the `monitoring` profile. | Web/backend |
| WEB-NFR-USE-01 | The customer app supports Android, web and Windows; the admin website is designed for desktops and still works on narrow screens. | Web/backend |
| WEB-NFR-COMP-01 | Web cameras need `localhost` or HTTPS; a real deployment must use HTTPS. | Web/backend |

NFR mechanisms may be evidenced in code; availability, throughput, universal accessibility and compatibility require runtime validation and are not established by static inspection.

## 19. Security Requirements

| ID | Security requirement and verification |
| --- | --- |
| WEB-SEC-01 | Reject forged/expired/wrong-issuer JWT and forbidden roles at gateway/service; test record-ID changes against ownership. |
| WEB-SEC-02 | Recompute prices and validate seat pairs/menu/code/points on server; do not trust client totals or redirect parameters as payment. |
| WEB-SEC-03 | Verify PayOS HMAC before effects; test repeat webhook, wrong signature, unknown order and amount mismatch. Keep merchant keys in backend. |
| WEB-SEC-04 | Use deployment HTTPS and restricted CORS/private-service exposure. Development HTTP is not proof of production TLS. |
| WEB-SEC-05 | Use platform secure-storage abstraction; never embed backend secrets in client. Clear/revoke credentials on logout/reset and handle unreadable storage as signed out. |
| WEB-SEC-06 | Encode user content in email; suppress stack traces/secrets. Generic forgot-password does not imply universal resistance to email enumeration. |

## 20. Testing Requirements

Derive tests from each FR AC-01/AC-02. Existing test files evidence coverage intent, not a newly run report. Backend fixtures use Testcontainers PostgreSQL/RabbitMQ and configured fakes for external PayOS/SMTP/catalogue dependencies. Live PayOS/SMTP, camera/share/printing require separate controlled acceptance.

| ID | Required test |
| --- | --- |
| WEB-TEST-01 | OTP expiry/attempts/resend; UTF-8 password bounds; refresh reuse; lock/role changes; wrong owner/role. |
| WEB-TEST-02 | Two simultaneous holds on one seat: one success, one 409; no partial seats/points. Reject half sweetbox. |
| WEB-TEST-03 | Payment success/cancel/timeout, duplicate signed webhook, late payment with available/lost seats; never false paid UI. |
| WEB-TEST-04 | Cancellation exactly at and around two hours; complete/reject/reopen refund; one refund, pending-seat retention and point reversal. |
| WEB-TEST-05 | Check-in immediately before/at/after time limits; two simultaneous scans; manual lookup after camera denial. |
| WEB-TEST-06 | Route restoration, missing draft, loading/empty/error, timeout/retry, unread counts and return from external app. |
| WEB-TEST-07 | Cash underpayment/change, transfer-to-cash race, 80 mm print; schedule overlap; Admin-only master-data/revenue access. |

### Existing test evidence

| Area / use case | Files |
| --- | --- |
| UC-WEB-01 | [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart); [Cinema_Mobile/test/register_validation_test.dart](../Cinema_Mobile/test/register_validation_test.dart) |
| UC-WEB-02 | [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| UC-WEB-03 | [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart); [Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart](../Cinema_Mobile/test/liquid_glass_responsive_preview_test.dart); [Cinema_Mobile/test/review_test.dart](../Cinema_Mobile/test/review_test.dart) |
| UC-WEB-04 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart); [Cinema_Mobile/test/showtime_format_test.dart](../Cinema_Mobile/test/showtime_format_test.dart) |
| UC-WEB-05 | [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| UC-WEB-06 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs); [Cinema_Mobile/test/showtime_format_test.dart](../Cinema_Mobile/test/showtime_format_test.dart) |
| UC-WEB-07 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PromotionTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/concession_test.dart](../Cinema_Mobile/test/concession_test.dart); [Cinema_Mobile/test/loyalty_test.dart](../Cinema_Mobile/test/loyalty_test.dart); [Cinema_Mobile/test/promotion_test.dart](../Cinema_Mobile/test/promotion_test.dart) |
| UC-WEB-08 | [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Unit/PayOsSignatureTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart) |
| UC-WEB-09 | [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart); [Cinema_Mobile/test/staff_booking_details_ui_test.dart](../Cinema_Mobile/test/staff_booking_details_ui_test.dart) |
| UC-WEB-10 | [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| UC-WEB-11 | [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| UC-WEB-12 | [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| UC-WEB-13 | [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |

## 21. Acceptance Criteria

All H requirements must meet both criteria; security, ownership, financial and concurrency tests must pass. Disclose every M/L omission and current implementation gap. This document does not certify a passing run.

| ID | Acceptance gate |
| --- | --- |
| WEB-ACC-01 | Demonstrate account → movie → showtime → seats → booking → payment → ticket/notification with real backend or documented fixtures. |
| WEB-ACC-02 | Reject cross-account unauthorized access and duplicate concurrent seat sale/check-in/payment effects. |
| WEB-ACC-03 | Demonstrate refund and late-payment outcomes with correct seats/points and no false confirmed ticket. |
| WEB-ACC-04 | Verify navigation, loading/error/empty and device fallbacks; disclose §27 limitations. |

## 22. Requirements Traceability Matrix

Complete FR matrix. Source IDs provide backward mapping; NAV/STATE/MEDIA are code-derived refinements. API associations are by functional area, not a claim that every screen invokes every listed operation. Existing tests are coverage candidates, not measured test results.

| Requirement / source | Business rules | Use case | Screens | API | AC / test evidence |
| --- | --- | --- | --- | --- | --- |
| WEB-FR-AUTH-01 ← FR-AUTH-01 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-REGISTER | WEB-API-033 | WEB-FR-AUTH-01-AC-01, WEB-FR-AUTH-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-02 ← FR-AUTH-02 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-027 | WEB-FR-AUTH-02-AC-01, WEB-FR-AUTH-02-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-03 ← FR-AUTH-03 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-027, WEB-API-032 | WEB-FR-AUTH-03-AC-01, WEB-FR-AUTH-03-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-04 ← FR-AUTH-04 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 |  | WEB-API-029 | WEB-FR-AUTH-04-AC-01, WEB-FR-AUTH-04-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-05 ← FR-AUTH-05 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-STAFF-ONLY | WEB-API-029 | WEB-FR-AUTH-05-AC-01, WEB-FR-AUTH-05-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-06 ← FR-AUTH-06 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-029 | WEB-FR-AUTH-06-AC-01, WEB-FR-AUTH-06-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-07 ← FR-AUTH-07 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-VERIFY | WEB-API-034, WEB-API-042 | WEB-FR-AUTH-07-AC-01, WEB-FR-AUTH-07-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-08 ← FR-AUTH-08 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-REGISTER, WEB-SCR-VERIFY | WEB-API-033 | WEB-FR-AUTH-08-AC-01, WEB-FR-AUTH-08-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-09 ← FR-AUTH-09 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-FORGOT, WEB-SCR-RESET | WEB-API-026, WEB-API-035 | WEB-FR-AUTH-09-AC-01, WEB-FR-AUTH-09-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-10 ← FR-AUTH-10 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-028, WEB-API-032 | WEB-FR-AUTH-10-AC-01, WEB-FR-AUTH-10-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-11 ← FR-AUTH-11 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-029 | WEB-FR-AUTH-11-AC-01, WEB-FR-AUTH-11-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-12 ← FR-AUTH-12 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN | WEB-API-029 | WEB-FR-AUTH-12-AC-01, WEB-FR-AUTH-12-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-13 ← FR-AUTH-13 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN, WEB-SCR-REGISTER, WEB-SCR-FORGOT, WEB-SCR-RESET, WEB-SCR-USER-EDITOR | WEB-API-027, WEB-API-033, WEB-API-035, WEB-API-041 | WEB-FR-AUTH-13-AC-01, WEB-FR-AUTH-13-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-14 ← FR-AUTH-14 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-VERIFY, WEB-SCR-FORGOT, WEB-SCR-RESET | WEB-API-027, WEB-API-032, WEB-API-034 | WEB-FR-AUTH-14-AC-01, WEB-FR-AUTH-14-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-15 ← FR-AUTH-15 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-COUNTER | WEB-API-030 | WEB-FR-AUTH-15-AC-01, WEB-FR-AUTH-15-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-16 ← FR-AUTH-16 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-031 | WEB-FR-AUTH-16-AC-01, WEB-FR-AUTH-16-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-AUTH-17 ← FR-AUTH-17 | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-PROFILE, WEB-SCR-MGT-PROFILE | WEB-API-025 | WEB-FR-AUTH-17-AC-01, WEB-FR-AUTH-17-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-USER-01 ← FR-USER-01 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-ADMIN-USERS | WEB-API-040 | WEB-FR-USER-01-AC-01, WEB-FR-USER-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-02 ← FR-USER-02 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-039 | WEB-FR-USER-02-AC-01, WEB-FR-USER-02-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-03 ← FR-USER-03 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-041 | WEB-FR-USER-03-AC-01, WEB-FR-USER-03-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-04 ← FR-USER-04 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-037 | WEB-FR-USER-04-AC-01, WEB-FR-USER-04-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-05 ← FR-USER-05 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-USER-EDITOR | WEB-API-038 | WEB-FR-USER-05-AC-01, WEB-FR-USER-05-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-USER-06 ← FR-USER-06 | WEB-BR-03, WEB-BR-24 | UC-WEB-02 | WEB-SCR-ADMIN-USERS, WEB-SCR-USER-EDITOR | WEB-API-036 | WEB-FR-USER-06-AC-01, WEB-FR-USER-06-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/UserManagementTests.cs); [Cinema_Mobile/test/admin_user_roles_test.dart](../Cinema_Mobile/test/admin_user_roles_test.dart) |
| WEB-FR-MOV-01 ← FR-MOV-01 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-070 | WEB-FR-MOV-01-AC-01, WEB-FR-MOV-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-02 ← FR-MOV-02 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES | WEB-API-064 | WEB-FR-MOV-02-AC-01, WEB-FR-MOV-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-03 ← FR-MOV-03 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES | WEB-API-066, WEB-API-068 | WEB-FR-MOV-03-AC-01, WEB-FR-MOV-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-04 ← FR-MOV-04 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME, WEB-SCR-ADMIN-MOVIES | WEB-API-066, WEB-API-069 | WEB-FR-MOV-04-AC-01, WEB-FR-MOV-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-05 ← FR-MOV-05 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-071 | WEB-FR-MOV-05-AC-01, WEB-FR-MOV-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-06 ← FR-MOV-06 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-065 | WEB-FR-MOV-06-AC-01, WEB-FR-MOV-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-07 ← FR-MOV-07 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-ADMIN-MOVIES | WEB-API-063 | WEB-FR-MOV-07-AC-01, WEB-FR-MOV-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-08 ← FR-MOV-08 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE | WEB-API-064 | WEB-FR-MOV-08-AC-01, WEB-FR-MOV-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-09 ← FR-MOV-09 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-SUMMARY, WEB-SCR-CHECKIN, WEB-SCR-ADMIN-MOVIES | WEB-API-064, WEB-API-065, WEB-API-071 | WEB-FR-MOV-09-AC-01, WEB-FR-MOV-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-10 ← FR-MOV-10 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME | WEB-API-066, WEB-API-067 | WEB-FR-MOV-10-AC-01, WEB-FR-MOV-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-11 ← FR-MOV-11 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-ADMIN-MOVIES | WEB-API-064, WEB-API-065, WEB-API-071 | WEB-FR-MOV-11-AC-01, WEB-FR-MOV-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-MOV-12 ← FR-MOV-12 | WEB-BR-26 | UC-WEB-03 | WEB-SCR-MOVIE, WEB-SCR-TICKET, WEB-SCR-ADMIN-MOVIES | WEB-API-102, WEB-API-103, WEB-API-105, WEB-API-106 | WEB-FR-MOV-12-AC-01, WEB-FR-MOV-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |
| WEB-FR-ROOM-01 ← FR-ROOM-01 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-OPERATIONS, WEB-SCR-ADMIN-ROOMS | WEB-API-004, WEB-API-005 | WEB-FR-ROOM-01-AC-01, WEB-FR-ROOM-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-02 ← FR-ROOM-02 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-RECORD-ROOMS, WEB-SCR-ADMIN-ROOMS | WEB-API-002, WEB-API-013 | WEB-FR-ROOM-02-AC-01, WEB-FR-ROOM-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-03 ← FR-ROOM-03 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-006, WEB-API-010 | WEB-FR-ROOM-03-AC-01, WEB-FR-ROOM-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-04 ← FR-ROOM-04 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-003 | WEB-FR-ROOM-04-AC-01, WEB-FR-ROOM-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-ROOM-05 ← FR-ROOM-05 | WEB-BR-04, WEB-BR-26 | UC-WEB-04 | WEB-SCR-ADMIN-ROOMS | WEB-API-001 | WEB-FR-ROOM-05-AC-01, WEB-FR-ROOM-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs) |
| WEB-FR-SEAT-01 ← FR-SEAT-01 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-010 | WEB-FR-SEAT-01-AC-01, WEB-FR-SEAT-01-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-02 ← FR-SEAT-02 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-009 | WEB-FR-SEAT-02-AC-01, WEB-FR-SEAT-02-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-03 ← FR-SEAT-03 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-SEATS, WEB-SCR-RECORD-ROOMS | WEB-API-013 | WEB-FR-SEAT-03-AC-01, WEB-FR-SEAT-03-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-04 ← FR-SEAT-04 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 |  | WEB-API-008 | WEB-FR-SEAT-04-AC-01, WEB-FR-SEAT-04-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-05 ← FR-SEAT-05 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-007 | WEB-FR-SEAT-05-AC-01, WEB-FR-SEAT-05-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-06 ← FR-SEAT-06 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-012 | WEB-FR-SEAT-06-AC-01, WEB-FR-SEAT-06-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-07 ← FR-SEAT-07 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-011 | WEB-FR-SEAT-07-AC-01, WEB-FR-SEAT-07-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-08 ← FR-SEAT-08 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-007, WEB-API-010, WEB-API-011, WEB-API-012 | WEB-FR-SEAT-08-AC-01, WEB-FR-SEAT-08-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SEAT-09 ← FR-SEAT-09 | WEB-BR-04, WEB-BR-07, WEB-BR-15, WEB-BR-16, WEB-BR-26 | UC-WEB-05 | WEB-SCR-RECORD-ROOMS | WEB-API-013 | WEB-FR-SEAT-09-AC-01, WEB-FR-SEAT-09-AC-02; [Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/SeatTests.cs); [Cinema_Mobile/test/booking_flow_test.dart](../Cinema_Mobile/test/booking_flow_test.dart); [Cinema_Mobile/test/seat_map_test.dart](../Cinema_Mobile/test/seat_map_test.dart) |
| WEB-FR-SHOW-01 ← FR-SHOW-01 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-OPERATIONS | WEB-API-023 | WEB-FR-SHOW-01-AC-01, WEB-FR-SHOW-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-02 ← FR-SHOW-02 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-024 | WEB-FR-SHOW-02-AC-01, WEB-FR-SHOW-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-03 ← FR-SHOW-03 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-RECORD-SHOWTIMES | WEB-API-017 | WEB-FR-SHOW-03-AC-01, WEB-FR-SHOW-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-04 ← FR-SHOW-04 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-018 | WEB-FR-SHOW-04-AC-01, WEB-FR-SHOW-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-05 ← FR-SHOW-05 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-016 | WEB-FR-SHOW-05-AC-01, WEB-FR-SHOW-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-06 ← FR-SHOW-06 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-022 | WEB-FR-SHOW-06-AC-01, WEB-FR-SHOW-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-07 ← FR-SHOW-07 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-021 | WEB-FR-SHOW-07-AC-01, WEB-FR-SHOW-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-08 ← FR-SHOW-08 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE | WEB-API-020 | WEB-FR-SHOW-08-AC-01, WEB-FR-SHOW-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-09 ← FR-SHOW-09 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-OPERATIONS | WEB-API-019 | WEB-FR-SHOW-09-AC-01, WEB-FR-SHOW-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-10 ← FR-SHOW-10 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-015 | WEB-FR-SHOW-10-AC-01, WEB-FR-SHOW-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-11 ← FR-SHOW-11 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-SHOW-EDITOR | WEB-API-018, WEB-API-024 | WEB-FR-SHOW-11-AC-01, WEB-FR-SHOW-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-12 ← FR-SHOW-12 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-RECORD-SHOWTIMES | WEB-API-013, WEB-API-017, WEB-API-050 | WEB-FR-SHOW-12-AC-01, WEB-FR-SHOW-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-SHOW-13 ← FR-SHOW-13 | WEB-BR-05, WEB-BR-06, WEB-BR-15, WEB-BR-19, WEB-BR-30 | UC-WEB-06 | WEB-SCR-MOVIE, WEB-SCR-SEATS, WEB-SCR-SHOW-EDITOR | WEB-API-017, WEB-API-018, WEB-API-024 | WEB-FR-SHOW-13-AC-01, WEB-FR-SHOW-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeFormatTests.cs); [Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs](../Cinema_BE/MovieService/MovieService.Tests/Integration/ShowtimeTests.cs) |
| WEB-FR-BOOK-01 ← FR-BOOK-01 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY | WEB-API-055 | WEB-FR-BOOK-01-AC-01, WEB-FR-BOOK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-02 ← FR-BOOK-02 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-RESULT, WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS | WEB-API-046 | WEB-FR-BOOK-02-AC-01, WEB-FR-BOOK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-03 ← FR-BOOK-03 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-OPERATIONS | WEB-API-048, WEB-API-052, WEB-API-054 | WEB-FR-BOOK-03-AC-01, WEB-FR-BOOK-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-04 ← FR-BOOK-04 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKETS | WEB-API-053 | WEB-FR-BOOK-04-AC-01, WEB-FR-BOOK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-05 ← FR-BOOK-05 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-TICKET | WEB-API-086, WEB-API-087, WEB-API-089 | WEB-FR-BOOK-05-AC-01, WEB-FR-BOOK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-06 ← FR-BOOK-06 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKET, WEB-SCR-RECORD-BOOKINGS | WEB-API-043 | WEB-FR-BOOK-06-AC-01, WEB-FR-BOOK-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-07 ← FR-BOOK-07 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-049 | WEB-FR-BOOK-07-AC-01, WEB-FR-BOOK-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-08 ← FR-BOOK-08 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-055 | WEB-FR-BOOK-08-AC-01, WEB-FR-BOOK-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-09 ← FR-BOOK-09 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS, WEB-SCR-SUMMARY | WEB-API-055 | WEB-FR-BOOK-09-AC-01, WEB-FR-BOOK-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-10 ← FR-BOOK-10 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-PAYMENT | WEB-API-046 | WEB-FR-BOOK-10-AC-01, WEB-FR-BOOK-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-11 ← FR-BOOK-11 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SEATS | WEB-API-013, WEB-API-049 | WEB-FR-BOOK-11-AC-01, WEB-FR-BOOK-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-12 ← FR-BOOK-12 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-SHOWTIMES | WEB-API-051 | WEB-FR-BOOK-12-AC-01, WEB-FR-BOOK-12-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-13 ← FR-BOOK-13 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER | WEB-API-055, WEB-API-057 | WEB-FR-BOOK-13-AC-01, WEB-FR-BOOK-13-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-14 ← FR-BOOK-14 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-SNACKS | WEB-API-056, WEB-API-057, WEB-API-058 | WEB-FR-BOOK-14-AC-01, WEB-FR-BOOK-14-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-15 ← FR-BOOK-15 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-COUNTER | WEB-API-055, WEB-API-099 | WEB-FR-BOOK-15-AC-01, WEB-FR-BOOK-15-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-16 ← FR-BOOK-16 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-PROMOTIONS | WEB-API-098, WEB-API-100, WEB-API-101 | WEB-FR-BOOK-16-AC-01, WEB-FR-BOOK-16-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-17 ← FR-BOOK-17 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-SUMMARY, WEB-SCR-TICKET, WEB-SCR-PROFILE, WEB-SCR-COUNTER | WEB-API-055, WEB-API-060 | WEB-FR-BOOK-17-AC-01, WEB-FR-BOOK-17-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-18 ← FR-BOOK-18 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-ADMIN-MEMBERS | WEB-API-030, WEB-API-059, WEB-API-061, WEB-API-062 | WEB-FR-BOOK-18-AC-01, WEB-FR-BOOK-18-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-BOOK-19 ← FR-BOOK-19 | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 | WEB-SCR-TICKET | WEB-API-017 | WEB-FR-BOOK-19-AC-01, WEB-FR-BOOK-19-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-PAY-01 ← FR-PAY-01 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT, WEB-SCR-CHECKOUT | WEB-API-088 | WEB-FR-PAY-01-AC-01, WEB-FR-PAY-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-02 ← FR-PAY-02 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT, WEB-SCR-RESULT, WEB-SCR-CHECKOUT | WEB-API-087 | WEB-FR-PAY-02-AC-01, WEB-FR-PAY-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-03 ← FR-PAY-03 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-TICKET, WEB-SCR-PAYHISTORY, WEB-SCR-RECORD-PAYMENTS | WEB-API-084 | WEB-FR-PAY-03-AC-01, WEB-FR-PAY-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-04 ← FR-PAY-04 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYHISTORY | WEB-API-095 | WEB-FR-PAY-04-AC-01, WEB-FR-PAY-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-05 ← FR-PAY-05 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-RECORD-PAYMENTS | WEB-API-085 | WEB-FR-PAY-05-AC-01, WEB-FR-PAY-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-06 ← FR-PAY-06 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-TICKET | WEB-API-043, WEB-API-082, WEB-API-083 | WEB-FR-PAY-06-AC-01, WEB-FR-PAY-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-07 ← FR-PAY-07 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 |  | WEB-API-089 | WEB-FR-PAY-07-AC-01, WEB-FR-PAY-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-08 ← FR-PAY-08 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-RESULT | WEB-API-087, WEB-API-089 | WEB-FR-PAY-08-AC-01, WEB-FR-PAY-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-09 ← FR-PAY-09 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-PAYMENTS | WEB-API-087, WEB-API-096 | WEB-FR-PAY-09-AC-01, WEB-FR-PAY-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-10 ← FR-PAY-10 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 |  | WEB-API-094 | WEB-FR-PAY-10-AC-01, WEB-FR-PAY-10-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-PAY-11 ← FR-PAY-11 | WEB-BR-09, WEB-BR-10, WEB-BR-11, WEB-BR-12, WEB-BR-13, WEB-BR-14, WEB-BR-20 | UC-WEB-08 | WEB-SCR-PAYMENT | WEB-API-046, WEB-API-087 | WEB-FR-PAY-11-AC-01, WEB-FR-PAY-11-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PayOsOrderCodeTests.cs) |
| WEB-FR-REF-01 ← FR-REF-01 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET | WEB-API-043, WEB-API-083, WEB-API-089 | WEB-FR-REF-01-AC-01, WEB-FR-REF-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-02 ← FR-REF-02 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-OPERATIONS, WEB-SCR-RECORD-REFUNDS | WEB-API-092, WEB-API-093 | WEB-FR-REF-02-AC-01, WEB-FR-REF-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-03 ← FR-REF-03 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-090 | WEB-FR-REF-03-AC-01, WEB-FR-REF-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-04 ← FR-REF-04 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-091 | WEB-FR-REF-04-AC-01, WEB-FR-REF-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-05 ← FR-REF-05 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET, WEB-SCR-RECORD-REFUNDS | WEB-API-016, WEB-API-043 | WEB-FR-REF-05-AC-01, WEB-FR-REF-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-06 ← FR-REF-06 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-TICKET, WEB-SCR-RECORD-PAYMENTS | WEB-API-082 | WEB-FR-REF-06-AC-01, WEB-FR-REF-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-REF-07 ← FR-REF-07 | WEB-BR-17, WEB-BR-18, WEB-BR-19, WEB-BR-20 | UC-WEB-09 | WEB-SCR-RECORD-REFUNDS | WEB-API-043, WEB-API-082 | WEB-FR-REF-07-AC-01, WEB-FR-REF-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/RefundTests.cs); [Cinema_Mobile/test/booking_details_ui_test.dart](../Cinema_Mobile/test/booking_details_ui_test.dart); [Cinema_Mobile/test/refund_details_ui_test.dart](../Cinema_Mobile/test/refund_details_ui_test.dart) |
| WEB-FR-POS-01 ← FR-POS-01 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-COUNTER | WEB-API-013, WEB-API-023, WEB-API-030, WEB-API-055 | WEB-FR-POS-01-AC-01, WEB-FR-POS-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-02 ← FR-POS-02 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-046 | WEB-FR-POS-02-AC-01, WEB-FR-POS-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-03 ← FR-POS-03 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-086 | WEB-FR-POS-03-AC-01, WEB-FR-POS-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-04 ← FR-POS-04 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-087, WEB-API-088 | WEB-FR-POS-04-AC-01, WEB-FR-POS-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-05 ← FR-POS-05 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-086 | WEB-FR-POS-05-AC-01, WEB-FR-POS-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-06 ← FR-POS-06 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-055, WEB-API-086 | WEB-FR-POS-06-AC-01, WEB-FR-POS-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-07 ← FR-POS-07 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT | WEB-API-044, WEB-API-046 | WEB-FR-POS-07-AC-01, WEB-FR-POS-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-POS-08 ← FR-POS-08 | WEB-BR-08, WEB-BR-15, WEB-BR-16, WEB-BR-22, WEB-BR-23, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-10 | WEB-SCR-CHECKOUT, WEB-SCR-RECORD-BOOKINGS | WEB-API-046 | WEB-FR-POS-08-AC-01, WEB-FR-POS-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CounterSaleTests.cs); [Cinema_Mobile/test/counter_booking_test.dart](../Cinema_Mobile/test/counter_booking_test.dart) |
| WEB-FR-CHK-01 ← FR-CHK-01 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-TICKET, WEB-SCR-CHECKOUT | WEB-API-046 | WEB-FR-CHK-01-AC-01, WEB-FR-CHK-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-02 ← FR-CHK-02 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN | WEB-API-047 | WEB-FR-CHK-02-AC-01, WEB-FR-CHK-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-03 ← FR-CHK-03 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN, WEB-SCR-CHECKOUT | WEB-API-044 | WEB-FR-CHK-03-AC-01, WEB-FR-CHK-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-04 ← FR-CHK-04 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-CHECKIN | WEB-API-044, WEB-API-047 | WEB-FR-CHK-04-AC-01, WEB-FR-CHK-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-CHK-05 ← FR-CHK-05 | WEB-BR-21 | UC-WEB-11 | WEB-SCR-TICKET, WEB-SCR-CHECKIN, WEB-SCR-RECORD-BOOKINGS | WEB-API-046, WEB-API-050 | WEB-FR-CHK-05-AC-01, WEB-FR-CHK-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/CheckInTests.cs); [Cinema_Mobile/test/check_in_test.dart](../Cinema_Mobile/test/check_in_test.dart) |
| WEB-FR-NOTI-01 ← FR-NOTI-01 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-NOTIFICATIONS | WEB-API-078, WEB-API-079 | WEB-FR-NOTI-01-AC-01, WEB-FR-NOTI-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-02 ← FR-NOTI-02 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-COMPOSE | WEB-API-080 | WEB-FR-NOTI-02-AC-01, WEB-FR-NOTI-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-03 ← FR-NOTI-03 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-COMPOSE | WEB-API-073 | WEB-FR-NOTI-03-AC-01, WEB-FR-NOTI-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-04 ← FR-NOTI-04 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-NOTIFICATION | WEB-API-075 | WEB-FR-NOTI-04-AC-01, WEB-FR-NOTI-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-05 ← FR-NOTI-05 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-074 | WEB-FR-NOTI-05-AC-01, WEB-FR-NOTI-05-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-06 ← FR-NOTI-06 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-078 | WEB-FR-NOTI-06-AC-01, WEB-FR-NOTI-06-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-07 ← FR-NOTI-07 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-026, WEB-API-033, WEB-API-042 | WEB-FR-NOTI-07-AC-01, WEB-FR-NOTI-07-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-08 ← FR-NOTI-08 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 |  | WEB-API-078 | WEB-FR-NOTI-08-AC-01, WEB-FR-NOTI-08-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-NOTI-09 ← FR-NOTI-09 | WEB-BR-11, WEB-BR-13 | UC-WEB-12 | WEB-SCR-HOME, WEB-SCR-NOTIFICATIONS, WEB-SCR-NOTIFICATION | WEB-API-072, WEB-API-076, WEB-API-077 | WEB-FR-NOTI-09-AC-01, WEB-FR-NOTI-09-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ShowtimeReminderTests.cs); [Cinema_Mobile/test/notification_read_test.dart](../Cinema_Mobile/test/notification_read_test.dart) |
| WEB-FR-DASH-01 ← FR-DASH-01 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH | WEB-API-019, WEB-API-048, WEB-API-051 | WEB-FR-DASH-01-AC-01, WEB-FR-DASH-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-02 ← FR-DASH-02 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH, WEB-SCR-ADMIN-DASH | WEB-API-019, WEB-API-051 | WEB-FR-DASH-02-AC-01, WEB-FR-DASH-02-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-03 ← FR-DASH-03 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-STAFF-DASH | WEB-API-052, WEB-API-093 | WEB-FR-DASH-03-AC-01, WEB-FR-DASH-03-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-DASH-04 ← FR-DASH-04 | WEB-BR-09, WEB-BR-23 | UC-WEB-13 | WEB-SCR-ADMIN-DASH | WEB-API-040, WEB-API-048, WEB-API-069, WEB-API-094 | WEB-FR-DASH-04-AC-01, WEB-FR-DASH-04-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/PaymentSummaryTests.cs); [Cinema_Mobile/test/today_at_cinema_test.dart](../Cinema_Mobile/test/today_at_cinema_test.dart) |
| WEB-FR-NAV-01 ← Code-derived | WEB-BR-01, WEB-BR-02, WEB-BR-03, WEB-BR-24, WEB-BR-25 | UC-WEB-01 | WEB-SCR-LOGIN, WEB-SCR-STAFF-ONLY | — | WEB-FR-NAV-01-AC-01, WEB-FR-NAV-01-AC-02; [Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AccountValidationTests.cs); [Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs](../Cinema_BE/AuthService/AuthService.Tests/Integration/AuthFlowTests.cs); [Cinema_Mobile/test/account_lock_flow_test.dart](../Cinema_Mobile/test/account_lock_flow_test.dart) |
| WEB-FR-STATE-01 ← Code-derived | WEB-BR-07, WEB-BR-08, WEB-BR-14, WEB-BR-15, WEB-BR-16, WEB-BR-17, WEB-BR-27, WEB-BR-28, WEB-BR-29 | UC-WEB-07 |  | — | WEB-FR-STATE-01-AC-01, WEB-FR-STATE-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/BookingFlowTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/ConcessionTests.cs); [Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/LoyaltyTests.cs) |
| WEB-FR-MEDIA-01 ← Code-derived | WEB-BR-26 | UC-WEB-03 | WEB-SCR-HOME | WEB-API-064 | WEB-FR-MEDIA-01-AC-01, WEB-FR-MEDIA-01-AC-02; [Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs](../Cinema_BE/BookingService/BookingService.Tests/Integration/MovieReviewTests.cs); [Cinema_Mobile/test/age_rating_test.dart](../Cinema_Mobile/test/age_rating_test.dart); [Cinema_Mobile/test/coming_soon_test.dart](../Cinema_Mobile/test/coming_soon_test.dart) |

## 23. Constraints

| ID | Constraint / open item |
| --- | --- |
| WEB-CON-01 | The .NET implementation is an API backend. A separate MVC/Razor/Blazor course UI is [TO BE CONFIRMED]. |
| WEB-CON-02 | DB submodule absent/uninitialized; exact SQL DDL/seed and live migration state [TO BE CONFIRMED]. Local EF/migrations are the available evidence. |
| WEB-CON-03 | Live merchant keys, public webhook, SMTP and deployment URLs are environment dependencies. No financial transaction or email was initiated for documentation. |
| WEB-CON-04 | Physical OS/device acceptance, signing/store release, SLA, backup retention and load targets [TO BE CONFIRMED]. Platform scaffolding is not a compatibility certificate. |
| WEB-CON-05 | Android emulator gateway defaults to http://10.0.2.2:5000; other local targets http://localhost:5000. Phones need reachable API_BASE_URL; ADMIN_URL/CUSTOMER_URL/PAYMENT_RETURN_URL depend on deployment. |

## 24. Out of Scope

Exclude native-only device work, store distribution and a hypothetical .NET-rendered UI. Native phone check-in belongs to Mobile; browser camera check-in belongs here.

No implemented FCM push or automatic bank-refund integration is claimed. Payroll, inventory and AI recommendations are not added. Existing concessions, promotions/voucher codes, membership/loyalty and reviews remain in scope where actually exposed by code.

## 25. Future Enhancements

| ID | Future work, not a current FR | Reason |
| --- | --- | --- |
| WEB-FUT-01 | Load more owned-ticket pages | Only first 50 currently returned to UI |
| WEB-FUT-02 | FCM push if approved | Current notifications are email/API history |
| WEB-FUT-03 | Automated refund if a suitable provider is chosen | Current flow records an external manual transfer |

## 26. Conclusion

This specification allocates one system to the course/client boundary, preserves language parity and makes API-only functions, shared dependencies and unverified gaps explicit. It supports test-case design and explanation of the actual implementation.

## 27. Implemented vs Requirement

Status vocabulary: Implemented; Partially Implemented; UI Only; Mock Data; Backend Pending; Not Implemented; To Be Confirmed. Only applicable statuses are used. Production dependencies use AppDependencies.remote; test fakes are not production mock data.

| Feature | SRS Requirement | Code Status | API Status | Notes |
| --- | --- | --- | --- | --- |
| Register | WEB-FR-AUTH-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Sign in | WEB-FR-AUTH-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| JWT claims | WEB-FR-AUTH-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Validate JWT | WEB-FR-AUTH-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Authorize roles | WEB-FR-AUTH-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Unauthenticated and forbidden responses | WEB-FR-AUTH-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Verify email OTP | WEB-FR-AUTH-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Repeat unverified registration | WEB-FR-AUTH-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Recover password | WEB-FR-AUTH-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Refresh and sign out | WEB-FR-AUTH-10 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Current account | WEB-FR-AUTH-11 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Lock and role-change enforcement | WEB-FR-AUTH-12 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Account field validation | WEB-FR-AUTH-13 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Authentication rate limits | WEB-FR-AUTH-14 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Find member by phone | WEB-FR-AUTH-15 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Edit profile | WEB-FR-AUTH-16 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Change current password | WEB-FR-AUTH-17 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| List accounts | WEB-FR-USER-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Account details | WEB-FR-USER-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create account | WEB-FR-USER-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Change account roles | WEB-FR-USER-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Lock and unlock | WEB-FR-USER-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| List roles | WEB-FR-USER-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Paged catalogue | WEB-FR-MOV-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Movie details | WEB-FR-MOV-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Title search | WEB-FR-MOV-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Active catalogue | WEB-FR-MOV-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create movie | WEB-FR-MOV-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Edit and reactivate movie | WEB-FR-MOV-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Deactivate movie | WEB-FR-MOV-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Open trailer | WEB-FR-MOV-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Age rating | WEB-FR-MOV-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Now showing and coming soon | WEB-FR-MOV-10 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Director and cast | WEB-FR-MOV-11 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Movie reviews | WEB-FR-MOV-12 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Find rooms | WEB-FR-ROOM-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Room details | WEB-FR-ROOM-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create room and seats | WEB-FR-ROOM-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Rename room | WEB-FR-ROOM-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Delete eligible room | WEB-FR-ROOM-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Generate seats | WEB-FR-SEAT-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Seat details | WEB-FR-SEAT-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Read room map | WEB-FR-SEAT-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Delete seat API | WEB-FR-SEAT-04 | Implemented | Controller exists; runtime unverified | API only; no dedicated current UI action. |
| Change seat type | WEB-FR-SEAT-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Paint seat types | WEB-FR-SEAT-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Change capacity | WEB-FR-SEAT-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Protect scheduled rooms | WEB-FR-SEAT-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Refresh management maps | WEB-FR-SEAT-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| List showtimes | WEB-FR-SHOW-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create showtime | WEB-FR-SHOW-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Showtime and prices | WEB-FR-SHOW-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Edit showtime | WEB-FR-SHOW-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Cancel showtime | WEB-FR-SHOW-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Open future showtimes | WEB-FR-SHOW-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Showtimes by movie | WEB-FR-SHOW-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Bookable movie showtimes | WEB-FR-SHOW-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Date range search | WEB-FR-SHOW-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Open and close sales | WEB-FR-SHOW-10 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Reject overlap | WEB-FR-SHOW-11 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Showtime seat/customer map | WEB-FR-SHOW-12 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Screening format | WEB-FR-SHOW-13 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Hold booking | WEB-FR-BOOK-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Booking details | WEB-FR-BOOK-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Management booking search | WEB-FR-BOOK-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Own ticket history | WEB-FR-BOOK-04 | Partially Implemented | Controller exists; runtime unverified | Only the first 50 tickets are loaded; older tickets are missing from the UI. |
| Confirm paid booking | WEB-FR-BOOK-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Cancel booking | WEB-FR-BOOK-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Occupied seat IDs | WEB-FR-BOOK-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Concurrent seat conflict | WEB-FR-BOOK-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Sweetbox pair | WEB-FR-BOOK-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Expire unpaid hold | WEB-FR-BOOK-10 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Refresh customer map | WEB-FR-BOOK-11 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Showtime booking statistics | WEB-FR-BOOK-12 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Concessions with tickets | WEB-FR-BOOK-13 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Concessions administration | WEB-FR-BOOK-14 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Promotion and voucher | WEB-FR-BOOK-15 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Promotion administration | WEB-FR-BOOK-16 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Membership points | WEB-FR-BOOK-17 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Member administration | WEB-FR-BOOK-18 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Share and calendar | WEB-FR-BOOK-19 | Partially Implemented | Controller exists; runtime unverified | Calendar uses actual show end or a 150-minute fallback; sharing falls back to clipboard. |
| Create/reuse PayOS link | WEB-FR-PAY-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Verify PayOS | WEB-FR-PAY-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Payment details | WEB-FR-PAY-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Own payment history | WEB-FR-PAY-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Payments by booking | WEB-FR-PAY-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Refund access | WEB-FR-PAY-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Signed webhook | WEB-FR-PAY-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Late payment | WEB-FR-PAY-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Management payments | WEB-FR-PAY-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Revenue summary | WEB-FR-PAY-10 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Automatic payment polling | WEB-FR-PAY-11 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create refund request | WEB-FR-REF-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Management refund list | WEB-FR-REF-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Record completed transfer | WEB-FR-REF-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Reject refund | WEB-FR-REF-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Reopen rejected refund | WEB-FR-REF-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Own refund status | WEB-FR-REF-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Unique refund per payment | WEB-FR-REF-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Create counter sale | WEB-FR-POS-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Counter checkout | WEB-FR-POS-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Cash and change | WEB-FR-POS-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Bank-transfer QR | WEB-FR-POS-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Switch transfer to cash | WEB-FR-POS-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Retain counter email | WEB-FR-POS-06 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Print and admit | WEB-FR-POS-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Reopen paid ticket | WEB-FR-POS-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Ticket QR | WEB-FR-CHK-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Lookup ticket code | WEB-FR-CHK-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Check-in validation | WEB-FR-CHK-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Camera/manual scanner | WEB-FR-CHK-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Display check-in time | WEB-FR-CHK-05 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Notification history | WEB-FR-NOTI-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Compose booking message | WEB-FR-NOTI-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Send/retry message | WEB-FR-NOTI-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Notification details | WEB-FR-NOTI-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Delete notification API | WEB-FR-NOTI-05 | Implemented | Controller exists; runtime unverified | API only; no dedicated current UI action. |
| Event emails | WEB-FR-NOTI-06 | Partially Implemented | Controller exists; runtime unverified | Event deduplication exists; SMTP/DB crash window prevents absolute exactly-once delivery. |
| OTP and welcome email | WEB-FR-NOTI-07 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Showtime reminder | WEB-FR-NOTI-08 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Read/unread notifications | WEB-FR-NOTI-09 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Today totals | WEB-FR-DASH-01 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Live showtime board | WEB-FR-DASH-02 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Staff attention queue | WEB-FR-DASH-03 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Admin monthly overview | WEB-FR-DASH-04 | Implemented | Controller exists; runtime unverified | Static implementation evidence; runtime acceptance not executed. |
| Route guards and recovery | WEB-FR-NAV-01 | Implemented | Client/platform; no dedicated API | Static implementation evidence; runtime acceptance not executed. |
| Loading, error and empty states | WEB-FR-STATE-01 | Partially Implemented | Client/platform; no dedicated API | State widgets exist; exhaustive device/error-path verification was not run. |
| Platform-specific movie media | WEB-FR-MEDIA-01 | Implemented | Controller exists; runtime unverified | Web preview and poster fallback exist; autoplay depends on browser. |

| Feature | SRS Requirement | Code Status | API Status | Notes |
| --- | --- | --- | --- | --- |
| .NET-rendered UI | WEB-CON-01 | Not Implemented | Existing ASP.NET API | Flutter Web UI only; course necessity [TO BE CONFIRMED] |
| FCM push | WEB-FUT-02 | Not Implemented | — | Future work, not accepted current FR |
| DB submodule SQL verification | WEB-CON-02 | To Be Confirmed | Local EF mappings exist | Submodule uninitialized; no live DB check |

## 28. Evidence and source reconciliation

| Evidence | Use / reconciliation |
| --- | --- |
| [docs/SRS_EN.md](../docs/SRS_EN.md); [docs/SRS_VI.md](../docs/SRS_VI.md) | 125 legacy FR rows per language, scoped with suffix IDs; NAV/STATE/MEDIA refine code behaviour |
| [Cinema_BE/Cinema_Microservice_SRS_Complete.md](../Cinema_BE/Cinema_Microservice_SRS_Complete.md) | Historical six-service intent; current three services take precedence |
| [README.md](../README.md); [Cinema_Mobile/README.md](../Cinema_Mobile/README.md); [DEMO.md](../DEMO.md) | Actual entry points/setup, no separate .NET UI |
| [Cinema_Mobile/lib/app/routes/app_router.dart](../Cinema_Mobile/lib/app/routes/app_router.dart); [Cinema_Mobile/lib/admin/admin_router.dart](../Cinema_Mobile/lib/admin/admin_router.dart) | Channel routes/role guards; native management only check-in |
| [Cinema_Mobile/lib/app/app_dependencies.dart](../Cinema_Mobile/lib/app/app_dependencies.dart); [Cinema_Mobile/lib/core/network/api_client.dart](../Cinema_Mobile/lib/core/network/api_client.dart) | Remote dependencies, 15-second timeout, refresh and public-session probe |
| [Cinema_BE/ApiGateway/ApiGateway/appsettings.json](../Cinema_BE/ApiGateway/ApiGateway/appsettings.json) | Actual route policies/rates/health; old prose route count is stale |
| [.github/workflows/ci.yml](../.github/workflows/ci.yml); [.github/workflows/flutter.yml](../.github/workflows/flutter.yml) | Declared CI; Flutter pin 3.47.4 supersedes older environment prose; old test counts are unverified current totals |
| [Cinema_Mobile/lib/core/widgets/trailer_preview_stub.dart](../Cinema_Mobile/lib/core/widgets/trailer_preview_stub.dart); [Cinema_Mobile/lib/core/widgets/trailer_player_native.dart](../Cinema_Mobile/lib/core/widgets/trailer_player_native.dart) | Native preview stub is empty; full trailer opens externally |
| [Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart](../Cinema_Mobile/lib/features/booking/widgets/ticket_share_actions.dart) | Calendar end fallback 150 minutes, not unconditional exact show end |
| [Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs](../Cinema_BE/BookingService/BookingService/Services/Implementations/NotificationService.cs) | Event deduplication and non-atomic SMTP/DB delivery; no absolute exactly-once claim |

Review inventory: 763 files enumerated; 594 relevant text/code/configuration files indexed, including approximately 64,397 C#/Dart lines. Generated build/cache/vendor folders, binary media, encrypted secret payloads and missing DB-submodule contents are excluded from functional evidence. No secret values are reproduced.
