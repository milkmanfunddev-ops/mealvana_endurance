---
category: Timeline
---
# Timeline

The day rail. Pass entries in time order; each carries a `time`, a `dot` state (`done` electrolyte, `planned` dashed, `food` orange, `skipped` dashed muted, `start` for the rail head) and its card. Put the `+ Add Food / + Add Activity` row as the first entry with `dot="start"`.

```tsx
<Timeline entries={[
  { dot: "start", children: <AddRow/> },
  { time: "5:57 AM", dot: "planned", children: <WorkoutCard … status="planned" /> },
  { time: "7:51 AM", dot: "food", children: <FoodRow … /> },
]} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart (rail + entries)`
