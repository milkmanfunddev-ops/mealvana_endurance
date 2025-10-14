# Calendar Feature - Unified Activity & Nutrition Hub

## Overview

The Calendar feature represents a major architectural shift in Mealvana Endurance, transforming from a tab-based navigation structure to an **activities-list-centric interface** that seamlessly integrates all training and nutrition activities. This feature replaces the current tab structure and consolidates nutrition planning, carb loading, activity tracking, and workout completion into a single, cohesive experience.

**IMPORTANT**: This is an **activities-first** app, not a calendar-first app. The main screen shows a calendar date picker with a daily activity list below it.

## Vision & Goals

### Primary Vision
Create an activities-list experience where athletes can:
- **Plan**: Schedule activities via tabbed creation interface
- **Generate**: Manually create nutrition plans through existing flow
- **Prepare**: Implement carb loading strategies for race events (2-day or 3-day protocols)
- **Execute**: Track workout completion and rate effectiveness
- **Review**: Maintain a comprehensive training and nutrition history

### Key Goals
1. **Simplify Navigation**: Two-tab structure (Activities List + Settings)
2. **Unify Experiences**: Integrate nutrition planning, carb loading, and activity tracking in daily list
3. **Manual Control**: Users explicitly create nutrition plans when ready
4. **Enhance Workflow**: Create logical progression from planning to execution to review
5. **Maintain Data Integrity**: Preserve all existing functionality while modernizing UX
6. **Device-Based Identity**: No authentication required - uses device_id from user_profiles

## Feature Capabilities

### Core Activity Management
- **Activity Types**: Running and Events (Biking/Swimming tabs surface as "Under Construction" placeholders for future work)
- **Activity States**: Planned, In Progress, Completed, Skipped
- **Smart Scheduling**: Activities appear in daily list immediately when created
- **Nutrition Integration**: Each activity can have ONE nutrition plan (manually created)

### Event Management System
- **Event Types**: Marathon, Half-Marathon, 10K, 5K, Ultra distances, Custom
- **Access**: Via "Upcoming Event" widget on Activities List screen
- **Separate List**: Events have their own dedicated list screen
- **Special Capabilities**:
  - Carb loading plan integration (0-day [none], 2-day, or 3-day protocols)
  - Manual nutrition plan creation via action buttons
  - Enhanced event details (bib number, goal times, registration URL)
- **Timeline Integration**: Events appear in Activities List with special event styling

### Carb Loading Integration (Phase 2)
- **Protocols**: 0-day (no carb loading), 2-day, or 3-day protocols only
- **Access**: From Event Detail Screen → "Create Carb Loading Plan" button
- **Protocol Selection**: Based on carb_loading_protocols.md specifications
- **Seamless Planning**: Carb loading days appear as separate activities in daily list
- **Intelligent Scheduling**: Automatically calculates optimal start dates relative to race day
- **Day Detail**: Tapping carb day shows single-day carb loading screen
- **Nutrition Coordination**: Carb loading plans complement race day nutrition plans

- **Simple Completion**: Mark Complete → Rate (5 emoji scale) → Optional Notes or Voice Note
- **Voice Notes Integration**: Reuse the existing voice notes feature for audio capture (no speech-to-text dependency)
- **Progress Tracking**: Visual indicators show completion status across calendar
- **Data Preservation**: All feedback stored for future plan optimization

## User Benefits

### For Daily Training
- **Quick Planning**: Create activities in 30 seconds with auto-generated nutrition plans
- **Visual Overview**: See entire week of training and nutrition at a glance
- **Effortless Tracking**: Mark activities complete with one tap
- **Performance History**: Review past workouts and nutrition effectiveness

### For Race Preparation
- **Comprehensive Planning**: Schedule race with automatic carb loading recommendations
- **Timeline Clarity**: See carb loading progression leading up to race day
- **Nutrition Confidence**: Race-specific nutrition plans optimized for distance and goals
- **Preparation Tracking**: Monitor carb loading adherence and make adjustments

### For Long-term Development
- **Pattern Recognition**: Identify successful nutrition strategies over time
- **Plan Evolution**: Learn from feedback to improve future recommendations
- **Training Load Management**: Balance nutrition with training intensity
- **Goal Achievement**: Track progress toward race and performance objectives

## Architecture Changes

### Navigation Structure Transformation

**Current Tab Structure (Replaced)**:
```
Bottom Tabs:
├── Current Plan (nutrition)
├── Voice Notes (journal)
├── Carb Loading (specialized)
└── Settings
```

**New Calendar Structure**:
```
Bottom Tabs:
├── Calendar (primary hub)
├── Activity Detail (dynamic)
└── Settings
```

### Data Flow Architecture

**Unified Data Model**:
- Activities as central organizing principle
- Nutrition plans as properties of activities
- Events as specialized activity types
- Carb loading as activity-linked entities

