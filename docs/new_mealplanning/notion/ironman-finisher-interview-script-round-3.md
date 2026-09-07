# 🏊 Ironman Finisher Interview Script — Round 3 (Targeted)

- Source URL: https://app.notion.com/p/36ee3fdb754c8140bbbdf95cc434c163
- Snapshot date: 2026-05-28
- Ancestor path: User Research → 🛠️ Product & Engineering
  - Parent: https://app.notion.com/p/27ae3fdb754c80e0beb3f656c7f827e5 ("User Research")
  - Grandparent: https://app.notion.com/p/2d9e3fdb754c819aa101c5fb5fcfa632 ("🛠️ Product & Engineering")

## Purpose
A targeted ~40-minute interview with an Ironman finisher. This is **not** a repeat of the Round 2 hypothesis script. Most of the original hypotheses are now saturated across 8 user interviews + the Rachel expert interview. This round is scoped deliberately to (a) the fueling depth only an ultra-endurance athlete can provide, (b) feedback on the race-day calculator, and (c) the new product directions that emerged from Round 2 and Rachel that have **not yet been tested with a user**.

## What's settled and is NOT being re-tested
- **H-4 (planning before shopping):** Settled. 6 of 8 participants wing it from staples, including the expert. No more confirmation needed.
- **H-5 (recipe vs. ingredient):** Settled. Component-driven base with recipe inspiration as the "stuck/bored" feature. Dropping the A/B paper test.
- **H-2 (macros):** Settled enough. Split population + Rachel's clinical caution. Dropping the macro A/B.
- **H-1 (prescription):** Mostly settled, refined to "augment, don't replace."

## What this round IS testing
1. **Race-day / during-event fueling** — the unique value of an ultra-endurance finisher.
2. **The race-day calculator** — does this athlete confirm Rachel's "it's too much / no one thinks in milliliters" critique?
3. **"Diagnose and add" vs. "generate a plan"** — the new product model from Rachel, never tested with a user.
4. **H-3 (conversational vs. button)** — still open; only 2 clean data points. Heavy-AI-user-predicts-chat segmentation hypothesis.
5. **Positioning** — performance vs. weight vs. numbers framing (handle the weight dimension carefully).

---

## Script (~40 min)

### Section 0 — Setup (2 min)
> Thanks for making time. I want to learn from you as an Ironman finisher — you've done the most sophisticated fueling any athlete does, and that's exactly what I want to understand. We'll talk about how you actually fuel and eat, I'll show you one thing we built and get your honest reaction, and I'll describe a couple of concepts. No right answers. Recording OK?

### Section 1 — Quick behavioral baseline (3 min)
*Establish their pattern fast. Don't belabor — you already know the population winds up here.*
- "Walk me through how you decide what to eat day to day during a big training block. Do you plan, wing it, meal prep?"
- "Last grocery trip — list or no list? How did you decide what to buy?"
- "When you cook, recipe or improvise?"

Move on once you have the shape. This section is context, not the main event.

### Section 2 — Race-day and during-event fueling deep dive (10 min)
**This is the gold. Protect the time. Let them run.**
- "Walk me through your fueling plan for your last Ironman — the days before, during the race, and recovery after."
- "How did you build that plan? Where did it come from — a coach, trial and error, research, a nutritionist?"
- "What went wrong the first time you tried to fuel a long event? What do you do differently now?"
- "How do you handle gut training — do you have a protocol for building carb tolerance?"
- "Sodium, cramping, GI issues, bonking — which have you dealt with, and how did you solve it?"
- "During the race itself, how much are you thinking in numbers versus just executing a routine you've practiced?"

Every time they say "I just…" or "I always…" — that's a learned heuristic. Probe it: "how did you figure that out?"

### Section 3 — Pressure-test the race-day calculator (6 min)
Show them the actual race-day plan tool. Frame neutrally — *don't* say "I need your help" (that invites validation). Say:
> "Here's a race-day fueling plan our tool generates. Walk me through it out loud — what you'd actually use, what you'd ignore, what's missing."
- "What would you actually act on here?"
- "What's noise for you?"
- *Listen specifically:* do they confirm Rachel's critique — too much numerical precision, can't measure 191ml, think in "hit every aid station" terms not amounts?
- "If this were stripped down to only what you'd use on race morning, what would be left?"

