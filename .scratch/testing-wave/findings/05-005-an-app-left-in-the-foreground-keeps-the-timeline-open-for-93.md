# 05-005 · An app left in the foreground keeps the timeline open for 93 minutes after Pro expired; only a resume lands on the paywall

- kind: idea
- status: open
- ticket: 05
- run: w5-20260924T0839Z
- screen: Timeline
- decision: 

**Steps.**
1. Account B buys the Test Store monthly at 08:50Z; the app opens on the timeline.
2. Leave the app in the foreground. The subscription expires at 09:15:45Z (RevenueCat, webhook, row all agree).
3. At 10:48Z the app is still on the timeline. Press Home and bring the app back.

**Expected.**
mp-457: no live Pro means the Gate is closed and the app is on the full-screen paywall. The decision does not say how soon after expiry a running app must notice.

**Actual.**
For 93 minutes after expiry the foreground app stayed open on the timeline (the console logged no customer-info change after 08:50Z). On resume, RevenueCat's SDK logged `customer info updated {active: false, expires_at: 09:15:45Z}` and the router went to `/paywall` straight away (21-after-resume.png). Only the server's own check (mp-457: the server refuses AI calls without Pro) stops paid actions in that window. Idea for triage: decide whether a foreground app should close the Gate at `expires_at` (a timer on the known expiry) or whether resume is enough, and write the answer into mp-457.

**Evidence.**
- runs/05/20-app-at-1055Z-after-expiry.png (timeline at 10:48Z)
- runs/05/21-after-resume.png (paywall after resume)
- runs/05/console.log tail (the `active: false` update and the `/paywall` redirect after resume)
- runs/05/revenuecat-B-subscriptions-1047Z.json

**Decision quote.**
> 

**Triage.**

