# Notes Feature Requirements

## Overview
The Notes feature will enhance the nutrition plan experience by allowing users to:
1. **Rate nutrition plans** on a 1-5 scale 
2. **Add detailed feedback** via text or audio transcription
3. **View historical plans** with their associated notes and ratings
4. **Track plan effectiveness** over time

This feature integrates with the existing nutrition plan system and leverages both local storage (Drift) and backend sync (Supabase).

---

## Core Requirements

### 1. Plan Rating System
- **5-star rating slider/picker** for each nutrition plan
- **Persistent storage** in both local database and Supabase
- **Visual feedback** showing current rating state
- **Rating history** visible in plan history view

### 2. Notes & Feedback System
- **Dual input methods**:
  - Traditional text input (keyboard)
  - **Audio transcription** using OS-level speech-to-text
- **Rich text support** for formatting notes
- **Character/word limits** for performance and storage
- **Auto-save functionality** to prevent data loss
- **Offline-first architecture** with sync when available

### 3. Plan History & Management
- **Historical plan view** showing all previous nutrition plans
- **Chronological organization** (newest first)
- **Quick access to notes/ratings** for each plan
- **Plan comparison features** (future enhancement)
- **Search/filter capabilities** by date, rating, or keywords

---

## Technical Implementation

### Database Schema Changes

#### Drift (Local Database) - Already Supported
The existing `NutritionPlan` domain model already includes:
- `notes: String?` - Text content for user feedback
- Full versioning and sync capabilities

**NEW FIELD NEEDED:**
- `rating: int?` - User rating (1-5 scale)

#### Supabase (Backend) - Schema Update Required
The `nutrition_plans` table already has:
- `notes: text` - User feedback text
- Full sync infrastructure in place

**NEW FIELD NEEDED:**
- `rating: integer` - User rating (1-5 scale, nullable)

### Audio Transcription Implementation

#### Option 1: OS-Level Speech Recognition (RECOMMENDED)
- **iOS**: `AVAudioEngine` + `SFSpeechRecognizer`
- **Android**: `SpeechRecognizer` + `RecognizerIntent`
- **Flutter Plugin**: `speech_to_text: ^6.6.0`

**Benefits:**
- Native OS integration (familiar UX)
- No additional backend costs
- Works offline after initial setup
- Consistent with OS accessibility features

#### Option 2: Cloud-Based Services
- **Google Speech-to-Text API**
- **Azure Cognitive Services**
- **AWS Transcribe**

**Trade-offs:**
- Higher accuracy but ongoing costs
- Requires internet connection
- Additional privacy considerations

### Feature Architecture (FOA Compliance)

```
lib/features/notes/
├── presentation/
│   ├── screens/
│   │   ├── plan_history_screen.dart
│   │   ├── plan_notes_screen.dart
│   │   └── add_notes_screen.dart
│   ├── widgets/
│   │   ├── rating_widget.dart
│   │   ├── audio_input_widget.dart
│   │   ├── notes_input_widget.dart
│   │   └── plan_history_item.dart
│   └── providers/
│       ├── notes_controller.dart
│       ├── plan_history_controller.dart
│       └── audio_transcription_controller.dart
├── application/
│   ├── notes_service.dart
│   ├── plan_history_service.dart
│   └── speech_recognition_service.dart
├── domain/
│   ├── plan_note.dart
│   ├── speech_recognition_result.dart
│   └── plan_history_item.dart
└── data/
    ├── notes_repository.dart
    ├── speech_recognition_repository.dart
    └── plan_history_repository.dart
```

---

## User Experience Flow

### 1. Post-Plan Rating Flow
1. User completes nutrition plan usage
2. **Rating prompt** appears (can be dismissed/delayed)
3. **5-star rating input** with optional notes
4. **Audio or text input** for detailed feedback
5. **Save confirmation** with sync status indicator

### 2. Plan History Flow
1. **History tab/screen** showing all previous plans
2. **List view** with plan name, date, rating, preview of notes
3. **Tap to expand** full notes and rating details  
4. **Edit capabilities** for updating notes/ratings
5. **Export/share** functionality (future enhancement)

### 3. Audio Input Flow
1. **Microphone button** in notes input area
2. **Permission request** (first time)
3. **Visual feedback** during recording (waveform/pulse)
4. **Real-time transcription** or post-recording processing
5. **Text review/edit** before saving
6. **Fallback to text input** if audio fails

