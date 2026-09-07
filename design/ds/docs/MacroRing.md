---
category: Data
---
# MacroRing

A single macro readout — `value/target unit`, eyebrow, thin progress bar. Compose three inside `NutritionalTargetsCard`; use alone in compact summaries. The bar colour must be passed explicitly: the macro colour mapping is not yet ratified.

```tsx
<MacroRing label="Carbs" value={72} target={97} unit="g" color="var(--me-yolk)" />
```
