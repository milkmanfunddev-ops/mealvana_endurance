# App Store submission bundle — Mealvana Endurance

**Status: FINAL — ready to submit** (prepared 2026-07-21; icon added 2026-07-22; opening panels refreshed 2026-07-25)
The full listing bundle for the next submission: the **8-panel screenshot set**, the **metadata copy**
(`LISTING_COPY.md`), and the **refreshed app icon** (`app-icon-1024.png`). Apply all three together.

## The set (upload in this order)
The **first 3 show inside search results**, so order matters — lead with the hook, the core value, and the differentiator.

| # | File | Headline | Screen |
|---|------|----------|--------|
| 1 | `1_training-dialed.png` | "Your training is dialed." | brand hook, panel 1 of 2 — collage, no device |
| 2 | `2_your-fueling.png` | "Is your fueling?" | brand hook, panel 2 of 2 — collage, no device |
| 3 | `3_fuel-your-day.png` | — (no caption) | day timeline — intake vs. burned, swim/bike with pre·during·recovery fuel, logged meals |
| 4 | `4_know-your-numbers.png` | "Know your numbers" | pre/during/post nutritional targets |
| 5 | `5_build-your-kit.png` | "Build your kit" | Formula Library (dietitian-curated) |
| 6 | `6_train-your-gut.png` | "Train your gut" | carbs/hr trend — "In Baseline, highest intake yet" |
| 7 | `7_log-any-product.png` | "Log any product, fast" | 60k+ searchable/scannable products |
| 8 | `8_ace-your-race.png` | "Ace your race" | race event · carb-loading · race-day checklist |

> ⚠️ **The opening changed — re-check the first-3 rationale before submitting.** Panels 1–2 now split
> the old single-panel hook across a two-panel spread, so the search-result preview is *hook · hook ·
> timeline* rather than *hook · numbers · kit*. That spends two of the three visible slots on the
> headline and pushes "Know your numbers" out of the preview. Deliberate if the spread is the bet;
> worth a second look if it isn't. Panel 3 carries no caption — it's the only silent panel in the set.

## App icon (proposed) — `app-icon-1024.png`
The refreshed icon: a **bolder cream mark on the orange→plum gradient**, replacing the thin line-art
that was illegible at search-thumbnail size (a prime suspect in the low search tap-through).
- ⚠️ **Not a metadata upload.** Unlike the screenshots/copy, the icon ships **inside the app binary** —
  add `app-icon-1024.png` to the app's asset catalog (`AppIcon`) and build. 1024×1024, full-bleed.
- **Confirm it reads at 60px** before shipping — that small-size legibility is the entire point.
- Strong first **Product Page Optimization (A/B)** candidate once live: new icon vs. current.

## Specs — ⚠️ verify before upload
- **Dimensions: 1284 × 2778** (portrait). That's the **6.5"** iPhone size.
- Apple's current large-iPhone requirement is **6.9"/6.7" = 1290 × 2796** (or 1320 × 2868). **Confirm the required size in App Store Connect** — if it wants 1290 × 2796, these need a trivial resize (they're the same aspect ratio, so it's a clean scale, no re-crop).
- Localization: **en-US**.

## Notes for submission (Lee)
- These **replace the older raw screenshots** in `../release_screenshots/` (welcome/macros/carb-loading etc.) — the old set was un-captioned app grabs; do not re-use them.
- Screenshots are only half the listing update. The matching **metadata** (keywords, subtitle, description, promotional text) is drafted in the ops repo: `ops/data/analytics/aso-ship-list.md`. Pull both for the same submission.
- Update this folder each time the set is refreshed; keep it as the source of truth (version the folder if you keep old sets).

## Provenance
Designed in Claude Design from real-device app captures, as the deliverable of the ASO / top-of-funnel effort. Tracked in Notion: **Marketing & Growth → 🍎 App Store Listing Lab**. Caption story and rationale live there and in `ops/data/analytics/aso-audit-2026-07-16.md`.