**State Management**:
- Calendar controller manages week view and navigation
- Activity controllers handle CRUD operations
- Nutrition plan controllers manage generation and editing
- Completion controllers handle workout feedback

### Feature Integration Points

**Existing Systems Enhanced**:
- **Nutrition Algorithm**: Maintains current AI-first architecture with algorithmic fallback
- **Content Management**: All text and parameters remain backend-configurable
- **Drift Database**: Extends current schema with new activity and event tables
- **Analytics**: Captures enhanced user journey through calendar interface
- **Offline Capability**: Full offline functionality for all calendar operations

## Technical Foundation

### FOA Architecture Compliance
The Calendar feature maintains strict adherence to Feature-Oriented Architecture:
- **Presentation Layer**: Calendar screens and activity components
- **Application Layer**: Activity services, calendar controllers, navigation logic
- **Domain Layer**: Activity, event, and calendar-specific models
- **Data Layer**: Extended repositories for activity and event management

### Riverpod Integration
All controllers follow AsyncNotifier patterns:
- `@riverpod` annotations with code generation
- `AsyncValue.guard()` for error handling
- Content service integration for dynamic UI text
- Proper dependency injection for services and repositories

### Database Strategy
- **Schema Extension**: Add new tables while preserving existing data
- **Migration Safety**: Versioned migrations with rollback capability
- **Sync Compatibility**: Maintain Supabase synchronization for new entities
- **Performance Optimization**: Indexes for calendar queries and activity lookups

## Success Metrics

### Adoption Metrics
- **Calendar Usage**: % of users who actively use calendar interface
- **Activity Creation**: Number of activities created per user per week
- **Completion Rate**: % of planned activities marked as completed
- **Feature Migration**: Success rate of transitioning from tab to calendar navigation

### Engagement Metrics
- **Session Duration**: Time spent in calendar interface
- **Plan Generation**: Frequency of nutrition plan creation
- **Carb Loading Adoption**: % of race events with carb loading plans
- **Feedback Quality**: Completion rate of workout ratings and notes

### Performance Metrics
- **Load Times**: Calendar rendering performance (<500ms target)
- **Navigation Efficiency**: Reduced taps to complete common workflows
- **Data Integrity**: Zero data loss during navigation restructure
- **Offline Reliability**: 100% feature availability without internet

## Implementation Principles

### User Experience First
- **Intuitive Flow**: Natural progression from planning to execution
- **Progressive Disclosure**: Show relevant information based on context
- **Consistent Patterns**: Maintain familiar interactions across feature areas
- **Error Prevention**: Guide users toward successful workflows

### Data Preservation
- **Backward Compatibility**: All existing data remains accessible
- **Migration Safety**: Zero data loss during feature transition
- **Export Capability**: Users can access historical data
- **Sync Integrity**: Maintain cloud backup functionality

### Performance Optimization
- **Lazy Loading**: Load calendar data as needed
- **Efficient Queries**: Optimize database performance for calendar views
- **Caching Strategy**: Smart caching for frequently accessed data
- **Memory Management**: Efficient widget lifecycle in calendar interface

### Accessibility & Inclusivity
- **Screen Reader Support**: Full VoiceOver/TalkBack compatibility
- **Touch Targets**: Minimum 44pt touch areas throughout
- **Color Accessibility**: High contrast mode support
- **Text Scaling**: Dynamic type support for all text elements

## Future Evolution

### Phase 1 Foundation
- Core calendar with running activities and events
- Basic carb loading integration
- Workout completion flow

### Phase 2 Expansion
- Carb loading refinements and richer event tooling
- Enhanced analytics for running performance
- Improved completion insights and history views

### Phase 3 Intelligence
- Optional multi-sport support (biking/swimming) once feature-ready
- AI-powered activity recommendations
- Predictive nutrition planning and performance correlation analysis

## Risk Mitigation

### Technical Risks
- **Database Migration**: Comprehensive testing of schema changes
- **Navigation Complexity**: Gradual rollout with feature flags
- **Performance Impact**: Continuous monitoring and optimization
- **Data Synchronization**: Robust conflict resolution strategies

### User Experience Risks
- **Feature Discovery**: Clear onboarding for new calendar interface
- **Workflow Disruption**: Provide familiar patterns where possible
- **Learning Curve**: Progressive feature introduction
- **Feedback Integration**: Continuous user research and iteration

### Business Risks
- **Development Timeline**: Phased approach minimizes delivery risk
- **User Adoption**: Maintain backward compatibility during transition
- **Feature Complexity**: Focus on core value proposition first
- **Resource Allocation**: Clear prioritization of MVP features

---

The Calendar feature represents the next evolution of Mealvana Endurance, transforming from a feature-separated experience to a unified, calendar-centric platform that puts the athlete's training schedule at the center of nutrition planning and performance tracking.
