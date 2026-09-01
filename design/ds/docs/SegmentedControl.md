---
category: Buttons
---
# SegmentedControl

Exclusive filter among 2–4 short labels — the timeline's `All · Workout · Meals`. Hairline pill track; the selected segment is a cream pill with blackberry text. Use `full` to stretch across the gutter width. Keep labels to one word.

```tsx
<SegmentedControl segments={[{value:"all",label:"All"},{value:"workout",label:"Workout"},{value:"meals",label:"Meals"}]} selected={f} onChange={setF} />
```

**Dart source (promote from):** `lib/shared/widgets/kyle_design/buttons/segmented_control.dart (library) — the filter/Daily-Weekly/Planned-Actual variants are feature-local in macro_dashboard + daily_macros`
