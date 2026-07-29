# Mealvana Endurance - App Context & Current Functionality

## What This App Does

**Mealvana Endurance** is a personalized nutrition planning app for endurance athletes (runners, cyclists, triathletes) that generates science-based nutrition plans for runs and races. The app creates personalized fueling strategies based on run distance, pace, user biometrics, and food preferences to optimize athletic performance.

### Target Users
- Endurance athletes preparing for races (5K to ultra-marathons)
- Runners seeking personalized nutrition guidance for training runs
- Athletes wanting to optimize their fueling strategy based on evidence-based sports nutrition

## Core App Flow & User Journey

### 1. **Initial Setup (First Time Users)**
```
Welcome Screen → User Profile → Food Preferences → Main App
```

**User Profile Collection:**
- Gender, birthday, height, weight
- Gut training level (low/moderate/high)
- Whether they run with water bottle
- Basic biometric data for nutrition calculations

**Food Preferences Setup:**
- Three-tier preference system: Like / Willing to Try / Dislike
- Users select from 50+ common endurance foods
- Preferences influence all future nutrition plan recommendations
- Examples: Bananas (like), Gels (willing to try), Dairy products (dislike)

### 2. **Main App Navigation (Three-Tab Structure)**

#### Tab 1: **Plan** - Core Nutrition Planning
**Entry Screen:** Distance/Pace/Gut Entry
- **Distance:** Run distance in miles (5K to 100+ miles)
- **Average Pace:** Expected pace in min/mile format
- **Time Before Run:** When they plan to eat (30min to 4+ hours)
- **Gut Training Level:** How well their stomach handles food during runs
- **Environmental Factors:** Temperature, humidity, sweat rate

**Generate Plan Button** → Creates personalized nutrition plan

#### Tab 2: **Journal** - Workout Notes & Voice Memos
- **Voice Memo Recording:** Athletes can record post-run thoughts
- **Plan Rating System:** Rate how well the nutrition plan worked (1-3 scale)
- **Journal Notes:** Free-form text feedback about the plan
- **Voice Notes List:** Browse and replay previous voice recordings

#### Tab 3: **Settings** - Profile & Preferences
- **Edit Profile:** Update biometric data
- **Food Preferences:** Modify liked/disliked foods
- **Account Settings:** Basic app preferences
- **Feedback:** Submit suggestions and bug reports

### 3. **Nutrition Plan Generation & Display**

#### **AI-First Dual System Architecture**
The app uses a sophisticated two-tier planning system:

**Primary: AI-Powered Planning**
- LLM integration with natural language understanding
- Linear programming optimization for food selection
- Advanced personalization considering context and preferences
- Multi-objective optimization balancing carbs, protein, fat, sodium, hydration

**Fallback: Algorithmic Planning**
- Evidence-based ACSM formulas for energy expenditure
- Sub-second response times with deterministic calculations
- ISSN sports nutrition guidelines for macro targets
- Reliable backup when AI system unavailable

#### **Generated Plan Structure**
Every nutrition plan contains three phases:

**Before Run (Pre-Run Fueling)**
- Timing: 30 minutes to 4+ hours before
- Focus: Carbohydrate loading without GI distress
- Example: Oatmeal with banana, coffee, 16oz water
- Macro targets: 30-60g carbs, minimal fat/fiber

**During Run (Mid-Run Fueling)**
- For runs >60-90 minutes
- Focus: Maintaining blood glucose and hydration
- Example: Energy gels, sports drink, electrolyte tablets
- Target: 30-90g carbs/hour depending on gut training

**After Run (Recovery Fueling)**
- Within 30 minutes post-run
- Focus: Glycogen replenishment and muscle protein synthesis
- Example: Protein shake with fruit, recovery drink
- Targets: 1.2g carbs/kg body weight + 20-25g protein

### 4. **Plan Interaction & Customization**

#### **Adjust Macros Screen**
- **Fine-tune Targets:** Modify carb/protein/fat/sodium/fluid targets
- **Evidence-Based Validation:** Warning indicators for values outside research ranges
- **Instant Recalculation:** Real-time plan updates as targets change
- **Science-Based Help:** Explanations of ISSN guidelines and nutrition research

#### **Food Swapping**
- **Dislike a Food?** Tap to swap for similar alternative
- **Preference Learning:** App remembers swaps for future plans
- **Nutritional Equivalency:** Maintains macro targets while respecting preferences
- **Contextual Replacements:** Suggests appropriate foods for each phase

#### **Plan Saving & History**
- **Local Storage:** All plans saved offline using Drift SQLite
- **Plan Rating:** Rate effectiveness after completing the run
- **Plan Notes:** Add custom notes about plan performance
- **History Tracking:** Browse previously generated plans

## Technical Architecture Overview

### **Development Framework**
- **Platform:** Flutter 3.8+ (iOS & Android)
- **Architecture:** Feature-Oriented Architecture (FOA) - Andrea Bizzotto patterns
- **State Management:** Riverpod 2.x with @riverpod AsyncNotifier pattern
- **Navigation:** GoRouter with robust initialization pattern

