# Race day checklist

domain: 3 Race week · folder: `lib/features/race_checklist/` (5 files)

A packing list for one race, opened from the race's details page ("Race Day Checklist", route
`/events/:eventId/checklist`). Described with the race on `events.md` ("Race day checklist"). Items are generated per
sport and gender (`application/gear_template_service.dart`) plus the race's fuel-plan foods; custom items can be
added; the list lives only on the phone (`race_checklist_items`, no sync). Reuse: `checklist_controller`,
`race_checklist_screen`.
