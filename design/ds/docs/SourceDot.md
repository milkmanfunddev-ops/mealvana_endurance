---
category: Data
---
# SourceDot

Provenance glyph: filled = verified (Garmin), half = self-reported, outline = estimated / planned. Always electrolyte — provenance is a burn-side truth. `SourceLegend` renders the legend row under a breakdown.

```tsx
<SourceDot source="verified" />
<SourceLegend labels={{ verified: "verified · Garmin", "self-reported": "self-reported", planned: "planned (estimate)" }} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/widgets/breakdown_pager.dart (provenance glyphs; spec: platform-resolution.md chips)`
