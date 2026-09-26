# 123-003 · Subscription screen names Pro Monthly but no price, and its date has no time

- kind: idea
- status: wontfix
- ticket: 123
- run: w38-20260926T0341Z
- screen: Subscription
- decision: 

**Steps.**
Idea, from 07-008. The Subscription screen for a paid Monthly account reads "Subscribed", "Pro Monthly", "Renews on September 25, 2026." It names the plan (mp-628) but not its price, and the date has no time of day. Spec story 50 (plan, expiry, a way to manage it) is met. Two ideas for Lee: show the price the athlete pays ("$9.95 a month"), as the paywall does; and on the dev build, where Test Store periods last 5 minutes (monthly) or an hour (Annual), show the time too, so a tester can tell a renewal happened. Also noted: the date is the local day (September 25 at 23:47 local was September 26 UTC), which is right for an athlete.

**Expected.**


**Actual.**
Seen at 03:47:22Z (Monthly) and after the Annual resubscribe (see notes).

**Evidence.**
- runs/123/04-A-07-008-subscription-monthly.png
- runs/123/37-A-07-008-subscription-annual.png

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): the price comes from the store; $9.95 exists only in the dev Test Store.
