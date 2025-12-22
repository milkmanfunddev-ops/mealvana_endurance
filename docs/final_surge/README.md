# Final Surge Integration Documentation

**Last Updated**: December 17, 2025
**Status**: Design Complete - Ready for Implementation
**Integration Type**: OAuth 2.0 Workout Import

---

## Overview

The Final Surge integration enables Mealvana Endurance users to automatically import their training calendar workouts from Final Surge and generate personalized nutrition plans. This integration uses a **chunked parallel generation** approach for fast, responsive plan creation with live progress updates.

---

## Quick Links

### 📋 Planning Documents
- **[Implementation Roadmap](./roadmap.md)** - Phased implementation plan with tasks and deliverables
- **[Comprehensive Notes](./notes.md)** - Detailed research, decisions, and open questions
- **[Technical Architecture](./technical-architecture.md)** - System design, data flow, and implementation patterns
- **[Data Transformation Guide](./data-transformation.md)** - Field-by-field mapping, unit conversions, and example transformations

### 📄 Reference Materials
- **[Final Surge Partner API PDF](./Final-Surge-Partner-API-Uploads.pdf)** - Official API documentation

---

## Key Implementation Decisions

### Nutrition Plan Generation: Chunked Parallel Processing ✅

**Decision (2025-12-17):** Use Flutter-based chunked parallel generation instead of background processing.

**Why:**
- ✅ **Faster:** 15-20 seconds vs 7 minutes with pg_cron
- ✅ **Better UX:** Live progress updates ("Generating plans... 7/14")
- ✅ **Simpler:** No distributed system coordination needed
- ✅ **Easier to debug:** All in Flutter code
- ✅ **Rate limit safe:** Max 5 concurrent API calls

**Technical Approach:**
```dart
const chunkSize = 5; // Process 5 at a time
for (var i = 0; i < activities.length; i += chunkSize) {
  final chunk = activities.skip(i).take(chunkSize).toList();
  await Future.wait(chunk.map((a) => generatePlan(a)));
  // Update progress UI after each chunk
}
```

---

## User Experience

### Onboarding Flow

1. **First Screen:** Connect Your Training
   - Final Surge (active)
   - TrainingPeaks (coming soon)
   - Strava (coming soon)

2. **OAuth:** User authorizes in Final Surge

3. **Import:** Fetch 14 days of upcoming workouts

4. **Generate Plans:**
   - Progress dialog: "Generating plans... 7/14"
   - Real-time calendar updates
   - Total time: 15-20 seconds

5. **Auto-Detect Sports:**
   - Rule: 2+ workouts = active sport
   - Pre-populate Sports Selection screen

6. **Continue:** User proceeds through rest of onboarding

### Settings Integration

**Location:** Settings → Connected Apps

**Display Info:**
- Athlete name: "John Doe"
- Connection status: Active/Disconnected
- Last sync: "2 hours ago"
- Last sync result: "Success - 3 new workouts"

**Actions:**
- "Sync Now" button (manual refresh)
- "Disconnect" button (with confirmation)
- Sync history (last 5 syncs)

---

## Technical Highlights

### OAuth Flow
- Uses `flutter_web_auth_2` package
- Same pattern as Google/Apple native SDKs
- No manual deep linking configuration needed
- Automatic callback handling via bundle ID

### Data Storage
- **Integrations table:** OAuth tokens, athlete info, sync metadata
- **Activities table:** New sync tracking columns
  - `synced_from_provider`: 'final_surge'
  - `provider_workout_id`: Unique identifier
  - `provider_workout_url`: Deep link
  - `user_modified`: Track user edits

### Multi-Sport Support
- Running ✅
- Cycling ✅
- Swimming ✅

### Deduplication
- Client-side: Check local database before creating activities
- Server-side: `UNIQUE(user_id, provider_workout_id)` constraint
- Multi-device safe: No duplicate activities across devices

---

## Implementation Phases

### Phase 0: Database & Schema Setup
- Create `integrations` table (Drift + Supabase)
- Add sync columns to `activities` table
- Set up FOA directory structure

