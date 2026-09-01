## Images

PNG exports of all 28 frames in the "Chat V2" filmstrip, captured 2026-08-26
via Chrome (Figma view-only, keyboard-zoom + hand-tool pan; canvas selection
and Cmd+Shift+E export do not work in this session). NN = left-to-right
position in the filmstrip. **Note:** the filmstrip actually contains 28
frames, not 27 as stated in §1 below — the S9 branch point (`Choose from
list` vs. `Snap my fridge`) is two separate physical frames (S9a, S9b), which
the original "27 mobile frames" count in §1 didn't account for. NN therefore
runs 01–28, one past the S-numbers below S9.

| File | Screen |
| --- | --- |
| `01-welcome-category-picker.png` | S1 |
| `02-training-schedule.png` | S2 |
| `03-primary-goal.png` | S3 |
| `04-dietary-preferences.png` | S4 |
| `05-meal-prep-style.png` | S5 |
| `06-include-breakfast.png` | S6 |
| `07-near-duplicate-s6.png` | S7 |
| `08-fridge-ingredients-prompt.png` | S8 |
| `09-choose-from-list-branch.png` | S9a |
| `10-snap-fridge-action-sheet.png` | S9b |
| `11-camera-crop-screen.png` | S10 |
| `12-photo-posted-composer-active.png` | S11 |
| `13-freeform-addition-submitted.png` | S12 |
| `14-generating.png` | S13 |
| `15-plans-generated-carousel.png` | S14 |
| `16-plan-detail-modal.png` | S15 |
| `17-per-meal-overflow-menu.png` | S16 |
| `18-all-days-collapsed-confirm.png` | S17 |
| `19-recipe-detail.png` | S18 |
| `20-user-requests-change.png` | S19 |
| `21-contextual-refinement-coupon-lookup.png` | S20 |
| `22-suggested-meals-checkboxes.png` | S21 |
| `23-selected-meals-tray-expanded.png` | S22 |
| `24-freeform-request-build-plan.png` | S23 |
| `25-plan-generation-selected-meals.png` | S24 |
| `26-follow-up-scheduling-question.png` | S25 |
| `27-user-accepts.png` | S26 |
| `28-final-day-list-confirm.png` | S27 |

# MealBuddy — Figma Concept Documentation

Source: Figma file **"AI Assistant module"**
https://www.figma.com/design/fpXDAtEbcgv3cDXB9tE6Yg/AI-Assistant-module?node-id=0-1
File key: `fpXDAtEbcgv3cDXB9tE6Yg`

Captured 2026-08-26 via browser (view-only access; the Figma MCP tools reported no
edit access to this file for the connected account, so all content below was read
by navigating the file in Chrome and reading rendered screens directly — no local
screenshots were saved to disk, this document is the record).

## 1. File overview

- **Pages:** `Design` (all real content lives here), `Prototype`, `Wireframes`,
  plus non-page sections in the sidebar: `Work File`, `Components & Styleguide`,
  `Archive`, `Cover`. The page switcher did not respond to clicks in the
  read-only session, so `Prototype` and `Wireframes` could not be opened — only
  `Design` was inspected. Given the content on `Design` is a single, complete,
  linear flow, it's likely `Prototype` just wires the same frames together and
  `Wireframes` holds an earlier low-fidelity pass; this could not be confirmed.
- **Design page structure:** one big section named **"Chat V2"** containing
  **27 mobile frames** (iPhone size, 375×812) laid out left-to-right as a single
  horizontal filmstrip. There is no day-by-day or task-based grouping — it reads
  as one continuous conversation transcript, branching at a couple of points
  (choose-from-list vs. snap-a-photo; accept-plan vs. request-changes).
- **Frame naming is inconsistent/non-sequential.** Frames are named things like
  `AI Assistant_ 26`, `AI Assistant_27`, `AI Assistant_Meal plan Modal 118`, and
  the numbers do **not** match left-to-right order (e.g. frame "24" appears
  before frame "33" appears before frame "9"). This document numbers screens by
  their actual position in the flow (S1–S27) and gives the literal Figma frame
  name in parentheses for cross-reference.
