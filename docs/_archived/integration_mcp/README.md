# E2E Production Readiness Test - Collaborative Build Guide

## Overview
Building a comprehensive Patrol integration test screen-by-screen using Mobile MCP for screenshots. The test covers the full user journey from onboarding through creating events and activity plans.

## Setup (Completed)
- **Patrol 4.3.0** added to `pubspec.yaml`
- **patrol_cli 4.2.0** installed globally
- Patrol config in `pubspec.yaml` (bundle ID: `com.milkman.mealvanaendurance`)
- Test file: `integration_test/e2e_production_readiness_test.dart`
- Device: iPhone 15 Pro Max simulator (ID: `8F030C0C-8965-4190-9655-BB3245C4D029`)

## How to Resume

### 1. Launch the app
```bash
flutter run --flavor prod -t lib/main_prod.dart -d 8F030C0C-8965-4190-9655-BB3245C4D029
```

### 2. Current progress
We are building two test paths:
- **Path 1**: Signup flow (onboarding → signup → create event → create plan)
- **Path 2**: Login flow (welcome → login → create event → create plan)

### 3. Screens completed

#### Screen 1: Welcome Screen (`/welcome`) - DONE
- **Assertions written**: "Mealvana", "Endurance", "Get Started", "Log In" text visible
- **Auth detection**: Checks if user is logged in or out, TODO for sign-out flow if logged in
- **Path 1 action**: Tap "Get Started" → navigates to onboarding
- **Path 2 action**: Tap "Log In" → navigates to auth screen

#### Screen 2: Connect Your Training (onboarding) - NEXT
- **Screenshot taken**: Shows integration providers (Final Surge, Training Peaks, Tridot, Runna, Vdot)
- **Elements visible**:
  - "Connect Your Training" heading
  - Final Surge → "Connect" button
  - Training Peaks → "Connect" button
  - Tridot, Runna, Vdot → "Notify Me" (coming soon)
  - "Skip for now" link
  - "Continue" button
- **TODO**: User needs to specify what to assert and which button to tap

### 4. Workflow for each screen
1. Take screenshot: `mobile_take_screenshot` via Mobile MCP
2. Ask user what to test/assert on this screen
3. Write Patrol test code for assertions and interactions
4. Tap the appropriate button to advance to next screen
5. Repeat

### 5. Key decisions made
- **Testing framework**: Patrol (not Flutter integration_test)
- **Backend**: Real Supabase (no mocks) - works with whichever flavor the app is built against
- **Structure**: Single test file with two patrolTest blocks (signup path + login path)
- **Device**: iOS Simulator
- **Auth**: Test both signup (fresh account) and login (existing credentials)

## Test File Location
`integration_test/e2e_production_readiness_test.dart`

## Running the test (when complete)
```bash
patrol test --target integration_test/e2e_production_readiness_test.dart
```
