# TrainingPeaks — Authentication

TrainingPeaks uses standard **OAuth 2.0**, three-legged `authorization_code` grant. Access tokens
are short-lived; a refresh token is issued alongside them. The **OAuth host is separate from the API
host**, and the same flow serves both web and mobile clients — only the `redirect_uri` differs.

> No real credentials appear here. Placeholders: `<TP_CLIENT_ID>`, `<TP_CLIENT_SECRET>`,
> `<ACCESS_TOKEN>`, `<REFRESH_TOKEN>`, `<AUTH_CODE>`.

---

## 1. OAuth hosts

| | Sandbox | Production |
|---|---|---|
| Authorize | `https://oauth.sandbox.trainingpeaks.com/OAuth/Authorize` | `https://oauth.trainingpeaks.com/OAuth/Authorize` |
| Token | `https://oauth.sandbox.trainingpeaks.com/oauth/token` | `https://oauth.trainingpeaks.com/oauth/token` |
| Deauthorize | `https://oauth.sandbox.trainingpeaks.com/oauth/deauthorize` | `https://oauth.trainingpeaks.com/oauth/deauthorize` |
| API base | `https://api.sandbox.trainingpeaks.com` | `https://api.trainingpeaks.com` |

Note the casing: the authorize route is **`/OAuth/Authorize`** (capitals); token and deauthorize are
lowercase **`/oauth/token`** and **`/oauth/deauthorize`**. That is TrainingPeaks' actual routing.

---

## 2. The three-legged flow

```
  1. Authorize redirect          2. Login + consent        3. Redirect back with code
Client ───────────────────────► TrainingPeaks ──────────► redirect_uri?code=<AUTH_CODE>
                                                                    │
  4. Exchange code for tokens                                       ▼
Client ── POST /oauth/token (code) ──► TrainingPeaks ── access_token + refresh_token
                                                                    │
  5. Call the API                                                   ▼
Client ── GET /v1/... (Bearer access_token) ──────────► api[.sandbox].trainingpeaks.com
```

### Step 1 — Authorization request

```
GET /OAuth/Authorize
  ?response_type=code
  &client_id=<TP_CLIENT_ID>
  &scope=<space-delimited scopes>
  &redirect_uri=<redirect_uri>
```

Example:

```
https://oauth.trainingpeaks.com/OAuth/Authorize?response_type=code
  &client_id=<TP_CLIENT_ID>
  &scope=athlete%3Aprofile%20workouts%3Aread
  &redirect_uri=https%3A%2F%2Fapp.example.com%2Fcallback
```

Scopes are **space-delimited** (URL-encoded as `%20`). A CSRF `state` parameter is supported and
should be verified on the callback.

### Step 2 — Login & consent

The user authenticates with TrainingPeaks and approves the requested scopes. This happens on
TrainingPeaks' pages, not the calling application's.

### Step 3 — Authorization code redirect

TrainingPeaks redirects to the registered `redirect_uri` with a `code`:

```
https://app.example.com/callback?code=<AUTH_CODE>&state=...
```

The **authorization code expires in 60 minutes**.

### Step 4 — Token exchange

```http
POST /oauth/token HTTP/1.1
Host: oauth.trainingpeaks.com
Content-Type: application/x-www-form-urlencoded
User-Agent: <application-name>/<version>

client_id=<TP_CLIENT_ID>
&client_secret=<TP_CLIENT_SECRET>
&code=<AUTH_CODE>
&redirect_uri=<redirect_uri>
&grant_type=authorization_code
```

**Response** (`200 OK`, [`examples/token-response.json`](examples/token-response.json)):

```json
{
  "access_token": "<ACCESS_TOKEN>",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "<REFRESH_TOKEN>",
  "scope": "athlete:profile workouts:read"
}
```

`expires_in` is in **seconds**. TrainingPeaks has documented it as `600` and it has been observed as
high as `3600`; treat the token as short-lived (~1 hour) and refresh proactively rather than
assuming a fixed lifetime.

### Step 5 — Authenticated requests

Every API request carries two headers:

```http
Authorization: Bearer <ACCESS_TOKEN>
User-Agent: <application-name>/<version>
```

The `User-Agent` is **required** and must identify the calling application (TrainingPeaks documents
the format `<client_id>/<version>`). Requests missing it can fail pre-production validation.

---

## 3. Refreshing tokens

