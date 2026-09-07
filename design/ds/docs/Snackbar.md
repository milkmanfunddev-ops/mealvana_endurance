---
category: Feedback
---
# Snackbar

Transient confirmation or error, floating above content. `type` carries the meaning: `success` electrolyte, `error` dragonfruit, `warning` orange, `info` cream. One short sentence, no exclamation mark; optional single action.

```tsx
<Snackbar type="success" message="Plan saved" actionLabel="Undo" onAction={undo} />
```
