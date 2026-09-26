# 122-004 · An Admin with no Pro gets Retry on Vana's refusal and no way to get Pro from the Subscription screen

- kind: idea
- status: triaged
- ticket: 122
- run: w38-20260926T0340Z
- screen: Ask Vana
- decision: 

**Steps.**
Seen on the Patrol account (Admin, eval ended 2026-09-16, no RevenueCat entitlement), which mp-416 lets past the paywall.
1. Ask Vana: the sheet shows "Mealvana Pro required" with a Retry link. Retry sends the turn again and gets the same 403 `pro_required`.
2. Settings -> Subscription: no status line, no date, no Upgrade, no Manage; only Redeem code and "What your plan includes".

Idea / product question: what should an Admin with no Pro see when the server refuses?
- Vana: drop Retry for `pro_required` (a retry can never pass) and say how an Admin gets Pro: a TestFlight subscription or a Grant, per mp-416's example.
- Subscription screen: a line saying the account has no plan. Ticket 106 removed the ended state and its Upgrade because a lapsed athlete never reaches this screen, but an Admin with no Pro does.

**Expected.**


**Actual.**
Retry at 22:45:25 local: second 403 in the console. The Subscription screen reads as if a plan were active ("What your plan includes") while the account has none.

**Evidence.**
- runs/122/05-patrol-vana-2.png
- runs/122/06-patrol-vana-retry.png
- runs/122/07-patrol-subscription.png
- runs/122/console-redacted.log (22:44:50 and 22:45:25 local, `[VANA_TRANSPORT] Vana HTTP 403`)

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Ruling: admins get every feature (see standing rules) (139). Closed by the retest after it merges. Record: `triage-20260926.md`.
