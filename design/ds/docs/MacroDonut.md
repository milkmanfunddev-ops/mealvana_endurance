---
category: Data
---
# MacroDonut

Macro progress ring. Three in a row — Carbs, Protein, Fat — each with its data colour (`--me-data-carbs / -protein / -fat`), value with a coloured unit, "of target", and a "g left" caption. `planned` draws a dimmer arc after the logged one.

```tsx
<MacroDonut label="Carbs" value={184} target={253} color="var(--me-data-carbs)" caption="70 g left" />
```

**Dart source (promote from):** `lib/features/daily_macros/presentation/widgets/today_hero_card.dart + macro_summary_strip.dart`
