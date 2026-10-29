from pathlib import Path
import json, hashlib, subprocess

ROOT = Path(__file__).resolve().parents[2]
PREAMBLE = r'''\documentclass[conference]{IEEEtran}
\usepackage[T1]{fontenc}
\usepackage{cite,amsmath,amssymb,graphicx,booktabs,array,tabularx}
\usepackage{tikz}
\usetikzlibrary{arrows.meta,positioning,fit}
\usepackage{listings}
\usepackage[hyphens]{url}
\usepackage[hidelinks]{hyperref}
\urlstyle{same}
\newcolumntype{Y}{>{\raggedright\arraybackslash}X}
\lstset{basicstyle=\ttfamily\scriptsize,breaklines=true,columns=fullflexible,
 frame=single,aboveskip=6pt,belowskip=6pt,showstringspaces=false}
\tikzset{box/.style={draw,rounded corners=1pt,align=center,font=\scriptsize,
 minimum height=7mm,text width=25mm},arr/.style={-{Latex[length=1.5mm]},thin}}
\newcommand{\code}[1]{\texttt{#1}}
\hyphenation{PostgreSQL RabbitMQ PayOS Flutter}
\begin{document}
'''
AUTHORS = r'''\author{
\IEEEauthorblockN{Nguyen Nguyen Ngu (QE190064), Dao Thi Thanh Huong (QE190046),\\
Pham Ngo Bich Tram (QE1900100), Nguyen Hoang Ngoc Chau (QE190088),\\
Nguyen Xuan Dang Khoa (QE1900126)}
\IEEEauthorblockA{Student Developers, Class: SEK19B.Net\\
Department of Software Engineering\\
FPT University Quy Nhon Campus, Binh Dinh, Vietnam}
\IEEEauthorblockN{Huynh Vang}
\IEEEauthorblockA{Project Advisor, Lecturer, Department of Software Engineering\\
FPT University Quy Nhon Campus, Binh Dinh, Vietnam\\
vangh@fe.edu.vn}}
\maketitle
'''
ACK = r'''\section*{Acknowledgment}
The student developers thank Mr. Huynh Vang, Department of Software Engineering,
FPT University Quy Nhon Campus, for his guidance as project advisor and for
supporting the team's software engineering work on CosmoQ Cinema.
\bibliographystyle{IEEEtran}
\bibliography{references}
\end{document}
'''

REPO = 'https://github.com/PRM393-Cinema/Cinema'
REV = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
DBREV = subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT/'Project-Cinema-DB',text=True).strip()
refs = []
for key,title,folder in [
 ('client','Flutter client entry points, routing, session state, and API adapters','Cinema_Mobile/lib'),
 ('webui','Customer browser layout and administration workflows','Cinema_Mobile/lib/features'),
 ('auth','Authentication, account validation, JWT generation, and user management','Cinema_BE/AuthService/AuthService'),
 ('gateway','Gateway policies, reverse proxy, and account-status middleware','Cinema_BE/ApiGateway/ApiGateway'),
 ('movie','Movie, room, showtime, and seat-pricing implementation','Cinema_BE/MovieService/MovieService'),
 ('booking','Booking, payment, refund, loyalty, notification, and messaging implementation','Cinema_BE/BookingService/BookingService'),
 ('deployment','Compose deployment and database initialization scripts','Cinema_BE'),
 ('tests','Backend tests and Flutter verification workflows','.'),
]:
    refs.append('@misc{%s,\n author={{CosmoQ Cinema Student Developers}},\n title={{%s}},\n howpublished={Repository source, revision %s, \\url{%s/tree/%s/%s}},\n note={Inspected Oct. 28, 2026}\n}\n' % (key,title,REV[:12],REPO,REV,folder))
refs.append('@misc{db, author={{CosmoQ Cinema Student Developers}}, title={{Cinema database SQL schemas and migrations}}, howpublished={Repository source, revision '+DBREV[:12]+r', \url{https://github.com/PRM393-Cinema/Project-Cinema-DB/tree/'+DBREV+'}}, note={Inspected Oct. 28, 2026}}\n')
for key,author,title,url in [
 ('flutter','Flutter','Architecting Flutter apps','https://docs.flutter.dev/app-architecture'),
 ('fluttertest','Flutter','Testing Flutter apps','https://docs.flutter.dev/testing/overview'),
 ('jwt','Microsoft','Configure JWT bearer authentication in ASP.NET Core','https://learn.microsoft.com/en-us/aspnet/core/security/authentication/configure-jwt-bearer-authentication'),
 ('npgsql','Npgsql','Npgsql Entity Framework Core provider','https://www.npgsql.org/efcore/'),
 ('postgres','PostgreSQL Global Development Group','PostgreSQL 17: Constraints','https://www.postgresql.org/docs/17/ddl-constraints.html'),
 ('rabbit','RabbitMQ','Consumer acknowledgements and publisher confirms','https://www.rabbitmq.com/docs/confirms'),
 ('payos','payOS','payOS API','https://payos.vn/docs/api/'),
 ('storage','flutter\_secure\_storage Maintainers','flutter\_secure\_storage 11.2.0','https://pub.dev/packages/flutter_secure_storage'),
]:
    refs.append('@misc{%s, author={{%s}}, title={{%s}}, howpublished={\\url{%s}}, note={Accessed Oct. 28, 2026}}\n'%(key,author,title,url))
BIB='\n'.join(refs)

def save(kind,title,abstract,terms,body):
    p=ROOT/'docs'/('ieee-'+kind)
    (p/'figures').mkdir(parents=True,exist_ok=True)
    (p/'main.tex').write_text(PREAMBLE+'\\title{'+title+'}\n'+AUTHORS+'\\begin{abstract}\n'+abstract+'\n\\end{abstract}\n\\begin{IEEEkeywords}\n'+terms+'\n\\end{IEEEkeywords}\n'+body+ACK,encoding='utf-8')
    (p/'references.bib').write_text(BIB,encoding='utf-8')