When the access token nears or reaches expiry, exchange the refresh token for a new pair:

```http
POST /oauth/token HTTP/1.1
Content-Type: application/x-www-form-urlencoded
User-Agent: <application-name>/<version>

client_id=<TP_CLIENT_ID>
&client_secret=<TP_CLIENT_SECRET>
&grant_type=refresh_token
&refresh_token=<REFRESH_TOKEN>
```

The response has the same shape as the token exchange. A `401 Unauthorized` on an otherwise valid
request signals an expired/revoked access token — refresh and retry once.

---

## 4. Deauthorization

Revoke the access + refresh token pair:

```http
POST /oauth/deauthorize HTTP/1.1
Host: oauth.trainingpeaks.com
Authorization: Bearer <ACCESS_TOKEN>
User-Agent: <application-name>/<version>
```

Returns `200 OK` (some clients observe `204 No Content`).

---

## 5. OAuth scopes — the full list

Scopes are requested space-delimited in the authorize URL. **Scopes are not inclusive** — e.g.
`workouts:details` does *not* imply `workouts:read`; request each capability explicitly. A grant's
scope set is fixed: to widen it, the user must re-authorize. `athlete:profile` and `coach:athletes`
are mutually exclusive.

| Scope | Unlocks |
|---|---|
| `athlete:profile` | Read the athlete's profile and training zones (`/v1/athlete/profile`, `/v1/athlete/profile/zones`). |
| `coach:athletes` | Access a coach's athlete list, assistants, and athlete data (`/v1/coach/...`). Broad: covers every managed athlete. Excludes `athlete:profile`. |
| `workouts:read` | Read workouts by range and by id; the changed-workouts feed. |
| `workouts:plan` | Create, update, and delete planned workouts (`POST`/`PUT`/`DELETE /v2/workouts/plan`). |
| `workouts:details` | Detailed workout channel data, mean-max, time-in-zones, and workout comments — **premium athletes only**. |
| `workouts:wod` | Read Workout of the Day and download WOD files. |
| `file:write` | Upload workout files (`POST /v3/file`) and poll upload status. |
| `events:read` | Read events/races from the athlete calendar (`/v2/events/next`, `/v2/events/{date}`). |
| `events:write` | Create calendar events (`POST /v2/events`). |
| `metrics:read` | Read body metrics (weight, HRV, steps, sleep, stress). Date-range reads are **premium only**. |
| `metrics:write` | Upload body metrics (`POST /v2/metrics`). |
| `nutrition:read` | Read nutrition entries (`GET /v1/athletes/{id}/nutrition`) — **premium athletes only**. |
| `nutrition:write` | Create, update, and delete nutrition entries. |
| `webhook:write-subscriptions` | Create/update/delete webhook subscriptions (early access). |
| `webhook:read-subscriptions` | Read webhook subscriptions (early access). |

---

## 6. Web vs mobile redirect URIs

The flow is identical; only the `redirect_uri` differs, and each URI must be pre-registered with
TrainingPeaks for the client.

| Platform | `redirect_uri` form | Callback mechanism |
|---|---|---|
| Mobile | Custom URL scheme, e.g. `com.example.app://callback` | OS intercepts the scheme and returns the code to the app. |
| Web | HTTPS URL on the app's own origin, e.g. `https://app.example.com/auth.html` | A small HTML page receives `?code=...` and relays it (e.g. via `postMessage`) to the running app. Must be same-origin. |

An unregistered `redirect_uri` yields an **"Invalid Redirect URI"** error; register new callbacks
through the support portal before use.

---

## 7. Access model and validation

- **Business/organizational use only.** Apply at `https://api.trainingpeaks.com/request-access`
  (allow 7–10 days).
- **Sandbox first.** New credentials are sandbox-only. Production credentials are granted after a
  pre-production validation covering: OAuth flow, token refresh, correct `User-Agent`, and per-scope
  behavior (e.g. that basic athletes are correctly prevented from modifying future planned
  workouts).
- **Sandbox refresh:** the sandbox DB is overwritten from production every Saturday 6:00 PM MST.
- **Test accounts:** create sandbox athletes at
  `https://home.sandbox.trainingpeaks.com/signup?partner=<TP_CLIENT_ID>` and coaches at
  `https://home.sandbox.trainingpeaks.com/coach/signup?partner=<TP_CLIENT_ID>`.
