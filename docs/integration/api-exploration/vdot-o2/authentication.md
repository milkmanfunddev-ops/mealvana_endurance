# VDOT O2 — Authentication

VDOT O2 uses the **OAuth 2.0 authorization-code grant**. The token endpoint is a
custom .NET service that looks standard but diverges from RFC 6749 in three ways a
client must handle: its non-standard error shape, a requirement that credentials
be sent in the request **body**, and authorization codes that can contain a
literal `+`. Each is documented below.

> Credentials in these docs are always redacted: `<VDOT_CLIENT_ID>`,
> `<VDOT_CLIENT_SECRET>`, `<ACCESS_TOKEN>`, `<REFRESH_TOKEN>`, `<AUTH_CODE>`.

---

## Hosts

| Purpose | Production | Sandbox |
|---|---|---|
| OAuth (`authBase`) | `https://app.vdoto2.com` | *(none — always production)* |
| REST API (`apiBase`) | `https://api.vdoto2.com` | `https://api.sandbox.vdoto2.com` |

The wiki documents `https://app.sandbox.vdoto2.com` as a sandbox OAuth host, but
**that hostname does not resolve** — only `app.vdoto2.com` exists. All OAuth
traffic (`authorize` and `token`) runs against production regardless of whether a
client is otherwise pointed at the sandbox API.

---

## Scopes

| Scope | Grants |
|---|---|
| `read:workouts` | The two workout `GET` endpoints |
| `write:upload-gps` | The two `POST …/upload-gps…` endpoints |

A token requests scopes at the `authorize` step. Calling an upload endpoint with
a token that was **not** granted `write:upload-gps` returns `403`.

---

## Step 1 — Authorize (browser redirect)

```
GET https://app.vdoto2.com/oauth/authorize
      ?client_id=<VDOT_CLIENT_ID>
      &redirect_uri=com.milkman.mealvanaendurance%3A%2F%2Fcallback
      &response_type=code
      &scope=read%3Aworkouts
      &state=9f2c1a...<64 hex chars>
```

| Param | Required | Value |
|---|---|---|
| `client_id` | ✅ | The registered client id |
| `redirect_uri` | ✅ | A URI pre-registered with VDOT O2 (see below) |
| `response_type` | ✅ | `code` |
| `scope` | ✅ | Space/`:`-delimited scopes, e.g. `read:workouts` |
| `state` | recommended | Opaque CSRF token — but VDOT O2 may not echo it back (see below) |

The athlete authenticates with VDOT O2 and approves the client, then VDOT O2
redirects to the `redirect_uri` with the authorization code appended as
`?code=…`.

### The custom-scheme redirect URI

VDOT O2 supports a **custom URL scheme** as the redirect target, which lets a
native mobile app receive the callback directly:

```
com.milkman.mealvanaendurance://callback
```

- The redirect URI **must be pre-registered with VDOT O2** before the flow will
  succeed (coordinate with `info@vdoto2.com`). A logo URL can be registered
  alongside it for the consent screen.
- It must match byte-for-byte across the `authorize` request, the `token`
  request, and the value registered with VDOT O2.

### State / CSRF behavior

VDOT O2 **does not reliably echo the `state` parameter back** on the callback —
the wiki's own example callback URL omits it entirely. A client should therefore
treat `state` as best-effort: validate it only when VDOT O2 actually returns a
value, and be prepared to proceed when it is absent.

---

## Step 2 — Exchange the code for tokens

```http
POST https://app.vdoto2.com/oauth/token
Authorization: Basic base64(<VDOT_CLIENT_ID>:<VDOT_CLIENT_SECRET>)
Content-Type: application/x-www-form-urlencoded
Accept: application/json

grant_type=authorization_code
&code=<AUTH_CODE>
&redirect_uri=com.milkman.mealvanaendurance%3A%2F%2Fcallback
&client_id=<VDOT_CLIENT_ID>
&client_secret=<VDOT_CLIENT_SECRET>
```

**Response 200** — see [`examples/token-response.json`](examples/token-response.json):

```json
{
  "accessToken": "<ACCESS_TOKEN>",
  "refreshToken": "<REFRESH_TOKEN>",
  "expiresIn": 7776000,
  "tokenType": "Bearer"
}
```

### Credentials must be in the BODY (the .NET quirk)

The token endpoint is a custom .NET service that **ignores the
`Authorization: Basic` header** and reads `client_id` / `client_secret` from the
**form body**. This applies to **both** the authorization-code exchange and the
refresh (Step 3).

- The body must be `application/x-www-form-urlencoded`. Sending a **JSON** body
  returns `invalid_payload`.
- `client_id` and `client_secret` must be present and **non-empty** in the body.
  An empty value returns `invalid_payload`, not `invalid_code`.
