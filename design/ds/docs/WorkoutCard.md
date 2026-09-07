---
category: Timeline
---
# WorkoutCard

The workout card on the fuel timeline. Three states drive the whole look: `planned` (dashed electrolyte border, dashed-ring chip, Planned pill), `verified`/`done` (tinted fill, filled chip, verified pill), `skipped` (dashed muted). `reveal="done"|"skip"` renders the swipe gesture mid-reveal for mockups. Titles are Compadre Wide caps, one line, ellipsized.

```tsx
<WorkoutCard title="12 mi Run" detail="5.0 mi · 43 min" status="verified" source="Garmin" />
<WorkoutCard title="Drills Day" detail="3 mi · 43 min" status="planned" reveal="done" />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/workout_card.dart (spec: components/workout-card.md v3)`
