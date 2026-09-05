---
category: Inputs
---
# IntensityPresetChips

Wrap of six workout-preset pills for the intensity estimate mode: the selected chip gets the orange treatment (15% fill, 2 px border, bold), the rest are hairline outlines; two-per-row falls out of the wrap at phone width. Labels are sport-specific and arrive from the surface (`Easy Run` / `Easy Ride` / `Easy Swim`…).

```tsx
<IntensityPresetChips
  chips={[
    { value: 'easy', label: 'Easy Run' }, { value: 'long', label: 'Long Run' },
    { value: 'tempo', label: 'Tempo Run' }, { value: 'intervals', label: 'Intervals' },
    { value: 'racePace', label: 'Race Pace' }, { value: 'recovery', label: 'Recovery Run' },
  ]}
  selected={preset} onSelect={setPreset}
/>
```

**Dart source:** `lib/shared/widgets/kyle_design/inputs/intensity_preset_chips.dart` (library) — spec `docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md`, chip geometry from `prototypes/create-activity-plan/v1.html`
