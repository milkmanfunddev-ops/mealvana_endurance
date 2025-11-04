# Weather Integration - Implementation Status

## 📋 Overview
Complete weather forecast integration for Mealvana Endurance app using Open-Meteo API (100% free, no API key required).

---

## ✅ Completed Components

### 1. Backend - Supabase Edge Function
**File:** `/supabase/functions/get-weather-forecast/index.ts`

**Features:**
- Open-Meteo API integration (forecast + historical)
- Future forecasts: 0-16 days ahead
- Historical data: 0-92 days back
- Graceful fallback to defaults (20°C, 60% humidity)
- Returns: temp, humidity, conditions, wind, precipitation
- CORS enabled for Flutter app

**Deployment:** Ready to deploy to Supabase dev

---

### 2. Mobile Permissions

**iOS** - `/ios/Runner/Info.plist`
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysAndWhenInUseUsageDescription`

**Android** - `/android/app/src/main/AndroidManifest.xml`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`

---

### 3. Dependencies

**Added to `pubspec.yaml`:**
```yaml
geolocator: ^13.0.2  # Location services
```

---

### 4. Domain Models

#### **WeatherForecast** - `/lib/features/weather/domain/weather_forecast.dart`
```dart
class WeatherForecast {
  final double temperatureC;
  final int humidityPct;
  final bool forecastAvailable;
  final DateTime forecastDate;
  final WeatherSource source; // forecast, historical, default
  final String? conditions;
  final int? windSpeedKmh;
  final double? precipitationMm;

  // Methods: fromJson, toJson, defaultForecast, isFresh
  // Computed properties: temperatureF, windSpeedMph, precipitationIn
}
```

#### **Location** - `/lib/features/weather/domain/location.dart`
```dart
class Location {
  final double latitude;
  final double longitude;
  final String? address;
  final String? city;
  final String? country;

  // Methods: fromJson, toJson
  // Computed: displayName, shortDisplayName
}
```

---

### 5. Database Layer

#### **Weather Cache Table** - `/lib/shared/database/tables/weather_forecasts_table.dart`
```dart
@DataClassName('WeatherForecastData')
class WeatherForecastsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get forecastDate => dateTime()();
  RealColumn get temperatureC => real()();
  IntColumn get humidityPct => integer()();
  BoolColumn get forecastAvailable => boolean()();
  TextColumn get source => text()();
  TextColumn get conditions => text().nullable()();
  IntColumn get windSpeedKmh => integer().nullable()();
  RealColumn get precipitationMm => real().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  DateTimeColumn get expiresAt => dateTime()(); // 1-hour cache
}
```

**Integration:** Added to `AppDatabase` in `/lib/shared/database/app_database.dart`

---

### 6. Services Layer

#### **LocationService** - `/lib/shared/services/location_service.dart`
```dart
@riverpod
LocationService locationService(LocationServiceRef ref)

class LocationService {
  Future<Location?> getCurrentLocation();
  Future<bool> hasLocationPermission();
  Future<bool> requestLocationPermission();
  Future<bool> openLocationSettings();
}
```

#### **WeatherRepository** - `/lib/features/weather/data/weather_repository.dart`
```dart
@riverpod
WeatherRepository weatherRepository(WeatherRepositoryRef ref)

class WeatherRepository {
  Future<WeatherForecast?> getCachedForecast({latitude, longitude, forecastDate});
  Future<void> cacheForecast({latitude, longitude, forecast});
  Future<void> clearExpiredForecasts();
  Future<void> clearAllForecasts();
}
```

#### **WeatherService** - `/lib/features/weather/application/weather_service.dart`
```dart
@riverpod
WeatherService weatherService(WeatherServiceRef ref)

class WeatherService {
  // Main method: checks cache first, then API
  Future<WeatherForecast> getWeatherForecast({
    Location? location,  // If null, uses device GPS
    required DateTime activityDate,
  });

  Future<Location?> getCurrentLocation();
  Future<bool> hasLocationPermission();
  Future<bool> requestLocationPermission();
}
```

---

### 7. Presentation Layer - UI Widgets

#### **WeatherIndicatorBadge** - `/lib/features/weather/presentation/widgets/weather_indicator_badge.dart`
- Shows weather forecast status with icon
- Displays temp/humidity when available
- Color-coded by source (forecast/historical/default)
- Clickable to open detail screen

