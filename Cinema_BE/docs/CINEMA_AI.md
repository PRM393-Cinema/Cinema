# Cinema AI

Cinema AI is a customer assistant for movies, upcoming showtimes and booking help.
Open **Cinema AI** from the Movies page on web or mobile. Guests can chat without
signing in. Booking still uses the existing sign-in, seat selection and payment flow.

## Configure OpenAI

Put the key in `Cinema_BE/.env` (ignored by Git), never in Flutter or a committed file:

```dotenv
OPENAI_API_KEY=<your OpenAI API key>
OPENAI_MODEL=gpt-4.1-mini-2025-04-14
```

Recreate the two affected services from `Cinema_BE`:

```powershell
docker compose up -d --build movie-service api-gateway
```

When running MovieService directly, use .NET User Secrets instead:

```powershell
dotnet user-secrets set "OpenAI:ApiKey" "<your OpenAI API key>" --project MovieService/MovieService
dotnet user-secrets set "OpenAI:Model" "gpt-4.1-mini-2025-04-14" --project MovieService/MovieService
```

Restart MovieService and ApiGateway. No database migration or new package is needed.
Without a key, the rest of Cinema still works; chat returns HTTP 503 with a clear message.
If the provider rejects the key, model access or quota, chat returns a safe HTTP 502.
The model can be changed through configuration if your OpenAI project uses another model.

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
- Server timeout: 25 seconds; output budget: 900 tokens. No automatic provider retries.
- The server supplies up to 30 active films and 80 future OPEN showtimes within 7 days,
  using Vietnam time and the existing seat/format price calculation. It does not send private bookings.
  This bounded catalogue suits the current single cinema; add retrieval when the catalogue grows.

## Data and behavior

The browser/mobile app talks only to Cinema. The backend calls OpenAI's Responses API
over HTTPS with `store: false`. User questions, recent chat turns and the public catalogue
are sent to OpenAI. No chat database is created; leaving the screen or choosing New chat
clears its local history. `store: false` disables response storage for later API retrieval;
it is not a promise of zero provider-side retention. Never enter credentials or payment data.

The assistant cannot book, charge, cancel, refund, query personal accounts or execute tools.
AI answers may be wrong; the real catalogue, seat map and checkout remain authoritative.
Set a spending budget/alerts in the OpenAI project before exposing this paid endpoint publicly.

Tests use a mocked OpenAI HTTP handler and an isolated PostgreSQL test container. They do
not consume OpenAI credits. A real response still needs a configured key and provider access.

Official references: [Responses/text generation](https://developers.openai.com/api/docs/guides/text),
[GPT-4.1 Mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini),
[response storage](https://developers.openai.com/api/reference/resources/responses/methods/create).
