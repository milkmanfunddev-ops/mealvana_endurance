---
category: Buttons
---
# PrimaryButton

The single filled orange pill on a screen. Use for the one action the screen exists for ("Generate Plan", "Complete Workout", "Create Plan"). Label in Title Case, no exclamation marks. Prefer `full` on mobile layouts. Never place two on one surface — demote the second to `SecondaryButton`.

```tsx
<PrimaryButton full onClick={generate}>Generate Plan</PrimaryButton>
```
