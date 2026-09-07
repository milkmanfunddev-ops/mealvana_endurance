# Variant B — control-forward conversation flow

- **Source URL:** https://app.notion.com/p/364e3fdb754c812eb05ace7b12135f44
- **Snapshot date (as fetched):** 2026-05-18T01:24:28.634Z
- **Icon:** 🔀
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **Variant B — control-forward conversation flow**

## Purpose

This is the **Variant B** build brief for the cofounder disagreement test. It pairs with the existing prototype (Variant A — suggestion-forward, dish-led) to give users a head-to-head comparison. Same persona (Caroline). Same week. Same UI primitives that Claude Design already built. **Inverted conversational dynamic.**

The purpose is to faithfully represent Lee's hypothesis: **user-in-charge, ingredient-driven input, system surfaces options instead of proposing.** Variant B is not a strawman — it should feel like a thoughtful product in its own right. The test only works if both variants are credible.

---

## What's inverted from Variant A

| Dimension | Variant A (Xuan) | Variant B (Lee) |
|---|---|---|
| Opener | System leads with weather + training + season frame, then offers three curated pills | System asks what the user wants; input field is the primary affordance |
| Pills | Curated suggestions ("Steak", "Light & fresh", "Surprise me") that drive the conversation | Examples of what you could type ("I have leftover chicken", "What's on sale?"), shown as low-emphasis shortcuts beside the input |
| First system reply | **One** meal proposal with a recipe card | **Five** candidate meals in a carousel — user picks |
| Cards | Each card framed as "the recommendation" with on-card editing (servings, swap) | Each card framed as "a candidate to consider" with [+ Add to plan] as primary action |
| Confirmation | "Lock all three" as one decisive action | Plan completes when user adds three meals; no system-driven lock moment |
| Training context | System-imposed frame in opener and on every card | Available as an optional filter or annotation the user can apply, not a system-led frame |
| Deals | Proactively surfaced after lock | User-pulled — system asks "want me to check deals?" before sending to store |
| Cooking sessions | System organizes; user accepts | System suggests a grouping; user can drag to rearrange or use as-is |
| Memory drawer | "What MealBuddy knows about you" — trust layer | "What MealBuddy uses for recommendations" — control layer; stronger edit affordances |

The goal across all rows: **the user is the decision-maker; the system is the helper.**

---

## The 7-turn script

Same turn counter (1-7) and same phone frame as Variant A.

### Turn 1 — Open the conversation, don't lead it

**Assistant message:**
> *Hey Caroline. What's the week looking like for you? Tell me ingredients you want to use, a dish you're craving, or whatever you have in mind — I'll find dinners that fit.*

**Pills (low-emphasis examples, not prescriptions):**
- `I have leftover chicken`
- `Steak this week`
- `What's on sale?`
- `30-min weeknights`

**Free-text input is the primary affordance.** Visually weighted heavier than the pills. For the demo, pre-fill the input after a brief delay with: *"I have asparagus to use up. And I want steak this week."* The user taps send.

Notice: no weather frame, no training frame, no seasonal frame in the opener. Those are available downstream as filters if the user asks for them. The system starts by listening.

### Turn 2 — User states intent

**User bubble** (from the pre-filled input):
> *I have asparagus to use up. And I want steak this week.*

### Turn 3 — System surfaces a selection (not a proposal)

**Assistant message:**
> *Five dinners that work with steak, asparagus, or both. Tap to add any you want to your plan.*

**Horizontal carousel of meal cards:**
1. **Grilled Ribeye with Charred Asparagus** — uses both
2. **Steak Stir-fry with Asparagus & Peppers** — uses both
3. **Lemon Salmon + Roasted Asparagus** — uses asparagus only
4. **Asparagus Frittata** — uses asparagus + eggs
5. **Roast Chicken Thighs + Asparagus** — uses asparagus

Each card has the same visual structure as Variant A (photo, title, composition components) but the primary action is `[+ Add to plan]`. No card is highlighted as "recommended." Order is by ingredient match strength.

**No training tag on cards by default.** If user has added a "recovery-aware" preference in Memory, a small tag can appear; otherwise it doesn't.

### Turn 4 — User adds, asks for more or filters

User taps `[+ Add to plan]` on the first two cards. Both flip to a "Selected" state. Bottom tray updates with two thumbnails.

Then the user filters or asks for more. Options visible:
- Filter pills: `30-min options` · `Different protein` · `Pantry-friendly`
- Free text: "I need one more for Tuesday"

For the demo: user taps `30-min options`. Carousel re-filters to show only fast meals. User picks one.

### Turn 5 — Plan ready

When three meals are in the tray, a `Review plan` button appears at the bottom. User taps it.

