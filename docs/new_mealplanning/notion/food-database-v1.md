# Food Database – V1

- **Source URL:** https://app.notion.com/p/32ee3fdb754c81dc9517d93cc6568c27
- **Parent/ancestor path:** 🛠️ Product & Engineering → 🔢 Feature Versions (database) → 🔢 Feature Versions (data source) → Food Database – V1
- **Fetched (Notion "as of" timestamp):** 2026-03-25T15:36:25.141Z

## Properties

| Property | Value |
|---|---|
| Version Name | Food Database – V1 |
| Feature | Food Database: https://app.notion.com/p/32ee3fdb754c810eb768e1826cf24b19 |
| Status | Done |
| Release | v1.17.0 |
| Effort | 2 |
| Impact | 4 |

## Description

Categorize all 1,636 products scraped from theFeed.com with proper workout timing tags and food categories, and fix the Open Food Fact categorization defaults so imported items stop appearing in wrong sections.

This is the data quality foundation that makes every food recommendation feature work correctly. Without clean categories, the algorithm suggests pasta during workouts and gels at breakfast.

## What it delivers

### theFeed.com product categorization

- Categorize all scraped feed data with appropriate workout timing tags:
  - **Pre-workout**: foods suitable for 1-3 hours before exercise (oatmeal, toast, banana, energy bars, etc.)
  - **During-workout**: portable, fast-absorbing items for use during exercise (gels, chews, drink mixes, bars designed for on-bike/on-run consumption)
  - **Post-workout**: recovery-focused items (protein shakes, recovery drink mixes, chocolate milk, etc.)
  - **Top-off**: quick items for 15-30 min before exercise (gels, small snacks, sports drinks)
  - **General/daily**: items suitable for everyday meals but not specifically timed around workouts
- Food category tags: gels, chews, drink mixes, bars, whole foods, protein, electrolytes, caffeine, recovery
- Products can have multiple timing tags (e.g., a bar could be both pre-workout and during-workout)

### Open Food Fact categorization fix

- Fix default categorization so imported items have better category assignments out of the box
- When users import from Open Food Fact, items that lack category data should get AI-assigned categories based on product name, ingredients, and nutritional profile
- Prevent non-workout foods (pasta, cooking ingredients, etc.) from appearing in during-workout recommendations
- Rule-based fallback: if AI categorization confidence is low, flag for manual review rather than assigning a wrong default

### Action items

- Rui to categorize all scraped feed data with appropriate workout timing and food categories
- Fix Open Food Fact categorization defaults so imported items have better category assignments
- Explore AI-based categorization for items that can't be manually categorized at scale

## Future version considerations

- V2 could expand to grocery items for Meal Planning feature support
- V2 could add cost-per-serving data to support the Shopping List feature and address the cost visibility problem from coach interviews
- V2 could add GI tolerance ratings or athlete-reported product feedback integration

## Comments

(Please feel free to provide comments below)

*No comments/discussion threads were present on this page at fetch time.*
