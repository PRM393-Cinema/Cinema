# Cinema AI

Cinema AI is a customer assistant for movies, upcoming showtimes and booking help.
Use the floating chat icon on customer pages on web or mobile. On desktop it
expands on hover or keyboard focus. Chat opens in a compact panel on the current
page; minimize it or press Escape without losing the conversation. Guests can chat
without signing in for public catalogue questions. Sign in to use account lookup,
live seat availability and ticket proposals. Every actual booking requires a review
and confirmation in the UI, then uses the existing checkout and PayOS flow.
Press Enter to send a message; Shift+Enter inserts a newline. The mobile keyboard's
Send action also submits. Empty messages and duplicate sends while waiting are blocked.
Assistant answers render short headings, bold labels and bullet lists as selectable
text in both themes. HTML and external links remain literal text. Known movie,
snack and verified showtime routes are interactive. Recommendations separate
movie titles, showtimes and costs. Long old plain-text bullets gain a bold leading
label and sentence breaks; currency amounts are emphasized even without Markdown.
This only changes rendering: saved text and amounts stay unchanged and no AI call is needed.

## Current capabilities

| Area | What works today | Example question |
| --- | --- | --- |
| Movie advice | Search all active movies by title, genre or description, following result pages beyond the initial snapshot. | “Gợi ý phim hành động dưới 2 tiếng.” |
| Showtimes | Search future OPEN showtimes across the full cinema, by film/genre, Vietnam date/time, cinema and room. Skip full sessions and those with fewer seats than requested; offer verified seat links. | “Suất gần nhất còn 2 ghế ở CosmoQ?” |
| Top rated | Rank released active movies by audience scores weighted by review count; include the original score /5 and count. | “Top phim đánh giá cao đang chiếu?” |
| Trending | Rank confirmed tickets and bookings over the last 7 days, with growth against the previous 7 days. View/interest tracking is not implemented and is never presented as ticket sales. | “Phim nào đang hot tuần này?” |
| Personal recommendations | Filter released active movies by genre, age rating and duration; provide synopsis and 3–5 options when enough films match. Missing content advisories do not prove a film has no gore. | “Gợi ý phim kinh dị dưới 2 tiếng, không quá máu me.” |
| Membership | Read the signed-in customer's tier, points, earn rate, next tier, gifts and recent points transactions. | “Tôi đang hạng gì, còn bao nhiêu điểm và quyền lợi?” |
| Bookings/payments | Search and paginate the customer's own booking/payment history. Compute highest paid payment and gross/refunded/net spending across the full selected period. | “Hóa đơn đã thanh toán cao nhất của tôi?” / “Tháng 10/2026 tôi chi bao nhiêu?” |
| Booking assistant | Collect missing film/date/time in a form, preview a verified showtime's seat map, choose seats, review prices and explicitly confirm the hold inside chat. Sign-in resumes the selected showtime. | “Tìm 2 ghế thường cạnh nhau cho Inception tối mai, hỏi tôi trước khi đặt.” |
| Conversation | Follow recent questions, reply in the user's language, and preserve the chat while minimized or changing customer pages. | “Trong hai phim vừa nêu, phim nào ngắn hơn?” |
| Interface | Guest access, both themes, mobile/desktop popup, selectable answers, retry, New chat and keyboard controls. | Enter sends; Shift+Enter adds a newline. |

Model tools are read-only and allowlisted: `search_movies`, `get_snack_menu`,
`find_showtimes`, `find_cinema_showtimes`, `get_top_rated_movies`,
`get_trending_movies`, `get_movie_candidates`, `request_booking_details`,
`get_seats`, `get_membership`, `get_account_summary`, `prepare_booking`.
The model cannot directly create/pay/cancel a booking or process a refund. A proposal
does not hold any seats. Only the explicit confirmation button calls the transactional
booking API, which checks conflicts and recalculates prices. The customer then
opens PayOS and the app verifies the payment with the server. The separate checkout
also supports concessions, promotions, points and membership gifts. The AI never
marks an order paid.