#### **LocationInputField** - `/lib/features/weather/presentation/widgets/location_input_field.dart`
- Displays current location
- "Use current location" button (GPS)
- "Edit location" button
- Shows coordinates
- Loading state support

#### **WeatherDetailScreen** - `/lib/features/weather/presentation/screens/weather_detail_screen.dart`
- Full weather forecast display
- Hero section with temperature and icon
- Location details
- All weather metrics (wind, precipitation, etc.)
- Forecast metadata (source, date)
- Explanation of data source

---

## 🚧 Integration Needed

### Controller Updates Required

Each sport input controller needs these additions:

#### **1. Add to State Class**
```dart
class CyclingFormState {  // or RunningFormState, SwimmingFormState
  // ... existing fields ...

  // NEW FIELDS:
  final Location? location;
  final WeatherForecast? weatherForecast;
  final bool isLoadingLocation;
  final bool isLoadingWeather;

  const CyclingFormState({
    // ... existing params ...
    this.location,
    this.weatherForecast,
    this.isLoadingLocation = false,
    this.isLoadingWeather = false,
  });

  CyclingFormState copyWith({
    // ... existing params ...
    Location? location,
    WeatherForecast? weatherForecast,
    bool? isLoadingLocation,
    bool? isLoadingWeather,
  }) {
    // ... implementation
  }
}
```

#### **2. Add Services to Controller**
```dart
@Riverpod(keepAlive: true)
class CyclingInputController extends _$CyclingInputController {
  WeatherService get _weatherService => ref.read(weatherServiceProvider);
  LocationService get _locationService => ref.read(locationServiceProvider);

  // ... existing methods ...
}
```

#### **3. Add Weather Methods to Controller**
```dart
/// Fetch current location and weather forecast
Future<void> fetchWeatherForecast() async {
  state = state.copyWith(isLoadingWeather: true);

  try {
    // Get activity date/time
    final activityDateTime = DateTime(
      state.selectedDate.year,
      state.selectedDate.month,
      state.selectedDate.day,
      state.selectedTime.hour,
      state.selectedTime.minute,
    );

    // Fetch weather (uses location if set, otherwise GPS)
    final forecast = await _weatherService.getWeatherForecast(
      location: state.location,
      activityDate: activityDateTime,
    );

    // Update temp/humidity from forecast if available
    if (forecast.forecastAvailable) {
      state = state.copyWith(
        weatherForecast: forecast,
        temperatureC: forecast.temperatureC,
        humidityPct: forecast.humidityPct.toDouble(),
        isLoadingWeather: false,
      );
    } else {
      state = state.copyWith(
        weatherForecast: forecast,
        isLoadingWeather: false,
      );
    }
  } catch (e) {
    state = state.copyWith(isLoadingWeather: false);
  }
}

/// Fetch current GPS location
Future<void> fetchCurrentLocation() async {
  state = state.copyWith(isLoadingLocation: true);

  try {
    final location = await _locationService.getCurrentLocation();
    state = state.copyWith(
      location: location,
      isLoadingLocation: false,
    );

    // Auto-fetch weather after getting location
    if (location != null) {
      fetchWeatherForecast();
    }
  } catch (e) {
    state = state.copyWith(isLoadingLocation: false);
  }
}

/// Clear location (allows manual entry)
void clearLocation() {
  state = state.copyWith(
    location: null,
    weatherForecast: null,
  );
}
```

#### **4. Auto-fetch on Date Change**
```dart
void updateDateTime(DateTime date, TimeOfDay time) {
  state = state.copyWith(
    selectedDate: date,
    selectedTime: time,
  );

  // Auto-fetch weather when date changes
  if (state.location != null) {
    fetchWeatherForecast();
  }
}
```

---

### Screen Updates Required

Each input screen needs:

#### **1. Add Import for Location Field Widget**
```dart
import '../../../weather/presentation/widgets/location_input_field.dart';
import '../../../weather/presentation/widgets/weather_indicator_badge.dart';
import '../../../weather/presentation/screens/weather_detail_screen.dart';
```

#### **2. Add Location Field (before Environment section)**
```dart
// Location Field
LocationInputField(
  location: cyclingForm.location,
  onFetchCurrentLocation: () {
    ref.read(cyclingInputControllerProvider.notifier).fetchCurrentLocation();
  },
  onEditLocation: () {
    ref.read(cyclingInputControllerProvider.notifier).clearLocation();
    // TODO: Could add manual location entry dialog
  },
  isLoadingLocation: cyclingForm.isLoadingLocation,
),

SizedBox(height: 20.h),

// Weather Badge (if weather fetched)
if (cyclingForm.weatherForecast != null)
  WeatherIndicatorBadge(
    forecast: cyclingForm.weatherForecast!,
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeatherDetailScreen(
            forecast: cyclingForm.weatherForecast!,
            location: cyclingForm.location,
          ),
        ),
      );
    },
  ),

SizedBox(height: 20.h),
```

