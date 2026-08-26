---
category: Dashboard
---
# ViewTabs

Top chrome of the dashboard: `BY WEEK · BY MONTH` caps tabs with underline, gear, and the month stepper. Two tabs only.

```tsx
<ViewTabs tabs={[{value:"week",label:"By Week"},{value:"month",label:"By Month"}]} selected="week" onChange={setView} period="August 2026" onPrev={prev} onNext={next} onSettings={openSettings} />
```

**Dart source (promote from):** `lib/features/calendar/presentation/widgets/calendar_view_toggle.dart + lib/features/fuel_timeline/presentation/widgets/fuel_timeline_day_header.dart`
