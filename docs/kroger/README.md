# Kroger Public API Integration

Last updated: 2026-09-04

## Status

Mealvana Endurance has a Kroger Public API application registered in the
**Certification** environment. No Kroger integration has been implemented in
the Flutter app or Supabase functions yet.

The registration initially failed with:

```text
Invalid argument passed to Api Endpoint, application name cannot be duplicated
```

The Kroger backend treated `Mealvana Endurance` as an existing application
name even though the portal's Apps list showed no items. Registering the unique
name `MealvanaEndurance` succeeded.

## Registered application

| Field | Value |
|---|---|
| App ID | `0b08b851-0691-4d91-a01f-1a56b38722f9` |
| App name | `MealvanaEndurance` |
| Environment | Certification |
| Description | A nutrition/mealplanning mobile app for endurance athletes. |
| Homepage | `https://endurance.mealvana.io/` |
| Logo | `https://endurance.mealvana.io/appicon.png` |
| Terms of Service | `https://endurance.mealvana.io/terms` |
| Privacy Policy | `https://endurance.mealvana.io/privacy` |
| Support contact | `lee.b.martin@gmail.com` |
| Owner | `lee.b.martin@gmail.com` |

The client ID and client secret are intentionally omitted here. They are stored
in the ignored local environment files and `secrets/kroger.md`.

## OAuth registration

Kroger registered this redirect URI:

```text
com.milkman.mealvanaendurance://callback
```

The registration confirmation is the source of truth: Kroger accepted the
native custom scheme directly. A previously considered HTTPS bridge at
`https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/kroger-oauth-callback`
was **not** registered and is not currently required.

OAuth token requests require the Kroger `client_id` and `client_secret` in the
Authorization header. The registered grant types are:

- `authorization_code`
- `client_credentials`
- `refresh_token`

Use the authorization-code flow for customer-specific access such as adding
items to a shopper's Kroger cart or reading the shopper profile. Client
credentials can be used for application-level product and location access.

When implementing the mobile authorization flow, follow the existing
`flutter_web_auth_2` approach used by Final Surge and pass the registered
custom scheme as both the OAuth redirect URI and callback scheme. Preserve and
validate an unpredictable OAuth `state` value. Keep token exchange and refresh
behavior in an application service rather than a screen.

## Granted certification APIs and scopes

| API | Scope |
|---|---|
| Cart (Public) - Certification | `cart.basic:write` |
| Locations (Public) - Certification | No scope listed |
| Profile (Public) - Certification | `profile.compact` |
| Products (Public) - Certification | `product.compact` |

The combined configured scope string is:

```text
cart.basic:write profile.compact product.compact
```

Do not invent a Locations scope; none was shown in the registration result.

## Environment configuration

The local configuration uses the certification API base URL:

```text
https://api-ce.kroger.com/v1
```

Environment keys:

```text
KROGER_CLIENT_ID
KROGER_CLIENT_SECRET
KROGER_BASE_URL
KROGER_OAUTH_URL
KROGER_TOKEN_URL
KROGER_REDIRECT_URI
KROGER_SCOPES
KROGER_USE_CERTIFICATION
```

Real credentials are present in `.env`, `.env.dev.local`, and
`.env.prod.local`. The production-local file deliberately still points at
Certification because Kroger has not issued production credentials. Replace
the client credentials and base URL only after production approval; do not
silently use certification credentials against the production API.

## Implementation notes

- API host for the current registration: `https://api-ce.kroger.com/v1`.
- OAuth endpoints live below `/connect/oauth2` on that host.
- Send the client ID and secret through HTTP Basic authentication for token
  requests; do not place the secret in authorization URLs or logs.
- Treat `KROGER_CLIENT_SECRET` as server-side only when the integration is
  implemented. Do not expose it through `--dart-define` or compile it into the
  Flutter application; perform token requests through a server-side service.
- The redirect URI used during authorization and token exchange must match the
  registered value exactly.
- Store access and refresh tokens using the existing integrations repository
  and offline-first conventions.
- Never hardcode the client secret or user tokens in committed source or docs.
- Production access will require a separate Kroger approval/registration
  step and may provide different credentials.

## External references

- [Kroger developer documentation](https://developer.kroger.com/documentation)
- [Kroger API products](https://developer.kroger.com/api-products)
- [Kroger developer support](https://developer.kroger.com/support/contact-us)
