# Mealvana Endurance - Requirements & Design Specification

## Project Overview

Design and develop an evidence-based nutrition planning app that generates personalized fueling plans for endurance athletes, covering pre-run, during-run, and post-run nutrition needs. The app follows comprehensive endurance athlete nutrition guidelines to ensure digestible, portable, and appropriately timed nutrition recommendations.

## Core Requirements

### Evidence-Based Foundation
The app implements scientifically-backed nutrition guidelines for endurance athletes:
- **Macro targets** based on body weight and exercise duration (1-4g/kg carbs pre-run, 0-60g total during-run)
- **Phase-specific food selection** with practicality constraints (no oatmeal/banana during runs)
- **Product-specific suitability** enforced via database categorization system
- **GI tolerance considerations** to minimize digestive stress
- **Duration-based recommendations** (no fueling <60min, progressive increases for longer runs)

See `nutrition_plan_guidelines.md` for complete scientific foundation.

## User Flow

### 1. Onboarding

Create a multi-step onboarding flow to collect:

- **Gender** (selection)
- **Age or Birthday** (recommend birthday for automatic age calculation)
- **Height** (feet & inches)
- **Weight** (pounds)
- Do you run with a water bottle?

*Note: No unit toggles needed for US MVP*

### 2. Food Preference Collection

Design a checkbox-based interface for food preferences on a single screen:

- **Checked** = Like this food (will be included in nutrition plans)
- **Unchecked** = Dislike this food (will be avoided in nutrition plans)
- **Single scrollable list** showing all 12 food items by name
- **Select All / Clear All buttons** for convenience
- **Tap food name** to see detailed information and nutritional guidance 

### Food Items to Include:

**Pre-Run Foods:**

- Oatmeal (when tapping, this information appears: "**Carb up, buttercup:** gentle complex carbs = smooth 2–3-hour energy. Hit 'em 30–60 min pre-run.")
- Waffle or pancakes
- Bagel or bread 🥯
- Peanut butter
- Banana
- Apple
- Juice
- Granola bars
- Coffee ☕

**During-Run Foods:**

- Sports drink
- Gel
- Chews
- Sport drink mix
- Dates or dried fruits
- Electrolyte tablets

**After-Run Foods:**

- Coconut water
- Protein shake
- Protein bars

[Tell me why](https://www.notion.so/Tell-me-why-24ee3fdb754c80b39832ed9b041fad72?pvs=21)

### 3. Main Screen

Design a simple input interface:

- **Distance input** (miles)
- **Average pace input** (min/mile)
- **"Generate Plan" button**
- **Display area for:**
    - Calculated macro needs
    - Pre-run meal plan (1-2 hours before)
    - During-run fueling schedule (based on time/distance)

A mock example of output:

### Macro Targets

- **Pre-run Carbs:** 70-280g (1-4g/kg based on available time)
- **During-run Carbs:** 0-60g total (based on run duration and gut training)
- **Sodium:** 0-600mg total for entire run
- **Fluids:** 150-800ml total for entire run

### Plan

**Before Run:** 

1 cup oatmeal + 1 banana, sliced + 1 cup coffee (1h before)

1 cup orange juice (30m before)

**During Run:**

2 gels + 16 oz sports drink (total for entire run, consume gradually) 

**After Run:**

1 Protein bar (within 30m)

2 cups coconut water (within 30m)

### 4. MVP Feedback Component

Create a post-plan generation feedback mechanism:

Feedback question 1: What do you think about this plan?

- Pretty close to what I think I should use
- Much more than what I think I should use
- Much less than what I think I should use

Feedback question 2: What do you think about this tiny app? 

- **Option 1**: "I like it! Remind me to use it"
    - → Links to reminder functionality
- **Option 2**: "It has potential but I need it to..."
    - → Text input field for suggestions
- **Option 3**: "Not interested"
    - → Optional reason selection

## Design Considerations

### Visual Design

- Clean, minimalistic interface
- Clear checkbox states for food preferences
- Tap-to-reveal detailed information for each food
- High contrast for outdoor visibility

### Information Architecture

- Nutrition plan should be easily scannable
- Clear separation between pre-run and during-run sections
- Time/distance markers for when to consume during-run items

### User Experience

- Simple checkbox interface for quick food preference selection
- Select All / Clear All buttons for convenience
- Tap food names to see additional details and timing guidance
- Make feedback component non-intrusive but easily accessible
- Progress indicator for onboarding steps
- Quick access to edit preferences after initial setup

## MVP Success Metrics

- Completion rate of onboarding
- Percentage of users who generate a plan
- Feedback response rate
- Specific feedback content for iteration

## Future Considerations

- Save/export nutrition plans
- Integration with popular running apps
- Weather-based adjustments
- Custom food additions
- Share plans with coaches/nutritionists

## Source Reference

Based on: `../../requirements/README.md`