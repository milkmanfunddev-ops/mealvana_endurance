# 🍽️ Food Database

- **Source URL:** https://app.notion.com/p/32ee3fdb754c810eb768e1826cf24b19
- **Parent/ancestor path:** Mealvana Endurance App Roadmap (data source) → (database) → Food Database
- **Fetched (Notion "as of" timestamp):** 2026-03-25T16:19:19.115Z

## Properties

| Property | Value |
|---|---|
| Name | Food Database |
| Status | Not started |
| Type | Free |
| Effort | 3 |
| Impact | 4 |
| User Behaviors | linked page: https://app.notion.com/p/37be3fdb754c819681b6e4192c12dd3d |
| Versions | Food Database – V1: https://app.notion.com/p/32ee3fdb754c81dc9517d93cc6568c27 |

## Description

Every food recommendation Mealvana Endurance makes is only as good as the data behind it. When an athlete asks "what should I eat before my long run?" or the algorithm generates a during-workout fueling plan, the system draws from a product database to suggest specific items. If that database has bad categorization — pasta showing up as a during-workout food, gels missing their workout timing tags, Open Food Fact imports with no category at all — the recommendations break down and athlete trust erodes.

This feature covers the ongoing work of building, curating, and improving the food and sports nutrition product database that powers all of Mealvana Endurance's recommendation features. It's the data infrastructure layer beneath Workout macro target → food recommendations, Personal Fueling Formulas, Shopping List, and Meal Planning.

**Current state of the data:**
- 1,636 products scraped from theFeed.com and loaded into Supabase
- Open Food Fact imports available but lack clean category data — many items have no workout timing or food category assigned
- When users import items from Open Food Fact, products like Morton gel appear in wrong workout sections because categorization defaults are missing

## Versions

- [Food Database – V1](https://www.notion.so/32ee3fdb754c81dc9517d93cc6568c27) — Categorize all theFeed.com products with workout timing and food categories

## Related features

This database powers:
- [Workout macro target → food recommendations](https://www.notion.so/328e3fdb754c8064afdddc196c32d0c8)
- [Personal Fueling Formulas](https://www.notion.so/2e9e3fdb754c80aaa695d9fb324f74cd)
- [Shopping List](https://www.notion.so/2f1e3fdb754c80129ba4ca5d3161149d)
- [Meal Planning](https://www.notion.so/2e8e3fdb754c80c4806ed277144fc50d)

## Comments

(Please feel free to provide comments below)

*No comments/discussion threads were present on this page at fetch time.*
