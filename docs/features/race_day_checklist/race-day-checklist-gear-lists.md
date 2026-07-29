# Race Day Gear Checklist - Comprehensive Gear Lists

## Overview
Dynamic gear checklist based on:
- **Event Type**: Running, Cycling, Swimming, Triathlon, Duathlon, Brick
- **User Gender**: Male, Female (for gender-specific items like sports bra)
- **Event Distance**: Longer events may require additional hydration/nutrition gear

---

## Gear Lists by Sport

### 🏃 Running Events

#### Essential Gear (All Athletes)
- [ ] Running shoes
- [ ] Running shorts/pants
- [ ] Running shirt/singlet
- [ ] Socks (moisture-wicking)
- [ ] GPS watch/fitness tracker
- [ ] Race bib
- [ ] Race belt OR safety pins
- [ ] Sunglasses
- [ ] Hat or visor
- [ ] Sunscreen
- [ ] Body glide/anti-chafe cream

#### Female-Specific
- [ ] Sports bra

#### Distance-Specific
**5K/10K:**
- Basic gear only

**Half Marathon/Marathon:**
- [ ] Energy gels/chews (4-8 packets)
- [ ] Hydration pack OR handheld water bottle
- [ ] Salt stick/electrolyte tabs
- [ ] Band-aids/blister protection
- [ ] Extra socks (drop bag)

**Ultra (50K+):**
- [ ] Headlamp + extra batteries
- [ ] Trail running shoes (if trail race)
- [ ] Trekking poles (if allowed)
- [ ] Drop bag with extra clothes
- [ ] Emergency blanket

---

### 🚴 Cycling Events

#### Essential Gear (All Athletes)
- [ ] Bike (race-ready)
- [ ] Helmet
- [ ] Cycling shoes
- [ ] Cycling shorts/bibs
- [ ] Cycling jersey
- [ ] Socks
- [ ] Cycling gloves
- [ ] Sunglasses
- [ ] GPS bike computer
- [ ] Water bottles (2+)
- [ ] Race number (pinned to jersey or frame)

#### Female-Specific
- [ ] Sports bra

#### Mechanical & Safety
- [ ] Saddle bag with tools
- [ ] Spare tube (2)
- [ ] CO2 cartridges (2-3) OR mini pump
- [ ] Tire levers
- [ ] Multi-tool
- [ ] Chain link
- [ ] Bike pump (at transition/car)

#### Nutrition
- [ ] Energy gels/bars (1 per hour)
- [ ] Electrolyte drink mix
- [ ] Salt stick/electrolyte tabs

---

### 🏊 Swimming/Open Water Events

#### Essential Gear (All Athletes)
- [ ] Swimsuit OR tri suit
- [ ] Goggles (primary)
- [ ] Goggles (backup pair)
- [ ] Swim cap (provided by race, but bring backup)
- [ ] Towel
- [ ] Flip flops/sandals
- [ ] Race bib (for post-swim)

#### Open Water Specific
- [ ] Wetsuit (if water temp requires)
- [ ] Wetsuit lubricant
- [ ] Neoprene swim cap (cold water)
- [ ] Earplugs (optional)

#### Female-Specific
- [ ] Sports bra (under tri suit)
- [ ] Hair ties

---

### 🏊‍♂️🚴‍♂️🏃‍♂️ Triathlon (Sprint/Olympic/Half/Full)

#### Transition Area Setup
- [ ] Transition bag/mat
- [ ] Towel (for drying feet)
- [ ] Race belt with bib
- [ ] Body marking (race numbers)

#### Swim Gear
- [ ] Tri suit OR swim-to-bike outfit
- [ ] Goggles (primary + backup)
- [ ] Wetsuit (if applicable)
- [ ] Wetsuit lubricant
- [ ] Swim cap (provided + backup)

#### Bike Gear
- [ ] Bike (race-ready, tires inflated)
- [ ] Helmet
- [ ] Cycling shoes OR running shoes with elastic laces
- [ ] Sunglasses
- [ ] Bike computer/GPS watch
- [ ] Water bottles (2+)
- [ ] Nutrition (gels, bars)
- [ ] Spare tube + CO2/pump
- [ ] Multi-tool

#### Run Gear
- [ ] Running shoes (with elastic laces)
- [ ] Race belt (with bib)
- [ ] Hat/visor
- [ ] Sunscreen (pre-applied)
- [ ] Nutrition (gels for run)

#### Female-Specific
- [ ] Sports bra (built into tri suit OR separate)

#### Distance-Specific Additions

**Half Ironman / Ironman:**
- [ ] Special needs bags (bike/run)
- [ ] Extra nutrition (10+ gels)
- [ ] Salt stick/electrolyte tabs
- [ ] Extra water bottles
- [ ] Bike lights (if early start/late finish)
- [ ] Reflective vest
- [ ] Arm warmers/leg warmers
- [ ] Rain jacket (in special needs bag)
- [ ] Extra socks
- [ ] Body glide/anti-chafe (reapply in transition)

---

### 🏃‍♂️🚴‍♂️ Duathlon (Run-Bike-Run)

#### Transition Area
- [ ] Transition bag/mat
- [ ] Towel
- [ ] Race belt with bib

