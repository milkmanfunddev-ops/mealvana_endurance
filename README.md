# Mealvana Endurance

Personalized nutrition planning app for endurance athletes. Generate evidence-based nutrition plans for long run days.

## Overview

Mealvana Endurance helps runners create personalized nutrition fueling plans based on their body composition, food preferences, and run details. The app uses evidence-based formulas to calculate optimal carbohydrate, sodium, and fluid intake for endurance activities.

## Features

- **Personalized Plans**: Nutrition calculations based on distance, pace, body weight, and running habits
- **Food Preferences**: Plan recommendations using foods you actually like 
- **Evidence-Based**: Algorithms based on sports nutrition research (30-90g carbs/hour, 200-700mg sodium/hour)
- **Offline-First**: Works completely offline with local storage
- **Clean UI**: Material Design 3 interface optimized for quick plan generation

## Architecture

Built using **Feature-Oriented Architecture (FOA)** with Flutter and Riverpod v2:

```
lib/
  features/
    auth/              # User profiles & food preferences
    nutrition_plan/    # Food database & nutrition calculations  
    onboarding/        # User setup flow
    feedback/          # Plan feedback collection
  shared/
    core/              # App routing, theming, initialization
    theme/             # Material Design 3 themes
```

## Technology Stack

- **Flutter**: Cross-platform mobile development
- **Riverpod v2**: State management with code generation
- **Hive**: Local-first data storage  
- **Material Design 3**: Modern, accessible UI design
- **GoRouter**: Declarative routing
- **flutter_screenutil**: Responsive design

## Getting Started

### Prerequisites

- Flutter SDK (3.19+)
- Dart SDK (3.3+) 
- iOS Simulator / Android Emulator or physical device

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/lbm54/mealvana_endurance.git
   cd mealvana_endurance
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Generate code (Hive adapters, Riverpod providers):
   ```bash
   flutter packages pub run build_runner build
   ```

4. Run the app:
   ```bash
   flutter run
   ```

## User Flow

1. **Welcome** → App introduction and features
2. **User Profile** → Collect demographics (gender, age, height, weight, running habits)
3. **Food Preferences** → Rate 12 food items (like/willing to try/dislike) 
4. **Plan Input** → Enter run distance and pace
5. **Results** → View personalized nutrition plan with hourly breakdown
6. **Feedback** → Provide plan feedback to improve recommendations

## Nutrition Calculations

The app uses evidence-based formulas for endurance nutrition:

- **Carbohydrates**: 30-90g/hour based on duration and body weight
- **Sodium**: 200-700mg/hour with sweat rate adjustments  
- **Fluids**: 13-27 fl oz/hour with body weight considerations

See `docs/business_logic/nutrition_algorithms.md` for detailed formulas and research sources.

## Food Database

Includes 12 carefully selected food items across categories:

**Pre-Run**: Oatmeal, Waffles/Pancakes, Bagel/Bread, Peanut Butter, Banana, Apple, Juice, Granola Bar, Coffee

**During-Run**: Sports Drink, Energy Gel, Energy Chews

Each item includes detailed nutritional information and timing guidance.

## Development

### Code Generation

When modifying Riverpod providers or Hive models, regenerate code:

```bash
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Testing

Run all tests:
```bash
flutter test
```

### Analysis

Check code quality:
```bash
flutter analyze
```

## Project Structure

```
lib/
├── features/
│   ├── auth/
│   │   ├── application/          # AuthService
│   │   ├── data/                 # UserRepository, Models
│   │   └── presentation/         # (future screens)
│   ├── nutrition_plan/
│   │   ├── application/          # NutritionPlanService, Calculator
│   │   ├── data/                 # FoodDatabase, Models, Repository
│   │   └── presentation/         # Plan Input/Results screens
│   ├── onboarding/
│   │   ├── application/          # OnboardingService
│   │   └── presentation/         # Welcome, Profile, Food Preference screens
│   └── feedback/
│       ├── application/          # FeedbackService
│       └── presentation/         # Feedback screens
├── shared/
│   ├── core/                     # AppRouter, initialization
│   └── theme/                    # Material Design 3 themes
└── main.dart                     # App entry point
```

## Contributing

This is a private repository for MVP development. 

## License

Private - All rights reserved.

---

**Built for endurance athletes, by endurance athletes.** 🏃‍♀️💪