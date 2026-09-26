# Ticket 118 expected records (wave 36, run w36-20260926T0031Z)

The ticket's Touches: read only, except the accounts the run creates and deletes.

## Dev database, before and after
- test@test.com `integrations` rows: TrainingPeaks `last_sync_status = requires_reauth`,
  `last_sync_error = "Token refresh refused. Please reconnect."`; vdot `requires_reauth`;
  Final Surge and Garmin `success` (lead's start state, 2026-09-25 23:38 UTC).
  After the sign-in sync: TrainingPeaks and vdot still `requires_reauth` (never flipped back to
  `success` or to a plain `error`). After the network-error leg: TrainingPeaks status not changed
  *because of* the network error (a network error stores at most `error`, never
  `requires_reauth`; it was already `requires_reauth`, so it must simply not throw).
  `last_sync_at` may move (ticket 119 signs in to the same account).
- New account (11-005): a pending coach pairing to test@test.com after DEVCOACH30 redeem (left for
  ticket 122). Code redemption row for DEVCOACH30 on the new account.
- 18-005: a pick added to the Vana conversation's draft by "+", removed again if the draft offers
  Remove. No draft confirmed.
- New accounts deleted at the end (auth user gone, `users` row gone).

## RevenueCat
- New accounts: a customer appears (anonymous or app user id); no purchase is made. After
  DEVCOACH30: a 30-day promotional Pro grant if the coach code grants one (mp-535/mp-598); noted, not
  judged here.

## Cost
- One `COST spend 36 chat 118` for the Ask Vana opener (12-002 / 18-005 share it). No plan, no
  logging spend (Analyze is never pressed).

## Screen expectations (per Finding)
- 03-007: New Event at the end of My Events rests fully above the floating tab bar and takes a tap.
- 08-002: Redeem code sheet's close X has AXLabel "Close".
- 11-005: success message after DEVCOACH30 does not cover the paywall's Continue.
- 12-002: testing-tools button does not overlap Ask Vana or Vana's Send; Ask Vana centre tap opens Vana.
- 18-005: a ticked "+" is still an element with a label (Added); active filter items report selected.
- 21-004: after sign-in the app tells the athlete once, on screen, TrainingPeaks (and V.O2) need
  reconnecting; Connected Apps shows Reconnect; nothing opens as if TrainingPeaks worked.
- 23-001: Analyze reachable above the keyboard on Describe with 3+ lines typed.
- 28-006: barcode and search buttons in the Log search bar are labelled buttons.
- 64-001: network-error during refresh does not escape as an unhandled exception and does not
  mark requires_reauth; 401-after-fresh-refresh leg not runnable while the refresh is refused.
- 04-006: onboarding answers survive back and forward; saved profile carries them.
