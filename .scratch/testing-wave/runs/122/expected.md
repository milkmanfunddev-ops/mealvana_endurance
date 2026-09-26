# Ticket 122 (wave 38): expected records

Run: w38-20260926T0340Z. App build 72d3723e. Written before the app was touched.

## Before
- `codes`: after `seed-codes.mjs seed` (03:41:54Z), every E2E code at 0 redemptions except E2EUSEDUP (1, spent by test@test.com). DEVCOACH30 and DEVCOACH18 are coach codes owned by test@test.com.
- Patrol account (37129f7e-…): `users.is_admin = true`; `user_entitlements` `period_type eval`, `active_until 2026-09-16 19:05Z`, `will_renew false` (lapsed). No active `pro` in RevenueCat.
- Each new `lee+e2e-122-*` account: no `user_entitlements` row, no active `pro` in RevenueCat, onboarding paywall with no close.

## After, per check
- **87-001 (A, E2EGIVE365 on the onboarding paywall):** one `code_redemptions` row for A; a 365-day promotional `pro` Grant in RevenueCat; `user_entitlements` mirrors it (`active_until` ~ now + 365 d). On screen, from the success until the timeline shows, Continue is busy or disabled and plan tiles are inert (ticket 106).
- **87-004 / 11-007:** a double tap sends one `redeem-code` request and leaves one redemption row. A sheet closed mid-request still gets the success message, and the code is spent once. A 32-character lowercase code with spaces redeems like the plain code. A reopened sheet starts empty. An empty field leaves Redeem disabled. Nothing sits under the software keyboard.
- **11-008:** E2EINFLUENCER -> "Code redeemed." (attributed), `influencer_code` attribute in RevenueCat, no pairing, no Grant. E2EEXPIRED -> "That code has expired." E2EFUTURE -> "That code isn't active yet." E2EUSEDUP -> "That code has already been used." E2EGIVE365 on a second account -> "That code has already been used." No Grant or redemption row for a refusal.
- **11-001 (C, own coach code, 30 days):** "You're set up as a coach, with 30 days of Pro."; an approved `coaches` row for C; a 30-day `pro` Grant, mirrored in `user_entitlements`; the Gate opens. Second entry -> "You've already used that code." and no second Grant.
- **87-005:** step 1, the athlete is told what happened to the days of a second giveaway on top of a running Grant. Step 2 (D, own code `--days 1`): the Subscription screen says "1 day left" (the last-day line needs the Grant's last local day, not reachable live).
- **11-010 (an account with Pro, Subscription -> Redeem code):** a coach code it does not own -> "Code redeemed. Your coach will see your request to pair." and a pending pairing; a made-up code -> "We don't recognise that code. Check it and try again." with the sheet open. Pro unchanged.
- **11-009:** each athlete's DEVCOACH* redemption makes one pending athlete-requested pairing with test@test.com. Signed in as test@test.com, the coach sees each request and can accept one and decline the other; the pairing row follows (active / declined). The athlete redeeming the same code after a decline is refused "You've already used that code."
- **87-003:** delete account from Settings goes straight to Welcome; no paywall frame in a 10 fps recording.
- **12-001 (Patrol account):** sign-in and relaunch skip the paywall (Admin, mp-416); a Vana chat call is answered 403 `pro_required`, no `vana_calls` debit.
- **12-006 (Patrol account, slow network):** the Gate waits no more than about two seconds for the admin read and shows the paywall; with the network back, a relaunch goes straight in.
- End: every `lee+e2e-122-*` account deleted in the app; their auth users, `user_entitlements`, pairings, redemptions and own codes gone.