**Assistant message:**
> *Three dinners locked in. Here's how I'd batch them — drag to rearrange, or keep as-is.*

**Cooking sessions card** appears with the suggested grouping, **plus a drag handle on each meal** and a `Use as-is` button. The user can override the grouping.

For the demo: user uses as-is.

### Turn 6 — Optional deal check

**Assistant message:**
> *Want me to check for deals this week before we build the shopping list?*

**Pills:**
- `Yes, check deals` (primary)
- `Skip, just build the list`

User picks `Yes, check deals`.

**Two deal cards** appear (peaches, asparagus) with `[+ Add to list]` per card. Same UI as Variant A's deal cards. User taps both.

### Turn 7 — Shopping list

Same as Variant A: aisle-grouped shopping list, meal-filter chips, `Send to Publix` CTA at the bottom.

---

## Memory drawer (control-forward reframing)

**Header text** changes from "What MealBuddy knows about you" to:

> **What MealBuddy uses for your recommendations**

Same profile, household, logistics, training, and learned-over-time sections as Variant A. Two structural changes:

- **Every section has a visible "Edit" affordance**, not just an icon. The drawer feels like a control panel rather than a viewer.
- **A `+ Add a preference` button** at the bottom of the Learned section. The user can teach the system manually — the system doesn't only learn passively.

Framing nudge: every label can be slightly more agentive. "Loves steak after hard training days" stays as a learned fact, but the user can also add: "Always include something with leafy greens." The drawer reads as **owned by the user**, not as a database the system maintains.

---

## UI components (same primitives, different uses)

Claude Design already built these for Variant A; Variant B reuses them:

- Phone frame + header (unchanged)
- Turn counter (unchanged)
- Chat bubbles (unchanged)
- Pills (same component, used differently — examples beside an input rather than curated choices)
- Meal card (same component — photo, title, composition, action button)
- Selected meals tray (same component, used more actively as user adds)
- Cooking sessions card (same component, with drag affordances added)
- Memory drawer (same structure, header text changed + edit affordances stronger)
- Shopping list (unchanged)
- Restart demo button (unchanged)

**New component needed:** a horizontal carousel layout for displaying 5+ meal candidates at once. Claude Design likely has this pattern available; if not, simple horizontal scroll with snap.

---

## Implementation notes for Claude Design

1. **The input field is the hero in Turn 1.** Weight it visually above the pills. Pills should look like example chips beneath the input, not the primary choice.
2. **Pre-fill the input after a brief delay** so the user doesn't have to type during the demo (same pattern as Variant A's send button activation).
3. **The carousel in Turn 3** is the key new layout. Five cards horizontally, swipeable. Each card retains the same component structure as Variant A's meal cards.
4. **No card is highlighted as "primary."** No badge that says "Recommended" or similar. Cards are equal candidates.
5. **The training-context tag is hidden by default.** If kept, it's a subtle annotation on cards, not a coral-tinted prominent tag. (Or remove entirely — cleanest for the test.)
6. **Filter pills in Turn 4** appear after the user has added at least one meal. They give the user more control without imposing options upfront.
7. **Drag handles on the cooking sessions card** in Turn 5. Users can rearrange before accepting.
8. **Deal check is opt-in in Turn 6** — the system asks rather than surfaces.
9. **Memory drawer header reframe** — "uses" not "knows." Edit buttons visible on every fact.

---

## Things deliberately NOT in Variant B

So the contrast with Variant A is clean and the test is interpretable:

- **No system-led opener frame.** No weather + training + season recital before the question. The system asks first.
- **No single-meal recipe card as the first response.** The first response is always a selection.
- **No "Lock all three" decisive moment.** The plan completes when the user has added three; no system-driven confirmation step.
- **No proactive deal surfacing.** Deals are user-pulled.
- **No prominent training-context tags on every card.** Available as a filter, not a frame.
- **No "Selected" states that bind the user to the system's frame.** The user picks freely from the carousel.

---

## What this enables in the test

With Variant A and Variant B side-by-side, the interview protocol from the [research design doc](https://www.notion.so/363e3fdb754c81c8b826da7b7e3f5889) becomes runnable (see `testing-two-cofounder-disagreements-research-design.md` in this archive). Each user sees both variants, counterbalanced order, same task: plan three dinners.

The metrics defined in that doc — time to confirmed plan, felt understood, felt in control, felt rushed, would use again, preferred variant — will produce comparable numbers across variants.

Most importantly: Lee should review this brief and confirm it represents his vision faithfully. If anything in here is a strawman or a soft version of his position, fix it before the build. The test is only as good as the fairness of Variant B.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).
