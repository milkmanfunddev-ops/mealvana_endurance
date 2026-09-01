# A conversation with chatGPT

- Source URL: https://app.notion.com/p/1e3e3fdb754c801fbb26cf6986193192
- Snapshot date: 2025-04-28
- Ancestor path: Features Summaries (database) → Features → Homepage
  - https://app.notion.com/p/199e3fdb754c8045be81fe97bcc7ce7f ("Features")
  - https://app.notion.com/p/199e3fdb754c8074bbbfe11afe559dee ("Homepage")
- Page properties: Multi-select tag "Mealvana for Endurance Athletes"; Status "Not started"

## MVP

### 1. User Profile Setup (Simple)
- Input: height, weight, age, gender
- Set training goal: maintain / lean out / build
- Set dietary preference (omnivore / vegetarian / vegan / gluten-free)

### 2. Training Plan Import
- **Manual entry only**:
  - Workout type (bike/run/swim/strength)
  - Duration and intensity (easy/moderate/hard)
- (TrainingPeaks API connection can come later.)

### 3. Nutrition Needs Estimation
- Calculate daily calorie + macro needs based on:
  - Baseline metabolic rate (simple formula like Mifflin-St Jeor)
  - Adjusted by entered training duration/intensity
- Simple logic (e.g., 60 minutes moderate = +400 calories).

## Iterations

| Phase | Focus | New Features |
|---|---|---|
| **1. Workout Sync** | Make training input automatic | TrainingPeaks API integration |
| 2. Meal planning | | |
| **2. Dynamic Meal Adjustment** | Update based on completed vs. planned workouts | - Meal plan adjusts when a workout changes<br>- "Light training day" auto mode |
| **3. Race Week Mode** | Special fueling weeks | - Carb loading meal plans<br>- Taper week light meals |
| **4. Coach Portal** | Expand audience | - Coach dashboard to assign and adjust meal plans<br>- Athlete-coach messaging |
| **5. Advanced Personalization** | Smarter AI | - Remember user food preferences<br>- Rate meals to improve suggestions |
| **6. Educational Library** | Empower athletes | - Race-day fueling articles<br>- Hydration calculators<br>- Recovery meal guides |
| **7. Progress Tracking** | Connect food and performance | - Energy balance dashboard<br>- Optional body composition tracking<br>- Race-day nutrition rehearsal logs |

### For phase 2, Meal planning

#### AI-Powered Basic Meal Plan
- AI matches calorie/macro target to 1 day of meals:
  - 1 breakfast
  - 1 lunch
  - 1 dinner
  - 2 snacks
- Meals pulled from a small **starter recipe library** (~50 triathlete-friendly recipes).
- User can "shuffle" to get alternative meal options.

#### 5. Grocery List Generator
- Weekly list based on selected meal plan.
- Organized by major store sections (Produce, Protein, Grains, etc.)

#### 6. Mobile-Optimized Web App
- Clean, simple responsive design.
- Save/load meal plans for the week.
- Email or download grocery list.

## Comments/Discussion
None found on this page (no `<page-discussions>` indicator returned by the fetch call).
