# Public Events System

## Overview

The Public Events system provides autocomplete functionality for event creation by maintaining a database of publicly available race events (marathons, triathlons, cycling races, etc.). Users can search for events while creating their calendar entries, and the system will auto-populate event details.

**Key Features:**
- 🔍 Natural language event search and population via `/populate-events` command
- 🚀 Fast autocomplete via Edge Function with full-text search
- 📊 Supports all sport types: running, cycling, swimming, triathlon, duathlon, multisport
- 🌍 Location-based filtering (city, state, country)
- 📅 Date-based filtering (upcoming events only)
- 🔄 Deduplication via source + external_id

---

## Database Schema

### Table: `public_events`

Located in production Supabase database.

**Migration:** `/supabase/migrations/20251113000003_create_public_events_table.sql`

#### Columns

| Column | Type | Description |
|--------|------|-------------|
| `id` | BIGSERIAL | Primary key |
| `event_name` | TEXT | Event name (e.g., "Boston Marathon") |
| `event_type` | activity_type_enum | Sport category: running, cycling, swimming, triathlon, duathlon, multisport |
| `event_subtype` | event_subtype_enum | Race distance/type: marathon, 5k, half_ironman, etc. |
| `location` | TEXT | Full address or venue name |
| `city` | TEXT | City name (for filtering) |
| `state` | TEXT | State/province (for filtering like "alabama", "california") |
| `country` | TEXT | Country (default: 'USA') |
| `event_date` | DATE | Event date (YYYY-MM-DD) |
| `start_time` | TIME | Start time (HH:MM:SS, optional) |
| `registration_url` | TEXT | Registration link |
| `website_url` | TEXT | Event website |
| `description` | TEXT | Event description |
| `organizer_name` | TEXT | Organizer/race director |
| `is_active` | BOOLEAN | Active flag (default: true) |
| `source` | TEXT | Data source: 'runsignup', 'marathonguide', 'manual', etc. |
| `external_id` | TEXT | ID from source system (for deduplication) |
| `search_vector` | tsvector | Generated column for full-text search (auto-generated) |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

#### Indexes

- `idx_public_events_search` - GIN index on search_vector for fast full-text search
- `idx_public_events_date` - Index on event_date for upcoming events
- `idx_public_events_type` - Index on event_type and event_subtype
- `idx_public_events_state` - Index on state for location filtering
- `idx_public_events_active` - Partial index on is_active = true
- `idx_public_events_unique_external` - Unique index on (source, external_id) for deduplication

#### Row Level Security (RLS)

- **Public Read**: Anyone can SELECT events where `is_active = true`
- **Service Role Write**: Only service role can INSERT/UPDATE/DELETE

---

## Edge Function: search-public-events

**Location:** `/supabase/functions/search-public-events/index.ts`

**Endpoint:** `https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/search-public-events`

### Request Format

```typescript
POST /functions/v1/search-public-events
Content-Type: application/json

{
  "query": string,        // Search query (min 2 characters)
  "limit": number,        // Optional, default 10
  "eventType": string,    // Optional filter: 'running', 'cycling', etc.
  "state": string         // Optional filter: 'california', 'alabama', etc.
}
```

### Response Format

```typescript
{
  "events": PublicEvent[],  // Array of matching events
  "count": number,          // Number of results
  "query": string           // Original query
}

interface PublicEvent {
  id: number;
  event_name: string;
  event_type: string;
  event_subtype: string | null;
  location: string | null;
  city: string | null;
  state: string | null;
  event_date: string | null;
  start_time: string | null;
  registration_url: string | null;
  website_url: string | null;
  description: string | null;
  organizer_name: string | null;
}
```

### Search Algorithm

1. **Full-text search** using PostgreSQL `search_vector` (generated from event_name, location, city, state)
2. **Fallback ILIKE search** if full-text returns no results
3. **Filters applied:**
   - Only active events (`is_active = true`)
   - Only upcoming events (`event_date >= CURRENT_DATE`)
   - Optional: event_type filter
   - Optional: state filter
4. **Results sorted by:**
   - Event date (ascending, soonest first)
   - Limited to specified limit (default 10)

### Example Usage

```typescript
// Search for marathons in California
const response = await fetch(
  'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/search-public-events',
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`
    },
    body: JSON.stringify({
      query: 'marathon',
      state: 'california',
      limit: 20
    })
  }
);

