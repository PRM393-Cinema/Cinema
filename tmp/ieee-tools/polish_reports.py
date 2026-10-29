from pathlib import Path
import shutil, re

ROOT = Path(__file__).resolve().parents[2]
backup = ROOT / 'tmp' / 'ieee-before-polish'
for kind in ('web', 'mobile'):
    source = ROOT / 'docs' / ('ieee-' + kind)
    if not (backup / kind).exists():
        shutil.copytree(source, backup / kind)

STYLE = r'''
% Restrained visual hierarchy; IEEEtran controls the page geometry and headings.
\definecolor{ReportInk}{HTML}{24465E}
\definecolor{ReportMuted}{HTML}{526270}
\definecolor{ReportRule}{HTML}{9AAAB5}
\definecolor{ReportTint}{HTML}{F2F5F7}
\definecolor{CodeString}{HTML}{486650}
\newenvironment{keypoints}{\begin{itemize}\setlength{\itemsep}{2pt}%
\setlength{\parsep}{0pt}}{\end{itemize}}
\renewcommand{\arraystretch}{1.12}
\setlength{\tabcolsep}{4pt}
\newcommand{\BIBdecl}{\raggedright\interlinepenalty=10000}
\lstdefinelanguage{Dart}{keywords={return,null,final,Future,void,async,await},
 sensitive=true,morecomment=[l]{//},morestring=[b]'}
\lstset{basicstyle=\ttfamily\scriptsize,breaklines=true,columns=fullflexible,
 numbers=left,numberstyle=\tiny\color{ReportMuted},numbersep=6pt,
 keywordstyle=\color{ReportInk}\bfseries,stringstyle=\color{CodeString},
 commentstyle=\color{ReportMuted}\itshape,backgroundcolor=\color{ReportTint},
 frame=single,rulecolor=\color{ReportRule},framerule=0.35pt,
 xleftmargin=12pt,xrightmargin=2pt,framexleftmargin=3pt,
 aboveskip=8pt,belowskip=8pt,captionpos=b,showstringspaces=false,
 keepspaces=true,tabsize=2}
\tikzset{box/.style={draw=ReportInk,fill=ReportTint,rounded corners=1pt,
 align=center,font=\scriptsize,minimum height=7mm,inner sep=2pt,text width=22mm},
 arr/.style={-{Latex[length=1.5mm]},draw=ReportInk,thin}}
'''

AUTHORS = r'''\author{
\IEEEauthorblockN{\small Nguyen Nguyen Ngu (QE190064), Dao Thi Thanh Huong (QE190046), Pham Ngo Bich Tram (QE1900100)\\
\small Nguyen Hoang Ngoc Chau (QE190088), Nguyen Xuan Dang Khoa (QE1900126)}
\IEEEauthorblockA{Student Developers, Class: SEK19B.Net\\
Department of Software Engineering\\
FPT University Quy Nhon Campus, Binh Dinh, Vietnam}
\IEEEauthorblockA{\textbf{Huynh Vang} --- Project Advisor, Lecturer\\
Department of Software Engineering, FPT University Quy Nhon Campus\\
Binh Dinh, Vietnam \quad\textbar\quad vangh@fe.edu.vn}}
'''

