# 📌 User Interview Result

- Source URL: https://app.notion.com/p/27ae3fdb754c8161ac57d6a42b0910ea
- Snapshot date: 2026-06-22
- Ancestor path: User Research → 🛠️ Product & Engineering
  - Parent: https://app.notion.com/p/27ae3fdb754c80e0beb3f656c7f827e5 ("User Research")
  - Grandparent: https://app.notion.com/p/2d9e3fdb754c819aa101c5fb5fcfa632 ("🛠️ Product & Engineering")

Note: this page is a synthesis/rollup of interview coding, not a generic feature list — its content is centrally about meal planning and nutrition-app adoption, so the full page is transcribed below. Several top-of-page sections ("All dovetail result 'doc'", "Potential Features", "Special topics") link out to embedded external objects (likely embedded Dovetail boards/links) that this tool could not resolve/render as text — noted as [unresolved embedded object] below. The bulk of the page content — the "Aug 15" toggle section with coded interview findings — rendered in full and is transcribed verbatim.

## All dovetail result "doc"
[unresolved embedded object — external Dovetail link, not resolvable via this tool] (block id `27ae3fdb-754c-81d6-891c-ca0c88dcf54b`)

## Potential Features
[unresolved embedded object] (block id `27ae3fdb-754c-8163-ad03-e0e6f716b92f`)
[unresolved embedded object] (block id `27ae3fdb-754c-81bd-a59a-f0f62ef1aad0`)

## Special topics
[unresolved embedded object] (block id `27ae3fdb-754c-8185-89b2-cf9088f25be9`)
[unresolved embedded object] (block id `27ae3fdb-754c-816e-a452-dbde0ce4ae54`)
[unresolved embedded object] (block id `27ae3fdb-754c-8144-b3f7-f41c7aee1e65`)
[unresolved embedded object] (block id `27ae3fdb-754c-819a-80b7-fcf6d19103ca`)

## Aug 15 (toggle section, expanded)

Based on 3 interviews: Meredith, Xuan, Bradley & Matt

### Top insights

1. **End-to-end beats "numbers."**
   Athletes won't stick with (or pay for) tools that stop at macro targets. They want **training → meals → one-tap grocery/cart**. This "last mile" both removes blockers and is the clearest reason to pay (time saved + decisions made).

2. **Weekly retention = ultra-low effort on weekdays, precision on key days.**
   People want **"easy mode" Mon–Fri** (minimal typing, quick swaps) and **"precision mode"** for long runs/race week. Effort tolerance varies by phase; design the app to **flex** accordingly.

3. **Trust comes from credible, prescriptive guidance — with receipts.**
   Users follow plans that look **coach/authority-backed** (credentials + citations) and **personalized** (body size, GI tolerance, iron needs). Heavy logging erodes trust/usage; lightweight **"do this at 6:30am / gel at 9:40"** steps scheduled on their training calendar drive adherence.

4. **Re-engagement is event-driven, but currently too late.**
   Athletes come back around **carb-loading and race week**, often only in the final days. Build **race-date–aware playbooks** that start **2–3 weeks out** with practice reps (breakfast, GI-safe options, travel stand-ins).

5. **Personalization must be "proven by me," not just calculated.**
   Confidence comes from **test → log → detect pattern** (e.g., white rice → GI issues). The app should learn from quick journals and surface **"worked for you"** evidence, not just formulas.

6. **GI risk and logistics cause most "didn't go as planned" failures.**
   Under-fueling (to avoid GI distress/calories) and last-minute, unpracticed changes drive bonks and churn. Ship **GI guardrails** (practice flags, red/yellow/green foods, Plan-B substitutions, "no glass containers"/travel cues).

7. **Users already operate on a weekly cadence.**
   Mid-week planning (Wed–Fri) + **weekend shopping** is a common rhythm. Auto-generate plans on Wed, finalize **plan→grocery** by Fri, and send a **long-run prep** card for Saturday/Sunday.

### Summary and quotes by code

#### Feature Needed
End-to-end, low-effort "auto-pilot to plate."
1. They don't want macro numbers or heavy logging
2. They want the app to **turn training into exact meals and a ready-to-buy grocery list**, with **minimal typing**
3. **smart personalization** that learns from their experience (GI/iron issues, food prefs, bulk-cook schedule)
4. **tells them what to do**.