WEB = r'''
\section{Introduction}
Cinema ticketing couples a customer-facing purchase with operational tasks such
as maintaining schedules, allocating seats, collecting payments, and admitting
customers. A booking interface must therefore coordinate information that can
change between browsing a show and completing checkout. A seat visible as free
is not necessarily still available when a customer submits an order. Likewise,
a browser returning from a payment page is not sufficient evidence that the
cinema has received money. These are the concrete coordination problems
addressed by the inspected CosmoQ implementation, rather than measured claims
about the shortcomings of a particular cinema's previous process.

CosmoQ Cinema implements customer booking and cinema-management workflows
through Flutter browser applications and an ASP.NET Core backend. This paper
examines the Web system: the customer application built from \code{main.dart}
and the administration application built from \code{main\_admin.dart}. They are
distinct entry points in one Flutter source project, not independently verified
frontend repositories. A mobile build shares customer code and backend APIs,
but its platform behavior is outside the primary scope of this paper.
Repository evidence, including source-level dependencies and SQL, establishes
the implementation described here \cite{client,webui,deployment,db}.

The engineering contribution is an integration of browser navigation, role-aware
management interfaces, server-priced bookings, transactional seat reservations,
and payment reconciliation. Supporting modules include concessions, promotions,
loyalty balances, customer reviews, ticket check-in, and notification records.
These capabilities are assessed at the implementation level; their presence does
not establish a production deployment or a successful live financial transaction.
The work does not claim a new booking algorithm or a performance improvement over
other ticketing systems.

\subsection{Evidence and Scope}
Inspection used repository revision \code{55642353331f} and database submodule
revision \code{e455d297c76b}, retrieved on October 28, 2026. Manifests,
entry points, controllers, services, repositories, entity mappings, SQL,
platform configuration, tests, and CI definitions were cross-checked. Existing
requirements documents served as navigation aids rather than proof that a
feature works. Official framework references explain the technologies, while
repository references substantiate CosmoQ-specific behavior.

The analysis distinguishes implemented source, mocked test dependencies,
configured external integrations, and behavior not executed during this review.
In particular, a test using a fake PayOS client cannot validate a merchant
account, banking settlement, or public webhook delivery. Section VII reports
the checks actually executed and their limits.

\section{System Architecture Overview}
\subsection{Deployment Units and Communication}
Figure~\ref{fig:architecture} summarizes the verified Web topology. Browser
requests use JSON over HTTP through a YARP gateway. AuthService manages identity;
MovieService contains movie and showtime/room functionality; BookingService
contains booking, payment, notification, and related business services. Each is
an ASP.NET Core executable. Their separate Compose service definitions and
inter-service HTTP/event communication support describing the backend as a
service-based deployment. This does not imply independently scalable production
infrastructure or a separate service for every business module
\cite{gateway,movie,booking,deployment}.

\input{figures/architecture}

The gateway listens on host port 5000 in Compose. Backend and infrastructure
debug ports are generally bound to loopback, while the gateway is accessible
from the network. Route-to-cluster configuration selects the destination
service; downstream failures are translated into structured 503 or 504 responses.
BookingService calls MovieService for authoritative showtime and seat data,
forwarding the acting user's bearer token. RabbitMQ carries business events
after local transactions commit. Browser clients do not connect directly to
PostgreSQL or RabbitMQ \cite{gateway,booking,deployment}.

\subsection{Technology and Repository Organization}
Table~\ref{tab:stack} identifies technologies confirmed by dependencies and
active code. The installed verification SDK is Flutter 3.47.2 with Dart 3.13.2;
the Flutter CI workflow instead requests version 3.47.4. This is a reproducibility
distinction, not evidence that either version was used for a released website.
Backend projects target \code{net8.0}; the local build host uses .NET SDK 9.0.305.
\begin{table}[t]
\caption{Verified Web Technology Stack}\label{tab:stack}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
Component & Technology & Responsibility\\\midrule
Browser UI & Flutter, Dart, Material & Customer and administration views\\
Client API & Dart \code{http} & JSON requests and bearer tokens\\
Gateway & ASP.NET Core 8, YARP 2.3.0 & Routing and request policies\\
Backend & ASP.NET Core 8 & Controllers and business services\\
Persistence & EF Core 8, Npgsql; PostgreSQL 17 image & Mappings and SQL databases\\
Events & RabbitMQ.Client 7.2.1 & Outbox publication and consumers\\
Payment & PayOS HTTP integration & Checkout links and reconciliation\\
Operations & Docker Compose; OpenTelemetry & Local topology and telemetry\\\bottomrule
\end{tabularx}
\end{table}

The Flutter \code{lib} tree separates \code{app}, \code{admin}, \code{core},
\code{data}, and feature-oriented directories. \code{AppDependencies.remote}
constructs real service adapters, repositories, secure token storage, and a
token manager. Backend services register controller, business-service,
repository, and EF Core dependencies explicitly. Interface-backed repositories
are present, but a uniform Clean Architecture or domain-driven design is not
established by this organization. Flutter's architecture guidance provides
context for separation of UI and data access \cite{flutter}; CosmoQ's actual
dependency construction remains the relevant evidence \cite{client}.

\subsection{Persistence Boundaries}
Compose initializes six databases on one PostgreSQL instance:
\code{cinema\_auth\_db}, \code{cinema\_movie\_db},
\code{cinema\_showtime\_db}, \code{cinema\_booking\_db},
\code{cinema\_payment\_db}, and \code{cinema\_notification\_db}.
MovieService owns two EF contexts and BookingService owns three. Thus six
database names do not imply six backend executables. Npgsql supplies the EF
Core provider \cite{npgsql}; source registration selects each database
\cite{auth,movie,booking,deployment}.

\section{Backend Design and Implementation}
\subsection{Identity and Access Services}
AuthService implements registration, email verification, login, refresh,
logout, profile changes, password changes, and administrative account operations.
Passwords and OTP values are hashed with BCrypt. JWT generation uses
HMAC-SHA256 and includes user identity and role claims. Refresh tokens are
generated from 64 cryptographically random bytes, stored in the authentication
database, and revoked when rotated. A logout revokes the supplied refresh token;
it is not described here as an instantaneous blacklist of every previously
issued access token \cite{auth}.

JWT validation checks issuer, audience, signature, and lifetime. Gateway policies
and downstream controller policies restrict privileged actions. Protected
gateway requests also query AuthService's current-account endpoint. Disabled
accounts are refused, and a mismatch between current roles and token roles
returns a role-change error. Failure to perform that check returns 503 rather
than forwarding an unchecked protected request \cite{gateway}. These are
concrete bearer-token mechanisms consistent with the ASP.NET Core model
\cite{jwt}, not a claim of OAuth/OpenID Connect federation.

\subsection{Catalog and Schedule Support}
MovieService provides movie browsing, detail retrieval, genres, title search,
and administrative editing. Its showtime code validates room membership of
requested seats, rejects shows that are not open or have started, and enforces
paired sweetbox selection when a partner exists. Seat prices derive from the
showtime price, presentation-format surcharge, and seat-type surcharge.
Room, seat, and schedule APIs support management screens rather than requiring
the browser to manipulate database records \cite{movie,webui}.

Showtime creation checks start/end ordering and room schedule conflicts through
the repository. Cancellation records a business event in the showtime database
outbox; BookingService consumes it to process affected bookings. These checks
show implemented business validation. They do not establish that all possible
concurrent administrative schedule edits have been tested in this environment.

\subsection{Booking Transactions and Seat Contention}
The booking controller derives the customer ID and email from authenticated
claims for self-service purchases. The service rejects duplicate seat IDs,
requests server-side seat prices, and calculates concessions from the active
menu. It loads showtime timing for later cancellation policy decisions. The
movie title normally comes from MovieService, although the code retains a
request-title fallback if no title is returned; therefore it would be inaccurate
to claim that every display field is exclusively server-derived \cite{booking}.

Inside a PostgreSQL transaction, the service locks existing reservation rows
with \code{FOR UPDATE}. It rejects booked seats and unexpired holds. For a new
seat/showtime pair, the SQL constraint \code{uq\_seat\_per\_showtime} supplies
the conflict boundary when no row yet exists to lock. A unique-violation catch
rolls the transaction back and returns a conflict. The booking, seat snapshots,
holds, and outbox event are committed together. This supports a specific
concurrency mechanism, not an unrestricted claim that duplicate bookings can
never occur under any failure mode \cite{booking,db,postgres}.

Listing~\ref{lst:seat} reproduces the relevant EF mapping. The database schema
contains the corresponding unique constraint. UI disabling alone would not
provide this protection; simultaneous browser sessions can submit the same
selection despite a recently refreshed map.
\begin{lstlisting}[caption={Reservation uniqueness mapping from BookingDbContext.},label={lst:seat}]
entity.HasIndex(e => new { e.ShowtimeId, e.SeatId }, "uq_seat_per_showtime").IsUnique();
\end{lstlisting}

\subsection{Database Model and Relationships}
Figure~\ref{fig:data} shows a selected, verified relational subset. Solid edges
represent declared SQL foreign keys; dashed edges denote application-level ID
references across database boundaries. Authentication uses users, roles, a join
table, refresh tokens, and OTP records. Showtime storage relates rooms to seats
and showtimes. Booking storage keeps ticket-seat price snapshots and
concession lines. Payments relate to refunds within their own database
\cite{db,booking}.
\input{figures/data}

Cross-database references such as a payment's booking ID are not PostgreSQL
foreign keys in the supplied schema. The reservation's booking ID is also not
declared as an SQL foreign key in the inspected base script. These distinctions
matter when discussing consistency: asynchronous handlers and application checks
coordinate business records, while database constraints cover only their
defined local scope. The figure is deliberately a partial ERD, not a claim to
reproduce every table or every entity-mapping detail.

Initialization SQL and incremental migrations are kept in the database
submodule. Compose mounts those files and runs an initialization script for
an empty volume, followed by a migration job. Additional SQL under the backend
tree updates movie metadata and reviews. The migration script excludes selected
demo-seeding migrations. This inspected path uses SQL scripts; no claim is made
that EF migration history governs the deployed schema \cite{deployment,db}.

\subsection{Payments and Event Delivery}
The PayOS adapter creates checkout links, queries orders, and cancels links.
It sends merchant headers and signs creation payloads with HMAC-SHA256.
Webhook handling validates the data signature before using fields, matches
the payment order and amount, and records the successful payment. A later
booking-confirmation conflict can initiate a refund request. These operations
are integrated in source; live merchant delivery was not exercised
\cite{booking,payos}.

Outbox publishers read unpublished events with \code{FOR UPDATE SKIP LOCKED},
publish persistent messages with publisher confirmations, and record publication
state. Consumers handle booking cancellation, payment/refund changes, email
notifications, and showtime cancellation. Event identifiers and uniqueness checks
support duplicate handling. This follows an at-least-once delivery approach:
a broker publish and database publication marker are not a single distributed
transaction. RabbitMQ confirms are useful evidence of broker acceptance, not
proof of exactly-once business effects or exactly-once email delivery
\cite{booking,rabbit}.

\section{Web Application Architecture and Implementation}
\subsection{Entry Points and Browser Navigation}
Both entry points restore a stored session before constructing their application.
The customer router maps named paths to movie, showtime, booking, payment,
notification, and account screens. Authentication-required routes redirect to
login while retaining a pending destination. Detail routes accept an identifier
and can reload their data when no in-memory navigation argument exists.
This is particularly relevant to browser refresh and shared links
\cite{client}.

The administration router classifies routes as public, staff, or admin. It
checks roles before creating protected pages. This improves navigation but is
not the security boundary: the backend independently authorizes management
operations. CI defines a customer Web build and a separate admin build using
\code{--base-href /admin/}. The configured build layout is evidence of packaging,
not proof that a hosting environment serves both correctly \cite{client,tests}.

\begin{table}[t]
\caption{Representative Browser Screens and Routes}\label{tab:routes}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
View & Route or entry & Responsibility\\\midrule
Customer home & \code{/home} & Browse and filter movies\\
Movie details & \code{/movies/\{id\}} & Metadata, reviews, showtimes\\
Seats & \code{/showtimes/\{id\}/seats} & Selection and availability\\
Booking detail & \code{/bookings/\{id\}} & Ticket and booking state\\
Payment & \code{/bookings/\{id\}/payment} & Checkout and reconciliation\\
Movie management & \code{/admin/movies} & Admin catalog editing\\
User management & \code{/admin/users} & Account and role operations\\
Staff workspace & \code{main\_admin.dart} & Counter sales and operations\\\bottomrule
\end{tabularx}
\end{table}

\subsection{State and API Abstractions}
\code{SessionState} extends \code{ChangeNotifier}; an
\code{InheritedNotifier} exposes authentication, the current user, and unread
notification count. Screens otherwise maintain local state for loading,
selection, filters, and errors. No evidence requires labeling this state system
as Bloc, Riverpod, or Redux. Repositories translate screen requests into
service calls; the shared API client handles JSON, timeouts, bearer headers,
and structured errors \cite{client}.

An authenticated 401 can trigger one refresh and a retry. Concurrent callers
share a pending refresh future to avoid independently rotating the same token.
Network failures retain the session where possible, whereas invalid refresh
credentials or account-status errors clear it. \code{SessionApp} then replaces
navigation with sign-in and displays the reason. These details connect the API
layer to visible browser behavior instead of relying on route guards alone.

\subsection{Responsive Presentation and Reuse}
The layout utility switches the main desktop arrangement at 900 logical pixels.
Wide customer pages use a top navigation frame; narrower layouts retain the
application-style bottom navigation. Shared width constraints distinguish forms,
reading views, and wide pages. \code{ResponsiveColumns} uses a separate local
constraint threshold, defaulting to 820 pixels, to stack a sidebar below content.
Consequently, there is not one universal breakpoint for every component
\cite{client,webui}.

Theme files define colors, spacing, radii, and typography; common components
provide buttons, panels, network-image fallbacks, loading, empty, and error
states. Web-specific trailer implementations and counter-ticket printing use
browser facilities through conditional imports. This is verified platform
branching, not evidence that all browsers or assistive technologies were
evaluated. Table~\ref{tab:modules} summarizes the main functional divisions.

\begin{table}[t]
\caption{Major Web Functional Modules}\label{tab:modules}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
Module & Implemented responsibility & Principal layers\\\midrule
Catalog & Browse, details, genres, trailers & Flutter; MovieService\\
Booking & Seats, summary, history, QR ticket & Flutter; BookingService\\
Checkout & PayOS link and status checks & Flutter; payment service\\
Counter & Walk-in booking and cash payment & Admin UI; booking/payment APIs\\
Management & Movies, rooms, schedules, users & Admin UI; authorized services\\
Retention & Promotions, points, reviews & Client views; booking database\\
Notifications & Lists, read state, email records & Flutter; event handlers\\\bottomrule
\end{tabularx}
\end{table}

\section{Core Business Workflows}
\subsection{Discovery to Reservation}
The home screen requests now-showing or coming-soon data, genre filters, and
title search. Search input is debounced by 350 milliseconds in source.
Movie details retrieve open showtimes; the catalog repository bounds customer
schedule selection to a seven-day window and can fetch subsequent pages while
that window is relevant. Room seats and occupied seat IDs are requested in
parallel and combined into a client map \cite{client,webui}.

Selection is initially local. Every five seconds, the seat screen attempts to
refresh availability while it is current; seats no longer free are removed
from the local selection, including paired-seat adjustments. Submitting the
summary creates the backend hold described in Section III. A conflict still
requires the customer to choose again. The repository therefore implements
polling plus transactional reservation, rather than a SignalR or WebSocket
seat-lock channel \cite{client,booking}.

\subsection{Pricing and Checkout}
For ticket subtotal $S$, applicable promotion discount $D$, concession subtotal
$C$, and redeemed loyalty points $q$, the booking code computes
\begin{equation}
T = S-D+C-1000q .\label{eq:price}
\end{equation}
The loyalty helper restricts redemption to at most
$\lfloor 0.5(S-D+C)/1000\rfloor$ points, additionally bounded by the customer's
balance. Promotion calculation caps the discount at 90\% of ticket value and
rounds it down to a 1,000-VND increment. These are implementation constants,
not measured economic outcomes \cite{booking}.

Figure~\ref{fig:flow} summarizes checkout. The payment page opens the returned
PayOS URL and displays the booking's expiry. It polls booking state every five
seconds and invokes provider verification every sixth eligible poll. Browser
return parameters identify an order to verify; the backend remains responsible
for deciding payment success. A timer or a successful redirect alone does not
confirm the ticket \cite{client,booking}.
\input{figures/flow}

\subsection{Confirmation, Cancellation, and Operations}
Confirmed bookings expose history/detail views and QR ticket content. Customers
can request cancellation subject to server policy; the default paid-booking
cutoff is two hours before the show. A customer refund request sets
\code{REFUND\_PENDING} and retains seats until the refund decision. Staff
complete or reject refund processing through privileged APIs. The code records
manual transfer references; it does not implement an automatic banking refund
through a PayOS refund endpoint \cite{booking,webui}.

Staff workflows include counter booking, cash collection, booking lookup,
check-in, showtime operations, payment records, and notification handling.
Admin screens additionally manage movies, rooms, users, concessions,
promotions, and membership data. These are source-backed screen-to-service
paths, not a claim that every management path was manually exercised. Check-in
requires an eligible paid booking and a server-configured time window;
repeated admission is rejected by business logic \cite{booking,webui}.

\section{Security and Data Protection}
\subsection{Trust Boundaries}
Role-based routing is paired with gateway and service authorization. Booking
reads compare ownership for non-management users, and self-service creation
overwrites user identity from claims. Server pricing avoids trusting a browser's
seat or concession totals. Webhook signature validation rejects malformed or
tampered provider data before booking confirmation. Password validation also
accounts for BCrypt's input-length boundary \cite{auth,gateway,booking}.

\subsection{Browser Storage and Configuration}
The client actively uses \code{flutter\_secure\_storage} for access/refresh
tokens and user metadata. Writes are sequential, with a source comment
explaining first-write key creation on Web. Unreadable storage clears local
credentials. This establishes the chosen storage abstraction, not an
application-level guarantee against script execution or browser compromise.
The package documents HTTPS or localhost requirements for its Web backend
\cite{client,storage}.

Gateway CORS uses configured origins when present, but falls back to allowing
any origin if the list is empty. Fixed-window IP rate limits include a separate
authentication policy and return 429 responses. Compose passes secrets via
environment variables; the review did not open or publish credential values.
The supplied local topology exposes HTTP, so TLS termination is a deployment
requirement to verify, not an observed property of a live website. Seed
accounts and demonstration data should not be treated as a production identity
baseline \cite{gateway,deployment,db}.

\section{Testing, Verification, and Evaluation}
\subsection{Method and Observed Results}
Verification was performed on October 28, 2026. Table~\ref{tab:tests} separates
successful checks from environmental blocks and external operations that were
not attempted. No response-time, load, availability, coverage, or usability
metrics were collected. Build success demonstrates compilation, while unit and
widget results support only the exercised assertions \cite{tests,fluttertest}.
\input{verification-table}

The 17 isolated BookingService tests exercise signature handling and email
templates. The 21 gateway tests exercise request policy and failure behavior
with test infrastructure. Neither total should be interpreted as a live
deployment acceptance count. AuthService compiled without warnings; MovieService
compiled with four nullable-analysis warnings. BookingService and ApiGateway
compiled as part of their successful test runs.

\subsection{Test Doubles and Missing Runtime Evidence}
Booking integration fixtures use PostgreSQL Testcontainers and optionally a
real RabbitMQ container, but replace MovieService, PayOS, and SMTP with fake
clients. Flutter workflow tests likewise use fake repositories and plugin
substitutes. Their test names describe intended assertions, not evidence of
real merchant payments or actual email delivery \cite{tests}.

Docker's daemon was unavailable during this review, preventing the
container-dependent suites and a complete Compose deployment from being
verified. SQL files and EF mappings were inspected directly, but no live-schema
or migration execution result is claimed. Browser-hosted checkout, external
trailer delivery, printing, and public HTTPS hosting were not manually
validated. These limitations are retained even when a source path and a unit
test exist.

\section{Limitations and Future Development}
\subsection{Current Limitations}
The two browser applications share a Flutter project, so reports of independent
Web and mobile products should not imply independent source ownership. Runtime
availability depends on gateway, identity, data, and messaging services; the
account-status call adds a dependency on AuthService for protected requests.
Polling provides periodic updates rather than immediate server push. Temporary
refresh failures deliberately retain older availability, making the booking
transaction the final arbiter \cite{client,gateway,booking}.

Refund transfer is a staff operation. Notification handling records failed
email sends for staff retry; database deduplication does not make SMTP and
database persistence atomic. Local-time timestamps and legacy Npgsql behavior
are explicitly used, limiting claims about multi-time-zone deployment. The
base SQL includes demonstration payment method labels such as VNPAY and MOMO;
no active integrations for those providers were established by the inspected
payment adapter. Missing runtime evidence and compiler warnings further limit
claims of operational readiness \cite{db,booking,deployment}.

\subsection{Recommendations}
Future work should first execute the container suites and migrations on a
controlled environment, add live provider acceptance checks with safe merchant
test arrangements, and verify browser reloads and payment returns under HTTPS.
Recommendations also include resolving nullable warnings, validating CORS and
secret settings for a named deployment, and testing keyboard/screen-reader
operation and supported browser printing. A push-based availability channel
could be evaluated if polling becomes insufficient; it is not a committed
roadmap item or a feature of the inspected version.

\section{Conclusion}
CosmoQ's Web implementation combines Flutter customer and administration entry
points with a shared ASP.NET Core service backend. Its most substantive
mechanisms are source-backed pricing and ownership checks, transactional seat
holds, payment verification, and event-mediated notification/refund processing.
SQL and entity mappings clarify both local constraints and cross-database
consistency responsibilities. Successful isolated backend checks substantiate
specific implementation properties, while the reported runtime limitations
prevent broader claims about production security, live payments, or capacity.
The resulting system is a documented engineering implementation whose next
evaluation step is controlled end-to-end deployment verification.
'''

