# Mealvana Endurance Roadmap

## Overview
This roadmap outlines the development phases for the Mealvana Endurance nutrition planning app, from MVP to full-featured platform.

## Phase 1: MVP - Hive-Only Local App
**Target:** TestFlight release to 5-6 testers  
**Timeline:** Quick turnaround (2-4 weeks)  
**Tech Stack:** Flutter, Hive (local storage only), Riverpod v2  
**Current Status:** 🚀 **ACTIVE DEVELOPMENT**

### Core Features
1. **Onboarding Feature**
   - Multi-step user profile collection
   - Gender, age/birthday, height, weight
   - Water bottle preference
   - Food preference collection (like/dislike/open to try)
   - 12 predefined foods across pre-run, during-run, after-run categories

2. **Nutrition Plan Feature**
   - Distance and pace input
   - Nutrition algorithm research and implementation
   - Macro calculation (carbs, sodium, fluids)
   - Plan generation with timing
   - Local plan storage (multiple plans)
   - Plan history/management

3. **Feedback Feature**
   - Post-plan generation feedback forms
   - Local storage only (no transmission)
   - Plan rating and app feedback

### Technical Tasks
**Foundation Setup:**
- [x] Project architecture planning and documentation review
- [ ] Initialize Flutter project with FOA structure
- [ ] Set up pubspec.yaml with all required packages
- [ ] Create `/theme` folder with Material Design 3 theming system
- [ ] Implement flutter_screenutil for responsive design
- [ ] Set up Riverpod v2 with code generation

**Core Features Implementation:**
- [ ] Create 12-item food database with nutritional data
- [ ] Implement Hive boxes for local data storage
- [ ] Build onboarding flow (4 screens: Welcome → Basic Info → Running Habits → Food Preferences)
- [ ] Create main nutrition planning screen with distance/pace input
- [ ] Implement nutrition calculation algorithms (carbs, sodium, fluids)
- [ ] Build plan display with timing (pre-run, during-run, after-run)
- [ ] Create feedback collection screens (2-step process)
- [ ] Add local plan storage and history management

**Polish & Assets:**
- [ ] Design and implement splash screen with theming
- [ ] Create placeholder launcher icons
- [ ] Implement loading states and micro-animations
- [ ] Add form validation and error handling
- [ ] Test offline functionality and data persistence

### Success Metrics
- [ ] All 5-6 testers can complete full user journey
- [ ] Plans generate accurately based on input
- [ ] App works completely offline
- [ ] No crashes during core flows

---

## Phase 2: Backend Integration & Multi-Device Sync
**Target:** Public beta release  
**Timeline:** 6-8 weeks  
**New Tech:** Supabase, Supabase Auth, RLS

### New Features
1. **Complete Branding Integration**
   - Updated Flutter theme with final brand colors, fonts, and styling
   - Logo integration and brand consistency across all screens
   - Refined UI components with brand guidelines

2. **User Authentication**
   - Supabase Auth integration (Email, Apple, Google)
   - Account creation and sign-in flows
   - User profile management

3. **Data Synchronization**
   - Supabase database setup with RLS
   - Hive ↔ Supabase sync implementation
   - Offline-first architecture with periodic sync
   - Conflict resolution (newest-wins)

4. **Enhanced Plan Management**
   - Cloud backup of nutrition plans
   - Cross-device plan access
   - Plan versioning and history

### Technical Tasks
- [ ] Implement Supabase Auth flows
- [ ] Design and create database schema with RLS policies
- [ ] Build sync layer between Hive and Supabase
- [ ] Handle online/offline state management
- [ ] Implement conflict resolution logic
- [ ] Add connectivity monitoring and retry mechanisms

### Success Metrics
- [ ] Seamless sign-up and sign-in experience
- [ ] Plans sync across devices reliably
- [ ] App maintains offline functionality
- [ ] No data loss during sync conflicts

---

## Phase 3: Advanced Features & Analytics
**Target:** Production release  
**Timeline:** 8-10 weeks  
**New Tech:** Mixpanel, Sentry

### New Features
1. **Recovery Nutrition**
   - Post-run nutrition recommendations
   - Recovery timing optimization
   - Protein and carb targets for recovery

2. **Coach/Athlete Sharing** (Late Phase 3)
   - Plan sharing capabilities
   - Coach dashboard for reviewing athlete plans
   - Collaboration features

3. **Analytics & Monitoring**
   - User behavior tracking with Mixpanel
   - Error monitoring with Sentry
   - Performance metrics and insights