### Section 4 — "Diagnose and add" vs. "generate a plan" (6 min)
**The most important new question in this script.** Describe both verbally, no screens.
> "Option A: every Sunday the app builds your week from scratch — 21 meals and a shopping list, ready to go."
> "Option B: you tell the app what you normally eat in a few days, and it tells you what you're missing and what to add, anchored to your training — like, 'add a snack at 3pm before your evening run, you're short on carbs Saturday before the long ride.'"
- "Which of those would actually be useful to you? Why?"
- "Which one would you still be using in two months?"
- *Follow-up:* "Has anyone ever built you a meal plan from scratch? Did you follow it? What happened?"

This tests whether the diagnose-and-add model (what Rachel actually does, and what dodges the 'I tried meal planning and stopped' failure mode) resonates more than the generate-a-plan model both prototypes assumed.

### Section 5 — Conversational vs. button-driven (6 min)
*Still-open hypothesis. Keep the layered structure that worked with Madhu.*

First, surface AI priors:
- "Tell me about an AI chatbot you've used in the last month. What for?"
- "When has AI been useful for you, and when has it been annoying?"

Then the two vignettes (read aloud, equal tone, no charm words):
> **A.** Sunday morning. You tap "Plan Week." A grid of meals and a shopping list appears. Swap any meal from three alternatives. 90 seconds.
> **B.** Sunday morning. A text conversation starts. The assistant asks one or two questions, proposes options, you accept or swap, the plan builds as you go. About 8 minutes.
- "Which would you tap first on Sunday morning? Why?"
- **Killer follow-up:** "Is that about the experience, or the time? If both took the same time, would your answer change?"
- "Given what you said about AI earlier — does that change how you feel about Option B?"

### Section 6 — Positioning probe (3 min)
*Handle the weight dimension carefully. Let them frame it. Don't lead toward weight.*
- "When you think about your nutrition, what's it mostly about for you — hitting numbers, fueling performance, managing weight, something else?"
- "Has that changed over your time as an athlete?"
- *If disordered-eating signals surface, note them, do not probe aggressively. Redirect gently to performance framing.*

### Section 7 — Commitment and close (3 min)
**Non-negotiable — this is the only behavioral intent data the interview produces. Don't skip it like last two rounds.**
- "Of everything we talked about, what one thing would change your fueling or eating routine the most if it existed?"
- "We're piloting this — every week you'd get a plan or recommendations built around your training, free for the first month. Want to sign up?" → **capture email immediately if yes.**
- "Anything I should have asked that I didn't?"

---

## Moderator reminders
1. **When you hear something important, STOP and double-click.** This is your one consistent gap across Landon, Madhu, and Rachel. With an Ironman finisher talking fueling, the gold is in the tangents. Let them run.
2. **No app demo until the research is done.** If you want product feedback beyond the race-day calculator, schedule a separate session. The Section 3 calculator test is the only product surface in this script — keep it contained.
3. **Ask one question, wait, then the next.** No stacked questions.
4. **Don't say "too much, right?"** or any leading confirmation. After they give a verdict, ask "say more about what specifically."
5. **Do the commitment ask in Section 7.** Skipped in the last 3 interviews. It's the data that survives.
6. **Weight this person's fueling input heavily, their mass-market preferences lightly.** They're a power user (n=1). Great on fueling depth; not representative of the median user's wants.

---

## After this interview
This is the last discovery interview before building. The hypotheses are saturated; the marginal interview now teaches less than a prototype would. Next step: build a thin version of the **diagnose-and-add** model and put it in front of Landon, Madhu, and Rachel, who've all agreed to test the dev build.

**Gut check before scheduling:** what would this athlete have to say to actually change the product direction? If "nothing," the interview is confirmation-seeking — skip to building. If there's a real answer (race-day fueling, the diagnose-and-add model), it's worth doing. Likely the latter, but check the motive first.

## Comments/Discussion
None found on this page (no `<page-discussions>` indicator returned by the fetch call).
