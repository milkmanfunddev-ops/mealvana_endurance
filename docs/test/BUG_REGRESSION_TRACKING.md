# Bug Regression Tracking for Integration Tests

**Purpose:** This document tracks bugs discovered during testing that need regression test coverage to prevent reoccurrence.

**Last Updated:** 2025-12-18

---

## How to Use This Document

1. **Add bugs as you discover them** - Include description, steps to reproduce, expected vs actual behavior
2. **Link to screenshots** - Reference any screenshot files in `docs/screenshots/` or `docs/bugfixes/`
3. **Mark test status** - Note when integration test coverage is added for each bug
4. **Priority levels** - Critical (app crashes), High (data loss/corruption), Medium (UX issues), Low (cosmetic)

---

## Critical Bugs (Data Integrity)

### BUG-001: Activity Count Mismatch
- **Status:** 🔴 Needs Test Coverage
- **Priority:** Critical
- **Description:** Activities saved to database don't all appear in calendar/activity list
- **Example:** User has 5 saved activities in DB, but only 3 show in UI
- **Expected:** All saved activities should appear in calendar and activity lists
- **Actual:** Some activities missing from UI despite being in database
- **Test Account Setup:** Account should have 5+ activities with known IDs
- **Verification Method:**
  - Query database for activity count
  - Count visible activities in calendar view
  - Assert counts match
- **Screenshots:**
- **Notes:**

### BUG-002: Food Preferences Not Persisting
- **Status:** 🔴 Needs Test Coverage
- **Priority:** Critical
- **Description:**
- **Expected:**
- **Actual:**
- **Test Account Setup:**
- **Verification Method:**
- **Screenshots:**
- **Notes:**

### BUG-003: Event Data Corruption
- **Status:** 🔴 Needs Test Coverage
- **Priority:** Critical
- **Description:**
- **Expected:**
- **Actual:**
- **Test Account Setup:**
- **Verification Method:**
- **Screenshots:**
- **Notes:**

### BUG-004: Carb Loading Plans Not Saving
- **Status:** 🔴 Needs Test Coverage
- **Priority:** Critical
- **Description:**
- **Expected:**
- **Actual:**
- **Test Account Setup:**
- **Verification Method:**
- **Screenshots:**
- **Notes:**

---

## High Priority Bugs (Functionality)

### BUG-005: [Title]
- **Status:** 🔴 Needs Test Coverage
- **Priority:** High
- **Description:**
- **Expected:**
- **Actual:**
- **Test Account Setup:**
- **Verification Method:**
- **Screenshots:**
- **Notes:**

---

## Medium Priority Bugs (UX Issues)

### BUG-006: [Title]
- **Status:** 🔴 Needs Test Coverage
- **Priority:** Medium
- **Description:**
- **Expected:**
- **Actual:**
- **Test Account Setup:**
- **Verification Method:**
- **Screenshots:**
- **Notes:**

---

## Test Account Data Requirements

Based on the bugs above, the test account needs:

- **User Profile:**
  - Email: test@test.com
  - Password: test
  - Age: 30
  - Gender: Male
  - Weight: 70kg
  - Height: 175cm

- **Activities:**
  - Count: 5 known activities with specific IDs
  - Mix of sports: 3 running, 1 cycling, 1 swimming
  - Various distances: 5km, 10km, half marathon, full marathon, ultra
  - Different gut training levels

- **Events:**
  - Count: 3 events
  - Mix: 1 upcoming, 1 past, 1 today
  - Each should have associated nutrition plans

- **Carb Loading Plans:**
  - Count: 2 plans
  - With meals and days properly set up

- **Food Preferences:**
  - At least 20 foods with various preference levels
  - Mix of avoided, neutral, and loved foods
  - Include edge cases (very high/low preference scores)

- **Saved Foods:**
  - 10+ user-saved foods from OpenFoodFacts
  - Should persist across sessions

---

## Integration Test Coverage Matrix

| Bug ID | Test File | Test Method | Status |
|--------|-----------|-------------|--------|
| BUG-001 | activity_data_verification_test.dart | `test('Verify activity count matches database')` | 🔴 Not Created |
| BUG-002 | food_preferences_verification_test.dart | `test('Food preferences persist after save')` | 🔴 Not Created |
| BUG-003 | event_data_verification_test.dart | `test('Event data integrity check')` | 🔴 Not Created |
| BUG-004 | carb_loading_verification_test.dart | `test('Carb loading plans save correctly')` | 🔴 Not Created |

---

## Template for Adding New Bugs

```markdown
### BUG-XXX: [Brief Title]
- **Status:** 🔴 Needs Test Coverage / 🟡 Test In Progress / 🟢 Test Added
- **Priority:** Critical / High / Medium / Low
- **Description:** [What is the bug? When does it occur?]
- **Expected:** [What should happen]
- **Actual:** [What actually happens]
- **Test Account Setup:** [What data is needed to reproduce this?]
- **Verification Method:** [How can we programmatically verify this is fixed?]
- **Screenshots:** [Link to docs/screenshots/ or docs/bugfixes/]
- **Notes:** [Any additional context]
```

---

## Status Legend

- 🔴 Needs Test Coverage - Bug identified, no test yet
- 🟡 Test In Progress - Test is being written
- 🟢 Test Added - Integration test covers this bug
- ✅ Verified Fixed - Bug confirmed fixed and test passing

---

## Next Steps

1. **Fill in bug details** - Add descriptions for BUG-001 through BUG-004
2. **Add more bugs** - Use the template to add all discovered bugs
3. **Provide screenshots** - Upload and link relevant screenshots
4. **Review with AI** - Once complete, use this document to generate integration tests
