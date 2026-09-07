---
category: Inputs
---
# Stepper

Increment / decrement control for macro targets. Value renders in Apercu Mono with the unit attached (`97g`, `444ml`). Pair one Stepper per macro on the Adjust Your Macros screen.

```tsx
<Stepper value={carbs} onChange={setCarbs} step={5} unit="g" />
```
