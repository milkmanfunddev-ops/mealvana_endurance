# Mealvana Endurance - App Overview

## Project Summary

Mealvana Endurance is a personalized nutrition planning app for endurance athletes that generates evidence-based nutrition fueling plans for long run days.

## Target Users

- Endurance athletes (runners, cyclists, triathletes)
- Athletes preparing for races from 5K to ultra-marathons
- Runners seeking personalized nutrition guidance
- Athletes wanting to optimize their fueling strategy

## Core Value Proposition

Generate personalized, science-based nutrition plans that help endurance athletes:
- Optimize energy delivery during training and races
- Prevent digestive issues through proper food timing
- Maintain hydration and electrolyte balance
- Respect individual food preferences and restrictions

## Key Features

### 🎯 Smart Food Prioritization
Plans use foods you like first, willing-to-try second, avoiding dislikes

### 📊 Evidence-Based Calculations
Algorithms based on sports nutrition research (30-90g carbs/hour, 200-700mg sodium/hour)

### 🏃‍♂️ Personalized Plans
Nutrition calculations based on distance, pace, body weight, and gut training level

### 📱 Device-Centric Auth
No account required - everything tied to your device for privacy

### 🔄 Multi-Category Foods
Foods can be recommended for multiple timing phases (before/during/after)

### 📏 Structured Serving Data
Proper food quantities like "3 cups cooked oatmeal" (no more hardcoded parsing)

### 💾 Offline-First
Works completely offline with local storage

### 🎨 Clean UI
Material Design 3 interface optimized for quick plan generation

## Tech Stack

- **Frontend**: Flutter with Riverpod 2.x (AsyncNotifier patterns)
- **Backend**: Supabase (PostgreSQL + Edge Functions)
- **Local Storage**: Drift SQLite database
- **Navigation**: GoRouter with nested navigation
- **Architecture**: Feature-Oriented Architecture (FOA)
- **Deployment**: Shorebird for code push updates

## Success Metrics

- User completion rate through onboarding
- Plans generated per user
- App stability (crash-free rate)
- User feedback scores
- Plan effectiveness feedback

## Source Reference

Based on: `../../README.md`