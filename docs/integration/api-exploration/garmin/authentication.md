# Garmin — Authentication (OAuth2 + PKCE)

The Garmin Connect Developer Program uses **OAuth 2.0 with PKCE** (Proof Key for Code Exchange)
_(Garmin spec — OAuth2 PKCE)_. PKCE removes the need to expose the client secret in public clients
and protects against authorization-code interception.

## Credentials

| Term | Meaning _(Garmin spec — Start Guide §2.2)_ |
|---|---|
| **Client ID** (consumer key) | Uniquely identifies a partner app. Public. |
| **Client secret** (consumer secret) | Validates that requests come from the partner. **Private — never embed in mobile/browser clients.** |

Credentials are created per app in the [Developer Portal](https://developerportal.garmin.com/user/me/apps?program=829).
The first app yields an **evaluation** (rate-limited) key; production keys require a technical + UX
review. Create separate client IDs for logically separated user bases _(Garmin spec)_.

## Scopes and permissions

The OAuth `scope` returned by the token endpoint is a **fixed default API scope and cannot be
modified** — e.g. `PARTNER_WRITE PARTNER_READ CONNECT_READ CONNECT_WRITE` _(Garmin spec — OAuth2
PKCE §2)_. Which API pillars an app may use is set at app-creation time; what a given user has
actually granted is expressed as **user permissions**, controlled by the user during consent:

| Permission _(Garmin spec)_ | Grants |
|---|---|
| `ACTIVITY_EXPORT` | Activity API data |
| `HEALTH_EXPORT` | Health API data |
| `WORKOUT_IMPORT` | Training API (workouts/schedules) |
| `COURSE_IMPORT` | Courses API |
| `MCT_EXPORT` | Women's Health API (Menstrual Cycle Tracking) |

A user may opt into fewer permissions than the app requests. Query the user's current set with
`GET https://apis.garmin.com/wellness-api/rest/user/permissions`, which returns a JSON array, e.g.
`["ACTIVITY_EXPORT","WORKOUT_IMPORT","HEALTH_EXPORT","COURSE_IMPORT","MCT_EXPORT"]` _(Garmin spec)_.

## Flow

```
  Client                          Garmin                       Partner server
    │  generate code_verifier
    │  code_challenge = base64url(sha256(code_verifier))
    │
    │  (1) GET connect.garmin.com/oauth2Confirm?...challenge  ─────►  user logs in & consents
    │  ◄──── 302 redirect_uri?code=<code>&state=<state> ────────────
    │
    │  (2) POST diauth.garmin.com/.../oauth/token (code + verifier) ►
    │  ◄──── { access_token, refresh_token, expires_in, ... } ──────
    │
    │  (3) GET wellness-api/rest/user/id  (Bearer access_token) ────►  { userId }
```

### Step 1 — Authorization request _(Garmin spec)_

The client first generates a **code verifier** (cryptographically random string, 43–128 chars, from
`A–Z a–z 0–9 - . _ ~`) and derives a **code challenge** = `base64url(sha256(code_verifier))`.

`GET https://connect.garmin.com/oauth2Confirm`

| Param | Required | Value |
|---|---|---|
| `response_type` | yes | `code` |
| `client_id` | yes | consumer key |
| `code_challenge` | yes | SHA-256 hash of `code_verifier` |
| `code_challenge_method` | yes | `S256` |
| `redirect_uri` | optional | URI to redirect back to |
| `state` | optional | opaque anti-spoofing string echoed back |

> CORS pre-flight (`OPTIONS`) requests are **not** supported on the authorize endpoint _(Garmin spec)_.

On consent, Garmin redirects to `<redirect_uri>?code=<code>&state=<state>`.

### Step 2 — Access token request _(Garmin spec)_

`POST https://diauth.garmin.com/di-oauth2-service/oauth/token`
(`Content-Type: application/x-www-form-urlencoded`)

| Param | Required | Value |
|---|---|---|
| `grant_type` | yes | `authorization_code` |
| `client_id` | yes | consumer key |
| `client_secret` | yes | consumer secret |
| `code` | yes | code from Step 1 |
| `code_verifier` | yes | the verifier hashed in Step 1 |
| `redirect_uri` | conditional | must match Step 1 if it was used |

Response:

```json
{
  "access_token": "<ACCESS_TOKEN>",
  "expires_in": 86400,
  "token_type": "bearer",
  "refresh_token": "<REFRESH_TOKEN>",
  "scope": "PARTNER_WRITE PARTNER_READ CONNECT_READ CONNECT_WRITE",
  "jti": "f9eb2316-9b9d-495a-8732-e16c4b5bcafd",
  "refresh_token_expires_in": 7775998
}
```

## Token lifecycle _(Garmin spec)_

- **Access tokens** expire **three months** after creation and must be refreshed to keep access.
  (The `expires_in` field is in seconds.) Garmin recommends subtracting ≥600 s from the expiry to
  absorb clock/network skew.
- A **new refresh token is returned every time** you obtain a new access token.
- Recommended flow: check whether the current access token is expired; if so, request a new one
  using the most recent refresh token.

### Refresh request

`POST https://diauth.garmin.com/di-oauth2-service/oauth/token`
(`Content-Type: application/x-www-form-urlencoded`)

| Param | Value |
|---|---|
| `grant_type` | `refresh_token` |
| `client_id` | consumer key |
| `client_secret` | consumer secret |
| `refresh_token` | last refresh token received |

The response has the same shape as the token response above (new `access_token` + new
`refresh_token`). An expired access token used against the REST APIs surfaces as a
`Token is not active` error _(confirmed in sample payloads — garmin-backfill)_, so refresh proactively.

## Calling the APIs with a token _(Garmin spec)_

Include the access token as a bearer header on every REST request:

```
Authorization: Bearer <ACCESS_TOKEN>
```

## User ID _(Garmin spec — OAuth2 PKCE, Start Guide §3.2)_

`GET https://apis.garmin.com/wellness-api/rest/user/id` → `{"userId":"d3315b1072421d0dd7c8f6b8e1de4df8"}`

Each Garmin user has one API User ID that **persists across UATs** — if the user disconnects and
re-authorizes with the same Garmin account, or signs up for several of a partner's programs, the
same `userId` is returned. Push/ping notifications include this `userId` so partners can match data
to a user. The ID carries no identifying information and is used only as the primary user key; it is
never passed back to the API (user lookup is always by the token in the `Authorization` header).

## Webhook validation

Inbound push/ping webhooks are **not** OAuth-authenticated. Garmin sends a `garmin-client-id`
request header identifying the target consumer, which the receiver compares against its registered
client ID _(confirmed in sample payloads — auth.ts)_. Garmin's Data Generator (and some push types)
may omit the header entirely _(confirmed in sample payloads)_.

## Lifecycle notifications

### Deregistration _(Garmin spec — Start Guide §2.6.2)_

Sent when a user disconnects the partner from their Garmin Connect account, **or** when the partner
calls `DELETE /wellness-api/rest/user/registration`. After a deregistration, all notifications for
that user stop immediately and further data requests are rejected as unauthorized; the connection
cannot be restored.

```json
{ "deregistrations": [ { "userId": "<USER_ID>" } ] }
```

### User-permission change _(Garmin spec — Start Guide §2.6.3)_

Sent when a user changes data-sharing permissions post-connection (the access token stays valid, but
data flow may stop). The spec form is an array of permission strings plus a `changeTimeInSeconds`:

```json
{ "userPermissionsChange": [ {
  "userId": "31be9cac-5bf9-406b-9fa8-89879bcaceac",
  "summaryId": "x120d383-60256e84",
  "permissions": [ "ACTIVITY_EXPORT", "WORKOUT_IMPORT", "HEALTH_EXPORT", "COURSE_IMPORT", "MCT_EXPORT" ],
  "changeTimeInSeconds": 1613065860
} ] }
```

Some deliveries instead carry `permissions` as a boolean map, e.g.
`{"ACTIVITY_EXPORT": true, "HEALTH_EXPORT": false}` _(confirmed in sample payloads — types.ts)_.

### Delete user registration (partner-initiated) _(Garmin spec — Start Guide §3.1)_

`DELETE https://apis.garmin.com/wellness-api/rest/user/registration` — no parameters. Returns
`204 No Content`. Must be called whenever the partner offers a "Delete My Account" / "Disconnect"
action. A final deregistration notification is then emitted (if enabled).
