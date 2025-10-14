# AI Summary – Calendar Feature Planning

## Conversation Timeline
1. **Initial Request**: User asked for comprehensive Calendar feature documentation, replacing the legacy tab structure and unifying nutrition, carb loading, and activity tracking.
2. **Clarification Round 1**: AI gathered details about activity types, events, carb loading expectations, data model requirements, completion flow, and migration strategy.
3. **Clarification Round 2**: Follow-up questions confirmed navigation renaming, activity–plan relationships, calendar interactions, carb loading behavior, and out-of-scope items.
4. **Clarification Round 3**: Final answers established running-only scope (with biking/swimming placeholders), reuse of the existing voice notes feature, editing rules, and user experience nuances.
5. **Documentation Pass 1**: AI produced README, roadmap, schema, user flows, and UI specifications aligning with the clarified requirements.
6. **Scope Adjustment**: User requested removal of speech-to-text, multi-sport implementation, integration prep, recurring templates, and coach sharing. AI revised all docs and added this summary.

## Key Decisions & Answers
- **Primary Scope**: Calendar tab becomes the main hub, supporting running activities and events. Biking and swimming appear only as under-construction placeholders.
- **Voice Notes**: Reuse the existing voice note recorder; no speech-to-text implementation required.
- **Events & Carb Loading**: Events are specialized activities. Carb loading plans (1/2/3/7 days) attach to events, generate day-level entries, and stay in sync when events change.
- **Activity Creation**: Activities cannot target past dates, carry a single nutrition plan, and default to the visible day/time in the calendar.
- **Completion Flow**: Users mark workouts complete, rate nutrition via 5 emojis, optionally attach a voice note or text note, and cannot complete workouts early.
- **Data Model**: New `activities`, `events`, `activity_completions`, `carb_loading_plans`, and `carb_loading_days` tables power the feature. Nutrition plans reference activities; completions can point to existing voice note records.
- **Navigation Updates**: "Current Plan" becomes "Activity Detail"; the entry form becomes "Create Activity". Calendar + Settings are the two bottom tabs.
- **Editing Rules**: Deleting or editing events cascades to carb loading days and linked nutrition plans. Past activities are immutable.

## Final Feature Scope
- Calendar week view (Monday start, swipeable) with Today button and month/year header.
- Running activity creation, duplication, editing, and completion.
- Event creation with marathon-centric subtypes, carb loading attachment, and duplication.
- Carb loading day entries surfaced in the calendar with progress tracking and adjustment.
- Completion workflow leveraging existing voice notes plus emoji ratings and optional text.
- Analytics hooks for calendar adoption, completion, and carb loading usage.
- Under-construction messaging for biking and swimming tabs (no backend logic yet).

## Explicitly Excluded for Now
- Speech-to-text transcription.
- Actual biking or swimming plan generation.
- Third-party integrations (Garmin, Strava, etc.).
- Recurring activity templates or automated training plans.
- Coach/athlete collaboration features.

## Deliverables Produced
- `README.md`: Feature vision, capabilities, architecture, and success metrics.
- `roadmap.md`: Three-phase implementation plan (Calendar foundation → Carb loading & completion enhancements → Polish & insights) with duration estimates and risk mitigations.
- `schema.md`: Detailed database design, migrations, and future multi-sport extension notes.
- `user-flows.md`: End-to-end journeys for activity creation, events, carb loading, completion, and pending activity handling.
- `ui-components.md`: Component specifications for calendar, activity detail, creation forms, completion workflow, event setup, and carb loading presentation.
- `ai_summary.md`: This consolidated record of decisions, scope boundaries, and artifacts.

## Next Steps (Suggested)
1. Review roadmap timelines with engineering/product to confirm availability.
2. Validate schema changes against current Drift/Supabase implementations.
3. Prototype the calendar week view and activity creation flow under a feature flag.
4. Plan user testing sessions focused on running + event scenarios before enabling the feature for all users.
