# Ticket 12, run w4-20260924T0417Z: expected records

Judged against mp-416 (and mp-632, the ticket card). Account: the dev admin, test@test.com
(`607f9dd5-6fa7-48ee-a628-720d4a0506a1`).

## Before the run (read 2026-09-24 04:17Z)

| System | Ticket expects | Found |
|---|---|---|
| Dev DB `users.is_admin` | `true` | `true` (db-admin-before.txt) |
| RevenueCat active `pro` | none, or its current Grant recorded | three active promotional Grants on `pro` (entla441faaeb4): 2026-09-15 → 2027-09-15, 2026-09-22 → 2026-10-22, 2026-09-23 → 2026-10-23 (revenuecat-admin-before.json) |
| Dev DB `user_entitlements` | mirrors RevenueCat | `active_until` 2027-09-15 19:39:14Z, `period_type` NORMAL, `event_at` 2026-09-23 02:34Z |

So the admin is **not** a no-access account today: it holds a Grant, which mp-416 names as the
thing that lets Vana answer.

## During and after the run

| Step | mp-416 says | Expected here, given the Grant |
|---|---|---|
| Sign in on a freshly claimed simulator | goes straight into the app, no paywall | tabs shell, no paywall |
| Relaunch (terminate + launch) | no paywall | tabs shell, no paywall |
| One Vana message | server refuses unless Pro or a Grant | server answers (200 stream), Vana replies; the admin flag plays no part |
| Dev DB after | unchanged `users` / `user_entitlements` | unchanged; one new `vana_messages` pair and a `vana_calls` row for the turn |
| RevenueCat after | unchanged | unchanged (no purchase, no grant) |

Because the account holds a Grant, the gate opens on the subscription status and never consults
the admin flag (`AppGate.build` returns open on `status.active` first), and the server's
`requirePro` passes on `user_entitlements`. Neither the admin-only bypass nor the server's
refusal can be observed on this account as it stands; that is recorded as a Finding, not worked
around (no grant is revoked).