#### Run 1 Gear
- [ ] Running shoes
- [ ] Running shorts/singlet
- [ ] Sports bra (female)
- [ ] Socks
- [ ] GPS watch
- [ ] Race bib
- [ ] Sunglasses
- [ ] Hat/visor

#### Bike Gear
- [ ] Bike
- [ ] Helmet
- [ ] Cycling shoes OR keep running shoes
- [ ] Sunglasses (if not wearing from run)
- [ ] Water bottles (2)
- [ ] Nutrition
- [ ] Spare tube + CO2/pump

#### Run 2 Gear
- [ ] Same running shoes (or change to fresh pair)
- [ ] Race belt with bib
- [ ] Additional nutrition

---

### 🧱 Brick Workouts (Training)

#### Bike Gear
- All cycling gear listed above

#### Run Gear
- All running gear listed above

#### Transition Practice
- [ ] Transition mat
- [ ] Elastic laces (practice quick shoe change)
- [ ] Race belt

---

## Dynamic Rules for Gear List Generation

### Rule 1: Gender-Based Items
```
IF user.gender == "female":
    ADD "Sports bra" to essential gear
```

### Rule 2: Event Distance
```
IF event.eventSubtype IN ["half_marathon", "marathon"]:
    ADD hydration gear
    ADD 4-8 energy gels
    ADD salt sticks

IF event.eventSubtype IN ["ultra_50k", "ultra_50m", "ultra_100k", "ultra_100m"]:
    ADD headlamp
    ADD trekking poles
    ADD drop bag items
```

### Rule 3: Event Type
```
IF event.eventType == "triathlon":
    INCLUDE swim gear + bike gear + run gear + transition gear

IF event.eventType == "duathlon":
    INCLUDE run gear + bike gear + transition gear

IF event.eventType == "brick":
    INCLUDE bike gear + run gear + transition gear (simplified)
```

### Rule 4: Weather-Specific (Future Enhancement)
```
IF weatherForecast.temp < 50°F:
    ADD arm warmers
    ADD leg warmers
    ADD jacket

IF weatherForecast.precipitation > 50%:
    ADD rain jacket
    ADD extra socks
    ADD plastic bag for electronics
```

### Rule 5: Time of Day (Future Enhancement)
```
IF event.startTime < "6:00 AM" OR event.startTime > "7:00 PM":
    ADD headlamp
    ADD reflective vest
    ADD bike lights
```

---

## Implementation Data Structure

### Option A: Hardcoded Templates (Recommended for MVP)
```dart
class GearTemplates {
  static List<String> getEssentialRunningGear({required bool isFemale}) {
    return [
      'Running shoes',
      'Running shorts/pants',
      'Running shirt/singlet',
      'Socks (moisture-wicking)',
      if (isFemale) 'Sports bra',
      'GPS watch/fitness tracker',
      'Race bib',
      'Race belt OR safety pins',
      'Sunglasses',
      'Hat or visor',
      'Sunscreen',
      'Body glide/anti-chafe cream',
    ];
  }

  static List<String> getDistanceSpecificRunningGear(String eventSubtype) {
    if (eventSubtype == 'half_marathon' || eventSubtype == 'marathon') {
      return [
        'Energy gels/chews (4-8 packets)',
        'Hydration pack OR handheld water bottle',
        'Salt stick/electrolyte tabs',
        'Band-aids/blister protection',
      ];
    }
    return [];
  }

  // Similar methods for cycling, swimming, triathlon, etc.
}
```

### Option B: JSON Configuration (Future Enhancement)
```json
{
  "running": {
    "essential": [
      {"item": "Running shoes", "gender": "all"},
      {"item": "Sports bra", "gender": "female"},
      ...
    ],
    "distance_specific": {
      "half_marathon": [...],
      "marathon": [...]
    }
  },
  "triathlon": {
    "swim": [...],
    "bike": [...],
    "run": [...],
    "transition": [...]
  }
}
```

---

## User Flow

1. **User clicks "Race Day Checklist" button** on Event Detail page
2. **System generates gear list** based on:
   - Event type (from `event.eventType`)
   - Event distance (from `event.eventSubtype`)
   - User gender (from `user.gender` in user profile)
3. **Display checklist screen** with:
   - Category: "Race Day Gear"
   - All applicable gear items with checkboxes
   - Items persist per event (saved to database)
4. **User checks off items** as they pack
5. **Progress indicator** shows completion (e.g., "15/20 items packed")

---

## Database Schema (Simple Version)

```dart
@DataClassName('ChecklistItem')
class ChecklistItemsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get eventId => text().named('event_id')(); // FK to events.id
  TextColumn get userId => text().named('user_id')();

  TextColumn get category => text()(); // "gear" for now
  TextColumn get itemName => text().named('item_name')();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isChecked => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get needsUpload => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Next Steps

1. **Create gear template utility class** with sport-specific lists
2. **Build checklist screen UI** with simple checkboxes
3. **Add button to EventActionButtonsCard**
4. **Create database table** for persisting checked items
5. **Implement state management** with Riverpod

---

**Status:** Ready to implement
**Complexity:** Medium (gear list logic + UI + database)
**Estimated Time:** 2-3 days for MVP
