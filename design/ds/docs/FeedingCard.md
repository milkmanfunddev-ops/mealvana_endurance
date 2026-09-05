---
category: Fueling
---
# FeedingCard

One pre-workout feeding (meal · snack · top-off) on the BEFORE card: orange Sansita title (assembler-named, FC-1), uppercase window eyebrow, DELIVERED-only header figures (FC-2), expanding in place (FC-G1) to stepper food rows (36 px orange ± discs, per-food colour disc + white glyph per the parity ruling) and the dashed "+ Add Food" pill (FC-7). Stack the three tiers with 12 px gaps; ± emits the new quantity — the surface repaints the summary (FC-G3).

```tsx
<FeedingCard
  title="Pre-Workout Snack" windowLabel="60 – 15 MIN BEFORE" foodsLine="Banana · Water (cups)"
  carbsDelivered={52} fluidOz={12} initiallyExpanded
  rows={[
    { id: 'banana', name: 'Banana', detail: '27g carbs', quantity: 1, step: 0.5, cap: 3, icon: 'appleWhole', iconColor: 'var(--me-orange)' },
    { id: 'water', name: 'Water (cups)', detail: '8 oz', note: 'ADDED FOR HYDRATION', quantity: 1.5, step: 0.5, cap: 8, icon: 'droplet', iconColor: 'var(--me-electrolyte-dark)' },
  ]}
  onStep={(row, q) => setQty(row.id, q)} onAddFood={openPicker}
/>
```

**Dart source:** `lib/shared/widgets/kyle_design/fueling/feeding_card.dart` (library) — spec `docs/ssot/spec/design/components/feeding-card.md` v1, food-row icons per the phase-card visual parity ruling (surface `pre-workout-before-card.md`, 2026-09-01, as amended)
