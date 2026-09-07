---
category: Surfaces
---
# PhaseCard

A fueling-phase section — `before` (orange), `during` (electrolyte), `after` (dragonfruit) — outlined in the phase colour with a caps Sansita title and `?` info. Children are the MacroStat trio in a 3-column grid, then FuelStep / FuelItem rows.

```tsx
<PhaseCard phase="before">
  <div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:16}}><MacroStat …/><MacroStat …/><MacroStat …/></div>
  <FuelStep title="Pre-Workout Snack" timing="Now – 30 min out" foods="Orange Juice + Bread / Toast" stats={[{value:"50g",label:"Carbs"},{value:"8oz",label:"Fluids"}]} />
</PhaseCard>
```

**Dart source (promote from):** `lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_section_widget.dart`
