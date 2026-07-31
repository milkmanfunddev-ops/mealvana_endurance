# Final Surge — Authentication

Final Surge uses an OAuth 2.0-style **authorization-code** flow. A partner application sends
the athlete to Final Surge to log in and approve access, receives an authorization `code` on
a redirect, and exchanges that code for an **access token**. The token is then presented as
a bearer token on every data call.

- **Base host:** `https://log.finalsurge.com`
- **No scopes.** There is no `scope` parameter; the token grants whatever the Partner API
  allows for that athlete.
- **No PKCE, no `response_type`.** The flow is a simplified variant of OAuth 2.0.

Client credentials (a **client id** GUID and a 64-character **client secret**) are issued by
Final Surge to the partner application. They are redacted throughout this doc set as
`<FINAL_SURGE_CLIENT_ID>` and `<FINAL_SURGE_CLIENT_SECRET>`.

---

## Step 1 — Authorization request

Open the authorize endpoint in a browser:

```
GET https://log.finalsurge.com/oauth/authorize
      ?client-id=<FINAL_SURGE_CLIENT_ID>
      &redirect-uri=<your_redirect_uri>
      &state=<opaque_value>
```

| Param | Notes |
|---|---|
| `client-id` | **Hyphen**, not `client_id`. The partner application's client id. |
| `redirect-uri` | **Hyphen**, not `redirect_uri`. Must be on the callback domain registered for the application, or a sub-domain. `localhost` and `127.0.0.1` are white-listed for local testing. |
| `state` | An opaque value echoed back on the redirect. Use it for CSRF protection. |

After the athlete approves or denies, the browser is redirected to `redirect-uri`:

- **Approved:** `?code=<authorization_code>&state=<same_state>`
- **Denied:** `?error=access_denied`

---

## Step 2 — Token exchange

Exchange the `code` for an access token. **Credentials go in the request body**, as
`application/x-www-form-urlencoded` fields, with hyphenated key names.

```http
POST /oauth/token HTTP/1.1
Host: log.finalsurge.com
Content-Type: application/x-www-form-urlencoded

client-id=<FINAL_SURGE_CLIENT_ID>&client-secret=<FINAL_SURGE_CLIENT_SECRET>&code=<authorization_code>
```

| Body field | Required | Notes |
|---|---|---|
| `client-id` | Yes | Hyphenated. |
| `client-secret` | Yes | Hyphenated. |
| `code` | Yes | The authorization code from Step 1. |

### Response — HTTP 200

```json
{
  "access_token": "REDACTED-FINAL-SURGE-TOKEN",
  "athlete": {
    "id": "16238aab-bd1d-4a89-9b17-50f33630a007",
    "firstname": "Brian",
    "lastname": "Roberds"
  },
  "error": null
}
```

The token is a GUID-shaped string. In observed live responses the athlete identity fields
(`id`, `firstname`, `lastname`) also appear at the **root** of the JSON object, not only
nested under `athlete` — read both locations defensively.
_(confirmed in sample payloads)_

| Field | Type | Notes |
|---|---|---|
| `access_token` | string (GUID) | The bearer token for all subsequent data calls. |
| `athlete.id` / `id` | string (GUID) | The Final Surge athlete id. |
| `athlete.firstname` / `firstname` | string, nullable | |
| `athlete.lastname` / `lastname` | string, nullable | |
| `error` | string, nullable | Non-empty means the exchange **failed** — even though the status is 200. |

Examples: [examples/auth-token-request.txt](./examples/auth-token-request.txt),
[examples/auth-token-response.json](./examples/auth-token-response.json),
[examples/auth-token-error.json](./examples/auth-token-error.json).

---

## The body-credential rule (the #1 gotcha)

Final Surge's token endpoint does **not** authenticate the client from an
`Authorization: Basic base64(id:secret)` header. The client id and secret must be present as
form fields in the `x-www-form-urlencoded` **request body**. And the field names are
**hyphenated**, not the OAuth-standard underscored names:

| ✅ Correct | ❌ Wrong |
|---|---|
| `client-id` | `client_id` |
| `client-secret` | `client_secret` |
| `redirect-uri` | `redirect_uri` |

The same body-not-header rule applies to token refresh (below).

> **Secret escaping:** the 64-character client secret contains shell-special characters
> (`$`, `#`, `*`, `?`, `^`, `+`). In `.env` files or shells, single-quote it so `$` is not
> interpolated away and the secret arrives intact.

---

## Token refresh

A refresh grant is available at the same `/oauth/token` endpoint:

```http
POST /oauth/token HTTP/1.1
Host: log.finalsurge.com
Content-Type: application/x-www-form-urlencoded

client-id=<FINAL_SURGE_CLIENT_ID>&refresh_token=<refresh_token>&grant_type=refresh_token
```

Note the key-name asymmetry: `client-id` is hyphenated, while `refresh_token` and
`grant_type` use underscores, and `client-secret` is not sent. A `400` or `401` here means
the refresh token is invalid or expired and the athlete must re-authorize from Step 1.

In observed live token responses, Final Surge does **not** return a `refresh_token` or an
`expires_in`; access tokens are long-lived and a `401` on a data call is handled by
re-running the authorization flow rather than by refreshing. Treat refresh as available per
the flow spec but not always exercised in practice.
_(not observed in sample payloads)_

---

## Using the token on data calls

Every `/API/v1/*` request must send **two** headers:

```
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer <access_token>
```

Both are required. The `client-id` header identifies the partner application; the bearer
token identifies the authorized athlete. (Contrast with the token endpoint, which carries
credentials in the body, not headers.)

---

## Error envelopes

Token-endpoint failures return HTTP 200 with a populated `error` field and null token:

```json
{ "access_token": null, "error": "invalid_grant" }
```

Data-endpoint failures return a `Success: false` envelope carrying an error number and
message — see [endpoints.md § Error responses](./endpoints.md#error-responses).

An invalid or expired bearer token yields:

```json
{ "Success": false, "ErrorNumber": 401, "ErrorDescription": "Access Forbidden" }
```
