# 08-002 · Jade has no entry point anywhere in the app (AiCoachBanner is mounted nowhere)

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Mealvana AI (AiCoachChatScreen, /jade)
- decision: 

**Steps.**
1. Grep lib/ for '/jade' and for AiCoachBanner( outside its own file (from code, unverified beyond the grep).
2. Look through Timeline, Events, Learn and Settings for a way into Mealvana AI.

**Expected.**
Lee's standing rule: AI surfaces stay on for dev, so an athlete can reach Jade from the app.

**Actual.**
The only push to '/jade' is inside ai_coach_banner.dart, and AiCoachBanner is constructed nowhere. None of the four tabs or Settings shows a Mealvana AI entry. The screen itself works by deep link (history loads), so it is wired but unreachable.

**Evidence.**
- runs/08/c11-jade.png the screen works by deep link
- runs/08/b11-timeline-after-signin.png Timeline with no Jade entry
- runs/08/b12-settings-after-signin.png Settings with no Jade entry

**Decision quote.**
> 

**Triage.**
