# Mealvana Endurance

Personalized nutrition planning app for endurance athletes. Generate evidence-based nutrition plans for long run days.

## Overview

Mealvana Endurance helps runners create personalized nutrition fueling plans based on their body composition, food preferences, and run details. The app uses evidence-based formulas to calculate optimal carbohydrate, sodium, and fluid intake for endurance activities.

## ✨ Features

- **🎯 Smart Food Prioritization**: Plans use foods you like first, willing-to-try second, avoiding dislikes
- **📊 Evidence-Based Calculations**: Algorithms based on sports nutrition research (30-90g carbs/hour, 200-700mg sodium/hour)
- **🏃‍♂️ Personalized Plans**: Nutrition calculations based on distance, pace, body weight, and gut training level
- **📱 Device-Centric Auth**: No account required - everything tied to your device for privacy
- **🔄 Multi-Category Foods**: Foods can be recommended for multiple timing phases (before/during/after)
- **📏 Structured Serving Data**: Proper food quantities like "3 cups cooked oatmeal" (no more hardcoded parsing)
- **💾 Offline-First**: Works completely offline with Hive storage + Supabase sync
- **🎨 Clean UI**: Material Design 3 interface optimized for quick plan generation

## 🏗️ Tech Stack

- **Frontend**: Flutter with Riverpod 2.x (AsyncNotifier patterns)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Local Storage**: Hive with TypeAdapters
- **Navigation**: GoRouter with nested navigation
- **Architecture**: Feature-Oriented Architecture (FOA)
- **Deployment**: Shorebird for code push updates

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

## 🗄️ Database Schema

### **Core Tables**
- **`users`** - Device-based user profiles with biometric data
- **`foods`** - Food database with structured serving information  
- **`food_categories`** - Many-to-many food timing relationships
- **`food_preferences`** - User preferences (like/dislike/willing_to_try)
- **`nutrition_plans`** - Generated plans with versioning
- **`feedback`** - User satisfaction ratings

### **Key Features**
- **Multi-category foods**: Items can be for before/during/after run
- **Structured serving data**: Database fields for proper quantity display
- **Smart preferences**: Plans prioritize liked → willing-to-try → other foods
- **Device-centric**: No traditional accounts, everything tied to device ID

## 🚀 API Endpoints

### **Edge Functions (Supabase)**

#### **Create User**
```
POST /functions/v1/create-user
```
Creates new user with device-based authentication.

#### **Save Food Preferences**  
```
POST /functions/v1/save-food-preferences
```
Saves user food preferences and completes onboarding.

#### **Create Nutrition Plan**
```
POST /functions/v1/create-nutrition-plan
```
Generates personalized nutrition plan using preferences and algorithms.

## 🍎 User Flow

1. **Welcome** → App introduction and features
2. **User Profile** → Collect demographics (gender, age, height, weight, running habits)
3. **Food Preferences** → Rate foods (like/willing to try/dislike) 
4. **Plan Input** → Enter run distance and pace
5. **Results** → View personalized nutrition plan with proper food quantities
6. **Feedback** → Provide plan feedback to improve recommendations

## 🧮 Nutrition Calculations

The app uses evidence-based formulas for endurance nutrition:

- **Pre-run Carbs**: 1-4g/kg body weight based on timing window
- **During-run Carbs**: 30-60g/hour based on gut training level and body weight
- **Post-run Recovery**: 1g carbs + 0.2g protein per kg body weight
- **Sodium**: 250mg/hour for runs >1 hour
- **Fluids**: 400-800mL/hour (13-27 fl oz/hour) based on intensity and body weight

## 📚 Documentation

### **Database & API**
- **`/docs/database/`** - Complete database schema, migrations, and deployment guide
- **`/docs/business_logic/`** - Edge functions, nutrition algorithms, and API documentation

### **Technical Architecture**
- **`/docs/technical/`** - FOA patterns, Riverpod setup, Supabase integration guides
- **`/docs/technical/andrea/`** - Andrea Bizzotto's architecture patterns and best practices

### **UI/UX Design**
- **`/docs/uiux/`** - Alex's design specifications and screenshot references

### **Requirements & Roadmap**
- **`/docs/requirements/`** - Feature requirements and acceptance criteria
- **`/docs/roadmap/`** - Development roadmap and daily progress tracking

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