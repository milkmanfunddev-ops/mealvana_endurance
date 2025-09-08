# Endurance Athlete Nutrition Planning Guidelines

Design principles for an algorithm to generate nutrition plans for long workouts or race days.

---

## High-Level Goal

> Given macro needs (e.g., carbs, sodium, fluids), generate a personalized nutrition plan using a mixture of food products that meets these targets across different race or workout phases, while also being **digestible**, **portable**, and **timed appropriately**.

---

## Core Guidelines for Endurance Nutrition Plan Generation

### 1. Macro Target Guidelines

| Nutrient       | Recommended Intake |
|----------------|--------------------|
| **Carbohydrates** | |
| • Pre-workout | 1–4g/kg body weight (~70–280g for 70kg athlete) |
| • During workout | 30–60g/hour (up to 90g/hour with glucose+fructose mix) |
| **Sodium** | 300–600mg/hour (up to 1000mg/hour in heat) |
| **Fluids** | ~0.4–0.8 L/hour depending on sweat rate |

---

## Input Parameters to Consider

- Athlete weight (kg)
- Activity type and duration
- Environmental conditions (heat, humidity)
- Food preferences (likes/dislikes)
- GI sensitivities
- Product availability

---

## Planning Rules by Time Phase

### A. Pre-Workout (2–3 hrs before start)

1. Limit to 3–6 different food items to reduce GI stress
2. Aim for low to moderate fiber and fat to speed digestion
3. Include easily digestible carbs (e.g., oatmeal, banana, waffle, white bread, honey)
4. Avoid high-fat or fibrous items (e.g., granola bars, nuts, raw veggies)
5. Include salt or electrolyte if sweat rate is high
6. Recommend sipping 16–24 oz fluids (water + drink mix) slowly
7. Optional small carb hit (e.g., gel) 15 minutes before start

### B. During Run

8. Match carb needs to duration; steady intake every 20–30 min
9. Use carb-dense, portable options (gels, chews, drink mix)
10. Use only easily consumed forms while running (gels, chews, fluids)
11. Flag foods that are not feasible while running (banana, sandwich, oatmeal)
12. Maximize palatability + minimize complexity (2–4 items)
13. Prefer products that combine carbs + sodium

---

## Product-Specific Practicality Table

| Product             | Pre-Run | During Run | Post-Run | Notes                          |
|---------------------|---------|------------|----------|--------------------------------|
| Oatmeal             | ✅ Yes  | ❌ No      | ⚠️ Maybe | Requires prep; pre-run only    |
| Banana              | ✅ Yes  | ❌ No      | ✅ Yes   | Not feasible while running     |
| Peanut Butter       | ✅ Yes  | ❌ No      | ⚠️ Maybe | High fat; slows digestion      |
| Waffle              | ✅ Yes  | ❌ No      | ⚠️ Maybe | Crumbly, hard to eat while running |
| Granola Bar         | ⚠️ Not ideal | ❌ No | ✅ Yes   | Dry and hard to chew while running |
| Gel                 | ✅ Optional | ✅ Yes | ❌ No    | Ideal for during-run fueling   |
| Chews               | ⚠️ No   | ✅ Yes     | ❌ No    | Great for running              |
| Tailwind Drink Mix  | ✅ Yes  | ✅ Yes     | ✅ Yes   | Combines fluid + carbs + Na+   |
| Sports Drink        | ✅ Yes  | ✅ Yes     | ✅ Yes   | Aid station or carried option  |

---

## Additional Rules for the Algorithm

18. Never assign a food during a phase where it's impractical (e.g., oatmeal during run)  
19. Prioritize easily consumed foods during running (gels, chews, fluids)  
20. Adjust plan for sensitive stomach (fewer, simpler items)  
21. Account for flavor fatigue (variety in flavors)  
22. Consider carried hydration capacity for during-run fluid recommendations

---

## Source Reference

Based on: `../../requirements/nutrition_plan_guidelines.md`