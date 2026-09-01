---
category: Navigation
---
# TripleAction

The floating Back • More • + pill at the bottom centre of list screens. Use `inline` in layouts that are not positioned; otherwise it pins itself 24 px from the bottom of the nearest positioned ancestor.

```tsx
<div style={{position:"relative",minHeight:400}}>
  …screen content…
  <TripleAction onBack={back} onMore={more} onAdd={add} />
</div>
```
