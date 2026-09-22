# Design SSOT — Component: Plan Ended Bar

**Status: PROPOSED v1 (Lee, 2026-09-22) — authored app-side, awaiting Xuan.** Written from the
paywall build (ticket 11, decision mp-457), which needed the bar before it had a component file.
No reference rendering yet.

**Component contract**: the strip a lapsed account sees at the top of every screen. It says the
plan has ended and carries a Subscribe button. A lapsed account is one that held `pro` once and
let it expire; it opens the app read-only (mp-457 §3). The bar is the one visible sign of that
state. Any edit or AI action the account attempts opens the paywall instead of running.

**Tokens:** [`../tokens.md`](../tokens.md): `blackberry` fill, `cream` copy, the primary button's
`orange` pill. This component introduces no colour of its own.

**Implementation:** `lib/shared/widgets/kyle_design/feedback/plan_ended_bar.dart`
(`PlanEndedBar`), placed by `lib/features/subscription/presentation/plan_ended_host.dart`.

## Contracts

- **PEB-1: presentation only.** The bar never decides whether it shows or what Subscribe does.
  The host shows it while the gate answers lapsed, on every signed-in route except the paywall
  itself. The ungated routes (startup, welcome, onboarding, sign-in) never show it. Subscribe opens
  the paywall over the current screen, so backing out returns to the same read-only screen.
- **PEB-2: top of the screen, above the page.** A full-width strip that runs up under the status
  bar. Its content starts below the status bar, and the page underneath starts below the strip:
  the strip takes the top safe area and the page's own top inset becomes zero. It never overlays
  the page's header, the tab bar or the Vana launcher.
- **PEB-3: one message, one action.** On the left, the message in body-medium (14 px) `cream`, at
  most two lines, then ellipsis. On the right, the primary button in its compact form: the
  `orange` pill, 36 px tall, 14 px label, 16 px side padding. Insets: 16 px leading, 8 px
  trailing, 8 px above and below the content, 12 px between message and button.
- **PEB-4: the same in both themes.** `blackberry` fill in light and dark, so the strip reads as
  the app speaking about the account rather than as part of the page.
- **PEB-5: copy from the content system.** `plan_ended.message` and
  `plan_ended.subscribe_button`; the bar composes no wording of its own.
- **PEB-6: announced once.** The message is a live region, so a screen reader announces it when
  the bar appears (an expiry mid-session, or opening the app lapsed).

## Open for Xuan

- Whether the bar belongs at the top (as built) or above the tab bar.
- The message wording, currently "Your plan has ended. Your data is read-only until you
  subscribe."
- Whether the bar should dismiss or collapse. As built it cannot: mp-457 says every screen
  carries it.