ARCHITECTURE = r'''\begin{figure*}[t]
\centering
\begin{tikzpicture}[x=1mm,y=1mm,
 layer/.style={font=\sffamily\scriptsize\bfseries,text=ReportMuted,anchor=west},
 component/.style={draw=ReportInk,rounded corners=2pt,fill=white,
 align=center,font=\footnotesize,inner sep=3pt},
 connection/.style={-{Latex[length=2mm]},draw=ReportInk,line width=0.55pt}]
% Each horizontal band has a single purpose; external bindings never run through a database.
\fill[ReportTint,rounded corners=3pt] (0,8) rectangle (170,-11);
\fill[ReportTint,rounded corners=3pt] (0,-15) rectangle (170,-37);
\fill[ReportTint,rounded corners=3pt] (0,-41) rectangle (170,-79);
\fill[ReportTint,rounded corners=3pt] (0,-83) rectangle (170,-108);
\node[layer] at (3,4) {CLIENT};
\node[component,text width=112mm,minimum height=10mm] (client) at (85,-3)
 {CLIENTTEXT};
\node[layer] at (3,-19) {API ENTRY};
\node[component,text width=112mm,minimum height=10mm] (gateway) at (85,-29)
 {\textbf{YARP API Gateway}\\JWT validation, role policies, account-status checks};
\node[layer] at (3,-45) {BACKEND SERVICES AND OWNED DATABASES};
\node[component,text width=46mm,minimum height=10mm] (auth) at (29,-55)
 {\textbf{AuthService}\\Accounts, OTPs, access and refresh tokens};
\node[component,text width=46mm,minimum height=10mm] (movie) at (85,-55)
 {\textbf{MovieService}\\Movies, rooms, seats and showtimes};
\node[component,text width=46mm,minimum height=10mm] (booking) at (141,-55)
 {\textbf{BookingService}\\Bookings, payments and notifications};
\node[component,text width=46mm,minimum height=9mm] (authdb) at (29,-71)
 {PostgreSQL\\\code{auth}};
\node[component,text width=46mm,minimum height=9mm] (moviedb) at (85,-71)
 {PostgreSQL\\\code{movie}, \code{showtime}};
\node[component,text width=46mm,minimum height=9mm] (bookingdb) at (141,-71)
 {PostgreSQL\\\code{booking}, \code{payment}, \code{notification}};
\draw[connection] (client)--node[right,font=\scriptsize,fill=white,inner sep=1pt]
 {JSON / bearer token}(gateway);
\draw[connection] (gateway.south)--++(0,-4)-|(auth.north);
\draw[connection] (gateway.south)--(movie.north);
\draw[connection] (gateway.south)--++(0,-4)-|(booking.north);
\draw[connection] (auth)--(authdb);
\draw[connection] (movie)--(moviedb);
\draw[connection] (booking)--(bookingdb);
\node[layer] at (3,-87) {SERVICE INTEGRATIONS};
\node[component,text width=46mm,minimum height=13mm] at (29,-98)
 {\textbf{SMTP email}\\Invoked by AuthService\\and BookingService};
\node[component,text width=46mm,minimum height=13mm] at (85,-98)
 {\textbf{RabbitMQ events}\\Outbox publishers / consumers\\in MovieService and BookingService};
\node[component,text width=46mm,minimum height=13mm] at (141,-98)
 {\textbf{PayOS HTTP API}\\Checkout links and status queries\\from BookingService};
\end{tikzpicture}
\caption{CAPTION Solid arrows show client/API and persistence paths.
The integration cards identify the backend services responsible for each external binding.
Database labels abbreviate the six \code{cinema\_\ldots\_db} names; all six use one PostgreSQL instance in Compose.}
\label{fig:architecture}
\end{figure*}
'''

def replace_once(text, old, new):
    assert old in text, old[:110]
    return text.replace(old, new, 1)