MOBILE = r'''
\section{Introduction}
Mobile cinema booking brings discovery, seat choice, payment, and ticket access
into a small-screen interaction. The user may leave the application to pay,
return after the operating system pauses it, or revisit a booking after a
network failure. A client must preserve an understandable distinction between
local selection, a server-held reservation, and a paid ticket. CosmoQ Cinema
addresses these tasks through a Flutter customer application connected to a
shared ASP.NET Core backend \cite{client,booking}.

This paper focuses on the mobile build of the customer entry point in
\code{Cinema\_Mobile}. The repository also builds browser applications, but
their management workspace is not a principal topic here. Platform directories
exist for Android and iOS, as well as desktop targets; directory presence is
not evidence that every platform has been built, signed, deployed, or tested.
The verified source supports discussing a cross-platform implementation while
retaining those distinctions.

The project's engineering contribution is a coordinated customer workflow:
remote catalog data, route-driven screens, recoverable authentication,
server-controlled seat holds, external PayOS checkout, booking history, and QR
ticket presentation. Notification read state, promotions, loyalty points,
reviews, ticket sharing, and a staff check-in path extend that workflow.
The contribution is the integration of these mechanisms in the inspected
project, rather than a novel mobile framework or a measured improvement over
existing cinema applications.

\subsection{Inspection Method and Claim Boundaries}
Source revision \code{55642353331f} and database revision
\code{e455d297c76b} define the inspected snapshot on October 28, 2026.
Inspection traced startup, routes, repositories, HTTP adapters, storage,
platform manifests, backend controllers/services, SQL constraints, tests, and
CI configuration. Requirements documents were not treated as proof of finished
behavior. The technology references explain APIs; repository citations identify
CosmoQ's implementation decisions.

The report separates strong implementation evidence from successful device
execution. Real HTTP repositories are selected by startup, while fake
repositories are used in tests. A source-level PayOS integration is not evidence
that a mobile customer completed a banking transaction. Likewise, use of a
secure-storage package is not a claim that storage and permissions were
validated on every supported operating system. Section VII describes what was
actually compiled, executed, or blocked.

\section{System Architecture Overview}
\subsection{Mobile-to-Service Topology}
The mobile application uses the same public API gateway as the other client
builds. It serializes requests as JSON and adds a bearer token for protected
operations. The gateway forwards requests to AuthService, MovieService, or
BookingService. Backend dependencies include PostgreSQL and RabbitMQ; external
communication includes PayOS HTTP calls and SMTP email. Figure~\ref{fig:architecture}
shows these boundaries from the mobile customer's perspective
\cite{client,gateway,deployment}.
\input{figures/architecture}

There are three domain-service executables plus the gateway. MovieService also
contains showtime and room code; BookingService contains payment and
notification code. These modules are not separate deployed services merely
because they have their own classes or database contexts. The gateway and
services are individually defined in Docker Compose, which provides a local
service-based topology rather than evidence of an operational cloud platform.

\subsection{Verified Technology Stack}
Table~\ref{tab:stack} distinguishes client, backend, and integration technology.
The client uses Material widgets and Dart's asynchronous futures; no active
Bloc or Riverpod implementation was needed to explain its state flow.
Flutter's architecture documentation is relevant context \cite{flutter}, but
the classes actually instantiated by \code{AppDependencies.remote} determine
CosmoQ's behavior \cite{client}.
\begin{table}[t]
\caption{Verified Mobile Technology Stack}\label{tab:stack}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
Component & Technology & Responsibility\\\midrule
Mobile UI & Flutter, Dart, Material & Customer screens and navigation\\
Networking & Dart \code{http} & JSON requests and error handling\\
Session storage & \code{flutter\_secure\_storage} & Persist tokens and user data\\
Platform actions & \code{url\_launcher}, \code{share\_plus} & Checkout, links, sharing\\
Tickets & \code{qr\_flutter}, \code{mobile\_scanner} & QR display and staff scanning\\
Shared backend & ASP.NET Core 8; YARP & Identity, catalog, booking APIs\\
Data access & EF Core 8 and Npgsql & Six PostgreSQL databases\\
Events/payment & RabbitMQ; PayOS & Async follow-up and checkout\\\bottomrule
\end{tabularx}
\end{table}

The locally installed SDK reports Flutter 3.47.2 and Dart 3.13.2, matching the
manifest's Dart range. CI requests Flutter 3.47.4. Backend targets are .NET 8
and the review host uses .NET SDK 9.0.305. These version facts describe the
review and configuration; they do not assert a version for a published mobile
release \cite{tests,client}.

\subsection{Configuration and Data Flow}
\code{ApiConfig} defaults Android's emulator connection to
\code{http://10.0.2.2:5000}; other default targets use localhost. A physical
phone requires an appropriate \code{API\_BASE\_URL} build definition and network
access to the gateway. A payment return URL can also be overridden. Defaults
for local development should not be read as HTTPS deployment evidence
\cite{client,deployment}.

The UI calls repository interfaces, whose remote implementations invoke service
adapters and a shared HTTP client. JSON models hold movies, showtimes, seats,
bookings, payments, notifications, and authentication data. The repositories
combine data when a screen requires more than one backend resource: seat
layout comes from MovieService and occupied IDs from BookingService. This is
client-side composition of server results, not direct database access.

\section{Backend Design and Implementation}
\subsection{Identity as a Mobile Session Dependency}
AuthService supports email registration and OTP verification, login, refresh,
logout, password recovery, and profile/password changes. BCrypt hashes
passwords and OTP values; JWTs carry the user's identity and role claims.
JWT signing is HMAC-SHA256. The refresh flow revokes an accepted old refresh
token before returning new session credentials. Tokens originate in this
service rather than in a social-login or federated identity provider
\cite{auth}.

For the phone, the useful contract is an authentication response followed by
authenticated API requests and recovery from expiry. Issuer, audience,
signature, and lifetime checks occur in gateway/service JWT validation.
Gateway middleware also requests current account status for protected
requests. A locked account or changed roles can therefore invalidate continued
use through the gateway even while a token's timestamp is still valid. An
unreachable status service results in 503, which the mobile client must present
as a service failure rather than a successful action \cite{gateway,jwt}.

\subsection{Catalog and Seat Information}
MovieService supplies browsing, details, genres, and showtime selection. The
showtime implementation checks that selected seats belong to the showtime's
room, the show is open, and its start time is still in the future. Sweetbox
seats are validated as pairs when the partner is defined. These checks run
server-side independently of the phone's selection widgets \cite{movie}.

Seat pricing uses a format surcharge followed by a type surcharge. Normal,
VIP, and sweetbox values are defined in helpers; the resulting seat prices
are returned in server responses and reobtained for booking creation. The
mobile display helps the user understand a total, while the backend supplies
the authoritative amount. This limits trust in stale or manipulated client
inputs without asserting that every possible pricing scenario was device-tested.

\subsection{Reservation Lifecycle}
On booking submission, BookingService validates the request, rejects repeated
seat IDs, prices concessions from its menu, resolves promotions, and applies
permitted loyalty redemption. Customer identity is taken from claims by the
controller. The service records the showtime time received from MovieService;
movie title retrieval includes a request-title fallback if the remote lookup
returns no title \cite{booking}.

The reservation transaction locks existing seat/showtime records with
\code{FOR UPDATE}. It rejects booked seats and active holds, creates a pending
booking with a ten-minute expiry, and associates held seats. The unique
\code{(showtime\_id, seat\_id)} key handles competing inserts when a reservation
row has not existed before. A unique-violation exception is translated into a
conflict response. The phone cannot turn a locally highlighted seat into a
reservation until this transaction succeeds \cite{booking,db,postgres}.

A background expiry worker changes overdue pending bookings and releases their
seat holds. Payment confirmation attempts to transition the booking to a paid
state, while cancellation and refund paths have distinct rules. In particular,
a paid customer cancellation request can become \code{REFUND\_PENDING}; it
does not simply free the seats before the refund decision. This distinction
must remain visible in booking history rather than being reduced to a
client-side Boolean \cite{booking}.

\subsection{Database Design for Mobile Workflows}
SQL initialization creates six databases on the configured PostgreSQL 17
instance. Auth data uses users, roles, a join table, refresh tokens, and OTPs.
Movie data is separate from rooms, seats, and showtimes. Booking data includes
seat snapshots, reservations, concessions, promotions, loyalty records, and
reviews. Payment and notification records have separate contexts/databases.
The Npgsql EF Core provider connects these models to PostgreSQL
\cite{db,booking,npgsql}.

The selected ERD in Fig.~\ref{fig:data} distinguishes SQL foreign keys from
logical ID references. Rooms have declared seat/showtime relationships;
bookings have declared booking-seat relationships; refunds reference payments.
Cross-database user, movie, and booking IDs are application references rather
than SQL-enforced relationships. The reservation's booking ID is not declared
as a foreign key in the inspected base schema. A full mobile workflow therefore
depends on service validation and event processing as well as local constraints.
\input{figures/data}

Schema files and migrations are maintained in the initialized database
submodule, with additional backend SQL updates. The Compose initialization and
migration jobs mount these sources. Inspection verifies intended schema
structure and execution scripts, not successful migration of a running
database. No live data or production credentials were required or inspected
for the relational analysis \cite{deployment,db}.

\subsection{Payment and Asynchronous Follow-Up}
PayOS integration requests checkout links and queries payment status. Creation
includes merchant headers and an HMAC signature. The webhook path validates
the payload signature before trusting fields and checks order/amount against
the saved payment. A verified provider status can also trigger reconciliation
when the customer returns to the app. These source paths avoid equating an
external-browser launch with payment success \cite{booking,payos}.

Payment and booking records are not described as one distributed transaction.
The code contains a confirmation-or-refund path when payment succeeds after
the booking can no longer be confirmed. Staff record refund processing and
transfer references; automatic bank refund execution was not found. RabbitMQ
outbox workers publish persistent events after local commits, and consumers
process notification/refund and showtime-cancellation effects. Publisher
confirms and event-ID deduplication support retries but do not establish
exactly-once external email delivery \cite{booking,rabbit}.

\section{Mobile Application Architecture and Implementation}
\subsection{Startup and Navigation}
\code{main.dart} initializes Flutter bindings, creates the session object and
remote dependencies, attempts session restoration, and wraps the application
in \code{SessionProvider}. Unreadable storage is handled as a signed-out start.
Named routes create screens with their dependencies; an authenticated route
can redirect to sign-in with a pending destination \cite{client}.

The customer app exposes discovery, ticket history, notifications, and account
functions. Detail screens accept route IDs and reload data when an earlier
screen's argument is unavailable. This design also serves browser builds,
but on mobile it gives a consistent navigation contract without relying on
one global mutable booking object. It does not prove operating-system deep-link
registration or recovery of every transient form after process termination.
Table~\ref{tab:routes} lists representative route contracts.

\begin{table}[t]
\caption{Representative Mobile Screens}\label{tab:routes}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
Screen & Named route & Responsibility\\\midrule
Home & \code{/home} & Catalog and movie filters\\
Movie details & \code{/movies/\{id\}} & Metadata and showtimes\\
Seat selection & \code{/showtimes/\{id\}/seats} & Room layout and local choice\\
Summary & \code{/showtimes/\{id\}/summary} & Order options and submission\\
My bookings & \code{/my-bookings} & Ticket history\\
Booking details & \code{/bookings/\{id\}} & QR and lifecycle state\\
Payment & \code{/bookings/\{id\}/payment} & External checkout and checks\\
Notifications & \code{/notifications} & Read/unread messages\\
Profile & \code{/profile} & Account and member functions\\\bottomrule
\end{tabularx}
\end{table}

\subsection{Session State and Token Recovery}
\code{SessionState} is a \code{ChangeNotifier}, distributed through an
\code{InheritedNotifier}. It stores guest/authenticated state, user information,
expiration messages, and unread-notification count. Individual screens own
selection, loading, error, and pagination state. The code therefore uses a
small explicit state arrangement rather than an evidenced application-wide
Bloc or Redux architecture \cite{client}.

The HTTP client gives requests a default fifteen-second timeout and decodes
structured API failures. On a protected 401 it asks \code{TokenManager} to
renew the token, then retries once. Listing~\ref{lst:refresh} reproduces the
shared-future mechanism. Since the server rotates refresh tokens, independently
refreshing concurrent failed requests could otherwise reuse an invalidated
token. Additional session-version checks stop an in-flight renewal from
overriding a later account-expiration event \cite{client}.
\begin{lstlisting}[caption={Concurrent refresh coordination from TokenManager.},label={lst:refresh}]
return _pendingRefresh ??= _refresh(failedToken).whenComplete(() {
  _pendingRefresh = null;
});
\end{lstlisting}

Network errors can preserve session data for a retry; rejected refresh
credentials clear it. \code{SessionApp} responds to the expiration message by
opening sign-in and displaying an explanatory notice. This links transport
errors to navigation and prevents the UI from silently continuing with an
expired account state. It is an implementation mechanism, not evidence that
every race or device interruption has been exhaustively tested.

\subsection{UI Composition and Feedback}
Feature directories group authentication, movie, seat, booking, payment,
notification, profile, and staff screens. Shared theme files define spacing,
typography, color, and radius values. Reusable buttons, panels, loading,
empty, and error states keep common interactions consistent. Screen code uses
asynchronous calls, mounted checks, and busy flags to avoid updating disposed
widgets or repeatedly submitting an active action \cite{client,webui}.

The layout switches desktop navigation at 900 logical pixels, while phone
layouts use the narrow application frame. Seat maps and reusable column
components respond to available width rather than assuming a fixed desktop
canvas. The existence of phone-sized widget assertions supports testing those
layouts with fixtures; it is not a general accessibility, device-compatibility,
or performance certification.

\subsection{Platform-Specific Actions}
The native trailer implementation launches an external application rather than
embedding the browser-specific player. PayOS checkout likewise uses
\code{url\_launcher}. Ticket sharing invokes \code{share\_plus}, with clipboard
fallback on failure. Calendar support constructs a Google Calendar event URL;
it is not a synchronized device-calendar database integration \cite{client}.

QR ticket rendering uses \code{qr\_flutter}. A staff-only customer-app route can
look up a ticket or scan a QR through \code{mobile\_scanner}, then submit
server check-in. The iOS property list contains a camera-purpose description;
Android declares Internet access. Those inspected settings establish platform
intent, while camera permission behavior, release packaging, and physical-device
scanning remain unverified in this review \cite{client}.

\section{Core Business Workflows}
\subsection{Authentication and Account Use}
A customer may browse as a guest, but protected booking/account actions require
sign-in. Registration sends account data to AuthService and continues through
email OTP verification. Password recovery and profile editing have remote
service paths. Session restoration reads saved credentials and current-user
information; failures requiring authentication return the user to sign-in.
The application does not establish biometric login merely by depending on a
package that can support biometric options \cite{client,auth}.

\subsection{Discovery, Showtimes, and Seat Choice}
Home browsing combines now-showing/coming-soon selection, genres, and title
search, with a 350-millisecond debounce. Details expose metadata, trailer
actions, reviews, and open showtimes. The catalog repository fetches schedules
within a seven-day customer window. Once a show is chosen, room seats and
occupied IDs are combined into \code{ShowtimeSeatsData} \cite{client}.

The selected seat set remains local until order submission. A five-second
timer refreshes the visible map; conflicting local seats are removed, with
sweetbox partner handling. Failed refreshes retain the last map and retry on a
later tick. The booking transaction is consequently essential even when the
display recently looked current. This is periodically refreshed availability,
not verified WebSocket or SignalR push \cite{client,booking}.

\subsection{Order Calculation}
Summary collects seats, concessions, promotion choice, and requested member
points before submission. The backend recalculates the total. If $S$ is seat
value, $D$ the applicable ticket promotion, $C$ concessions, and $q$ redeemed
points, the code implements
\begin{equation}
T=S-D+C-1000q .\label{eq:total}
\end{equation}
The redemption ceiling is 50\% of the pre-points total and the account's
available balance. Promotion reductions are capped and rounded down to
1,000-VND steps. This notation explains real arithmetic rather than adding
an unrelated optimization model \cite{booking}.

Loyalty earning is also explicit. For paid amount $A$ and tier earn rate $r$,
the helper returns $\lfloor Ar/1000\rfloor$ points. The configured tier rates
are 5\%, 7\%, and 10\% for MEMBER, VIP, and VVIP. These values describe code
constants; no customer-retention or revenue effect has been measured.

\subsection{External Checkout and App Resumption}
Figure~\ref{fig:flow} describes the mobile checkout path. After creation of a
pending booking, the app requests a PayOS link and launches it externally.
\code{PaymentScreen} observes application lifecycle changes: a resumed app
that previously opened checkout requests verification. It also polls booking
state every five seconds, with provider verification every sixth eligible
poll, and disposes timers when leaving the screen \cite{client}.
\input{figures/flow}

The displayed countdown is computed from the booking expiry; it does not
authorize or extend the hold. A successful provider result is reconciled on
the backend before a confirmed ticket is shown. If the application is
terminated, booking history and ID-based detail loading provide a recovery
path; no claim is made that the OS automatically returns to the exact prior
payment screen or that offline purchase completion is supported.

\subsection{Tickets, Notifications, and Reviews}
Booking history/detail shows current status and paid-ticket QR content.
Sharing produces ticket text and a booking code; the QR must not be described
as cryptographically signed unless separately evidenced. Staff check-in
validates the booking on the server and records admission within a configured
time window. Review submission requires an owned booking that has been
checked in, with a unique user/movie review mapping \cite{client,booking}.

Notification lists retrieve stored messages and update read state through
APIs; the home/session UI tracks an unread count. Backend workers and event
handlers create reminder and ticket-related messages and send SMTP email.
No Firebase Cloud Messaging, APNs registration, or background OS push delivery
was established in the inspected implementation. Source-backed in-app records
and email must therefore be distinguished from native push notifications.

\begin{table}[t]
\caption{Major Mobile Functional Modules}\label{tab:modules}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}lYY@{}}\toprule
Module & Customer interaction & Supporting layer\\\midrule
Identity & Login, OTP, account recovery & Auth repository/AuthService\\
Discovery & Search, details, schedules & Catalog repository/MovieService\\
Reservation & Seats, options, summary & Booking repository/BookingService\\
Payment & External checkout, resumption & Payment screen/PayOS adapter\\
Tickets & History, QR, share, calendar URL & Flutter/native plugins\\
Messages & Lists, detail, read state & Notification APIs/SMTP handlers\\
Membership & Points, discounts, reviews & Booking business services\\\bottomrule
\end{tabularx}
\end{table}

\section{Security and Data Protection}
\subsection{Token and Account Protection}
The application persists access token, refresh token, expiry, and user data
using \code{SecureAuthTokenStorage}. It serializes writes and clears unreadable
storage. The package supplies platform-specific implementations
\cite{storage}; this review verifies calls to that abstraction, not hardware
backing or resistance to a compromised phone. No additional biometric gate,
certificate pinning, or device attestation was established \cite{client}.

Backend password/OTP hashing, input validation, role checks, and resource
ownership constrain API use. The booking controller replaces a customer's
submitted identity with claims, and price calculation uses backend data.
Gateway rate limiting and account-status validation add request controls.
These mechanisms reduce particular trust assumptions but do not establish
complete application security \cite{auth,gateway,booking}.

\subsection{Transport and External Data}
The default API addresses are HTTP development endpoints. HTTPS operation,
certificate configuration, and Android/iOS release network policies must be
verified for a named deployment. The client does not embed merchant signing
secrets in the inspected dependency construction; PayOS signing and webhook
checks occur in the backend. Actual secret values were not opened or printed
\cite{client,booking,deployment}.

Ticket sharing intentionally exposes booking information to the recipient.
Calendar actions construct an external URL containing event details. Those
flows should be explained to users in a release assessment rather than being
described as encrypted ticket distribution. Notification and payment records
also contain personal or payer metadata; no retention-policy or deletion
compliance guarantee can be derived solely from their entity definitions.

\section{Testing, Verification, and Evaluation}
\subsection{Executed Checks}
Table~\ref{tab:tests} records the review's verification outcomes. The installed
Flutter/Dart SDK and .NET SDK were identified directly. Backend isolated
tests succeeded: 17 BookingService unit cases and 21 gateway cases. AuthService
compiled with no warnings; MovieService compiled with four nullable warnings.
Gateway and BookingService builds also completed as part of their test runs.
These results do not measure device startup, frame rates, battery use, or
production API response times.
\input{verification-table}

\subsection{What the Test Suite Can Establish}
Flutter tests cover model parsing, API-client handling, form validation,
navigation, seat maps, checkout states, account changes, ticket features,
and responsive views. They inject repositories, HTTP responses, and platform
substitutes. This accords with the distinction between unit/widget tests and
complete-device integration described by Flutter \cite{fluttertest,tests}.
Passing such tests does not demonstrate camera capture, an actual share sheet,
a real secure-storage backend, or banking completion on a physical phone.

Backend integration fixtures create PostgreSQL through Testcontainers and
can enable a RabbitMQ container; MovieService, PayOS, and SMTP are otherwise
substituted in the booking fixture. The Docker daemon was unavailable, so
those container suites and a full deployment were blocked. Database SQL and
mappings were inspected, but migrations were not run against a live database.
Android/iOS release builds and physical-device acceptance were not executed
\cite{tests,db}.

\subsection{Interpretation}
The evidence supports an implemented remote-client architecture and specific
tested backend helpers/policies. It does not support an overall mobile
acceptance rate, production availability, a completed merchant transaction,
or a quantified security level. A workflow with both UI code and API code is
reported as implemented in source with runtime verification outstanding where
appropriate. No fixture data or example payment record is counted as a
successful real customer action.

\section{Limitations and Future Development}
\subsection{Current Limitations}
The client depends on connectivity for catalog retrieval, booking, and payment
confirmation. A stale seat map is possible between polling ticks or after a
failed refresh. External checkout introduces operating-system lifecycle and
browser behavior that widget mocks cannot fully reproduce. The implementation
does not establish offline booking, native push, universal app links, or
biometric authentication merely through route names or dependencies
\cite{client}.

Refund transfer remains manual staff work. Email sending and database updates
are separate operations despite event-ID checks, so exactly-once SMTP delivery
is not guaranteed. Local-time timestamps with Npgsql legacy behavior constrain
assumptions about users in other time zones. The source includes a calendar
duration fallback of 150 minutes when exact showtime data cannot be obtained;
that fallback is a convenience, not guaranteed schedule accuracy
\cite{booking,client,deployment}.

The review could not demonstrate live provider operation, container integration,
native secure storage, QR scanning, or signed store distribution. Existing SQL
seed payment labels are demonstration data, not evidence of active VNPAY or
MOMO implementations. Platform folders establish potential targets rather
than a tested support matrix. These limits prevent describing the application
as production-ready.

\subsection{Recommendations}
Recommended next steps are a controlled Android/iOS device matrix, release
build and permission checks, and lifecycle tests that interrupt checkout at
multiple stages. Verification should include token restoration after process
death, network transitions, camera denial, share-sheet failure, and repeated
payment reconciliation. Container suites and schema migrations should be run
before a complete system acceptance test.

Further recommendations include validating HTTPS and release network policy,
testing accessibility and text scaling, resolving backend nullable warnings,
and reviewing notification delivery requirements before considering native
push. Any push, offline cache, biometric gate, or deep-link enhancement should
be treated as proposed development rather than an implemented feature or
committed project roadmap.

\section{Conclusion}
CosmoQ's mobile implementation provides a Flutter customer workflow over a
shared ASP.NET Core backend. Session recovery, remote repositories, periodic
seat updates, server-created holds, external checkout reconciliation, and QR
ticket access form the central implementation. SQL constraints and backend
authorization carry responsibilities that cannot safely be delegated to phone
UI state. The reported verification establishes selected compilation and
automated-test outcomes while preserving the gap to physical-device and live
provider validation. The system is therefore documented as an implemented
mobile client with explicit operational verification limits.
'''

