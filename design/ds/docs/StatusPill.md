---
category: Timeline
---
# StatusPill

The workout-state pill: `planned` (electrolyte outline), `verified`/`done` (teal fill, check, source), `skipped` (muted). It always sits on a `WorkoutCard`; never use it for anything but workout state — the state set is the contract (`components/workout-card.md`).

```tsx
<StatusPill status="verified" source="Garmin" />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/workout_card.dart (status chip)`