const data = await response.json();
console.log(`Found ${data.count} marathons in California`);
```

---

## Admin Tool: /populate-events

**Location:** `/.claude/commands/populate-events.md`

The `/populate-events` slash command allows you to search the web for race events and automatically populate the `public_events` table.

### Usage

Type natural language queries like:

```
/populate-events find all marathons in california in 2025
/populate-events find 5ks in alabama
/populate-events find triathlons in new york between may and august
/populate-events find half ironmans in texas in spring 2025
```

### How It Works

1. **Parse Query**: Extracts event type, location, and date range
2. **Web Search**: Searches race calendar sites (RunSignUp, MarathonGuide, USAT, etc.)
3. **Extract Details**: Parses event listings from race calendar websites
4. **Map to Schema**: Converts to our activity_type_enum and event_subtype_enum
5. **Insert to Supabase**: Batch inserts events using service role key
6. **Deduplication**: Skips events with duplicate (source, external_id)
7. **Report Results**: Shows summary of added/skipped/failed events

### Example Output

```
✅ Event Population Complete

Query: "find all marathons in california in 2025"

Results:
- Total events found: 47
- Successfully inserted: 45
- Duplicates skipped: 2
- Errors: 0

Sample events added:
1. Los Angeles Marathon (2025-03-17) - Los Angeles, CA
2. Big Sur International Marathon (2025-04-27) - Big Sur, CA
3. San Francisco Marathon (2025-07-27) - San Francisco, CA
...

All events are now available in the public_events table for autocomplete.
```

### Event Type Mapping

The command automatically maps race names to our enums:

**Distance Mappings:**
- "5K" → `5k`
- "10K" → `10k`
- "Half Marathon" / "13.1" → `half_marathon`
- "Marathon" / "26.2" → `marathon`
- "50K" / "Ultra 50K" → `50k`
- "50 Mile" → `50_mile`
- "100K" → `100k`
- "100 Mile" → `100_mile`
- "Sprint Triathlon" → `sprint_triathlon`
- "Olympic Triathlon" → `olympic_triathlon`
- "Half Ironman" / "70.3" / "IM 70.3" → `half_ironman`
- "Ironman" / "140.6" / "Full Ironman" → `full_ironman`
- "Century" / "100 mile bike" → `century`
- "Gran Fondo" → `gran_fondo`

**Sport Type Mappings:**
- Running races → `running`
- Cycling races → `cycling`
- Open water swims → `swimming`
- Triathlons → `triathlon`
- Duathlons → `duathlon`
- Mixed events → `multisport`

### Data Sources

The command searches these public race calendar sites:
- **RunSignUp** - Comprehensive race calendar with API access
- **MarathonGuide** - Marathon and half marathon database
- **USAT** - USA Triathlon sanctioned events
- **Active.com** - General endurance events
- **Local race calendars** - State and regional race listings

---

## Event Subtype Enums

### Running Events

| Enum Value | Display Name | Distance |
|------------|--------------|----------|
| `5k` | 5K | 3.1 mi |
| `10k` | 10K | 6.2 mi |
| `15k` | 15K | 9.3 mi |
| `10_mile` | 10 Mile | 10 mi |
| `half_marathon` | Half Marathon | 13.1 mi |
| `25k` | 25K | 15.5 mi |
| `30k` | 30K | 18.6 mi |
| `marathon` | Marathon | 26.2 mi |
| `50k` | 50K | 31.1 mi |
| `50_mile` | 50 Mile | 50 mi |
| `100k` | 100K | 62.1 mi |
| `100_mile` | 100 Mile | 100 mi |
| `12_hour` | 12 Hour | Timed |
| `24_hour` | 24 Hour | Timed |
| `custom_distance` | Custom Distance | Variable |

### Cycling Events

| Enum Value | Display Name | Distance |
|------------|--------------|----------|
| `10k_tt` | 10K Time Trial | 6.2 mi |
| `20k_tt` | 20K Time Trial | 12.4 mi |
| `40k_tt` | 40K Time Trial | 24.9 mi |
| `50k` | 50K | 31.1 mi |
| `half_century` | Half Century | 50 mi |
| `metric_century` | Metric Century | 100 km |
| `century` | Century | 100 mi |
| `gran_fondo` | Gran Fondo | 70-100+ mi |
| `200k` | 200K | 124.3 mi |
| `custom_distance` | Custom Distance | Variable |

### Swimming Events

| Enum Value | Display Name | Distance |
|------------|--------------|----------|
| `1k_open_water` | 1K Open Water | 1 km |
| `1_5k_open_water` | 1.5K Open Water | 1.5 km |
| `2_5k_open_water` | 2.5K Open Water | 2.5 km |
| `5k_open_water` | 5K Open Water | 5 km |
| `10k_open_water` | 10K Open Water | 10 km |
| `custom_distance` | Custom Distance | Variable |

### Triathlon Events

| Enum Value | Display Name | Distances |
|------------|--------------|-----------|
| `sprint_triathlon` | Sprint Triathlon | 750m / 20K / 5K |
| `olympic_triathlon` | Olympic Triathlon | 1.5K / 40K / 10K |
| `half_ironman` | Half Ironman / 70.3 | 1.9K / 90K / 21.1K |
| `full_ironman` | Full Ironman / 140.6 | 3.8K / 180K / 42.2K |
| `custom_triathlon` | Custom Triathlon | Variable |

### Duathlon Events

| Enum Value | Display Name | Distances |
|------------|--------------|-----------|
| `sprint_duathlon` | Sprint Duathlon | 5K run / 20K bike / 2.5K run |
| `standard_duathlon` | Standard Duathlon | 10K run / 40K bike / 5K run |
| `long_course_duathlon` | Long Course Duathlon | 10K run / 60K bike / 10K run |
| `custom_duathlon` | Custom Duathlon | Variable |

### Multisport Events

| Enum Value | Display Name | Description |
|------------|--------------|-------------|
| `aquathlon` | Aquathlon | Swim + Run |
| `aquabike` | Aquabike | Swim + Bike |
| `custom_multi_sport` | Custom Multi-Sport | Variable |

---

## Integration with Event Creation

### Current Flow (Active.com - to be replaced)

**File:** `lib/features/events/presentation/screens/event_creation_screen.dart`

Currently uses Active.com API for autocomplete. This will be replaced with our `public_events` system.

### New Flow (Public Events)

1. User types in event name field
2. After 2 characters, trigger autocomplete with debounce (300ms)
3. Call `search-public-events` Edge Function
4. Display results in dropdown
5. When user selects event:
   - Auto-populate: event_name, event_type, event_subtype, location, event_date, registration_url
   - User can still edit all fields
6. Create event with pre-populated data

### Service Layer

**To be created:** `lib/features/events/application/public_events_service.dart`

```dart
@riverpod
PublicEventsService publicEventsService(PublicEventsServiceRef ref) {
  return PublicEventsService(
    supabaseClient: ref.watch(supabaseClientProvider),
  );
}