save('web',r'CosmoQ Cinema: A Flutter Web Ticket Booking and Cinema Management System with an ASP.NET Core Backend',
r'''Cinema ticketing requires customer purchases and cinema operations to agree on
showtimes, seat ownership, and payment state. CosmoQ Cinema implements these
interactions through Flutter Web customer and administration entry points and
a shared ASP.NET Core 8 backend. This report reconstructs the implementation
from source, dependency manifests, SQL schemas, tests, and deployment scripts.
A YARP gateway routes JSON requests to authentication, movie, and booking
services. Entity Framework Core with Npgsql accesses six PostgreSQL databases;
transactional reservation rows and a seat/showtime uniqueness constraint support
seat contention handling. The browser layer uses named routes, explicit session
state, remote repositories, responsive layouts, and token-refresh coordination.
PayOS checkout and reconciliation, RabbitMQ outboxes, notification records,
counter sales, promotions, and loyalty functions are analyzed within their
verified boundaries. Seventeen isolated booking-service unit tests and
twenty-one gateway tests passed; backend compilation succeeded, with four
nullable warnings in MovieService. Container-dependent verification was blocked
by an unavailable Docker daemon. Client verification outcomes are reported
separately from source implementation, and no live payment or production
deployment is claimed. The contribution is a traceable account of the Web
system's coordination mechanisms and remaining verification obligations.''',
'Cinema booking, Flutter Web, ASP.NET Core, PostgreSQL, JWT, PayOS, RabbitMQ, cinema management.',WEB)
save('mobile',r'CosmoQ Cinema: A Cross-Platform Flutter Mobile Ticket Booking Application with an ASP.NET Core Backend',
r'''Mobile cinema booking must coordinate local screen state with server-owned
reservations while users leave the application for payment and later return.
CosmoQ Cinema addresses this workflow with a Flutter customer application and
a shared ASP.NET Core 8 backend behind a YARP gateway. This report examines
the mobile implementation using startup code, navigation, remote repositories,
HTTP adapters, platform configuration, SQL, and tests. The client uses explicit
session notifications, secure-storage calls, coordinated refresh-token renewal,
movie/showtime discovery, periodically updated seat maps, booking history,
and QR ticket presentation. The backend uses Entity Framework Core and Npgsql
with PostgreSQL, server-priced ten-minute holds, PayOS verification, and
RabbitMQ-mediated notification and refund processing. Mobile-specific paths
include external checkout, application-resumption verification, ticket sharing,
calendar URLs, and staff QR-scanner integration. The analysis distinguishes
these source implementations from successful physical-device execution.
Seventeen isolated booking-service tests and twenty-one gateway tests passed;
backend builds succeeded with four MovieService nullable warnings. Docker-backed
integration was blocked, and native release, live merchant payment, and device
acceptance were not executed. The report contributes an evidence-linked
description of mobile state recovery and booking coordination without treating
plugin dependencies, test doubles, or platform folders as proof of operational
completion.''',
'Mobile ticket booking, Flutter, Dart, ASP.NET Core, JWT, PostgreSQL, PayOS, QR tickets.',MOBILE)

