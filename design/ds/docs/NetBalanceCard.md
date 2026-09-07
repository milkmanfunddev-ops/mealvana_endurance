---
category: Dashboard
---
# NetBalanceCard

The day's net energy summary. `value` is signed kcal; `status` is the band copy from the spec ("slight deficit", "on track"). Tapping opens the energy sheet. One per dashboard.

```tsx
<NetBalanceCard value={-415} status="slight deficit" onExpand={openEnergy} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/energy_summary_card.dart`