#### Habit
They organize food around a weekly rhythm tied to long runs and the weekend.
Planning mid-week (Wed–Fri) and shopping on the weekend.
Many only seek guidance in the final pre-race week.

#### Need for nutrition information
- Athletes want prescriptive, science-backed, but personalized guidance
- which is needed for high-stakes windows (long runs, race week, travel).
- When credible sources tell them *exactly what to do* (what to eat, when, how much) and the plan reflects their size, tolerance, and phase, they'll follow it.
- Generic rules or one-size-fits-all tips push them back to trial-and-error and influencer PDFs.

#### Professional Knowledge
- When guidance looks like it comes from a real sports-nutrition authority (credentialed, science-backed, and personalized), the trust goes up.
- Athletes will follow a plan "on schedule" if it's clearly evidence-based, sized to them (e.g., body size, iron needs, GI tolerance), and presented by credible experts.
- Trust drops if it requires heavy self-tracking.
- They shy away when tools ask them to do the math or log everything.

> *"If a **sports nutrition authority** told me exactly what to eat for a long run, I'd follow it… if it's **on the schedule**, I do it."*

#### Reason for paying
- People pay when the app does the last mile for them and saves time — i.e., turns numbers into decisions and a grocery-ready plan.
- They won't pay for information they can get free.

> *"If something **saves me time**… then I may want to pay for it."*
> *"I'd think twice… if I can get that information for free."*

#### Personalized need
- They want personalization that's grounded in their own evidence and tuned to who they are (age, gender, diet, stage), with adjustable complexity.
- Generic formulas aren't enough; confidence comes from testing, tracking, and seeing "what worked for me," plus targeted guidance for issues like GI tolerance and iron (e.g., vegetarian female athletes).
- Newer athletes want simpler flows; advanced/elite users will invest in more detail.

> *"Personalization should come through **my own experience**… tested → worked → higher confidence."*

#### Nutrition Planning Process
They already follow a weekly, phase-driven workflow: intuitive day-to-day eating, a mid-week ramp toward long-run carb loading, weekend shopping, and tighter protocols in race weeks.

#### Ease of use
1. Ultra-low effort. They want the app to do the work, surface answers in 1–2 taps, with minimal typing, especially during weekdays.
2. They'll tolerate more effort only on key days (long runs/race week).

> *"I will pick easy… if Monday–Friday, I need something easy. I don't have time."*

#### Didn't go as planned (for nutrition needs)
Most breakdowns happen at crunch time because they deviate from the plan. Either under-fueling to avoid calories/GI issues or making last-minute, unpracticed changes driven by logistics.

> *"I could take in more fuel, but I'm scared of getting sick."*

#### Retention / Coming Back
They return when a race is near and they need simple, trusted, phase-specific guidance (esp. carb-loading), but without prompts, they only re-engage in the final week, which is too late to practice.

> *"A lot of runners… only the last week I need to start to look up the information… but it should have been taken care of earlier."*
> *"Race-day performance is the result of daily training and nutrition habits, not just race-day eating."*

#### Pain Points
1. They don't trust or stick with nutrition tools that don't help them avoid GI problems and under-fueling in the moments that matter most (day-before/morning-of runs, race morning, travel).
2. Fear of getting sick → conservative fueling (or winging it) → bad sessions → loss of trust in tools.

#### Blockers in using the tool (or when they stopped using the tool)
1. When the app doesn't convert targets into actual food and a fast grocery plan, users default to free info and intuition.
2. Not end-to-end: stop at nutrition "numbers" and make them do the last mile themselves.
3. Too much work: demand heavy, ongoing tracking.

> *"A lot of apps… do not deliver end-to-end results… fueling tells you carbs but not what your shopping list looks like… I still need to do a lot more work."*

#### Tools used
- meal app
- expert PDFs
- MyFitnessPal (until friction/paywalls)
- coach schedule
- mental/physical notes
- Whatever is low-effort and tied to their training calendar.
- experienced athletes may rely on intuition
- Recommend simple tools for beginners.

#### Variance in needs
- Age & life stages
- experience level (beginners want guidance; advanced users want control)
- diet
- body size
- GI tolerance
- Weekday simplicity vs. race-week precision
- daily plan: school, work, etc.

## Comments/Discussion
None found on this page (no `<page-discussions>` indicator returned by the fetch call).
