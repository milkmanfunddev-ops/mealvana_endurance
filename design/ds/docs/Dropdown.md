---
category: Inputs
---
# Dropdown

Labelled select for a longer list of options (activity type, intensity, units). The label is part of the component. Use `SegmentedControl` instead when there are four options or fewer.

```tsx
<Dropdown label="Activity type" value={type} items={[{value:"run",label:"Run"},{value:"ride",label:"Ride"},{value:"swim",label:"Swim"}]} onChange={setType} />
```
