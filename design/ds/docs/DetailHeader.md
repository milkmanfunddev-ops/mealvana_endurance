---
category: Navigation
---
# DetailHeader

Chrome for a pushed detail screen: translucent back circle, Sansita title, trailing action glyphs. Delete is always `tone="destructive"` (dragonfruit) — the meaning contract.

```tsx
<DetailHeader title="12 mi Run" onBack={back} actions={[{icon:"penToSquare",label:"Edit",onClick:edit},{icon:"trash",label:"Delete",tone:"destructive",onClick:del}]} />
```

**Dart source (promote from):** `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