### **Data & Storage Strategy**
**Offline-First Dual Database Architecture:**

**Local Storage (Drift SQLite v2):**
- 10 tables with type-safe migrations
- Full offline functionality without internet
- User profiles, food preferences, nutrition plans, feedback
- 24-hour refresh cycles for reference data

**Cloud Storage (Supabase PostgreSQL):**
- Mirrors local schema for backup and synchronization
- Dynamic content management for UI text and algorithm parameters
- Edge functions for AI nutrition plan generation
- Row Level Security for privacy protection

### **Authentication & Privacy**
**Device-Based Authentication (No User Accounts):**
- Users identified by device ID (iOS: identifierForVendor, Android: Android ID)
- All data stored locally first, synced using device ID as identifier
- No email, password, or personal identification required
- Privacy-first approach with anonymous analytics

### **Content Management System**
**"Fat Backend" Architecture:**
- All UI text editable via Supabase backend
- Algorithm parameters configurable without app updates
- A/B testing capabilities for nutrition formulas
- Instant content updates without App Store releases
- Fallback to local defaults for offline functionality

### **AI & Nutrition Intelligence**

**Edge Functions (Supabase):**
1. **`generate-ai-nutrition-plan`** - Primary AI-powered planning with LLM integration
2. **`run-plan`** - Fast algorithmic fallback using evidence-based formulas
3. **`save-food-preferences`** - Three-tier preference management system

**Nutrition Science Integration:**
- **ACSM Formulas:** Energy expenditure calculations using metabolic equations
- **ISSN Guidelines:** International Society of Sports Nutrition recommendations
- **Evidence-Based Timing:** Pre/during/post-run nutrition based on research
- **Individual Variation:** Gut training levels and personal tolerance factors

## Current Feature Set (What Users Can Do Today)

### ✅ **Fully Implemented Features**

**Core Nutrition Planning:**
- Generate personalized nutrition plans for any run distance
- Three-phase planning (before/during/after run)
- AI-powered and algorithmic plan generation
- Real-time macro target adjustment
- Food swapping based on preferences

**User Profile Management:**
- Biometric data collection and storage
- Food preference management (like/willing/dislike)
- Profile editing and updates
- Gut training level customization

**Plan Management:**
- Save nutrition plans locally
- Rate plan effectiveness (1-3 scale)
- Add custom notes to plans
- Browse plan history
- Offline access to all saved plans

**Voice Journal & Feedback:**
- Record voice memos about workouts
- Play back previous recordings
- Submit feedback about app functionality
- Rate and review generated plans

**Settings & Customization:**
- Edit user profile and preferences
- Modify food likes/dislikes
- App configuration options
- Feedback submission system

### 🔄 **In Development**
- Enhanced food database with more options
- Advanced analytics and plan effectiveness tracking
- Improved voice memo organization and search
- Recipe management system

### 🚧 **Planned Features**
- Race calendar integration
- Carb loading calculator for race preparation
- Social features for sharing plans
- Coach/athlete plan collaboration
- Advanced nutrition tracking and logging

## Data Flow & User Experience

### **Typical User Session:**
1. **Open App** → Automatic startup and data sync
2. **Plan Generation** → Enter run parameters → Generate nutrition plan
3. **Plan Review** → Review recommendations → Adjust if needed → Save plan
4. **Pre-Run** → Follow pre-run nutrition suggestions
5. **During Run** → Execute during-run fueling strategy
6. **Post-Run** → Complete recovery nutrition → Rate plan effectiveness
7. **Journal** → Record voice memo about workout and nutrition experience

### **Offline Functionality:**
- Complete app functionality without internet connection
- All user data stored locally with Drift SQLite
- Background sync when connectivity restored
- Cached food database and content for offline access

### **Data Synchronization:**
- Device-based sync using device ID as user identifier
- Conflict resolution using timestamps (newest-wins)
- 24-hour refresh cycles for reference data
- Automatic sync triggers on app start and connectivity changes

## Key Differentiators

**Science-Based Approach:**
- Uses ACSM and ISSN evidence-based formulas
- Calculations based on peer-reviewed sports nutrition research
- Personalized to individual biometrics and gut tolerance

**Offline-First Design:**
- Full functionality without internet connection
- Local data storage with cloud backup
- No dependency on constant connectivity

**Preference-Aware Planning:**
- Learns from user food preferences and swaps
- Balances nutritional needs with food enjoyment
- Avoids foods that cause individual GI distress

**AI-Enhanced Personalization:**
- Dual AI/algorithmic system for reliability
- Context-aware recommendations
- Linear programming optimization for food selection

**Privacy-First Architecture:**
- No user accounts or personal identification required
- Device-based authentication
- Local data storage with optional cloud sync

---

**Current Status:** Production app with active users, continuously improving nutrition algorithms and user experience based on athlete feedback and sports nutrition research.