### Phase 1: OAuth Implementation
- Add `flutter_web_auth_2` package
- Create `FinalSurgeOAuthService`
- Build `FinalSurgeApiClient`
- Implement token storage

### Phase 2: Workout Sync
- Fetch upcoming workouts (14 days)
- Map to Mealvana activities
- Handle sport type detection
- Implement deduplication

### Phase 3: Onboarding Integration
- Create "Connect Your Training" screen
- Build sport detection from workout history
- Pre-fill Sports Selection screen
- Add success dialog

### Phase 4: Nutrition Plan Generation
- Implement chunked parallel processing
- Create progress UI component
- Add progress stream to controller
- Show real-time updates

### Phase 5: Settings & Management
- Create "Connected Apps" screen
- Add to Settings navigation
- Implement disconnect functionality
- Show sync status and history

### Phase 6: Polish & Testing
- Error handling for all edge cases
- Integration tests (OAuth, sync, UI)
- Edge function tests (multi-sport import)
- Security audit
- Performance optimization

---

## Key Metrics

| Metric | Target |
|--------|--------|
| OAuth completion rate | >80% |
| Sync success rate | >95% |
| Error rate | <1% |
| Avg sync time (14 workouts) | <20 seconds |
| User retention (7-day) | >80% for connected users |

---

## API Reference

### OAuth Endpoints
- **Authorization:** `GET https://log.finalsurge.com/oauth/authorize`
- **Token Exchange:** `POST https://log.finalsurge.com/oauth/token`

### Workout Endpoints
- **Upcoming Workouts:** `GET https://log.finalsurge.com/API/v1/UpcomingWorkouts`
  - Parameters: `NumDays` (1-7), `NumWorkouts` (1-21)
  - Returns: Array of workouts with all details

### Rate Limits
- No explicit limits documented
- Conservative approach: Max 5 concurrent API calls
- ETag caching for repeat requests

---

## Future Enhancements

### Phase 2 Features (Post-MVP)

1. **Structured Workout Parsing**
   - Parse `json_fs_v1` format for interval details
   - Adjust nutrition based on workout intensity
   - Display structured workouts in UI

2. **Historical Import**
   - Import past workouts (30/60/90 days)
   - Premium feature
   - Batch processing

3. **Webhook Support**
   - Real-time workout updates (if Final Surge adds webhooks)
   - Replace polling with push notifications

4. **Two-Way Sync**
   - Push nutrition data back to Final Surge
   - Explore ProfileInfo API for plan links

---

## Development Resources

### External Links
- [Final Surge Website](https://www.finalsurge.com)
- [flutter_web_auth_2 Package](https://pub.dev/packages/flutter_web_auth_2)

### Internal Documentation
- [FOA Architecture](../technical/foa-architecture.md)
- [Drift Migration Guide](../technical/drift-migration-guide.md)
- [Testing Strategy](../test/README.md)

### Test Tools
- [Final Surge API Test Script](../../tool/final_surge_api_test.dart)

---

## Getting Started

### Prerequisites
1. Final Surge Partner API credentials (Client ID + Secret)
2. Flutter 3.8+ with Dart SDK
3. Supabase project (dev + prod)
4. Drift database v2+ schema

### Setup Commands
```bash
# Add dependency
flutter pub add flutter_web_auth_2

# Add environment variables to .env
FINAL_SURGE_CLIENT_ID=<your_client_id>
FINAL_SURGE_CLIENT_SECRET=<your_client_secret>

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Test OAuth flow (desktop only)
dart run tool/final_surge_api_test.dart auth
```

### Next Steps
1. Read [Technical Architecture](./technical-architecture.md) for system design
2. Review [Roadmap](./roadmap.md) for implementation tasks
3. Check [Notes](./notes.md) for detailed decisions and rationale

---

## Questions or Issues?

- **Technical Questions:** Review [notes.md](./notes.md) for open questions and decisions
- **Implementation Help:** See [technical-architecture.md](./technical-architecture.md) for code examples
- **API Questions:** Refer to [Final-Surge-Partner-API-Uploads.pdf](./Final-Surge-Partner-API-Uploads.pdf)

---

*Last updated: December 17, 2025*
