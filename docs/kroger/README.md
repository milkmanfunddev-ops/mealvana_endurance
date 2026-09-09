# Kroger Public API Integration

Last updated: 2026-09-08

## Status

Mealvana Endurance has separate Kroger Public API applications registered in
**Certification** and **Production**. Kroger Production credentials are now
configured on Mealvana's dev backend; see [Production registration and native callback](PRODUCTION.md).
A release-gated first implementation now exists:
editable retailer drafts in Flutter, product matching, server-side OAuth,
store-specific catalog search and a duplicate-protected cart handoff. It is
**not deployed or enabled in Mealvana production**. Customer OAuth and a real approved
cart addition still require end-to-end testing against Kroger Production;
Kroger does not provide customer accounts in Certification.

The schema and `kroger` function **are deployed to dev**, with Kroger Production
credentials stored as server secrets and the dev pilot enabled. Signed-in and
unauthenticated live status checks passed. See [deployment record](DEPLOYMENT.md).

- [Implementation and limitations](IMPLEMENTATION.md)
- [Testing and rollout checklist](TESTING.md)
- [Server-only configuration template](server.env.example)

The registration initially failed with:

```text
Invalid argument passed to Api Endpoint, application name cannot be duplicated
```

The Kroger backend treated `Mealvana Endurance` as an existing application
name even though the portal's Apps list showed no items. Registering the unique
name `MealvanaEndurance` succeeded.

## Registered Certification application

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
in ignored `secrets/kroger.env` and `secrets/kroger.md`. Neither file is a Flutter asset.

## Certification OAuth registration

Kroger registered this redirect URI:

```text
com.milkman.mealvanaendurance://callback
```

The registration confirmation is the source of truth: Kroger accepted the
native custom scheme directly. A previously considered HTTPS bridge at
`https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/kroger-oauth-callback`
was **not** registered for Certification. Lee also corrected the initial
Production registration information to use the native callback above;
see [PRODUCTION.md](PRODUCTION.md). No HTTPS bridge is required for this flow.

OAuth token requests require the Kroger `client_id` and `client_secret` in the
Authorization header. The registered grant types are:

- `authorization_code`
- `client_credentials`
- `refresh_token`

Use the authorization-code flow for customer-specific access such as adding
items to a shopper's Kroger cart or reading the shopper profile. Client
credentials can be used for application-level product and location access.

The mobile authorization flow follows the existing
`flutter_web_auth_2` approach used by Final Surge and pass the registered
full URI as the OAuth redirect URI and its scheme alone as the callback scheme.
The server stores short-lived, single-use OAuth state bound to the authenticated
Mealvana user; both client and server validate it. Exchange and refresh happen
only on Supabase. The browser receives no client secret or customer tokens.

Android dev currently registers `com.milkman.mealvanaendurance.dev` in its
manifest, which differs from the sole Kroger-registered URI. The app detects
that mismatch before opening sign-in. Register the dev URI with Kroger and use
the matching server configuration before Android-dev OAuth testing. Do not
silently change the registered redirect or give dev and prod competing intent
filters. Web OAuth needs a separately registered HTTPS callback and is not enabled.

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

The active local public configuration and Mealvana dev backend use Kroger Production:

```text
https://api.kroger.com/v1
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

The client secret was originally saved in `.env`, `.env.dev.local`, and
`.env.prod.local`. **Those files are bundled by `pubspec.yaml`.** The Kroger
secret has now been removed from all three and moved to `secrets/kroger.env`
(ignored, mode 0600); `secrets/kroger.md` remains the private registration record.
Public configuration may remain in the usual env files, but never restore the
secret there. If an app artifact was built while the secret was present, rotate
it in Kroger before rollout and update both private files.

The server reads `KROGER_CLIENT_ID`, `KROGER_CLIENT_SECRET`,
`KROGER_USE_CERTIFICATION`, `KROGER_REDIRECT_URI`, and `KROGER_ENABLED`.
The host is selected from a fixed certification/production allowlist, not an
arbitrary URL. `KROGER_ENABLED` defaults off. UI rollout separately requires
`--dart-define=KROGER_SHOPPING_ENABLED=true` for production. The entry is visible
on dev automatically, per the deployment policy. Dev's server flag is now on;
the server template remains fail-closed for fresh environments.
Separate Production credentials are now saved in `secrets/kroger.prod.env`;
`.env.prod.local` contains their public configuration only. Do not send
Certification credentials to the production host or mix registrations.
Never upload an entire client env file as server secrets.

## Implementation notes

- Active API host: `https://api.kroger.com/v1`. Preserved Certification credentials
  remain separate and are only valid on `https://api-ce.kroger.com/v1`.
- OAuth endpoints live below `/connect/oauth2` on that host.
- Send the client ID and secret through HTTP Basic authentication for token
  requests; do not place the secret in authorization URLs or logs.
- Treat `KROGER_CLIENT_SECRET` as server-side only when the integration is
  implemented. Do not expose it through `--dart-define` or compile it into the
  Flutter application; perform token requests through a server-side service.
- The redirect URI used during authorization and token exchange must match the
  registered value exactly.
- Customer tokens are in a new service-role-only table, not the client-readable
  training integrations repository. Retailer drafts use local-first persistence
  with dirty/revision tracking and owner-scoped, compare-and-swap cloud saves.
- Never hardcode the client secret or user tokens in committed source or docs.
- Production registration is complete and the saved native callback is aligned;
  dev backend credentials are deployed; end-to-end OAuth testing remains pending. Android dev
  still needs its separate callback registration; see [PRODUCTION.md](PRODUCTION.md).

## External references

- [Kroger developer documentation](https://developer.kroger.com/documentation)
- [Kroger API products](https://developer.kroger.com/api-products)
- [Kroger developer support](https://developer.kroger.com/support/contact-us)
- [Kroger-maintained Public API reference](https://www.postman.com/kroger/the-kroger-co-s-public-workspace/documentation/ki6utqb/kroger-public-apis)
