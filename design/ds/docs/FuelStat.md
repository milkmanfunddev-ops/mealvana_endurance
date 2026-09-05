---
category: Fueling
---
# FuelStat

One BEFORE-summary quantity (carbs · fluids · sodium): 16 px bold figure (electrolyte; sodium cream — and never a band, F-2), uppercase label, and the optional band — cream rail, orange suggested triangle (engine target, M-1), electrolyte delivered diamond that goes dragonfruit out-of-band (M-2/Q-D9). Figures arrive already in whole oz / g (M-5). Three across compose the summary row; `absentLine` is the fluid gate ("No fluid target for this session"), distinct from a real `0g` (F-1).

```tsx
<FuelStat quantity="carbs" delivered={52} unit="g" label="CARBS" bandLow={40} bandHigh={68} target={54} />
<FuelStat quantity="fluids" delivered={12} unit="oz" label="FLUIDS" bandLow={8} bandHigh={16} target={12} />
<FuelStat quantity="sodium" delivered={300} unit="mg" label="SODIUM" />
```

**Dart source:** `lib/shared/widgets/kyle_design/fueling/fuel_stat.dart` (library) — spec `docs/ssot/spec/design/components/fuel-stat.md` v1, figure typography per the phase-card visual parity ruling (surface `pre-workout-before-card.md`, 2026-09-01)
