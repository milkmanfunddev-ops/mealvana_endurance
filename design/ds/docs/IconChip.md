---
category: Foundations
---
# IconChip

The round icon marker on every card and row. **Orange = food / intake, electrolyte = activity / burn** — that pairing is the app's visual contract. 56 px on cards (default), 36 px in rows. `variant="outline"` gives the ring look used for filter chips (dragonfruit / orange / electrolyte rings).

```tsx
<IconChip color="var(--me-orange)"><Icon name="utensils" size={22} /></IconChip>
<IconChip><Icon name="personRunning" size={24} /></IconChip>
```
