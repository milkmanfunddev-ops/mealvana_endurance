# 87-008 · Subscription screen ended state: an athlete whose plan ended cannot reach it, since the Gate keeps them on the paywall

- kind: followup-test
- status: open
- ticket: 87
- run: w25-20260925T1325Z
- screen: Subscription
- decision: 

**Steps.**
1. A lapsed account (its store plan ended) looks for the Subscription screen's ended state: "It ended on <date>…", Upgrade and Manage (mp-495, mp-558).
2. Try every way in: the lapsed paywall's ⋯ menu, a deep link to /settings, a push notification that opens Settings.

**Expected.**
Either the ended state is reachable somewhere, or the record says a lapsed athlete never sees it (mp-457: closed lands on the full-screen paywall and stays there), and the ended state can go.

**Actual.**
Not run beyond the ⋯ menu: after A lapsed at 14:15:14Z the app sat on the paywall, whose ⋯ menu has Restore purchases, Redeem code, Manage subscription, Sign out and Delete account, and no way to Settings. 08-004's "ended" leg could not be seen in the app.

**Evidence.**
- runs/87/24-A-lapsed-paywall-menu.png

**Decision quote.**
> 

**Triage.**
