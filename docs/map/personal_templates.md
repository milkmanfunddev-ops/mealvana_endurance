# Routines (personal_templates)

domain: 1 Fuel a workout · folder: `lib/features/personal_templates/` (9 files)

A whole generated plan, foods and amounts, saved under a name and reused for a later workout of the same sport.
Shown to athletes as "Routines".

- **Save one.** The bookmark on the plan screen ("Save as Routine") or the "Save as Routine" button under "Save
  Workout" on a just-created plan: "Save your food selections as a reusable {sport} routine." → "Routine Name"
  ("e.g., Saturday Long Run") → "Save Routine" → "Workout and routine saved!" (the workout saves too). Ten at most:
  "Routine limit reached (10). Delete one to save a new routine."
- **Use one.** On the "Create New Activity Plan" form, "Use Routine" appears beside "Generate Plan" when a routine
  exists for that sport → "My Routines" sheet with "Scale to fit this activity" (foods scaled by each phase's carb
  ratio) → the plan screen, skipping Adjust Your Macros.
- **Manage them.** "Manage routines →" in that sheet opens "My Routines" (route `/settings/templates`; there is no
  Settings entry): "Rename", "Delete" ("Routine deleted"), "N of 10 routines used", "No Routines Yet".

Table `personal_templates` (phone and Supabase): name, sport, original duration, distance and title, the plan JSON,
totals, brick leg order. Reuse: `personal_templates_controller`, `template_picker_sheet`, `save_template_dialog`,
`template_scaling_service`. Dead: `macro_comparison_banner.dart`. qa: `spec/design/vana/cards.md:28`. Related:
`nutrition_plan/activity-detail.md`, `nutrition_plan/new-activity-form.md`.
