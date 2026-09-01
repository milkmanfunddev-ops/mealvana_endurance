---
category: Data
---
# SourceLegend

The legend row under a breakdown or energy list: `● verified · Garmin  ◐ self-reported  ○ estimated`. Pass only the sources the surface actually uses; `planned` replaces `estimated` on the Active Energy sheet.

```tsx
<SourceLegend labels={{ verified: "verified · Garmin", "self-reported": "self-reported", planned: "planned (estimate)" }} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart`
