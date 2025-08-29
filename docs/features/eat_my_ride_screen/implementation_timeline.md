# Adjust Macros Screen - Implementation Timeline

## Phase 1: Core Data Models and Repository
**Status: IN PROGRESS**
**Started: [Current Date]**

### Tasks:
- [x] Create timeline.md file
- [x] Create domain models (MacroTargets, PreRunMacros, DuringRunMacros, PostRunMacros, RunMetrics)
- [ ] Create repository interface
- [ ] Implement repository with Drift integration
- [ ] Update Drift database schema for macro storage
- [ ] Add offline fallback integration

### Deliverables:
- `lib/features/nutrition_plan/domain/macro_targets.dart`
- `lib/features/nutrition_plan/domain/macro_models.dart`
- `lib/features/nutrition_plan/data/macro_repository.dart`
- Database migration for macro storage

---

## Phase 2: Basic UI with Editable Fields
**Status: PENDING**

### Tasks:
- [ ] Create adjust_macros_screen.dart
- [ ] Implement basic layout with sections
- [ ] Add editable text fields for all macros
- [ ] Implement collapsible sections
- [ ] Add basic navigation flow
- [ ] Connect to controller

### Deliverables:
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- `lib/features/nutrition_plan/presentation/widgets/macro_input_field.dart`
- `lib/features/nutrition_plan/presentation/widgets/macro_section.dart`

---

## Phase 3: Validation Logic and Warnings
**Status: PENDING**

### Tasks:
- [ ] Implement validation ranges
- [ ] Add real-time validation
- [ ] Create warning UI components
- [ ] Implement field linking logic for during-run values
- [ ] Add unit conversions (ml ↔ fl oz)

### Deliverables:
- `lib/features/nutrition_plan/application/macro_validator.dart`
- `lib/features/nutrition_plan/presentation/widgets/validation_warning.dart`
- Updated macro input fields with validation

---

## Phase 4: CMS Integration and Help Content
**Status: PENDING**

### Tasks:
- [ ] Add CMS keys for all UI text
- [ ] Integrate ContentService
- [ ] Create help bottom sheet
- [ ] Add scientific rationale content
- [ ] Implement global help icon

### Deliverables:
- Updated content_defaults.json
- `lib/features/nutrition_plan/presentation/widgets/macro_help_sheet.dart`
- CMS integration in screen and widgets

---

## Phase 5: Analytics and Error Handling
**Status: PENDING**

### Tasks:
- [ ] Add analytics events
- [ ] Implement error handling for API failures
- [ ] Add snackbar notifications
- [ ] Implement retry logic
- [ ] Add loading states

### Deliverables:
- Analytics integration
- Error handling in controller
- Loading/error UI states

---

## Phase 6: Testing Suite
**Status: PENDING**

### Tasks:
- [ ] Unit tests for validation logic
- [ ] Unit tests for offline calculator
- [ ] Repository tests
- [ ] Widget tests for UI components
- [ ] Integration tests for full flow

### Deliverables:
- `test/features/nutrition_plan/domain/`
- `test/features/nutrition_plan/data/`
- `test/features/nutrition_plan/presentation/`
- `test/features/nutrition_plan/application/`

---

## Completion Summary
- **Total Phases**: 6
- **Completed**: 0
- **In Progress**: 1
- **Pending**: 5

## Notes:
- Each phase builds on the previous one
- Testing can be done incrementally as each phase completes
- UI can be tested manually after Phase 2
- Full integration testing possible after Phase 5