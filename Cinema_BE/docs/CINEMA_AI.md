# Cinema AI

Cinema AI is a customer assistant for movies, upcoming showtimes and booking help.
Use the floating chat icon on customer pages on web or mobile. On desktop it
expands on hover or keyboard focus. Chat opens in a compact panel on the current
page; minimize it or press Escape without losing the conversation. Guests can chat
without signing in. Booking still uses the existing sign-in, seat selection and payment flow.

## Configure OpenRouter

Put the key in `Cinema_BE/.env` (ignored by Git), never in Flutter or a committed file:

```dotenv
OPENROUTER_API_KEY=<your OpenRouter API key>
OPENROUTER_MODEL=openai/gpt-6.1-sol
OPENROUTER_REASONING_EFFORT=medium
```

Recreate the two affected services from `Cinema_BE`:

```powershell
docker compose up -d --build movie-service api-gateway
```

When running MovieService directly, use .NET User Secrets instead:

```powershell
dotnet user-secrets set "OpenRouter:ApiKey" "<your OpenRouter API key>" --project MovieService/MovieService
dotnet user-secrets set "OpenRouter:Model" "openai/gpt-6.1-sol" --project MovieService/MovieService
dotnet user-secrets set "OpenRouter:ReasoningEffort" "medium" --project MovieService/MovieService
```

Restart MovieService and ApiGateway. No database migration or new package is needed.
Without a key, the rest of Cinema still works; chat returns HTTP 503 with a clear message.
If the provider rejects the key, model access or quota, chat returns a safe HTTP 502.
The model can be changed through configuration using its exact OpenRouter model ID.
On a hosted MovieService, set `OpenRouter__ApiKey`, `OpenRouter__Model` and
`OpenRouter__ReasoningEffort` in the host's environment settings. Docker Compose reads
the `OPENROUTER_*` variables above; a directly hosted .NET process uses the double-underscore names.

## API and limits

`POST /api/v1/chat` through the existing gateway on port 5000:

```json
{"messages":[{"role":"user","content":"Có phim nào đang chiếu?"}]}
```

```json
{"message":"..."}
```

- Only alternating `user` / `assistant` turns, ending with a user message, are accepted.
- Maximum 12 messages, 4,000 characters per message, 12,000 characters total and a 64 KiB request body.
- The UI limits each question to 1,000 characters and sends at most the latest 11 messages,
  keeping complete turns within the character budget. At most 60 messages remain in screen memory.
- Gateway: 10 requests per IP per minute. MovieService: 30 requests total per instance per minute.
  These are local process limits; multiple replicas need a shared budget before increasing traffic.
- Server timeout: 60 seconds; gateway activity timeout: 70 seconds; chat client: 75 seconds.
  Output budget: 4,096 tokens, including reasoning; effort defaults to `medium`.
  Responses are requested under 200 words. No automatic client retries.
- The server supplies up to 30 active films and 80 future OPEN showtimes within 7 days,
  using Vietnam time and the existing seat/format price calculation. It does not send private bookings.
  This bounded catalogue suits the current single cinema; add retrieval when the catalogue grows.

## Data and behavior

The browser/mobile app talks only to Cinema. The backend calls OpenRouter's Responses API
over HTTPS with `store: false`. User questions, recent chat turns and the public catalogue
are sent through OpenRouter to the selected model provider. No chat database is created. Conversation history stays in memory
when minimized or changing customer pages; New chat, an account change or reloading
the app clears it. `store: false` disables response storage for later API retrieval;
it is not a promise of zero retention by OpenRouter or the provider. Never enter credentials or payment data.

The assistant cannot book, charge, cancel, refund, query personal accounts or execute tools.
AI answers may be wrong; the real catalogue, seat map and checkout remain authoritative.
Set a spending limit on the OpenRouter key before exposing this paid endpoint publicly.

Tests use a mocked provider HTTP handler and an isolated PostgreSQL test container. They do
not consume OpenRouter credits. A real response still needs a configured key, available credits and model access.

Official references: [OpenRouter quickstart](https://openrouter.ai/docs/quickstart),
[GPT-6.1 Sol](https://openrouter.ai/openai/gpt-6.1-sol),
[reasoning and output limits](https://openrouter.ai/docs/guides/best-practices/reasoning-tokens).