for kind in ('web', 'mobile'):
    p = ROOT / 'docs' / ('ieee-' + kind)
    # Always derive from this task's baseline so the script is safe to rerun.
    t = (backup / kind / 'main.tex').read_text(encoding='utf-8')
    t = t.replace(r'\usepackage{listings}', r'\usepackage{listings,xcolor}')
    t = re.sub(r'\\lstset\{.*?\\newcommand\{\\code\}', lambda m: STYLE + '\n'+r'\newcommand{\code}', t, count=1, flags=re.S)
    t = re.sub(r'\\author\{.*?\\maketitle',lambda m:AUTHORS+r'\maketitle',t,count=1,flags=re.S)
    title = (r'CosmoQ Cinema: Web Ticket Booking and Cinema\\Management with Flutter and ASP.NET Core'
             if kind == 'web' else r'CosmoQ Cinema: Mobile Ticket Booking\\with Flutter and ASP.NET Core')
    t = re.sub(r'\\title\{[^\n]*\}',lambda m:r'\title{'+title+'}',t,count=1)
    # Headers are emphasized without changing table data or adding decorative rules.
    def bold_headers(m):
        return m.group(1) + ' & '.join(r'\textbf{'+s.strip()+'}' for s in m.group(2).split('&')) + m.group(3)
    t = re.sub(r'(\\toprule\s*\n)([^\n]+?)(\\\\\\midrule)',bold_headers,t)

    if kind == 'web':
        t = replace_once(t,
'''The engineering contribution is an integration of browser navigation, role-aware
management interfaces, server-priced bookings, transactional seat reservations,
and payment reconciliation. Supporting modules include concessions, promotions,
loyalty balances, customer reviews, ticket check-in, and notification records.
These capabilities are assessed at the implementation level; their presence does
not establish a production deployment or a successful live financial transaction.
The work does not claim a new booking algorithm or a performance improvement over
other ticketing systems.''', r'''The principal engineering contributions are the following integrated mechanisms:
\begin{keypoints}
\item \textbf{Browser workflow composition.} Named navigation, session recovery,
responsive customer pages, and role-aware management entry points share remote API adapters.
\item \textbf{Server-controlled reservation.} Backend pricing, transactional seat
holds, and a seat/showtime uniqueness constraint coordinate competing purchases.
\item \textbf{Payment and operational follow-up.} Provider reconciliation and
outbox events connect booking state to notifications, refunds, and cinema operations.
\end{keypoints}
Concessions, promotions, loyalty balances, reviews, check-in, and notification
records support these workflows. Their source implementation does not establish
a production deployment, successful live payment, or performance improvement
over another ticketing system.''')
        t = replace_once(t,
'''Inside a PostgreSQL transaction, the service locks existing reservation rows
with \code{FOR UPDATE}. It rejects booked seats and unexpired holds. For a new
seat/showtime pair, the SQL constraint \code{uq\_seat\_per\_showtime} supplies
the conflict boundary when no row yet exists to lock. A unique-violation catch
rolls the transaction back and returns a conflict. The booking, seat snapshots,
holds, and outbox event are committed together. This supports a specific
concurrency mechanism, not an unrestricted claim that duplicate bookings can
never occur under any failure mode \cite{booking,db,postgres}.''',r'''The transaction uses three complementary mechanisms \cite{booking,db,postgres}:
\begin{keypoints}
\item \textbf{Lock existing reservations.} PostgreSQL \code{FOR UPDATE} locks
the selected rows; booked seats and unexpired holds are rejected.
\item \textbf{Constrain new reservations.} The unique
\code{uq\_seat\_per\_showtime} key protects a seat/showtime pair before a row
exists to lock. A unique violation rolls back the transaction and returns a conflict.
\item \textbf{Commit related state.} The booking, seat snapshots, holds, and
outbox event are persisted in one local transaction.
\end{keypoints}
These are specific concurrency mechanisms; they do not establish an unrestricted
guarantee under every failure mode.''')
        t = replace_once(t,
'''Role-based routing is paired with gateway and service authorization. Booking
reads compare ownership for non-management users, and self-service creation
overwrites user identity from claims. Server pricing avoids trusting a browser's
seat or concession totals. Webhook signature validation rejects malformed or
tampered provider data before booking confirmation. Password validation also
accounts for BCrypt's input-length boundary \cite{auth,gateway,booking}.''',r'''The implementation places checks at three trust boundaries
\cite{auth,gateway,booking}:
\begin{keypoints}
\item \textbf{Identity and ownership.} Gateway/service authorization accompanies
UI routing. Booking reads check ownership; self-service creation uses identity claims.
\item \textbf{Order value.} Server pricing recalculates seat and concession
amounts instead of trusting totals submitted by the browser.
\item \textbf{Provider data.} Webhook signatures are checked before payment data
is used to confirm a booking.
\end{keypoints}
Password validation additionally accounts for BCrypt's input-length boundary.''')
        labels = [
('AuthService implements registration',r'\textbf{Account lifecycle.} AuthService implements registration'),
('JWT validation checks issuer',r'\textbf{Request authorization.} JWT validation checks issuer'),
('Outbox publishers read unpublished events',r'\textbf{Asynchronous delivery.} Outbox publishers read unpublished events'),
('Selection is initially local.',r'\textbf{Selection versus reservation.} Selection is initially local.'),
('Gateway CORS uses configured origins',r'\textbf{Deployment configuration.} Gateway CORS uses configured origins'),
('Docker\'s daemon was unavailable',r'\textbf{Runtime verification boundary.} Docker\'s daemon was unavailable'),
]
        t=t.replace(r'\begin{lstlisting}[caption=',r'\begin{lstlisting}[language=[Sharp]C,caption=')
        t=t.replace('entity.HasIndex(e => new { e.ShowtimeId, e.SeatId }, "uq_seat_per_showtime").IsUnique();',
'''entity.HasIndex(
    e => new { e.ShowtimeId, e.SeatId },
    "uq_seat_per_showtime")
  .IsUnique();''')
    else:
        t = replace_once(t,
'''The project's engineering contribution is a coordinated customer workflow:
remote catalog data, route-driven screens, recoverable authentication,
server-controlled seat holds, external PayOS checkout, booking history, and QR
ticket presentation. Notification read state, promotions, loyalty points,
reviews, ticket sharing, and a staff check-in path extend that workflow.
The contribution is the integration of these mechanisms in the inspected
project, rather than a novel mobile framework or a measured improvement over
existing cinema applications.''',r'''The mobile implementation integrates three principal engineering mechanisms:
\begin{keypoints}
\item \textbf{Recoverable client state.} Route-driven screens, remote catalog
data, secure-storage calls, and coordinated renewal support the customer session.
\item \textbf{Server-owned booking state.} Seat availability, transactional
holds, order pricing, and payment reconciliation remain backend responsibilities.
\item \textbf{Mobile ticket interaction.} External checkout and resumption,
booking history, QR presentation, sharing, and a staff check-in path complete the flow.
\end{keypoints}
Notification read state, promotions, points, and reviews extend these workflows.
The contribution is their implementation and integration, rather than a novel
framework or a measured improvement over another cinema application.''')
        t = replace_once(t,
'''The native trailer implementation launches an external application rather than
embedding the browser-specific player. PayOS checkout likewise uses
\code{url\_launcher}. Ticket sharing invokes \code{share\_plus}, with clipboard
fallback on failure. Calendar support constructs a Google Calendar event URL;
it is not a synchronized device-calendar database integration \cite{client}.

QR ticket rendering uses \code{qr\_flutter}. A staff-only customer-app route can
look up a ticket or scan a QR through \code{mobile\_scanner}, then submit
server check-in. The iOS property list contains a camera-purpose description;
Android declares Internet access. Those inspected settings establish platform
intent, while camera permission behavior, release packaging, and physical-device
scanning remain unverified in this review \cite{client}.''',r'''Platform actions are isolated from the shared booking contract \cite{client}:
\begin{keypoints}
\item \textbf{External activities.} Native trailers and PayOS checkout launch
through \code{url\_launcher}; the native trailer path does not embed the Web player.
\item \textbf{Sharing and calendar links.} \code{share\_plus} invokes sharing,
with a clipboard fallback. Calendar support constructs a Google Calendar event URL,
not a synchronized device-calendar integration.
\item \textbf{Ticket display and scanning.} \code{qr\_flutter} renders tickets.
A staff-only route uses ticket lookup or \code{mobile\_scanner} before submitting
server check-in.
\end{keypoints}
The iOS property list declares a camera-purpose description and Android declares
Internet access. These settings show platform intent; camera permissions,
release packaging, and physical-device scanning remain unverified.''')
        t = replace_once(t,
'''The application persists access token, refresh token, expiry, and user data
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
complete application security \cite{auth,gateway,booking}.''',r'''Protection is divided between client persistence and API enforcement:
\begin{keypoints}
\item \textbf{Local credentials.} \code{SecureAuthTokenStorage} persists tokens,
expiry, and user data using serialized writes and clears unreadable storage.
Platform-specific package implementations are used \cite{client,storage};
hardware backing and compromised-device resistance were not tested.
\item \textbf{Server enforcement.} Password/OTP hashing, input validation,
role checks, and resource ownership constrain API use. Customer identity comes
from claims and pricing uses backend data \cite{auth,booking}.
\item \textbf{Gateway controls.} Rate limiting and current-account validation
add request checks independently of the mobile screen state \cite{gateway}.
\end{keypoints}
No additional biometric gate, certificate pinning, or device attestation was
established. These mechanisms do not constitute a complete security guarantee.''')
        labels = [
('The reservation transaction locks existing',r'\textbf{Reservation conflict boundary.} The reservation transaction locks existing'),
('A background expiry worker changes',r'\textbf{Expiry and cancellation.} A background expiry worker changes'),
('The HTTP client gives requests',r'\textbf{Concurrent token renewal.} The HTTP client gives requests'),
('Network errors can preserve session data',r'\textbf{Visible session recovery.} Network errors can preserve session data'),
('The selected seat set remains local',r'\textbf{Local choice and server hold.} The selected seat set remains local'),
('The displayed countdown is computed',r'\textbf{Resumption and reconciliation.} The displayed countdown is computed'),
]
        t=t.replace(r'\begin{lstlisting}[caption=',r'\begin{lstlisting}[language=Dart,caption=')
        t=t.replace('return _pendingRefresh ??= _refresh(failedToken).whenComplete(() {',
                    'return _pendingRefresh ??=\n    _refresh(failedToken).whenComplete(() {')
    for old,new in labels:
        t=replace_once(t,old,new)

    # Keep source-verified module labels legible in narrow table cells.
    t=t.replace('repository/AuthService',r'repository / AuthService')
    t=t.replace('repository/MovieService',r'repository / MovieService')
    t=t.replace('repository/BookingService',r'repository / BookingService')
    t=t.replace('screen/PayOS',r'screen / PayOS')
    t=t.replace('APIs/SMTP',r'APIs / SMTP')
    (p/'main.tex').write_text(t,encoding='utf-8')
    client = (r'\textbf{Flutter Web}\\Customer website and separate staff/admin entry point' if kind=='web'
              else r'\textbf{Flutter Mobile}\\Customer screens, remote repositories and native plugin calls')
    caption = ('Web system architecture with explicit service/database ownership and external integration bindings.'
               if kind=='web' else 'Mobile system architecture: the app uses the shared gateway; backend services own persistence and integrations.')
    (p/'figures'/'architecture.tex').write_text(ARCHITECTURE.replace('CLIENTTEXT',client).replace('CAPTION',caption),encoding='utf-8')
    table=(backup/kind/'verification-table.tex').read_text(encoding='utf-8')
    table=re.sub(r'(\\toprule\s*\n)([^\n]+?)(\\\\\\midrule)',bold_headers,table)
    for status in ('PASS','BLOCKED','NOT EXECUTED'):
        table=table.replace(status+':',r'\textbf{'+status+'}:')
    (p/'verification-table.tex').write_text(table,encoding='utf-8')
print('Polished both sources; previous versions preserved under tmp/ieee-before-polish.')