for kind in ('web','mobile'):
    p=ROOT/'docs'/('ieee-'+kind)
    client = 'Flutter customer Web\\and admin Web' if kind=='web' else 'Flutter mobile app\\screens and repositories'
    architecture = r'''\begin{figure}[t]
\centering
\begin{tikzpicture}[node distance=5mm and 4mm]
\node[box,text width=54mm] (ui) {CLIENT};
\node[box,below=of ui,text width=54mm] (gw) {YARP API gateway / JWT policies};
\node[box,below=7mm of gw] (mo) {MovieService\\movies and showtimes};
\node[box,left=of mo] (au) {AuthService\\accounts and tokens};
\node[box,right=of mo] (bo) {BookingService\\booking / payment / mail};
\node[box,below=of mo,text width=82mm] (db) {PostgreSQL: auth, movie, showtime, booking, payment, notification};
\node[box,below=of db,text width=82mm] (ext) {RabbitMQ events; PayOS HTTP; SMTP email\\external calls are made by backend services};
\draw[arr] (ui)--node[right,font=\tiny]{JSON / bearer token}(gw);
\draw[arr] (gw)--(au);\draw[arr] (gw)--(mo);\draw[arr] (gw)--(bo);
\draw[arr] (au)--(db.north west);\draw[arr] (mo)--(db);\draw[arr] (bo)--(db.north east);
\draw[arr] (db)--(ext);
\end{tikzpicture}
\caption{Verified deployment overview. The lower grouping names dependencies,
not a database-to-provider network connection; service code performs those calls.}
\label{fig:architecture}
\end{figure}
'''.replace('CLIENT',client)
    # Replace grouping link with direct service-to-integration edges, avoiding false DB routing.
    architecture=architecture.replace(r'\draw[arr] (db)--(ext);',r'\draw[arr] (bo.east) -- ++(2mm,0) |- (ext.east);')
    (p/'figures'/'architecture.tex').write_text(architecture,encoding='utf-8')
    (p/'figures'/'data.tex').write_text(r'''\begin{figure}[t]
\centering
\begin{tikzpicture}[node distance=5mm and 8mm]
\node[box] (room) {rooms};
\node[box,right=of room] (seat) {seats};
\node[box,below=of room] (show) {showtimes};
\node[box,right=of show] (movie) {movies\\separate database};
\node[box,below=of show] (booking) {bookings};
\node[box,right=of booking] (bs) {booking\_seats};
\node[box,below=of booking] (payment) {payments\\separate database};
\node[box,right=of payment] (refund) {refunds};
\draw[arr] (room)--node[above,font=\tiny]{1 : N}(seat);
\draw[arr] (room)--node[left,font=\tiny]{1 : N}(show);
\draw[arr,dashed] (movie)--node[above,font=\tiny]{ID ref.}(show);
\draw[arr,dashed] (show)--node[left,font=\tiny]{ID ref.}(booking);
\draw[arr] (booking)--node[above,font=\tiny]{1 : N}(bs);
\draw[arr,dashed] (booking)--node[left,font=\tiny]{ID ref.}(payment);
\draw[arr] (payment)--node[above,font=\tiny]{1 : 0..1}(refund);
\end{tikzpicture}
\caption{Selected schema relationships reconstructed from SQL. Solid arrows
denote parent-to-child SQL foreign keys; dashed arrows denote logical ID
references. Reservations, identity, and other extension tables are omitted.}
\label{fig:data}
\end{figure}
''',encoding='utf-8')
    flow = r'''\begin{figure}[t]
\centering
\begin{tikzpicture}[node distance=4mm]
\node[box,text width=72mm] (s) {Browse movie / choose show / select local seats};
\node[box,below=of s,text width=72mm] (b) {Submit booking: server prices order, locks reservations,\\commits PENDING booking and ten-minute holds};
\node[box,below=of b,text width=72mm] (p) {Request PayOS link / open external checkout};
\node[box,below=of p,text width=72mm] (v) {VERIFY};
\node[box,below=of v,text width=72mm] (r) {Backend reconciliation: confirm booking, or handle\\expiry / conflict / refund request; client reloads result};
\draw[arr] (s)--(b);\draw[arr] (b)--(p);\draw[arr] (p)--(v);\draw[arr] (v)--(r);
\end{tikzpicture}
\caption{FLOW No client redirect or timer is itself proof of payment.}
\label{fig:flow}
\end{figure}
'''
    flow=flow.replace('VERIFY','Browser return / booking polling / backend webhook' if kind=='web' else 'App resumption / booking polling / backend webhook')
    flow=flow.replace('FLOW','Web reservation and checkout control flow.' if kind=='web' else 'Mobile external-checkout and resumption flow.')
    (p/'figures'/'flow.tex').write_text(flow,encoding='utf-8')
    (p/'verification-table.tex').write_text(r'''\begin{table}[t]
\caption{Verification Executed on October 28, 2026}\label{tab:tests}
\centering\footnotesize
\begin{tabularx}{\columnwidth}{@{}YY@{}}\toprule
Check and method & Observed result / status\\\midrule
BookingService isolated unit filter & PASS: 17 tests, zero failed\\
ApiGateway test project & PASS: 21 tests, zero failed\\
AuthService build & PASS: zero errors/warnings\\
MovieService build & PASS: zero errors; four nullable warnings\\
Flutter analysis and widget suite & See final client-verification paragraph; package restoration required\\
PostgreSQL/RabbitMQ integration suites & BLOCKED: Docker daemon unavailable\\
SQL/migration execution & NOT EXECUTED: no running database\\
Live PayOS, SMTP, deployed acceptance & NOT EXECUTED: external services not exercised\\
Native release/device verification & NOT EXECUTED: no device acceptance run\\\bottomrule
\end{tabularx}
\end{table}
''',encoding='utf-8')
    (p/'README.md').write_text(f'''# CosmoQ Cinema — {kind.title()} IEEE report

This independent paper uses `IEEEtran` conference format. `main.tex` is the entry point;
`references.bib` contains IEEE references; `figures/*.tex` are reproducible TikZ diagrams.
All source references use repository snapshot `{REV}` and database snapshot `{DBREV}`.
The user explicitly waived the unavailable DIKE format reference in favor of the supplied IEEE requirements.

## Compile

From this directory, run either:

```powershell
tectonic --keep-logs --keep-intermediates main.tex
```

or, with a full TeX installation:

```powershell
pdflatex -interaction=nonstopmode -halt-on-error main.tex
bibtex main
pdflatex -interaction=nonstopmode -halt-on-error main.tex
pdflatex -interaction=nonstopmode -halt-on-error main.tex
```

The parent `ieee-common-build.ps1` builds both reports. An isolated Tectonic executable
was downloaded under `tmp/ieee-tools`; it is a report-generation tool, not an app dependency.
Required TeX packages: IEEEtran, fontenc, cite, amsmath, amssymb, graphicx, booktabs,
array, tabularx, TikZ, listings, url, hyperref. No shell escape is needed.

See `../ieee-evidence.md` for claim-to-source mapping and review limitations.
Verification results are bounded by the documented environment and test doubles.
''',encoding='utf-8')

print('Created both independent LaTeX projects.')
print('Words (approx.):', len(WEB.split()), len(MOBILE.split()))
