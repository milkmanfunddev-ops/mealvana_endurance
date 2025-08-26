# Mealvana Endurance - Project Overview

## Purpose
Mealvana Endurance is a personalized nutrition planning app for endurance athletes (runners, cyclists, triathletes). It generates science-based nutrition plans based on run distance, pace, user biometrics, and food preferences.

## Target Users
- Endurance athletes preparing for races (5K to ultra-marathons)
- Runners seeking personalized nutrition guidance  
- Athletes wanting to optimize their fueling strategy

## Key Features
- **Personalized Nutrition Plans**: Algorithm-based plans considering distance, pace, body weight, and gut training
- **Food Preference Integration**: Respects user's liked/disliked foods
- **Science-Based Calculations**: Uses ACSM formulas and evidence-based nutrition research
- **Offline-First Architecture**: Works without internet using Drift SQLite database
- **Content Management System**: Backend-editable UI text and algorithm parameters

## Architecture Pattern
The project follows **Feature-Oriented Architecture (FOA)** based on Andrea Bizzotto's patterns. Each feature is self-contained with its own layers:

```
lib/features/{feature_name}/
├── presentation/   # UI widgets and controllers
├── application/    # Service classes and business logic
├── domain/        # Data models and entities
└── data/          # Repositories and data sources
```

## Current Status
- Successfully migrated from Hive to Drift database
- Uses Shorebird for over-the-air updates
- Implements fat backend architecture for content management
- Production-ready with Sentry error tracking and Mixpanel analytics