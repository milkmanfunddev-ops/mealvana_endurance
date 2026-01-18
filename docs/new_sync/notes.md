# New Sync Implementation Notes

**Purpose**: Working document for agents to record discoveries, decisions, and issues.

---

## How to Use This Document

- Add dated entries for any important findings
- Document decisions made during implementation
- Record issues encountered and how they were resolved
- Note any deviations from the roadmap

---

## Decisions Log

### 2026-01-18 - Initial Planning

**Decision**: Use 24-hour staleness threshold
- Rationale: Balance between data freshness and network efficiency
- Alternative considered: On-demand sync (rejected - too many network calls)

**Decision**: SharedPreferences for sync timestamps
- Rationale: Simple, fast, persists across restarts
- Alternative considered: Dedicated Drift table (rejected - adds complexity)

**Decision**: App Support directory for dirty record backups
- Rationale: Hidden from user, persists across updates, survives iOS offload
- Alternative considered: Documents directory (rejected - visible to user)

**Decision**: Block app on version check failure (schema mismatch)
- Rationale: Data integrity is critical for nutrition planning
- Alternative considered: Graceful degradation (rejected - risk of data corruption)

---

## Implementation Notes

### Phase 1 Notes

*(Agents: Add notes here as you work on Phase 1)*

---

### Phase 2 Notes

*(Agents: Add notes here as you work on Phase 2)*

---

### Phase 3 Notes

*(Agents: Add notes here as you work on Phase 3)*

---

### Phase 4 Notes

*(Agents: Add notes here as you work on Phase 4)*

---

### Phase 5 Notes

*(Agents: Add notes here as you work on Phase 5)*

---

### Phase 6 Notes

*(Agents: Add notes here as you work on Phase 6)*

---

## Issues Encountered

### Template:
```
### Issue: [Brief description]
**Date**: YYYY-MM-DD
**Agent**: [Agent ID]
**Status**: Open | Resolved
**Description**: [Detailed description]
**Resolution**: [How it was resolved, if applicable]
```

---

## Code Patterns Discovered

*(Document any patterns found in existing code that are useful)*

### Existing Dirty Flag Pattern
```dart
// Found in activities_repository.dart
final activityWithDirtyFlag = activity.copyWith(
  needsUpload: true,
  localUpdatedAt: DateTime.now(),
);
await _saveToDrift(activityWithDirtyFlag);
unawaited(_uploadActivityToSupabase(deviceId, activityWithDirtyFlag, 'update'));
```

### Existing Supabase Query Pattern
```dart
// Found in user_repository.dart
final response = await supabase
    .from('users')
    .select()
    .eq('id', userId)
    .maybeSingle();
```

---

## Questions for Lee

*(Add questions here that need human input)*

1. *(None yet)*

---

## Agent Activity Log

| Date | Agent ID | Task | Status | Notes |
|------|----------|------|--------|-------|
| | | | | |

---

*Last updated*: 2026-01-18
