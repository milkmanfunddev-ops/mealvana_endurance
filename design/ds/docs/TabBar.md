---
category: Navigation
---
# TabBar

Floating bottom navigation pill: three glyphs, selected in a cream circle. Use inside a `position: relative` screen container, or `inline` in layouts. Default set: calendar (timeline), calendarCheck (plan), graduationCap (learn).

```tsx
<TabBar items={[{value:"timeline",icon:"calendar",label:"Timeline"},{value:"plan",icon:"calendarCheck",label:"Plan"},{value:"learn",icon:"graduationCap",label:"Learn"}]} selected="timeline" onChange={go} />
```

**Dart source (promote from):** `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart (already in library — verify)`