- **Product name inside the design: "MealBuddy"** (shown once, on the welcome
  screen — the rest of the UI just says "AI Assistant" in the header). Mascot:
  a cartoon **broccoli character wearing glasses**, used as the avatar and as a
  "thinking" illustration during loading states.
- **Visual style:** cream/off-white chat background, navy-blue primary text and
  buttons, white pill-shaped quick-reply chips with colored outlines (no icons —
  see §4 open questions, icons were explicitly removed per review comments),
  system font, iOS status bar chrome (9:41, signal/wifi/battery) baked into every
  frame — this is a pure iOS mock, not adaptive/responsive.
- **Existing design-review comments on the file** (left as Figma comments by
  Lee Martin and Xuan Huang, dated ~1 year ago) — kept here as they record open
  questions/decisions about this exact design that the screens themselves don't
  answer:
  - Lee: "Don't like this background image" (an earlier veggie photo background
    was pushed back on; the current welcome screen still has a veggie photo
    strip at the bottom, so this may be partially unresolved).
  - Lee: "These icons are a little too basic. Probably better to remove them
    and just have the text." / "Same for this icon. Let's just have text here."
    — this is why every quick-reply and category button in the current screens
    is plain text with no icon.
  - Lee: "What's the point of this hamburger icon? Is it to view history or
    something like that?"
  - Xuan: "what does the hamburger icon lead to?"
  - Xuan: "Is this button to start a new conversation and discard the
    current?"
  - Xuan: "what does the delete button do? Does it delete the conversation
    that comes after it as well?"
  - Lee: "At the end we would like the following: 1) the ability to confirm
    the plan with a..." (comment truncated in the UI, rest not recoverable).

  **None of a hamburger icon, a "new conversation" button, or a delete button
  is visible anywhere in the 27 frames actually captured** (every header is
  just `X` + mascot avatar + "AI Assistant" title). These controls were
  apparently designed/discussed but live on a screen this pass didn't reach
  (possibly on `Prototype`/`Wireframes`, which couldn't be opened) — flag as an
  unresolved gap if this file is used as a spec.

## 2. Screen-by-screen walkthrough

The whole thing is one chat thread. Every question the assistant asks is
answered either by tapping a **quick-reply chip** (which converts into a
right-aligned white user bubble with a small **"Edit"** link underneath it —
tapping Edit presumably reopens the chip picker for that question) or by
**typing free text** in the composer at the bottom (same visual result: a
right-aligned bubble with an "Edit" link). Both interaction modes are
supported at almost every step — this is a real hybrid guided-chips +
freeform-chat design, not a rigid form.

### S1 — Welcome / category picker (`AI Assistant_ Default`)
Header: `X` close button, broccoli mascot avatar, "AI Assistant" title.
Body: large mascot avatar, heading **"Hi, I'm MealBuddy"** ("MealBuddy" in
blue), subtext **"I'm here to help you create a plan that works for you!
Choose category you want to create plan for"**. Eight category buttons, one
primary (filled navy) and the rest outlined in different colors (no evident
color-coding logic, reads as decorative variety):
`Athletic Performance` (primary/filled), `Budget Constraints`, `Health Issues`
(red outline), `Specific Dietary Preferences` (yellow outline), `Weight Loss`,
`Family-Friendly` (green outline), `Special Occasions`, `Ingredients on Hand`
(yellow outline). Background: a photo strip of vegetables along the bottom
edge. Composer: `+` button, placeholder "What can I do for you?", mic icon,
navy circular send button — present on every screen.

### S2 — Training schedule (`AI Assistant_ 26`)
Agent: *"Hey Athlete! I'm here to help fuel your workouts and recovery. Let's
create a meal plan that supports your goals and performance!"* then *"What's
your training schedule like this week?"* Chips: `Rest Week (Recovery)`
(selected/primary), `Strength Training`, `Cardio`, `Mixed (Cardio + Strength)`,
`Other`.

### S3 — Primary goal (`AI Assistant_27`)
`Rest Week (Recovery)` is now a user bubble with `Edit`. Agent: *"What's your
primary goal for this week's meal plan?"* Chips: `Energy Boost` (selected),
`Muscle Recovery`, `Fat Loss`, `Lean Muscle Building`, `Other`.

### S4 — Dietary preferences (`AI Assistant_ 28`)
`Energy Boost` now a user bubble. Agent: *"Do you have any specific dietary
preferences or restrictions?"* Chips: `No Restriction` (selected), `Gluten
Free`, `Keto`, `Vegan`, `Lactose Free`, `Allergie` [sic, missing final "s"],
`Other`.

### S5 — Meal prep style (`AI Assistant_29`)
`No Restriction` bubble now shows both `Edit` **and** `Delete` links (the only
screen where Delete appears on a past answer — inconsistent with the Edit-only
pattern elsewhere). Agent: *"Would you like to meal prep for the week or
prefer fresh meals daily?"* Chips: `Meal Prep (Cook once, eat all week)`
(selected, primary), `Fresh Meals (Cook daily)`.

### S6 — Include breakfast? (`AI Assistant_24`)
Agent: *"Do you want me to include breakfast in your diet? It is extremely
important to eat before any physical activity"* Chips: `Yes` (selected), `No`.

### S7 — Near-duplicate of S6 (`AI Assistant_25`)
Same question/state as S6, appears to be a stray duplicate/variant frame left
in the file (or an unused branch) — no new content.

### S8 — Fridge ingredients prompt (`AI Assistant_33`)
Agent: *"I'll recommend meals that are aligned with your workout intensity. Do
you have any ingredients in your fridge you'd like to use?"* Two options,
**this is the branch point**: `Choose from list` (primary) vs. `Snap my
fringe` [sic — typo for "fridge"].

### S9a — Choose-from-list branch (`AI Assistant_Coose from list 9`, note the
typo in the frame name too)
A date divider **"Yesterday 12.05.2025"** appears (suggesting this branch was
mocked as a separate session/day). Agent re-asks the fridge question, then
shows a pantry chip grid: `Chicken` (selected), `Avocados`, `Sweet Potatoes`,
`Cheese`, `Salmon`, `Broccoli`, `Eggs`, `Sea Food`, `Rice`, `Fresh Fruits`, and
a trailing `+` chip (presumably to add a custom ingredient not in the list).

### S9b — Snap-my-fridge branch, action sheet (`AI Assistant)_ Snap option 10`)
A native iOS-style action sheet overlays the chat, dimming it: **"Take a new
photo"**, **"Choose from Gallery"**, **"Cancel"**.

### S10 — Camera/crop screen (`Crop - Snap 11`)
Full-bleed photo of an open fridge (stocked with condiments, produce, dairy).
A translucent crop overlay frames the shot. Large pill button at the bottom:
**"Snap"**.

### S11 — Photo posted + free-text composer active (`AI Assistant)_ Active chat 12`)
The agent's fridge question is shown with the captured fridge photo attached
as a right-aligned image bubble (with an `Edit` link). The iOS keyboard is
open and the composer shows partially-typed text: **"I'd like to add some
G…"** — i.e. the mock demonstrates a user typing a free-text addition on top
of (not instead of) the photo.

### S12 — Freeform addition submitted (`AI Assistant_12`)
User bubble (photo) followed by a second user bubble: **"I'd like to add some
Grilled Steak this week"** (plain free text, no chip involved). Agent: *"Great!
Would you like me to prepare your personalized meal plan now based on your
answers."* Chips: `Yes` (selected), `No, I have some details to include`.

### S13 — Generating (`AI Assistant_Loading 15`)
A circular progress ring at **10%**, mascot illustration, and a blue "agent
thinking" bubble: **"Hold on a few seconds! I'm finding the best meals for
your goals…"**

### S14 — Plans generated, card carousel (`AI Assistant_Meal plan Generated 14`)
Agent: *"Awesome! 🙌 Here are 3 meal plans made just for you — to support
recovery and give your body the boost it needs after training. 💪"* Below it,
a horizontally-scrollable row of plan cards (only "Plan 1" fully visible, two
more peek off the right edge). Each card: calorie badge (`1800kca` — kcal
truncated, likely a text-overflow bug in the mock), a "people" icon × count
and a "fork/knife" icon × count (read as servings/meals-per-day, unlabeled), an
outbound-arrow button (opens the modal), title **"Plan 1-Balanced
Performance"**, a duration tag **"7d"**, description **"Perfect for
maintaining muscle and energy levels throughout the day."**, then "Daily
average:" with five color-outlined macro pills: `Protein: 120g`, `Carbs:
160g`, `Fat: 55g`, `Fiber: 25g`, `Sugar: 18g`. Below the carousel, a
**"↻ Regenerate"** link (regenerates the whole set of 3 plans).

### S15 — Plan detail modal (`AI Assistant_Meal plan Modal 15`)
Tapping a card opens a full-screen modal (slides up over the chat, which is
still visible dimmed behind it). Header: plan title + "7d" + `X` close.
Repeats the description and macro pills from S14, then a **day-by-day list**:
`Day 1` as a collapsed row (people×4, fork×4, "1800kcal"), `Day 2` expanded
into a 2×2 (visible) grid of meal photo cards, each labeled `Breakfast
300kca`, `Snack 300k…` etc., each card has a `⋮` overflow button.
**Note:** the plan is explicitly organized into named days (Day 1, Day 2, …)
with specific meals per day — see §3 conflicts.

### S16 — Per-meal overflow menu (`AI Assistant_Meal plan Modal 17`)
Tapping `⋮` on a meal card opens a small popover: **"↻ Regenerate"** /
**"🗑 Remove"** — swap or delete an individual meal within a day.

### S17 — All days collapsed + confirm (`AI Assistant_Meal plan Modal 118`)
All seven day-rows shown collapsed: `Day 1` 1800kcal, `Day 2` 1800kcal, `Day
3` 1800kcal, `Day 4` 1900kcal, `Day 5` 1750kcal, `Day 6` 1800kcal, **`Day 6`
1800kcal again** (duplicate row — looks like a mock error; a "7d" plan should
have 7 uniquely-numbered days, not two Day 6s and no Day 7). Bottom: primary
button **"Confirm & Add Plan"**.

### S18 — Recipe detail (`AI Assistant_Meal plan Modal_Recepie 19`, note
typo "Recepie")
Drilling into a single meal card opens a recipe screen: back arrow + title
**"Garlic & Rosemary Roasted Potatoes"**, servings/meals icons, `1800kcal`,
and — notably — a **price: "$57.32"** next to a coin icon (see cost feature
below). Ingredients in two columns: *"500g baby potatoes, 2–3 garlic cloves, 2
tbsp olive oil, 1 tbsp butter (optional, for flavor)"* / *"1–2 sprigs of fresh
rosemary, Salt and black pepper to taste"*. Macro pills repeated at the
bottom: Protein 120g, Carbs 160g, Fat 55g, Fiber 25g, Sugar 18g.

### S19 — User requests a change (`AI Assistant_20`)
Back in the main chat (modal dismissed). User free-text bubble: **"In fact, I
am not entirely satisfied with these plans. I want something that matches the
season."**

### S20 — Contextual refinement + coupon lookup (`AI Assistant_AI processing 21`)
Agent responds with **weather/training-aware reasoning**, not just a generic
prompt: *"Next week is balmy at 80F. You have some serious training over the
weekend. I suggest some lighter meals during weekdays and carb load on
Friday. Do you crave for anything specific? You can say, for example, Salmon,
or Something spicy."* Chips: `Salmon`, `Something spicy.` (stray trailing
period in the chip label). User then types free text: **"I actually want
something in sale"** (i.e. asking for discounted/on-sale ingredients, not
"in season" — easy to misread at a glance). Agent status line: **"gathering
coupons…"** — implying a grocery-deals/coupon-matching feature tied to meal
suggestions.

### S21 — Suggested meals with checkboxes (`AI Assistant_22`)
Agent: *"Here are 3 meals you might want to add to your new plan"* — a
horizontal set of recipe cards (same visual language as the recipe detail:
photo, title, kcal, price, ingredient bullets, macro pills), each with a
**checkbox** in the top-right corner to select/deselect it (shown checked on
"Garlic & Rosemary Roasted Potatoes"). Below the chat, a persistent collapsed
**"Selected Meals"** tray/bar pinned above the composer.

### S22 — Selected Meals tray expanded (`AI Assistant_Selected meals 23`)
Tapping the tray expands it inline to show thumbnail chips of the currently
selected recipes (checked state repeated) — a running "cart" of meals the
user has hand-picked from suggestions, separate from the auto-generated plan.

### S23 — Freeform request to build a plan (`AI Assistant_Request type 24`)
Composer active with keyboard, partially-typed suggested/example input:
**"Generate a plan that i…"** — implying the UI nudges users toward typing
natural-language plan requests, not just tapping chips.

### S24 — Plan generation from selected meals (`AI Assistant_AI processing 25`)
Submitted message: **"Generate a plan that include all selected recipes"**
[sic, subject-verb mismatch in the mock copy]. Loading state again: 10% ring,
mascot, blue bubble **"Sure! I'm generating best meals that include selected
recipes…"**

### S25 — Follow-up scheduling question (`AI Assistant_AI processing 26`)
Agent: *"Do you want for the assistant to help plan out the meals across the
week?"* [awkward phrasing, likely placeholder copy] — no chips visible yet at
this point in the frame.

### S26 — User accepts (`AI Assistant_AI processing 27`)
User bubble: **"Yes"**.

### S27 — Final day list + confirm (`AI Assistant_AI processing 28`)
Same pattern as S17: `Day 1`–`Day 5` at varying kcal (1800/1800/1800/1900/1750),
then **`Day 6` twice** again (same duplicate-row issue), and the primary
**"Confirm & Add Plan"** button. This is the last frame in the filmstrip — the
flow ends here without showing what happens after confirmation (no
post-confirm "success" screen, no shopping list screen, no calendar/day-slot
assignment screen exists anywhere in the 27 frames).

## 3. Widgets / components inventory

- **Chat shell:** fixed header (`X` close, mascot avatar, "AI Assistant"
  title), scrolling message list, fixed composer (`+` attach, text field,
  mic, send button).
- **Agent message:** left-aligned, no bubble background, black text, plain
  paragraphs — reads as narration rather than a boxed bubble.
- **User message ("answer") bubble:** right-aligned, white rounded bubble,
  navy text, with a small gray `Edit` link (and occasionally `Delete`)
  underneath.
- **Quick-reply chip group:** one or more pill buttons under an agent
  message; selected/primary state = filled navy; unselected = white with a
  colored outline (no consistent color→meaning mapping observed); text-only,
  no icons (explicitly removed per review comments).
- **Loading/thinking bubble:** blue bubble + circular percentage ring +
  mascot illustration, used both for "generating a plan" and "gathering
  coupons."
- **Plan card (carousel):** kcal badge, servings icon×count, meals icon×count,
  open-modal arrow button, title, duration tag, description, 5 macro pills,
  "Regenerate" affordance.
- **Plan detail modal:** full-screen sheet over the chat; header with close;
  description + macro pills repeated; collapsible **Day** rows; each expanded
  day shows a grid of **meal cards** (photo, name, kcal, `⋮` menu →
  Regenerate/Remove).
- **Recipe detail screen:** photo, title, servings/meals/kcal, **price**,
  two-column ingredient bullet list, macro pills.
- **Recipe suggestion card (chat-inline):** same recipe-card anatomy but with
  a selection checkbox, used when the agent proposes specific meals mid-chat.
- **Selected Meals tray:** persistent collapsible bar pinned above the
  composer, holding hand-picked recipe thumbnails as a running selection.
- **Native iOS action sheet:** used for the photo-source picker (Take a new
  photo / Choose from Gallery / Cancel).
- **Camera/crop screen:** full-bleed photo capture with crop overlay and a
  single "Snap" pill button.
- **Date divider:** a centered gray "Yesterday 12.05.2025" rule, used once,
  implying the design also handles multi-session/multi-day chat history.

## 4. Ideas worth keeping

- **Hybrid quick-reply + freeform input at every step.** Nothing is chip-only;
  the user can always type instead, and typed answers render with the same
  Edit affordance as chip answers. This matches Mealvana's own "chat-forward
  planner agent" direction well.
- **Context-aware follow-up questions** (S20: referencing forecast weather and
  the user's own training schedule to suggest lighter weekday meals / carb-load
  Friday) is a strong differentiator worth borrowing conceptually — using
  known user context (training calendar, not just chat history) to shape the
  next question instead of asking generic ones.
- **Editable-answer pattern** (`Edit` link under every past answer) is a clean,
  low-friction way to let users revise earlier steps without restarting the
  whole conversation — directly reusable.
- **Photo-of-fridge → detected-ingredients chip list**, with the freeform
  "add anything else" follow-up layered on top, is a nice combination of
  low-effort input (snap a photo) and high-control refinement (type an
  addition). Mealvana already has photo-capture AI surfaces (per team working
  agreements, these must stay on for dev) — this pattern could inform how that
  surface feeds into plan generation.
- **Selected Meals "cart" while browsing suggestions** (pick specific recipes
  out of AI suggestions before asking the agent to assemble them into a plan)
  is a good middle ground between "AI decides everything" and "user builds
  everything manually."
- **Per-meal swap/remove from within the plan** (S16's Regenerate/Remove on an
  individual card) rather than only being able to regenerate the whole plan
  is a good granularity to support.
- **Ingredient-cost line on recipes** ("$57.32" + coin icon) and the "gathering
  coupons…" step are a distinct monetization/utility idea (grocery-savings
  awareness baked into meal suggestions) that doesn't exist in Mealvana today
  and could be worth a product conversation on its own, independent of the
  rest of this concept.
- **Confirm-before-committing pattern**: nothing gets added to "your plan"
  without an explicit "Confirm & Add Plan" tap at the end, even after the
  agent has already "generated" it — keeps the AI's output provisional until
  the user accepts it, which fits Mealvana's write-consistency posture of not
  silently committing AI output.

## 5. Things that conflict with Mealvana's approach

- **Meals are slotted to specific numbered days (Day 1, Day 2, …) inside the
  plan**, each with its own Breakfast/Snack/etc. cards and its own kcal
  target. Mealvana's model is the opposite: **formulas are simple food
  collections and batch-cooking weekly plans are explicitly *not* slotted to
  days.** Adopting this screen's plan structure as-is would mean rebuilding
  around a day-by-day calendar model Mealvana has deliberately avoided.
- **"Meal Prep (Cook once, eat all week)" is presented as an alternative to a
  day-by-day plan, but the resulting modal still shows Day 1…Day 6 with
  different meals per day** — i.e. even the "cook once" branch in this mock
  doesn't actually behave like batch cooking (same food repeated across the
  week); it generates a different recipe set per day regardless. That's a
  direct structural mismatch with Mealvana's batch-cooking mental model, not
  just a surface-level one.
- **No web/desktop consideration** — every frame is a fixed 375×812 iOS mock
  with iOS status-bar chrome and a native action sheet; Mealvane ships iOS,
  Android, and Web. The interaction patterns (native photo picker sheet,
  bottom composer with mic button) would need real cross-platform equivalents.
- **Branding:** the character mascot ("MealBuddy" the broccoli) and cream/navy
  palette don't match Mealvana's dark-plum brand identity; this is a concept
  file, not a skin, and would need a full visual pass regardless of whether
  the interaction ideas are kept.
- **Ambiguous/undocumented chrome** — review comments reference a hamburger
  menu, a "new conversation" button, and a delete button that would discard
  history, none of which appear in the 27 captured frames. If this flow were
  adopted, that missing chat-management surface (history, starting over,
  deleting a thread) would need to be designed from scratch, not ported.
- **Grocery-cost/coupon feature** (recipe price tags, "gathering coupons…")
  has no equivalent anywhere in Mealvana's current architecture (no
  grocery-pricing or coupon integration exists) — worth flagging as new scope,
  not an existing pattern to reuse.
- **Placeholder-quality copy in several places** — "Do you want for the
  assistant to help plan out the meals across the week?", "Generate a plan
  that include all selected recipes", the duplicated "Day 6" row, the
  "Allergie" chip, "Snap my fringe" typo, the truncated "1800kca" badges —
  none of this is production copy; treat every string in this document as a
  first-draft placeholder, not final content, and cross-check against
  Mealvana's own content/default-string system before reusing any of it
  verbatim (per the project rule against hardcoding user-facing strings).
