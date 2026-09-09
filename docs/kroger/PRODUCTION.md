# Production registration

Saved 2026-09-08 from the user's successful Kroger registration confirmation.
After explicit approval, the credentials were uploaded and enabled on Mealvana's
dev backend on 2026-09-08. Mealvana production remains untouched. See [deployment record](DEPLOYMENT.md).

| Field | Value |
|---|---|
| App name | Mealvana Endurance Prod |
| App ID | `a680e248-e2c2-45ea-81cd-fd5ae57af55b` |
| Environment | Production |
| Description | A nutrition/mealplanning app for endurance athletes. |
| Homepage | `https://endurance.mealvana.io/` |
| Logo | `https://endurance.mealvana.io/appicon.png` |
| Terms | `https://endurance.mealvana.io/terms` |
| Privacy | `https://endurance.mealvana.io/privacy` |
| Support / owner | `lee.b.martin@gmail.com` |

APIs: Cart (Public), Locations (Public), Products (Public), Profile (Public).
Scopes: `cart.basic:write profile.compact product.compact`; Locations lists no scope.
Grants: `authorization_code`, `client_credentials`, `refresh_token`.
Token requests authenticate the client with HTTP Basic using the client ID and secret.

## Storage

- `.env`, `.env.dev.local`, `.env.prod.local`: public Kroger Production
  configuration; client secrets remain blank because these are Flutter assets.
- `secrets/kroger.prod.env`: server-only Production credentials and configuration,
  ignored by Git and mode 0600. The local template stays fail-closed with
  `KROGER_ENABLED=false`; the deployed Mealvana dev flag is explicitly enabled.
- `secrets/kroger.prod.md`: private registration record referencing that env file.
- `secrets/kroger.env` and `secrets/kroger.md`: Certification credentials preserved.

## Native callback — corrected by Lee on 2026-09-08

Lee corrected the initially supplied HTTPS redirect to:

```text
com.milkman.mealvanaendurance://callback
```

This matches the implemented direct native callback, with server-side exchange
through the `kroger` function. No HTTPS bridge is required for this flow.
The saved configuration reflects Lee's correction; the portal was not edited or
independently re-verified. The live dev backend now reports `available:true` and
`environment:production`; end-to-end customer OAuth testing remains pending.
Android dev has a separate `.dev` scheme that still
needs registration and matching configuration; see [README](README.md).

Kroger's [API Basics](https://developer.kroger.com/documentation/public/getting-started/apis#environments)
states customer accounts are unavailable in Certification; customer OAuth,
Identity and Cart testing must use Production. A Production Kroger app can be
used by Mealvana's dev backend without releasing Mealvana to production.
