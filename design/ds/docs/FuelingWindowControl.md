---
category: Fueling
---
# FuelingWindowControl

The pre-workout window stepper for the create flow: −/+ walk the 15-min grid (CF-1; an off-grid clamp-seeded value snaps onto the grid on the first step, but the off-grid ceiling itself stays reachable) between 0 and the ruled clamp `min(240, time-until-start)`; at the clamp the + disables — the athlete sees the real ceiling, never a feeding in the past (CF-2). The label is sport-dynamic (`Pre-Run` / `Pre-Ride` / `Pre-Swim` / `Pre-Activity`, CF-5) and the caption carries the Q-CF1 class line or the CF-2 clamp explanation — both supplied by the owning controller, never derived here.

```tsx
<FuelingWindowControl label="Pre-Run Fueling Window" minutes={180} maxMinutes={240} onChanged={setMinutes} caption="3 h — long session" />
<FuelingWindowControl label="Pre-Ride Fueling Window" minutes={35} maxMinutes={35} onChanged={setMinutes} caption="Capped: session in 35 min" />
```

**Dart source:** `lib/shared/widgets/kyle_design/fueling/fueling_window_control.dart` (library) — spec `docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md` v1
