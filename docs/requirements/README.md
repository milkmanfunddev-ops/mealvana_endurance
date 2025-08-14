# Long Run Nutrition Fueling Plan App - UI/UX Design Task

## Project Overview

Design a simple MVP app that generates personalized nutrition fueling plans for endurance athletes' long run days, covering both pre-run and during-run nutrition needs.

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

~~Design a swipe-based interface for food preferences:~~

- **~~Right swipe**: Like~~
- **~~Left swipe**: Dislike~~
- **~~Down swipe**: Want to try~~
- **~~Up swipe**: Need more information~~

We've decided to go for a checkbox style design that Lee will implement directly: Like, Dislike, Open to try. 

### Food Items to Include:

**Pre-Run Foods:**

- Oatmeal (when swiping up, this information appears: "**Carb up, buttercup:** gentle complex carbs = smooth 2–3-hour energy. Hit 'em 30–60 min pre-run.")
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

- **Carbs:** 285 grams
- **Sodium:** 800-1200mg
- **Fluids:** 40-48 oz

### Plan

**Before Run:** 

1 cup oatmeal + 1 banana, sliced + 1 cup coffee (1h before)

1 cup orange juice (30m before)

**During Run:**

4 gels + 4 cups sport drinks (spaced out every 30m) 

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
- Clear visual indicators for swipe directions (consider overlay hints)
- Subtle animations for swipe gestures
- High contrast for outdoor visibility

### Information Architecture

- Nutrition plan should be easily scannable
- Clear separation between pre-run and during-run sections
- Time/distance markers for when to consume during-run items

### User Experience

- Consider adding a "skip" option for unfamiliar foods
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