- Sending a Basic header as well is harmless — tolerant servers may read it — but
  it is never sufficient on its own.

This was proven by probing the live endpoint:

| Request shape | Response |
|---|---|
| form-urlencoded, creds in body | `invalid_code` (payload accepted; only the dummy code is bad) |
| JSON body instead of form-urlencoded | `invalid_payload` |
| form, **empty `client_secret`** | `invalid_payload` |
| form, wrong-but-present secret | `invalid_code` |
| form, missing `redirect_uri` | `invalid_code` (redirect is not the cause) |

So `invalid_payload` always means a body field was missing/empty or the body was
JSON — it is never about the code itself.

### camelCase vs snake_case

The **wiki documents snake_case** (`access_token`, `expires_in`, …), but the
**live API returns camelCase** (`accessToken`, `expiresIn`, …). A robust client
should accept either. See
[`examples/token-response-snake-case.json`](examples/token-response-snake-case.json)
for the documented variant.

| Field (camelCase / snake_case) | Type | Units | Optional | Notes |
|---|---|---|---|---|
| `accessToken` / `access_token` | string (JWT) | — | required | The JWT carries only a numeric VDOT user id — no name or email |
| `refreshToken` / `refresh_token` | string | — | optional | May be omitted on a refresh response |
| `expiresIn` / `expires_in` | int | **seconds** | optional | Observed at 7 776 000 (~90 days) live; the wiki example shows 3 600 |
| `tokenType` / `token_type` | string | — | optional | `"Bearer"` |

---

## Step 3 — Refresh

```http
POST https://app.vdoto2.com/oauth/token
Authorization: Basic base64(<VDOT_CLIENT_ID>:<VDOT_CLIENT_SECRET>)
Content-Type: application/x-www-form-urlencoded
Accept: application/json

grant_type=refresh_token
&refresh_token=<REFRESH_TOKEN>
&client_id=<VDOT_CLIENT_ID>
&client_secret=<VDOT_CLIENT_SECRET>
&token=<EXPIRED_ACCESS_TOKEN>
```

- **`client_id` / `client_secret` must be in the body here too.** Sending them
  only via the Basic header returns `invalid_payload` and the refresh fails. This
  is the same .NET quirk as Step 2.
- `token` (the *expired* access token) is an extra, non-standard field shown in
  the wiki's refresh example. It is optional — include it when available.
- The refresh response may **omit `refreshToken`**; when it does, the previously
  issued refresh token remains valid and should be retained.

Response is the same token shape as Step 2.

---

## The `+`-in-authorization-code requirement

VDOT O2's authorization codes are base64-flavored and **can contain a literal
`+`**. This collides with the standard way query strings are parsed:

- The `application/x-www-form-urlencoded` decoding rule treats `+` as a space. A
  generic query-parameter parser (e.g. Dart's `Uri.queryParameters`) will
  therefore turn a code `aB3+xY9/zQ==` into `aB3 xY9/zQ==`, corrupting it.
- VDOT O2 then rejects the corrupted code at token exchange with `invalid_code`.
  Because it only triggers when a code happens to contain a `+`, the failure is
  intermittent.

**A client must parse the raw callback query itself**, decoding each component
with a `%XX`-only decode (`Uri.decodeComponent`-style) that leaves `+`
untouched — never the form-urlencoded rule. Authorization codes never contain
real spaces, so preserving `+` is always correct.

```
Callback:  com.milkman.mealvanaendurance://callback?code=aB3%2BxY9%2FzQ%3D%3D&state=...

Form-urlencoded parse → code = "aB3 xY9/zQ=="   ✗  rejected as invalid_code
Raw %XX-only parse    → code = "aB3+xY9/zQ=="   ✓
```

---

## Error responses

The token endpoint does **not** follow RFC 6749's `{error, error_description}`
shape. It returns:

```json
{ "status": "NOK", "error": "invalid_payload" }
```

| Token-endpoint `error` | Meaning |
|---|---|
| `invalid_payload` | A body field (`grant_type` / `client_id` / `client_secret`) is missing or **empty**, or the body was sent as JSON instead of form-urlencoded. Observed — see [`examples/error-invalid-payload.json`](examples/error-invalid-payload.json). |
| `invalid_code` | Payload shape and credentials were accepted; the **code** is bad — expired, already used, corrupted by the `+` issue, or the `client_secret` value is wrong-but-present. Observed — see [`examples/error-invalid-code.json`](examples/error-invalid-code.json). |

REST-endpoint HTTP statuses follow ordinary conventions: `401` when the access
token is expired (refresh and retry), `403` for a missing scope (e.g. an upload
without `write:upload-gps`), `429` for rate limiting (honor `Retry-After` if
present), and `5xx` for retryable server errors.
