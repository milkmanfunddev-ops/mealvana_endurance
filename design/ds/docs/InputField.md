---
category: Inputs
---
# InputField

Single-line text or number entry. Use `numeric` with a `suffix` unit for quantities (`g`, `ml`, `kg`, `min`) — the value right-aligns with tabular figures. Label it from the surrounding layout (a `.me-descriptor` above) and pass `label` for accessibility.

```tsx
<div className="me-descriptor">Body weight</div>
<InputField numeric suffix="kg" value={kg} onChange={setKg} label="Body weight" />
```
