---
category: Sheets
---
# BreakdownTable

"Where the burn comes from": a bordered card with a two-column figure table. Every row has a provenance `SourceDot`, a name with `InfoIcon`, and so-far / by-day's-end numbers; totals in electrolyte. Use for any so-far vs projected breakdown.

```tsx
<BreakdownTable title="Energy burned" rows={[{name:"Resting",source:"estimated",sourceLabel:"estimated",soFar:"808",byEnd:"1,064"},{name:"Workout",source:"verified",sourceLabel:"verified · Garmin",soFar:"+411",byEnd:"+930"}]} total={{label:"Total burned",soFar:"1,522",byEnd:"2,462"}} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart`