#### **3. Auto-fetch Location on Screen Load**
```dart
@override
void initState() {
  super.initState();
  // ... existing init code ...

  // Auto-fetch location if not already set
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final controller = ref.read(cyclingInputControllerProvider.notifier);
    if (controller.state.location == null) {
      controller.fetchCurrentLocation();
    }
  });
}
```

---

## 📁 Files That Need Updates

### Controllers (Add weather integration):
1. `/lib/features/nutrition_plan/presentation/providers/cycling_input_controller.dart`
2. `/lib/features/nutrition_plan/presentation/providers/swimming_input_controller.dart`
3. `/lib/features/nutrition_plan/presentation/providers/running_input_controller.dart`

### Screens (Add UI widgets):
1. `/lib/features/nutrition_plan/presentation/screens/cycling_input_screen.dart`
2. `/lib/features/nutrition_plan/presentation/screens/swimming_input_screen.dart`
3. `/lib/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart` (running)

---

## 🚀 Deployment Steps

### 1. Deploy Edge Function
```bash
cd supabase/functions/get-weather-forecast
supabase functions deploy get-weather-forecast --project-ref <dev-project-id>
```

### 2. Test Edge Function
```bash
curl -X POST https://<dev-project-id>.supabase.co/functions/v1/get-weather-forecast \
  -H "Authorization: Bearer <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{
    "latitude": 40.7128,
    "longitude": -74.0060,
    "activity_date": "2025-10-28T14:00:00Z"
  }'
```

### 3. Run Code Generation
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Test on Device
```bash
flutter run --debug
```

---

## 🧪 Testing Checklist

- [ ] Location permission prompt appears
- [ ] GPS location fetches successfully
- [ ] Weather forecast displays in badge
- [ ] Weather detail screen shows all data
- [ ] Temperature/humidity auto-populate
- [ ] Cache works (second fetch is instant)
- [ ] Default fallback works for far future dates
- [ ] Historical data works for past dates (within 92 days)
- [ ] Works across all 3 sports (running, cycling, swimming)

---

## 📊 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Cycling      │  │ Swimming     │  │ Running      │      │
│  │ Input Screen │  │ Input Screen │  │ Input Screen │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │               │
│  ┌──────▼──────────────────▼──────────────────▼────────┐    │
│  │         Sport Input Controllers                      │    │
│  │  - fetchWeatherForecast()                           │    │
│  │  - fetchCurrentLocation()                           │    │
│  └──────────────────────┬───────────────────────────────┘    │
└─────────────────────────┼───────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────┐
│                   Application Layer                          │
│  ┌───────────────────────────────────────────────────┐      │
│  │            WeatherService                          │      │
│  │  - getWeatherForecast(location, date)            │      │
│  │  - getCurrentLocation()                           │      │
│  └─────┬─────────────────────┬────────────────┬──────┘      │
│        │                     │                │              │
│  ┌─────▼──────┐  ┌──────────▼─────┐  ┌──────▼──────────┐  │
│  │ Location   │  │ Weather        │  │ Supabase Edge   │  │
│  │ Service    │  │ Repository     │  │ Function Call   │  │
│  │ (GPS)      │  │ (Cache)        │  │                 │  │
│  └────────────┘  └────────────────┘  └─────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                                                │
┌───────────────────────────────────────────────▼─────────────┐
│                      Data Layer                              │
│  ┌──────────────────┐              ┌──────────────────┐    │
│  │ Drift SQLite     │              │ Supabase Edge    │    │
│  │ Weather Cache    │              │ Function         │    │
│  │ (1-hour expiry)  │              │ (Open-Meteo API) │    │
│  └──────────────────┘              └──────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Next Steps for You

1. **Review this implementation** - Make sure the architecture fits your needs
2. **Deploy edge function** - Test it in Supabase dev environment
3. **Choose integration approach:**
   - Option A: I can integrate all controllers/screens now
   - Option B: You want to do the integration yourself
   - Option C: We do one sport together, then you do the rest
4. **Test thoroughly** on real device with location permissions

Let me know how you'd like to proceed!
