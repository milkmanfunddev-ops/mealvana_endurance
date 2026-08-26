---
category: Buttons
---
# SelectionButton

A selectable tile for grids of options (onboarding sport picker, goal picker, dietary preferences). Lay tiles out in a CSS grid; one or many may be selected depending on the question. Selected tiles fill with the surface foreground.

```tsx
<div style={{display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:12}}>
  <SelectionButton label="Running" icon={<RunIcon/>} isSelected onTap={()=>{}} />
  <SelectionButton label="Cycling" icon={<BikeIcon/>} isSelected={false} onTap={()=>{}} />
</div>
```
