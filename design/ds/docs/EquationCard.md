---
category: Sheets
---
# EquationCard

The energy sheet hero: `eaten − burned = net`. Eaten renders orange (intake), burned electrolyte (burn side), the net in Sansita orange. Pass real spec quantities; the card does the subtraction.

```tsx
<EquationCard eaten={1107} burned={1522} onInfo={explainNet} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart + energy_summary_card.dart (spec: components/energy-card.md v1)`
