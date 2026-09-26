# Decisions: Miscellany

Feature: misc
Feature name: Miscellany

## mp-197 · Everything new is drawn in the Kyle design system
- category: Design system
- status: approved
- folded: mp-259
- image: docs/new_mealplanning/figma/16-plan-detail-modal.png
- caption: A MealBuddy frame, whose look was not adopted.
- screen: Vana chat
- source: vana-chatbot-update-plan.md; spec.md; memory 09-11

**Context.** MealBuddy, a Figma concept, explored a meal-planning assistant with a mascot and a cream and navy look. The app already had the Kyle design system and a prototype styled with it.

**Question.** Which look do the new screens use?

**Decision.** Kyle, and only Kyle. From MealBuddy, only how things behave comes in, not how they look: no mascot, no cream and navy, no iPhone-only controls. Each new designed piece, such as the Vana sheet and the Vana button, gets a written spec and is built once for every screen to use. When a design file and the Kyle tokens disagree, the tokens win.

**Why.** One look across iOS, Android and Web. MealBuddy was a concept, not a system.

**What else was considered.** Adopting MealBuddy's look.

> 2026-09-26 overhaul: rewritten from mp-197, mp-259

## mp-261 · Meal macros show as four numbers: kcal, carbs, protein and fat
- category: Design system
- status: approved
- image: none
- screen: Vana chat, Plan tab
- source: memory 09-07; memory 09-04; OPEN-QUESTIONS.md

**Context.** Meal cards, plan tiles and the plan summary all show a meal's macros.

**Question.** Which numbers does a meal show?

**Decision.** Four, on by default: kcal, carbs, protein and fat. The meal picker's small tiles show kcal only.

**Why.** Those four are what an athlete reads at a glance.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-261

## mp-252 · Vana runs on Supabase, not a separate server
- category: Data and sync
- status: approved
- image: none
- screen: none (algorithm/data)
- source: README; 02-contract.md; 03-backend.md

**Context.** The meal-planning prototype ran its server on Vercel. The app's backend is Supabase.

**Question.** Where does Vana run?

**Decision.** On Supabase, next to the app's database, with no Vercel service. Vana reads data as the athlete she is talking to, so she can only see that athlete's own records.

**Why.** One backend, and the database itself decides who can read what.

**What else was considered.** Keeping the prototype's Vercel server.

> 2026-09-26 overhaul: rewritten from mp-252

## mp-254 · Meal plan edits work offline, except the ones the server builds
- category: Data and sync
- status: approved
- image: none
- screen: Plan tab
- source: 05-flutter-feature.md; plan-tab-v2.md; memory 09-01

**Context.** The app works offline first. Shopping lists and plan changes that pick new meals are worked out on the server.

**Question.** Which plan changes need a connection?

**Decision.** Small edits save on the phone and upload later: servings, removing a meal, shopping ticks, notes and settings. Changes the server builds need a connection: picking or swapping a meal, starting or confirming a plan. If one of those fails, the plan stays as it was and the app says it needs a connection. Example: with no signal, ticking eggs on the list works, but swapping a dinner says it needs a connection.

**Why.** A failed change must never leave a half-changed plan.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-254

## mp-257 · The athlete's home is set by telling Vana
- category: Data and sync
- status: approved
- image: none
- screen: none (algorithm/data)
- source: spec.md; ticket 02; memory 09-10

**Context.** Weather and the Kroger delivery check used the race venue, because the app had nowhere to keep the athlete's home.

**Question.** How does the app learn where the athlete lives?

**Decision.** The athlete tells Vana, and she saves the city and its location to their profile. No settings screen edits it. Weather and the Kroger check use home once it is set, and the race venue until then. Example: an athlete says they live in Birmingham, Alabama, and from then on the Kroger check looks there.

**Why.** Home is said once, in conversation, and the rest of the app reads it from one place.

**What else was considered.** none recorded

> 2026-09-26 overhaul: rewritten from mp-257
