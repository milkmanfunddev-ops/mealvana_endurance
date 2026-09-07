---
category: Buttons
---
# TertiaryButton

Text-only link action. `tone="dragonfruit"` (default) is destructive — Remove, Swap out, Delete. `tone="electrolyte"` is additive — Add food, Add activity. Those meanings are the contract (tokens.md): never use dragonfruit for a non-destructive link.

```tsx
<TertiaryButton tone="electrolyte" onClick={add}>+ Add Food</TertiaryButton>
<TertiaryButton onClick={remove}>× Remove Food Item</TertiaryButton>
```
