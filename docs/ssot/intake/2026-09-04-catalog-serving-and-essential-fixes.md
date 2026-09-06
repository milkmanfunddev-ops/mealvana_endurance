type: spec-erratum
bundle: catalog data (pre_workout_templates + foods) — dev AND prod, applied 2026-09-04, row-identical

## Why this matters
Three catalog rows defeated ratified behavior on device; all three are data-only fixes (no code),
already applied to BOTH dev and prod at Xuan's direction. This note is the catalog-as-truth
handback so the qa catalog mirror stays row-identical (2026-09-01 conventions).

## The three row changes
1. `pre_workout_templates` "Energy Chews" (bc7463de-9b16-45f3-9187-a564a4bee8ce):
   min_servings 1 → **0.5**. Chews are 3–4 discrete pieces (deliberately NOT in the C1
   is_indivisible set); a half sleeve (12.5 g) now competes for small top-off slots instead of
   Applesauce Pouch winning every time (ruled by Xuan 2026-09-04).
2. `pre_workout_templates` "Banana (Top-Off)" (2a7e2219-fbaf-5086-8aab-3830f721527f):
   min_servings 1 → **0.5** (max stays 1). Same rationale; also the only top-off that could not
   scale at all.
3. `foods` "Electrolyte tablet (electrolyte-only)" (9fd63557-c41b-4fc6-a7f5-884582c282ed):
   is_essential false → **true**. Closes the food-recommendation §4 item 5 / W6 conformance gap:
   the ruled capsule-first sodium backfill sorted a pool (`foods WHERE is_essential`) that
   contained only Water + Salt Packet, so pinned-formula plans shipped salt packets (7.5 on
   Xuan's device — ops bug 2026-09-04-pinned-backfill-ships-salt-packets-tablet-not-in-pool.md).
   W6's vector passed only because its fixture pool included a tablet.

## Gates
QA: mirror the three rows in the catalog SSOT / migration ledger so a catalog replay reproduces
them; consider a data-shape guard for W6 (the essential pool must contain ≥1
capsule/tablet-class row, else the ruling is unsatisfiable — that is what happened). No vector
changes needed. Also open (Xuan, optional): 1–2 additional 12–18 g top-off templates for variety.
