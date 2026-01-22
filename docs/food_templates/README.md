# Food Templates Documentation

This folder contains documentation for Mealvana Endurance's nutrition template system.

## Overview

The template system provides pre-built meal/snack combinations for different fueling scenarios that athletes encounter. Templates are designed to scale based on body weight and validated against nutrition science guidelines.

## Folder Structure

```
/docs/food_templates/
├── README.md                 # This file
├── checklist.md              # Progress tracking for template expansion
├── notes.md                  # Nutrition guidelines and science reference
├── foods_database.md         # All foods with nutrition data
├── templates_database.md     # All templates organized by timing window
└── research/                 # Research output from agents
    ├── during_run_research.md
    ├── during_bike_research.md
    ├── during_swim_research.md
    ├── post_workout_research.md
    └── transition_research.md
```

## Template Categories

### Currently Implemented (Pre-Workout)
- **30-60 min (Top-Up)**: 11 templates - Quick carbs, no fat/protein
- **1-2 hours (Snack)**: 11 templates - Moderate carbs, low fat/protein
- **3-4 hours (Full Meal)**: 11 templates - Full meal with balanced macros

### In Development
- **During Run**: Fueling during running workouts (gels, chews, drinks)
- **During Bike**: Fueling during cycling (more solid food options)
- **During Swim**: Pool deck or open water feed scenarios
- **Post-Workout**: Recovery nutrition (0-30 min window)
- **T1 Transition**: Swim → Bike quick fueling
- **T2 Transition**: Bike → Run quick fueling

## Source of Truth

The primary data lives in Notion:
- **Foods Database**: https://www.notion.so/cc1c5237ab7d4b348b42e7c39de73ed4
- **Templates Database**: https://www.notion.so/4f3838cf5dcf4bb0aaf39fcd3ce594df
- **Templates Page**: https://www.notion.so/2efe3fdb754c80f7ab74cf8b883b795a

These markdown files are working copies for development and research.

## Validation Process

Each template is validated against 4 test personas:
| Persona | Weight |
|---------|--------|
| Small Female | 54 kg (120 lb) |
| Medium Female | 64 kg (140 lb) |
| Medium Male | 73 kg (160 lb) |
| Large Male | 91 kg (200 lb) |

Templates must hit carb targets within ±10% of minimum for their timing window.

## Nutrition Science Reference

Full guidelines are in `notes.md`, sourced from:
- [How Mealvana Calculates Race Fueling](https://endurance.mealvana.io/blog/2026/01/21/how-mealvana-calculates-race-fueling/)
- ACSM Position Stand on Nutrition and Athletic Performance
- International Society of Sports Nutrition guidelines

## Workflow

1. Research common fueling practices (see `/research` folder)
2. Add any new foods to `foods_database.md`
3. Create template entries in `templates_database.md`
4. Validate templates against personas
5. Update Notion databases with final templates
6. Mark items complete in `checklist.md`

## Related Documentation

- [Business Logic](/docs/business_logic/README.md) - Nutrition algorithm details
- [Nutrition Algorithms](/docs/business_logic/nutrition_algorithms.md) - Calculation formulas
- [Content Management](/docs/technical/content-management.md) - How templates integrate with the app