The public discovery tools need the gateway route `/api/v1/cinema-insights/{**catch-all}`
and BookingService's `availability`, `ratings` and `trends` endpoints. Deploy the
ApiGateway, BookingService and MovieService from the same GitHub revision before
testing a new frontend. A 404 on these routes can indicate a missing route or an older
backend deployment; check the hosting response and logs before concluding which.
Rebuilding Flutter alone cannot supply these APIs. An individual
data-tool timeout is returned to the model as `DATA_UNAVAILABLE`, so it can explain
the failure without inventing results. Provider failures still return a safe 502;
generation is never automatically retried because it may be billed.

Proposals are limited to 1–8 distinct seats in one showtime. Sweetbox pairs must stay
together. Expired proposals, changed prices, occupied seats and account changes block
confirmation. The client blocks repeated confirmation; existing seat reservations and
unique constraints prevent two active bookings from taking the same seats. A lost
booking response can still leave a temporary hold until its existing expiry; check
My tickets rather than repeatedly requesting a different set of seats.

Private lookups derive identity only from the JWT. An authenticated chat endpoint
passes gateway account-lock/role checks before calling the model. Private tool calls
forward the caller's token only to the configured Cinema gateway, never to OpenRouter.
There are no tool arguments for user IDs, arbitrary URLs, SQL or payment actions.

Payment totals cover all matching owner records, independently of the 10-row list
pages or text search. Gross paid includes SUCCESS, REFUND_PENDING and REFUNDED;
net subtracts completed REFUNDED amounts. Highest paid includes these three statuses
and reports its current status. Failed/pending transactions are excluded from paid
totals. Date filters are inclusive Vietnam calendar days based on creation date,
not showtime or refund completion date. Monetary calculations use backend decimals.

Film descriptions are shortened to 300 characters. Older chat turns are dropped
from model context. The history button lists up to 20 conversations saved on this
device, with up to 60 messages each; reopening a saved conversation restores its
recent context. New chat keeps previous conversations in history. Individual chats
can be deleted with confirmation. Account histories are stored under separate keys;
signing out hides account history, and signing back in restores that account's chats.
Guest history is shared by guests using the same browser profile/device. Storage
uses the existing Flutter Secure Storage dependency; clearing app/browser storage,
using another origin/browser or switching devices will not restore these local chats.
There is no server synchronization. Only completed question/answer turns are saved;
pending/failed requests and actionable booking proposals are not restored. Chats lost
before this feature existed cannot be recovered. There is no image/file upload,
voice interface or web search. Seat availability is a snapshot until the server
successfully creates a hold; another customer can take seats while a proposal is open.

## Configure OpenRouter

Put the key in `Cinema_BE/.env` (ignored by Git), never in Flutter or a committed file:

```dotenv
OPENROUTER_API_KEY=<your OpenRouter API key>
OPENROUTER_MODEL=openai/gpt-6.1-sol
OPENROUTER_REASONING_EFFORT=medium
```

Recreate the affected services from `Cinema_BE`:

```powershell
docker compose up -d --build --no-deps booking-service movie-service api-gateway
```

When running MovieService directly, use .NET User Secrets instead:

```powershell
dotnet user-secrets set "OpenRouter:ApiKey" "<your OpenRouter API key>" --project MovieService/MovieService
dotnet user-secrets set "OpenRouter:Model" "openai/gpt-6.1-sol" --project MovieService/MovieService
dotnet user-secrets set "OpenRouter:ReasoningEffort" "medium" --project MovieService/MovieService
```

Restart BookingService, MovieService and ApiGateway. No database migration or new package is needed.
Without a key, the rest of Cinema still works; chat returns HTTP 503 with a clear message.
If the provider rejects the key, model access or quota, chat returns a safe HTTP 502.
The model can be changed through configuration using its exact OpenRouter model ID.
On a hosted MovieService, set `OpenRouter__ApiKey`, `OpenRouter__Model` and
`OpenRouter__ReasoningEffort` in the host's environment settings. Docker Compose reads
the `OPENROUTER_*` variables above; a directly hosted .NET process uses the double-underscore names.
Also set `CinemaApi__BaseUrl` on MovieService to the **trusted Cinema gateway** root
URL (HTTPS when hosted). Docker Compose supplies `http://api-gateway:8080/`;
direct local execution defaults to `http://localhost:5000/`. This is server configuration,
never a URL supplied by the model. The gateway must reach BookingService and AuthService.

## API and limits

`POST /api/v1/chat` through the existing gateway on port 5000:

```json
{"messages":[{"role":"user","content":"Có phim nào đang chiếu?"}]}
```

```json
{"message":"...","booking":null}
```

- Only alternating `user` / `assistant` turns, ending with a user message, are accepted.
- Signed-in clients use `POST /api/v1/chat/account` with their bearer token;
  the public endpoint never enables account tools, even if a token is attached.
  `GET /api/v1/bookings/assistant-summary?from=2026-10-01&to=2026-10-31&query=&page=1`
  exposes only the caller's own summary. `from`/`to` can be omitted for all history.
- Maximum 12 messages, 4,000 characters per message, 12,000 characters total and a 64 KiB request body.
- The UI limits each question to 1,000 characters and sends at most the latest 11 messages,
  keeping complete turns within the character budget. At most 60 messages remain in screen memory.
- Gateway: 10 requests per IP per minute. MovieService: 30 requests total per instance per minute.
  These are local process limits; multiple replicas need a shared budget before increasing traffic.
- Server timeout: 120 seconds; gateway activity timeout: 130 seconds; chat client: 135 seconds.
  At most five provider calls and eight tool executions per turn, bounded by the same timeout.
  Output budget per provider call: 4,096 tokens, including reasoning; effort defaults to `medium`.
  Responses are requested under 200 words. No automatic client retries.
- The server supplies up to 30 active films and 80 future OPEN showtimes within 7 days,
  using Vietnam time and the existing seat/format price calculation. Retrieval tools can search
  beyond this initial snapshot (20 movies/showtimes per page). Large searches may require
  a narrower question or a follow-up when the tool budget is exhausted.

## Data and behavior

The browser/mobile app talks only to Cinema. The backend calls OpenRouter's Responses API
over HTTPS with `store: false`. User questions, recent chat turns and the public catalogue
and the account facts requested through tools are sent through OpenRouter to the selected
model provider. Tokens, passwords, email and payer bank/card details are not included in
tool outputs. Booking codes, amounts, movie selections, loyalty benefits and point history
are personal data: ask for them only if you accept that provider routing. No chat database
is created on the server. Conversation history persists locally as described above,
including requested account facts in assistant answers. Use Delete chat when using
a shared device. `store: false` disables provider response storage for later API retrieval;
it is not a promise of zero retention by OpenRouter or the provider. Never enter credentials or payment data.

The assistant cannot autonomously charge, cancel or refund. It only prepares tickets
for explicit UI confirmation and reads the logged-in customer's account facts.
AI answers may be wrong; the real catalogue, seat map and checkout remain authoritative.
Tool workflows can require multiple billable model calls per question. Set a spending
limit on the OpenRouter key before exposing this paid endpoint publicly.

Tests use a mocked provider HTTP handler and an isolated PostgreSQL test container. They do
not consume OpenRouter credits. A real response still needs a configured key, available credits and model access.

## Verification — November 2, 2026

- MovieService: 46 tests passed; the six agent tests were rerun after the final tool-budget change.
- ApiGateway: 24 tests passed, including locked-account rejection on the account chat route.
- BookingService: 30 focused summary/booking/payment/refund/loyalty tests passed, plus a
  concurrent duplicate-confirmation test proving one hold and a conflict for the repeat.
- Flutter: 501 tests passed after the agent upgrade; 44 focused chat/agent/history tests
  passed after adding persistent history. Changed Dart files analyzed without issues;
  customer release web build passed.
- Edge: Enter/Shift+Enter, protected chat, desktop/mobile proposal review, cancellation,
  confirmation into existing checkout, history resume/reload and persistent deletion passed.
  Booking creation was intercepted with a fake hold; no real ticket or payment was created.
- With explicit user permission, one live OpenRouter membership question returned VVIP
  and 194 points, matching the demo customer's backend record. Other agent scenarios used
  a mocked provider; they are not a guarantee that every model phrasing chooses the right tool.
- Not exercised: real PayOS settlement, physical Android/iOS devices, cross-device history
  (not implemented), production deployment or production traffic limits.

Official references: [OpenRouter quickstart](https://openrouter.ai/docs/quickstart),
[GPT-6.1 Sol](https://openrouter.ai/openai/gpt-6.1-sol),
[Responses tool calling](https://openrouter.ai/docs/api_reference/responses/tool-calling),
[reasoning and output limits](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens).
