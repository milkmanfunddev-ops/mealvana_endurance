# Testing two cofounder disagreements — research design

- **Source URL:** https://app.notion.com/p/363e3fdb754c81c8b826da7b7e3f5889
- **Snapshot date (as fetched):** 2026-05-17T23:54:58.927Z
- **Icon:** ⚖️
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **Testing two cofounder disagreements — research design**
- **Note:** This page is linked from `variant-b-control-forward-conversation-flow.md` (as "research design doc") and is an EXTRA page fetched beyond the original 7, since it directly defines the metrics/protocol referenced by the Variant A/B test.

## What this is

Xuan and Lee disagree on two foundational product assumptions. Both positions are coherent. Both have evidence behind them. Neither can be resolved by argument — only by user data.

This document defines the research that would settle (or refine) both disagreements. It is deliberately neutral: the test design is structured to falsify either position, not to confirm a preferred one. Both founders should review and approve the protocol before running.

---

## The two disagreements

### Disagreement 1 · Suggestion-forward vs. user-driven control

**Xuan's hypothesis:** Users want to be told what to eat. Meal planning is a decision-fatigue problem. The product wins by leading with confident suggestions and letting users push back where needed.

**Lee's hypothesis:** Users want to be in control. Suggestions feel patronizing. The product wins by surfacing options and tools, letting users compose their own answer.

**Real-world precedents on both sides.** Spotify Discover Weekly and Stitch Fix are suggestion-forward and beloved. Pinterest and Google Search are control-forward and beloved. Both models work — for different users, at different times, for different mental loads. The question for Mealvana is *which one is the right default for endurance athletes planning meals.*

The current prototype encodes Xuan's hypothesis. To test fairly, we need a Lee variant.

### Disagreement 2 · Recipe-level vs. ingredient-level entry

**Xuan's hypothesis:** Users think in named dishes. "Chicken teriyaki." "Salmon bowl." The dish is the unit. The system serves variety by recombining components inside dish patterns — HungryRoot-style lego.

**Lee's hypothesis:** Users think in ingredients. "I want chicken and broccoli tonight." The ingredients are the unit. The system maps those to dishes that fit. The recipe is downstream of the inputs.

These are two different entry points into the same downstream system, but they imply very different UX and information architecture. The current prototype encodes Xuan's view (the conversation surfaces dishes, components are inside).

---

## Why these can't be debated to resolution

Both disagreements are about what's in the user's head when they sit down to plan meals. Neither founder has direct access to that. Any argument is a stalemate of plausible intuitions. The cheapest path to a real answer is six structured user sessions.

There is also a third possible outcome neither founder may want to hear: **both are partially right, and they correlate.** Suggestion-lovers may also be dish-level thinkers; control-lovers may also be ingredient-level thinkers. If that's true, you don't have one user — you have two segments, or one user with two modes (busy weeknight vs. relaxed weekend). The test is designed to surface that pattern if it exists.

---

## Test design 1 · Suggestion-forward vs. control

Build two prototype variants of the same planning conversation. Use the existing prototype as Variant A; build a stripped-down Variant B that mirrors Lee's vision.

### Variant A (Xuan's): Suggestion-forward

Uses the current prototype unchanged. Opener:

> *Hey Caroline. Heat wave through Wednesday, then cooling. Your brick on Sunday means recovery's the theme. I'm thinking grilled ribeye for Thursday and salmon for Sunday — want to see the week?*

The system proposes a complete plan up front. User accepts, modifies via card actions, or rejects.

### Variant B (Lee's): Control-forward

New variant. Opener:

> *Hey Caroline. What are you in the mood for this week? You can name dishes, ingredients, or just give me a vibe.*

The system asks for input first. User specifies what they want. System then returns matching options for the user to select from. No upfront plan.

### Protocol

Within-subjects: each user tries both variants. Counterbalance the order — half see A first, half see B first — so order effects cancel.

Same goal in both: plan three dinners for the week.

### Metrics (defined in advance)

| Metric | How to capture |
|---|---|
| Time to confirmed plan | Stopwatch from opener to lock |
| Felt understood (1-7) | Asked after each variant |
| Felt in control (1-7) | Asked after each variant |
| Felt rushed / overwhelmed (1-7) | Asked after each variant |
| Would use again (1-7) | Asked after each variant |
| Preferred variant (forced choice) | Asked at the end |
| Reason for preference | Free response |
| Behavioral: did the user modify the proposal in A? How much? | Observed |
| Behavioral: did the user feel stuck or restart in B? | Observed |

### Interpretation grid

| If we see... | It means... |
|---|---|
| A wins on time, satisfaction, NPS across most users | Xuan's hypothesis holds — lead with suggestions |
| B wins on time, satisfaction, NPS across most users | Lee's hypothesis holds — lead with input collection |
| A wins on "felt understood," B wins on "felt in control" | Both right — surface the tension as a setting or a mode |
| Strong preference splits 50/50 by user, not by mood | Two segments — Mealvana needs both modes or a clear positioning choice |
| Same user prefers A on weeknights, B on weekends | Mood-dependent — one product, two entry points |

