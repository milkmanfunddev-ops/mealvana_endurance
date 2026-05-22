---
title: Figma "AI Assistant" analysis + generative-UI widget catalog
generated_date: 2026-05-08
fileKey: yxeTEbBWK1rvUsPgcMGi0V
url: https://www.figma.com/design/yxeTEbBWK1rvUsPgcMGi0V/Mealvana-AI-Assistant
summary: Decomposition of Kyle's chat-AI flow + a 30-widget catalog for our generative-UI rebuild. Keeps Mealvana brand (Blackberry/Mango/Electrolyte/Cream) while adopting Figma's category-first entry, macro-chip vocabulary, inline rich cards, and day-modal pattern.
---

# 1. What Kyle drew (the Figma)

28 mobile screens (375×812) in a single `Chat V2` section. Walks the user from a cold launch through a finished meal plan with day-by-day modal browsing. Persona is **"Milkman"** (broccoli mascot). Color palette is navy + cream (different from our app's Blackberry/Mango). We **keep our brand colors** and steal the *patterns*.

## Screens we have inspected

| File | Node | Purpose |
|---|---|---|
| `01_default.png` | 2736:9315 | Cold launch — mascot hero + 8 category pills + composer |
| `02_active_chat.png` | 2736:3372 | User-asks state — Jade text on cream + user fridge photo + Edit link + iOS keyboard |
| `03_meal_plan_generated.png` | 2736:4263 | Jade returns 3 plan cards in a swipeable carousel + Regenerate link |
| `04_meal_plan_modal.png` | 2736:7389 | Modal sheet — plan title + macros + per-day expandable accordion w/ 2×2 photo grid |

(Figma MCP rate-limit hit before pulling the remaining 24 — patterns are clear from the strip overview + these 4.)

## 12 design moves to steal

1. **Mascot anchor** — large named-character avatar at the top of the empty state. Not a generic robot icon.
2. **Category-first entry** — 8 colored pills offering coarse goal categories (Athletic Performance, Budget, Health, Dietary, Weight Loss, Family-Friendly, Special Occasions, Ingredients on Hand). The user picks one before typing — it primes the conversation.
3. **Color-coded category vocabulary** — each pill has its own outline color (blue/red/yellow/green) signalling category type. We translate to our brand: Mango / Electrolyte / Dragonfruit / muted-Blackberry.
4. **No-bubble Jade text** — Jade's messages flow in Apercu directly on the surface. User messages get a soft pill bubble. (We already do this in Variant E — keep.)
5. **"Edit" affordance per user turn** — small ghost link below every user message lets them revise without retyping. (New for us.)
6. **Image attachments inline** — user can snap their fridge interior + send. Inline rich preview in the chat thread.
7. **Voice input** — microphone in the composer right of the input.
8. **Inline meal-plan card** — when Jade emits a plan it's a rich card: kcal pill, attendee count + bowl count, macros as colored chips, expand arrow.
9. **Macro chips with semantic color** — Protein, Carbs, Fat, Fiber, Sugar each get their own outline color. We map to brand: Mango (carbs), Electrolyte (protein), Dragonfruit (fat), muted (fiber), Cream-dark (sugar).
10. **Carousel of 3 options** — when Jade has multiple ideas, she shows them as 3 swipeable cards. User picks one. Default to the middle.
11. **Day-by-day expandable modal** — tap a plan card → modal sheet → days as accordion → each day expands to a 2×2 photo grid (B/L/D/Snack).
12. **Always-present Regenerate link** — small "↻ Regenerate" under any AI-generated content. One-click full retry.

## What we don't take

- **Navy-blue palette** → keep our Blackberry/Mango/Electrolyte. Translation table below.
- **"Milkman" name** → Lee asked for "Jade" earlier; we keep Jade. Maybe rename the avatar later.
- **Family / attendee count icons** → out of scope for endurance solo athletes. Cut them.
- **Photo-realistic meal images** → these require a content pipeline. We use photographic-style placeholders or icon-color blocks for v1, photo support deferred.

## Brand translation table

| Figma | Our brand | Used for |
|---|---|---|
| Navy `#1A2D5E` | Blackberry `#381633` | Primary text, dark surfaces, header icons |
| Cream `#F5EFE6` | Cream `#F8F6EB` | Primary surface (light mode) |
| Navy circle send | Mango pill send | Primary CTA in composer |
| Red outline pill | Dragonfruit `#DC2597` outline | Health / warning categories |
| Yellow outline pill | Mango `#F78B14` outline | Default "neutral" categories |
| Green outline pill | Electrolyte `#1CF9CF` outline | Goal / positive categories |
| Blue solid pill | Blackberry-light fill | Selected state |

---

# 2. Generative UI architecture

We adopt the **AI SDK Generative UI** pattern: Jade's tools return structured payloads, and the chat client renders a typed React component for each. The AI decides *what to show*; the client handles *how it looks*.

## Server-side (in `vite.config.ts` middleware → `streamText`)

Each tool exports `{ description, inputSchema, execute }`. The model invokes them; tool results stream as `tool-call` + `tool-result` parts on the assistant message.

```ts
// shape we adopt for every Jade tool
type JadeTool<I, O> = {
  description: string;
  inputSchema: z.ZodType<I>;
  execute: (input: I, ctx: { userId: string; supabase: SupabaseClient }) => Promise<O>;
};
```

## Client-side (in `components/shared/jade-message-renderer.tsx`)

```tsx
function JadeMessageRenderer({ message }: { message: UIMessage }) {
  return (
    <>
      {message.parts.map((part, i) => {
        if (part.type === "text") return <JadeText key={i} text={part.text} />;
        if (part.type === "tool-call") return <ToolPending key={i} toolName={part.toolName} />;
        if (part.type === "tool-result") {
          const Widget = WIDGET_REGISTRY[part.toolName];
          return Widget ? <Widget key={i} input={part.input} output={part.output} /> : null;
        }
        return null;
      })}
    </>
  );
}
```

A central `WIDGET_REGISTRY` maps tool name → component. Adding a widget = adding a tool + a registry entry.

## Stream protocol

Already on AI SDK v6 with `toUIMessageStreamResponse()`. Tool parts arrive as `tool-input-start` / `tool-input-delta` / `tool-call` / `tool-result`. The renderer handles each.

---

# 3. Widget catalog (30 widgets)

All widgets live in `packages/web/src/components/shared/widgets/`. Each is a small TSX file with a default export. Each maps to a Jade tool of the same name in `server/jade/tools.ts`. All widgets respect Kyle tokens.

## A. Input widgets (Jade asks the user)

These use AI SDK's "addToolResult" pattern — the user's choice gets sent back as the tool result, and Jade continues from there.

| # | Widget | Purpose | Trigger |
|---|---|---|---|
| 1 | **CategoryPicker** | 8 brand-colored category pills (Athletic Performance / Race Prep / Recovery Week / Budget / Dietary / Weight / Family / Pantry-only) | Jade's first-turn empty state |
| 2 | **DayChips** | Mon–Sun chip row, single or multi | "Which days?" |
| 3 | **SlotChips** | B / L / D / Snack / Pre / During / Post | "Which meal?" |
| 4 | **AllergyMultiSelect** | 9 chips (dairy / eggs / fish / gluten / peanuts / sesame / shellfish / soy / tree_nuts) | First-time setup or override |
| 5 | **DietaryToggle** | Single-select segmented (omnivore / vegetarian / pescatarian / vegan / mediterranean / keto / paleo / low-carb) | Profile capture |
| 6 | **MacroSlider** | 3-track slider (carb / protein / fat %) summing to 100 | "Adjust split?" |
| 7 | **PortionStepper** | + / − stepper around serving count | Cell-level swap inline |
| 8 | **DurationDial** | Circular slider 0–240 min | "How long is the workout?" |
| 9 | **YesNoChips** | Quick yes / no / maybe / unsure | Confirmation prompts |
| 10 | **PhotoUploadPrompt** | "Snap your fridge" CTA + file input | "Use what you have" intent |
| 11 | **WeekRangePicker** | Calendar mini-picker for week-of | Plan range capture |
| 12 | **FollowUpQuestionGroup** | Jade's question text + 2–4 quick-reply chips | Anywhere context-narrowing |

## B. Output widgets (Jade renders content)

| # | Widget | Purpose |
|---|---|---|
| 13 | **MealPlanCard** | Figma-pattern: kcal pill, day count, daily-avg macro chips, expand arrow opens DayBreakdownModal |
| 14 | **MealCardCarousel** | 3 alternative plans/meals side-by-side, swipe or arrow keys, default-select middle |
| 15 | **DayBreakdownModal** | Sheet with day accordion → 2×2 meal grid (B/L/D/Snack) |
| 16 | **MealAlternatives** | 3 swap options inline as small stacked cards w/ "Use this" |
| 17 | **MacroProgressRings** | 3 SVG circular progress rings (c/p/f) with target overlay |
| 18 | **WeekHeatmap** | Compact 7-day strip with carb-tier shading (REST→RACE) |
| 19 | **WorkoutTimeline** | Vertical PRE/DURING/POST fuel windows with timing |
| 20 | **WeatherCard** | Temp + condition + hydration recommendation pill |
| 21 | **RaceCountdown** | Days-until-race header + carb-load tier indicator |
| 22 | **InsightTile** | "I noticed you're trending low on protein this week" + action button |
| 23 | **GroceryListCard** | Checkable list grouped by aisle |
| 24 | **HydrationTracker** | Water progress vs goal + heat-adjusted target |
| 25 | **NutritionBreakdown** | Full macro split with fiber, sugar, sodium for one meal |
| 26 | **ComparisonCard** | Side-by-side macro+ingredient comparison of 2 options |
| 27 | **CompactMealList** | Slot bullet rundown — for inline summaries |

## C. Proactive widgets (Jade-initiated on app open)

These render at top of the chat thread on first load when context warrants.

| # | Widget | Trigger |
|---|---|---|
| 28 | **MorningGreetingCard** | Sub-trigger: between 5am–10am local AND user has activity scheduled today |
| 29 | **PreWorkoutReminderCard** | Sub-trigger: workout starts in 60–120 min |
| 30 | **WeatherAdvisoryCard** | Sub-trigger: temp >85°F or <40°F on a workout day |

## D. External-data tools (no widget — Jade calls these for context)

| Tool | Returns | Used by |
|---|---|---|
| `getWeather({ date })` | temp_f, condition, humidity, advisory_string | WeatherCard, hydration adjustments |
| `getEvents({ days })` | calendar events (race, travel, social) | RaceCountdown, plan adjustments |
| `getUpcomingActivities({ days })` | scheduled workouts | Already wired in chat context |
| `getMacroTargets({ from, to })` | per-day c/p/f/tdee | MacroProgressRings, day cards |
| `getUserProfile()` | biometrics + diet + allergies + ftp/css | All personalization |
| `proposeWeekPlan({ goal, week_start })` | structured WeekPlan | MealPlanCard, DayBreakdownModal |
| `proposeMealSwap({ slot, day, current })` | 3 alternatives | MealAlternatives |

---

# 4. Per-variant integration

Each variant uses the widgets it fits. We **don't** force-fit every widget into every variant.

## Variant A — Calendar
- **Ask Jade drawer** → full generative-UI surface. Jade can render any widget.
- **Per-cell click** → opens a Sheet that uses MealAlternatives + ComparisonCard.
- **Coach strip** → InsightTile when Jade has a heads-up; WeatherAdvisoryCard when it's hot.
- **Top-right** → MorningGreetingCard pinned for the first session of the day.

## Variant B — Stack
- **Card overlay** → during swipe, inline Jade narration uses FollowUpQuestionGroup ("Lock all proteins for the week?").
- **Pre-deck** → CategoryPicker as the "what kind of week?" capture before the deck builds.
- **Done summary** → MealPlanCard wraps the result; tapping opens DayBreakdownModal.

## Variant C — Columns
- **"Fill my week with Jade" pill** → spawns a CategoryPicker first, then MacroSlider, then runs proposeWeekPlan.
- **Per-row picker** → Jade-rendered InsightTile inside the popover ("most carb-rich option for tempo day").
- **Bottom totals bar** → MacroProgressRings replaces flat numbers.

## Variant D — Hybrid
- **Right chat panel** → all widgets, full generative UI.
- **Drag affordance** → meal cards in chat panel are draggable to grid (already wired); we extend so MealAlternatives cards are also draggable.
- **Suggestion chips** → CategoryPicker + WeekRangePicker.

## Variant E — Coach (the showcase)
- **Empty state** → CategoryPicker as the hero, with the broccoli-style mascot replaced by 96px Jade avatar.
- **Every Jade turn** → mix of text + 0–N widgets.
- **MorningGreetingCard / WeatherAdvisoryCard / PreWorkoutReminderCard** → pinned proactively.
- **PhotoUploadPrompt** → exposed when Jade asks "what do you have on hand?".
- **Composer enhanced** → + button opens action menu: photo / voice / category-picker / week-range.

---

# 5. Implementation plan

| Phase | Owner | Deliverable | Time |
|---|---|---|---|
| 1 | This doc | Analysis + widget catalog | done |
| 2a | Agent INFRA | Generative UI plumbing in middleware + 5 new tools (weather, events, etc.) + JadeMessageRenderer | 60 min |
| 2b | Agent WIDGETS | All 27 input/output widget components in `components/shared/widgets/` | 90 min |
| 3 | 5 parallel variant agents | Each variant integrates the widgets that fit its UX | 45 min each |
| 4 | Verify | Browser-test, screenshot, commit | 15 min |

Phase 2a + 2b run in parallel. Phase 3 starts when 2a + 2b both land.

---

# 6. Open questions for Lee

These don't block implementation but should be decided before a v2:

1. **Mascot vs human-presence avatar.** The Figma's broccoli mascot is playful but doesn't fit "premium athletic." Should we keep the abstract "J" avatar with electrolyte glow, or commission a Mealvana-specific mascot?
2. **Photo upload — fridge or meals?** Fridge-content recognition is heavy. We can ship "snap and describe in text" first, real CV later.
3. **Voice — Whisper now or later?** Chrome has SpeechRecognition built in (MediaRecorder + Whisper as fallback). Worth a v1 stub.
4. **Family / multi-eater planning.** Figma shows attendee counts. Endurance solo athletes don't need this. Skip for v1?
5. **Weather provider.** OpenWeather (free tier 1k/day), WeatherAPI.com, or Vercel's edge geo + a single forecast call per session?
