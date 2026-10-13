# Weather

domain: 1 Fuel a workout · folder: `lib/features/weather/` (8 files)

Fills in temperature and humidity on the "Create New Activity Plan" form from the forecast for the workout's place
and time; those values feed the hydration and sodium targets. Described with the form on
`nutrition_plan/new-activity-form.md` ("Check the conditions"): the "AUTO" badge, "Auto-filled from location", the
source chips "Measured" (fetched for this place and time) / "Assumed" (the 20 °C / 60 % fallback, 45 % indoors) /
"Manual", the location prompts, and "View Forecast", which opens "Weather Forecast" (Location, Weather Details,
Forecast Info with Source: Forecast / Historical / Default, "About this forecast"). On the bike tab "View Forecast"
only re-fetches. The plan's conditions label takes the less confident of the two values.

Provider Open-Meteo through the `get-weather-forecast` function (16 days ahead, 92 back); location via the phone at
low accuracy, only when the workout is within the 16-day window; address search via LocationIQ. Phone cache
`weather_forecasts` (forecasts expire after an hour, history after a day). Reuse: `application/weather_service.dart`
(location → cache → function → default), `data/weather_repository.dart`, `domain/forecast_window.dart`,
`presentation/screens/weather_detail_screen.dart`. Dead: `location_input_field.dart`, `weather_indicator_badge.dart`.
qa: `spec/design/surfaces/create-flow-fueling-controls.md` (CF-4/5/7/8), `spec/fueling/during-workout-hydration.md`
(CP-1…CP-6). ops: feature-request `experiment-post-workout-cta-weather`.