class PublicEventsService {
  final SupabaseClient _supabase;

  PublicEventsService({required SupabaseClient supabaseClient})
      : _supabase = supabaseClient;

  Future<List<PublicEvent>> searchEvents({
    required String query,
    int limit = 10,
    String? eventType,
    String? state,
  }) async {
    final response = await _supabase.functions.invoke(
      'search-public-events',
      body: {
        'query': query,
        'limit': limit,
        if (eventType != null) 'eventType': eventType,
        if (state != null) 'state': state,
      },
    );

    final data = response.data as Map<String, dynamic>;
    final events = (data['events'] as List)
        .map((e) => PublicEvent.fromJson(e))
        .toList();

    return events;
  }
}
```

---

## Maintenance

### Updating Events

Events can be updated via direct SQL or by re-running `/populate-events` with updated data:

```sql
-- Deactivate old events
UPDATE public_events
SET is_active = false
WHERE event_date < CURRENT_DATE;

-- Update specific event
UPDATE public_events
SET
  event_name = 'Updated Event Name',
  registration_url = 'https://new-url.com'
WHERE id = 123;
```

### Bulk Population

To populate events for an entire year:

```
/populate-events find all marathons in united states in 2025
/populate-events find all half marathons in united states in 2025
/populate-events find all ironman races worldwide in 2025
```

### Data Quality

- Review events periodically for accuracy
- Remove or deactivate past events: `is_active = false`
- Check for duplicates using source + external_id
- Validate event_type and event_subtype against enums

---

## Testing

### Manual Testing

1. **Populate test events:**
   ```
   /populate-events find marathons in california in 2025
   ```

2. **Query via SQL:**
   ```sql
   SELECT * FROM public_events
   WHERE state = 'California'
   AND event_type = 'running'
   ORDER BY event_date;
   ```

3. **Test Edge Function:**
   ```bash
   curl -X POST \
     https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/search-public-events \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -d '{"query": "marathon", "state": "california", "limit": 5}'
   ```

4. **Test autocomplete in app:**
   - Open event creation screen
   - Type "boston marathon"
   - Verify autocomplete shows results
   - Select event and verify auto-population

---

## Future Enhancements

- [ ] Admin UI for manual event entry/editing
- [ ] Automatic event updates from race APIs
- [ ] Event popularity tracking (clicks/selections)
- [ ] Event recommendations based on user preferences
- [ ] Integration with race result APIs
- [ ] Notification system for registration deadlines
- [ ] User-submitted events (with moderation)

---

## Support

**Issues:** Report in GitHub or contact development team

**Questions:** See main documentation at `/docs/`
