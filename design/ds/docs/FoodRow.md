---
category: Data
---
# FoodRow

A meal card on the fuel timeline: 56 px orange utensils chip, caps food name (Compadre), then `640 kcal · 116C · 16P · 12F` with the surface data colours. Stack rows with `gap: 10px`; a timeline rail with times is layout you compose around them.

```tsx
<FoodRow name="Oatmeal, Banana & Honey" kcal={640} carbs={116} protein={16} fat={12} onClick={open} />
```

**Dart source (promote from):** `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart (meal card) + lib/features/nutrition_plan/presentation/widgets/fuel_log/fuel_log_food_row.dart`
