# User interview plan — MealBuddy UIUX prototype hypotheses

- **Source URL:** https://app.notion.com/p/363e3fdb754c811f9051e210771c14f9
- **Snapshot date (as fetched):** 2026-05-17T23:22:42.325Z
- **Icon:** 🎯
- **Ancestor path:** Homepage › [unnamed] › [unnamed] › Features › Technical and Product Documentation › (data source: Technical and Product Documentation) › AI Assistant › **User interview plan — MealBuddy UIUX prototype hypotheses**

## What we're testing

A ~30-minute session per user, walking them through the MealBuddy planning prototype. Audience: endurance athletes (primary) and 1-2 nutrition coaches if accessible.

These interviews are not adoption tests — one sitting won't tell us whether someone would use this weekly. What they will tell us: **what people notice, understand, miss, and find believable.** Every design decision in the prototype encodes a bet. The point is to find out which bets hold.

---

## The five hypotheses to focus on

Ranked by strategic stakes — H1 and H2 are bet-the-product calls; H3-H5 are core UX bets the product depends on.

### H1 · Training-aware framing beats macro numbers

*"Thursday · post-hill recovery" tells an athlete more than "580 kcal, 42g protein."*

**Holds if:** They engage with the training context tag. They use training-adjacent language unprompted ("for after my long run," "a recovery dinner"). They don't ask where the numbers are.

**Breaks if:** They explicitly ask "what are the macros?" early. They scan past the training tags. They describe meals in nutritional terms unprompted.

**Probe:** Show the ribeye card. "What's most important to you on this card?" Don't lead. Wait.

---

### H2 · The deal-stitched-to-meal moment feels like intelligence

*"Peaches 25% off — already in Thursday's salad, bump for grilled side too" is the marquee differentiator. This is the moment that should make them say "how did it know?"*

**Holds if:** They light up. Comment unprompted. Connect the deal back to the locked meal. Say something like "oh that's smart" or "that's actually useful."

**Breaks if:** They scroll past. Treat it like a generic sale flyer. Don't notice the connection. Or worse: it feels manipulative ("are you trying to upsell me?").

**Probe:** Pause on Turn 6 deal cards. "Tell me what you're seeing here." If they don't mention the connection back to the locked meals, follow up: "and why this peach card specifically?"

---

### H3 · Card-scoped actions are discoverable

*Athletes find the serving editor and swap action on the card without prompting. Pills are only used to advance the conversation.*

**Holds if:** When asked to change servings to 4, they tap +/- on the card. When asked to swap salmon, they tap ⇄ Swap on the card.

**Breaks if:** They look at the input field. Search the pills. Ask the assistant directly. Don't find the on-card affordances.

**Probe:** After Turn 4 cards appear, ask two questions: "How would you change the servings to 4?" and "What if you don't want salmon — how would you swap it?"

---

### H4 · The system feels like it knows them specifically

*Not generic. Not creepy. Distinctly Caroline-shaped.*

**Holds if:** They use words like "personalized," "tailored," "it knows me." They notice the training week reference, the cooking session rhythm, the local store.

**Breaks if:** They describe it as "AI suggestions," "meal planner," or "the algorithm." Generic language is the tell.

**Probe:** After the full demo: "If you described this to a teammate in one sentence, what would you say it does?"

---

### H5 · The memory drawer feels empowering, not surveillance

*The trust layer reads as "you're in control" rather than "we collect everything."*

**Holds if:** They scroll with interest. Notice individual facts. Ask about editing. Express they like seeing what's known.

**Breaks if:** They get quiet. Say "this is a lot." Express concern about data. Want to close it quickly.

**Probe:** Open the Memory drawer. "Take a moment to look through this. What's your reaction?" Then silence. Let them fill it.

---

## Secondary hypotheses (probe if time allows)

- **Composition view (hero + circular insets) reads as a meal of swappable parts** — do they treat the components as distinct items, or read the meal as one named thing?
- **Free-text input is valued enough to justify mixing channels** — do they prefer typing or tapping pills? Do they try to type in the input field unprompted?
- **Cooking sessions match their actual cooking rhythm** — do they batch-cook 2-3x/week or cook daily? Does the cooking-sessions card describe their reality?
- **They feel ChatGPT couldn't do this** — ask directly: "Could you get this from ChatGPT?" Their answer reveals whether the differentiation is visible.
- **The 5-minute arc is the right length** — too slow, too fast, or just enough to feel substantial?

---

## Things to watch, not ask

Observation > self-report. People underrate what they notice and overrate what they want.

- Where they hesitate (confusion is data)
- What they comment on unprompted (memorable moments are data)
- Whether they try to type vs. tap (interaction preference)
- Eye movement: do they read training context tags or skim past?
- Pauses on macro absence — do they notice the missing numbers, or not?
- What they remember at the end vs. what they passed over in the moment

---

## Suggested interview structure (~30 min)

1. **Warm-up (3 min)** — current meal planning tools, what works, what frustrates. Sets the comparison baseline.
2. **Driven walkthrough (10 min)** — they tap through the prototype. You observe. Don't interject unless they stall.
3. **Targeted prompts (5 min)** — the three probes on H1, H2, H3 from above.
4. **Memory drawer reaction (5 min)** — open it, ask, wait.
5. **Open reflection (5 min)** — "How does this compare to how you plan meals today?" "Could you get this from ChatGPT or another tool?"
6. **Wrap (2 min)** — willingness to be re-interviewed after iterations.

---

## Signals that we're wrong

Listen specifically for these. One per user is a flag; two is a finding.

- *"I'd want to see the macros somewhere."* — macro-free needs a hidden details view
- *"I didn't see how to change the salmon."* — swap discoverability fails
- *"Sure, peaches are cheap, fine."* — deal moment doesn't land
- *"This feels like another meal planner."* — personalization story isn't landing
- *"Why does it know that about me?"* — memory feels invasive
- *"I'd just ask ChatGPT."* — differentiation isn't visible to the user
- *"How would I do X?"* (repeated for multiple actions) — affordance design fails

---

## Sample size

Four to six athletes will surface the strongest signals. If you can get 1-2 nutrition coaches alongside, you'll get a useful contrast — athletes react to personalization, coaches react to trust and auditability.

Don't wait for 10 before acting on what you hear. Interview three, look for repeated signals, iterate the prototype, interview three more. The point is to find what's clearly wrong fast — not to certify what's right.

---

## What to write down per interview

For each session, a one-page summary:
- Athlete profile (sport, training volume, current planning tool)
- For each hypothesis: held / broke / unclear, with one quote each
- Top three quotes (verbatim, with timestamp if recorded)
- Top three unprompted reactions
- Any spontaneous comparisons (to ChatGPT, MyFitnessPal, their current tool)
- One sentence: what surprised you?

The last question is the most important. Surprise is where new design ideas come from.

---

## Comments / discussion threads

None found (no discussion markers returned by `notion-fetch` with `include_discussions: true`).