### Technical Tasks
- [ ] Research and implement recovery nutrition algorithms
- [ ] Build sharing infrastructure and permissions
- [ ] Integrate Mixpanel for user analytics
- [ ] Set up Sentry for error tracking and monitoring
- [ ] Create coach dashboard interface
- [ ] Implement plan sharing and collaboration features

### Success Metrics
- [ ] Users actively use recovery nutrition features
- [ ] Coach-athlete sharing works smoothly
- [ ] Analytics provide actionable insights
- [ ] Error rates below 1%

---

## Phase 4: Race-Day & Monetization
**Target:** Premium features launch  
**Timeline:** 6-8 weeks  
**New Tech:** RevenueCat

### New Features
1. **Race-Day Specific Plans**
   - Event-specific nutrition strategies
   - Taper week nutrition guidance
   - Race morning protocols
   - Distance-specific optimizations (5K, 10K, half, full marathon)

2. **Monetization**
   - RevenueCat integration
   - Freemium model implementation
   - Premium features (advanced plans, unlimited storage, priority support)
   - Subscription management

### Technical Tasks
- [ ] Research race-day nutrition strategies
- [ ] Implement event-specific algorithms
- [ ] Integrate RevenueCat for payments
- [ ] Create premium feature gating
- [ ] Build subscription management flows
- [ ] Design pricing and feature tiers

### Success Metrics
- [ ] Users create race-day specific plans
- [ ] Conversion to premium subscriptions
- [ ] Revenue targets met
- [ ] User satisfaction with premium features

---

## Phase 5: Integrations & Advanced Analytics
**Target:** Platform integrations  
**Timeline:** 8-10 weeks

### New Features
1. **Running App Integrations**
   - Strava integration for automatic plan suggestions
   - Garmin integration for real-time guidance
   - Training plan synchronization

2. **Weather-Based Adjustments**
   - Weather API integration
   - Temperature-based hydration adjustments
   - Humidity and heat index considerations

3. **Advanced Analytics**
   - Plan effectiveness tracking
   - User success pattern analysis
   - Personalized recommendations based on history

### Technical Tasks
- [ ] Integrate with Strava and Garmin APIs
- [ ] Implement weather data integration
- [ ] Build advanced analytics dashboards
- [ ] Create personalization algorithms
- [ ] Develop automated recommendation engine

---

## Phase 6: Custom Foods & Community
**Target:** User-generated content  
**Timeline:** 6-8 weeks

### New Features
1. **Custom Food Additions**
   - User-created food database
   - Nutritional information input
   - Food photo uploads via Supabase Storage
   - Community food sharing

2. **Community Features**
   - Plan sharing and discovery
   - User reviews and ratings
   - Community challenges and goals

### Technical Tasks
- [ ] Build custom food creation interface
- [ ] Implement Supabase Storage for food images
- [ ] Create community sharing platform
- [ ] Build moderation tools for user content

---

## Future Considerations

### Potential Phase 7+ Features
- **AI-Powered Recommendations:** Machine learning for personalized nutrition
- **Wearable Integrations:** Heart rate and effort-based adjustments
- **Nutritionist Marketplace:** Connect users with certified professionals
- **International Expansion:** Multi-language support and regional foods
- **Corporate Wellness:** Team and organization features

### Technical Debt & Maintenance
- **PowerSync Migration:** Consider migrating to PowerSync for improved sync
- **Performance Optimization:** Monitor and improve app performance
- **Security Audits:** Regular security reviews and updates
- **Accessibility:** Ensure app meets accessibility standards

---

## Development Timeline Summary

| Phase | Duration | Key Milestone | Target Users |
|-------|----------|---------------|--------------|
| Phase 1 | 8-12 weeks | TestFlight MVP | 5-6 testers |
| Phase 2 | 6-8 weeks | Public Beta | 50-100 users |
| Phase 3 | 8-10 weeks | Production Release | 500+ users |
| Phase 4 | 6-8 weeks | Premium Launch | 1000+ users |
| Phase 5 | 8-10 weeks | Platform Integrations | 2000+ users |
| Phase 6 | 6-8 weeks | Community Features | 5000+ users |

**Total Timeline:** ~12-18 months to full-featured platform

---

## Success Metrics by Phase

### Phase 1 Metrics
- User completion rate through onboarding
- Plans generated per user
- App stability (crash-free rate)
- User feedback scores

### Phase 2 Metrics
- User retention after auth implementation
- Sync success rate
- Cross-device usage
- Data integrity maintenance

### Phase 3+ Metrics
- Feature adoption rates
- User engagement metrics
- Revenue and conversion rates
- Customer satisfaction scores

This roadmap provides a clear path from MVP to full-featured platform while maintaining focus on user needs and technical feasibility.