---

## Test design 2 · Recipe-level vs. ingredient-level entry

This runs in two stages: open-ended observation first, then a forced-choice test.

### Stage 1 · Natural-language capture

Before showing any prototype, ask each user the same open question:

> *Imagine it's Sunday afternoon and you're planning dinners for the week. Without thinking about apps or tools — tell me, out loud, the first three things you'd want.*

Capture verbatim. Code each response:
- **Dish-level:** "Chicken teriyaki," "Stir fry," "Salmon bowl"
- **Ingredient-level:** "Chicken and broccoli," "Steak," "Whatever's on sale"
- **Method-level:** "Something on the grill," "One-pan"
- **Mood-level:** "Something light," "Comfort food"
- **Constraint-level:** "Under 30 minutes," "Cheap"
- **Mixed:** combinations of the above

The distribution across N=15-20 users tells you what mental model dominates *before* any product framing biases them.

### Stage 2 · Forced-choice entry path

Within Variant B (the control-forward variant), present two entry paths and observe which the user gravitates to. Phrase neutrally:

> *Two ways to start. You can name dishes you want (steak teriyaki, salmon bowl), or name ingredients you want to use (chicken, asparagus). Which feels more natural?*

Observe their answer, then let them complete the planning task that way. Optionally have them try the other path too.

### Metrics

| Metric | How to capture |
|---|---|
| Natural-language distribution | Coded from Stage 1 |
| Preferred entry path (Stage 2) | Direct ask |
| Time-to-meal in each path | Stopwatch |
| Variety / surprise in results | "Did the system show you anything you wouldn't have thought of?" |
| Felt-right rating | 1-7 per path |

### Interpretation grid

| If we see... | It means... |
|---|---|
| Stage 1 dominated by dish-level responses (>60%) | Xuan's hypothesis holds — design around dishes |
| Stage 1 dominated by ingredient-level responses (>60%) | Lee's hypothesis holds — design around ingredients |
| Stage 1 mixed (40-60% split) | Both mental models are valid; design needs to accept both |
| Stage 2 preference splits along same lines as Stage 1 | Mental model is stable per user → segments |
| Stage 2 preference flips depending on time pressure or mood | Same user, two modes |

---

## The 2×2 to plot at the end

For each user, place them on this grid:

```
                 │ Dish-level entry        │ Ingredient-level entry
─────────────────┼─────────────────────────┼──────────────────────────
Suggestion-      │ Quadrant 1              │ Quadrant 2
forward          │ "Tell me what to make"  │ "I have these — surprise me"
                 │ (HungryRoot)            │ (Blue Apron meal kits)
─────────────────┼─────────────────────────┼──────────────────────────
Control-         │ Quadrant 3              │ Quadrant 4
forward          │ "I want chicken         │ "I have these — show me
                 │ teriyaki — show me how" │ what I can make"
                 │ (NYT Cooking, recipe    │ (SuperCook, BBC Good Food's
                 │ search)                 │ ingredient search)
```

Where do endurance athletes cluster? That's the answer to both disagreements at once. If they pile into one quadrant, you have a clear product. If they spread across two or three, you have either a segment story or a mode story.

---

## Sample size and bias controls

**Six to eight users** for the first pass. Within-subjects, both variants, counterbalanced. Mix of training disciplines (run, tri, cycle) and cooking experience.

**Critical bias controls:**
- The interviewer should not be either founder. If Xuan runs it, suggestion-forward wins; if Lee runs it, control-forward wins. Use a third party (Rui, Haibin, or an unbiased external).
- Stage 1 (natural-language capture) must come *before* the user sees any prototype.
- Variant order must be randomized.
- Metrics must be agreed and locked before any session is run. Re-defining "felt understood" after seeing data is how disagreements survive bad research.
- Both founders watch the recordings independently, code observations independently, then compare. Disagreement on what was said is itself a finding.

---

## What "settled" looks like

After six to eight users, you'll have a clear pattern on at least one of three outcomes:

1. **One position dominates.** One founder updates their priors.
2. **Both are right for different users.** You have segments; positioning becomes a strategic choice (which segment to win first).
3. **Both are right at different moments for the same user.** The product becomes one entry experience with a mode switch — accept that complexity and design for it.

Any of these outcomes is more useful than continuing to argue. The cost of running the research is roughly two weeks of build for Variant B and one week of interviews. The cost of *not* running it is months of design debate and a product that splits the difference badly.

---

## What to do this week

1. Both founders read this document and approve (or amend) the metrics before any build starts.
2. Define who runs the interviews (must not be either founder).
3. Scope Variant B build (the control-forward prototype). Likely 2-3 days using the existing components.
4. Recruit 6-8 endurance athletes with mixed training disciplines and cooking experience.
5. Run Stage 1 + Stage 2 across one week of interviews.
6. Both founders watch and code recordings independently; sync on findings together.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).
