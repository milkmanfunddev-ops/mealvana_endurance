---
category: Inputs
---
# Switch

Boolean setting toggle. Put the setting label to the left in `.me-body`, the Switch flush right. Electrolyte when on.

```tsx
<label style={{display:"flex",justifyContent:"space-between",alignItems:"center"}}>
  <span className="me-body">Carb loading</span>
  <Switch value={on} onChange={setOn} label="Carb loading" />
</label>
```
