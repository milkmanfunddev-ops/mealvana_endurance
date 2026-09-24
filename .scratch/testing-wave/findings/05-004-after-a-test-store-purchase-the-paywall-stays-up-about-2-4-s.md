# 05-004 · After a Test Store purchase the paywall stays up about 2.4 s with Continue enabled again before the app opens

- kind: bug
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: Paywall
- decision: 

**Steps.**
1. New account on the onboarding paywall, Monthly selected, tap Continue.
2. Test Store sheet: "Test valid purchase".
3. Watch the screen (simulator screen recording, 10 fps).

**Expected.**
mp-457 / criterion 3: the Gate opens as soon as the purchase lands, with the paywall gone and nothing on it to tap.

**Actual.**
The sheet closes and the paywall keeps its spinner for about 1 s. Then Continue comes back **enabled** and the full paywall stays up for about 2.4 s (recording 26.2 s → 28.6 s) before the timeline slides in with the What's New sheet over it. The console logs `customer info updated {active: true}` and `redirecting to RouteMatchList(/main)` *before* `purchase succeeded`, so the router knew the Gate was open while the paywall was still up and live. A second tap on Continue in that window would start another purchase (see 05-010). Nothing in the console explains the delay.

**Evidence.**
- runs/05/19-purchase-to-app-frames-25s-29s.png (frames at 25.0, 26.4, 27.6, 28.6, 29.0 s: spinner, Continue live, Continue live, Continue live, timeline)
- runs/05/16-after-purchase-1.png … -6.png (1.5 s apart after the tap)
- runs/05/console.log lines 467-471

**Decision quote.**
> 

**Triage.**

