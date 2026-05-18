# Onboarding — Default Fuel Plan

Prototype for the Mealvana Endurance onboarding step that replaces
dietary-preference + food-preferences with **almost no decisions**: we
show the user a sensible default pre, during, and post-workout
formula. They can tap any meal to swap it for an alternate, or just
hit Continue and use the defaults as-is.

## Why this exists

The old food-preferences screen made users tag dozens of foods before
we could plan anything. Most users want to *get going*. This screen
gives them a plan instantly:

- **Before** — Oatmeal + Banana (3h pre)
- **During** — Gel + Water (every 30 min)
- **After**  — Classic Chocolate Milk (within 30 min)

These mirror the canonical defaults from the seeded Supabase tables
(`pre_workout_templates`, `during_workout_templates`,
`post_workout_templates`).

## Run

```bash
cd prototypes/onboarding-fuel-style
npm install
npm run dev
```

Opens `http://localhost:5173`.

## What's here

| File | Purpose |
| --- | --- |
| `src/components/PhoneFrame.tsx` | 390×844 phone canvas on the blackberry bg |
| `src/components/DefaultsScreen.tsx` | Main screen — three meal cards + Continue |
| `src/components/MealSwapSheet.tsx` | Bottom sheet for picking an alternate formula |
| `src/data/templates.ts` | Pre / during / post template lists pulled from real DB seed data |
| `src/styles/tokens.css` | Full `--me-*` design tokens (blackberry, cream, orange, etc.) |
| `src/styles/globals.css` | `@font-face` declarations for Apercu / Sansita / Compadre / Apercu Mono |
| `public/fonts/` | Real brand fonts copied from `assets/fonts/` |

## Source of the defaults

Pulled from these files in the repo:

- `docs/templates/templates_now.txt` — pre-workout templates
- `supabase/migrations/20260406320000_during_workout_templates_complete.sql` — during
- `supabase/migrations/20260408200000_post_workout_templates.sql` — post

If you change which template is the canonical default in the DB,
update the `isDefault: true` flag in `src/data/templates.ts`.

## Brand parity

Same tokens as the Formula Kit settings prototype on GitHub Pages.

| Token            | Value                       |
| ---------------- | --------------------------- |
| Background       | `#381633` blackberry        |
| Card surface     | `#52284B` blackberry-light  |
| Accent           | `#F78B14` orange            |
| Cream            | `#F8F6EB`                   |
| Display font     | Sansita                     |
| Body font        | Apercu                      |
| UI font          | Compadre                    |
| Card radius      | 25px                        |
| CTA radius       | pill / 100px                |

## Not wired up

This is a visual prototype. The Continue button just `alert`s the
chosen plan. When we promote this to Flutter, the chosen template ids
should be cached on `onboardingControllerProvider` and persisted to
the user's profile when onboarding completes.