---

## Open Questions & Clarifications Needed

### 1. Rating System Details
**Question:** Should the rating be:
- **Overall plan satisfaction** (how well did the plan work?)
- **Plan execution success** (how well did you follow the plan?)
- **Multiple dimensions** (taste, energy, digestibility, etc.)?

**Current Assumption:** Single overall satisfaction rating (1-5 stars)

### 2. Notes Timing & Context
**Question:** When should users be prompted to add notes/ratings?
- **Immediately after plan creation** (initial thoughts?)
- **After plan execution** (post-run feedback?)
- **Both occasions** with different prompting?
- **Manual only** (no automatic prompts)?

**Current Assumption:** Primarily post-execution feedback with optional immediate notes

### 3. Audio Transcription Scope
**Question:** What are the requirements for audio input?
- **Maximum recording length** (30 seconds, 2 minutes, unlimited?)
- **Language support** (English only, multiple languages?)
- **Accuracy expectations** (editing required, or near-perfect?)
- **Offline capability** required or online-only acceptable?

**Current Assumption:** 2-minute max, English-only, editing expected, offline preferred

### 4. Plan History Integration
**Question:** How should plan history integrate with existing UI?
- **New tab** in bottom navigation?
- **Section within existing screen** (current plan screen?)
- **Separate feature** accessed via settings/menu?
- **Replace current plan** with history-focused view?

**Current Assumption:** New dedicated history screen accessible from main navigation

### 5. Notification & Reminders
**Question:** Should the app prompt users to rate/review plans?
- **Push notifications** reminding to add feedback?
- **In-app reminders** after certain time periods?
- **No prompting** (user-initiated only)?

**Current Assumption:** Gentle in-app prompts, no push notifications initially

### 6. Plan Identification & Naming
**Question:** How should historical plans be identified?
- **Auto-generated names** based on date/parameters (e.g., "10-mile Long Run - Jan 15")?
- **User-customizable names** for better organization?
- **Distance + date only** (current approach)?

**Current Assumption:** Auto-generated with optional user customization

### 7. Data Privacy & Storage
**Question:** What are the privacy requirements for notes?
- **Local-only storage** option for sensitive feedback?
- **Encryption** for personal notes?
- **Data export** capabilities for user data portability?
- **Retention policies** for old notes?

**Current Assumption:** Standard encryption, full sync, standard retention

---

## Success Metrics

### User Engagement
- **% of plans with ratings** (target: >60%)
- **% of plans with notes** (target: >30%)
- **Average note length** (indicates engagement depth)
- **Audio vs. text usage** (measure feature adoption)

### Technical Performance  
- **Audio transcription accuracy** (measured against user corrections)
- **Sync success rate** for notes/ratings
- **App performance impact** (loading times, battery usage)

### User Satisfaction
- **Feature usage retention** (continued use over time)
- **User feedback** on audio transcription quality
- **Support requests** related to notes functionality

---

## Implementation Phases

### Phase 1: Core Notes & Rating (Week 1-2)
- Basic text notes functionality
- 5-star rating system
- Database schema updates
- Integration with existing plan flow

### Phase 2: Plan History (Week 2-3)
- Historical plans view
- Notes/ratings display
- Edit existing notes/ratings
- Search/filter basic functionality

### Phase 3: Audio Transcription (Week 3-4)
- Speech-to-text integration
- Audio input UI/UX
- Permission handling
- Error handling and fallbacks

### Phase 4: Polish & Enhancement (Week 4+)
- Performance optimization
- Advanced filtering/search
- Export capabilities
- Push notification integration (if needed)

---

## Dependencies & Risks

### Technical Dependencies
- `speech_to_text` Flutter plugin (audio transcription)
- Drift database schema migration
- Supabase table schema update
- iOS/Android permission management

### Potential Risks
- **Platform permission issues** (microphone access)
- **Audio transcription accuracy** varies by user accent/environment
- **Storage growth** with text/audio data over time
- **Sync complexity** with versioned notes across devices

### Mitigation Strategies  
- **Graceful degradation** when audio fails (fallback to text)
- **Clear user education** on feature capabilities/limitations
- **Progressive enhancement** (basic notes first, audio second)
- **Comprehensive testing** across devices and environments

---

*This document should be reviewed and updated based on stakeholder feedback and technical discovery during implementation.*