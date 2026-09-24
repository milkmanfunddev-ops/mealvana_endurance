# 08-004 · Subscription screen for a cancelled, an ended and a Grant plan: Ends on, It ended on with Upgrade, Grace month or Pro from a code

- kind: followup-test
- status: open
- ticket: 08
- run: w7-20260924T1216Z
- screen: Subscription
- decision: 

**Steps.**
1. Cancel a running Test Store or sandbox subscription (ticket 09's path), open Settings → Subscription.
2. Let it end; open the screen again.
3. An account on a 30-day Grant (coach's own code), a 365-day giveaway code, and the Legacy grace month each open the screen.

**Expected.**
mp-495 and mp-558: cancelled shows "Ends on <date>. It won't renew." and Manage; ended shows "It ended on <date>…", Upgrade and Manage (Manage "stays after they cancel and the plan ends"). Grants per mp-615 (proposed): "Grace month, N days left" for 30 days ±1.5, else "Pro from a code, N days left", "1 day left", "Last day today", and no Manage. Note the open proposal that a coach's own 30-day code will read "Grace month".

**Actual.**
Not run. This run saw only the running, renewing state ("Subscribed", "Renews on September 24, 2026.", Manage, Redeem code, no Upgrade).

**Evidence.**
- runs/08/09-subscription-paid.png

**Decision quote.**
> 

**Triage.**
