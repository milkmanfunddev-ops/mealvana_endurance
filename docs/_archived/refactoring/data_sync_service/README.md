# DataSyncService Refactoring Plan

**Date**: 2026-01-09
**Status**: Analysis Complete, Ready for Implementation
**Priority**: High (Technical Debt Reduction)

## Executive Summary

The `DataSyncService` has grown to **2,508 lines** in a single file, making it one of the largest and most complex services in the codebase. This document outlines a comprehensive refactoring plan to break it into **6 specialized services** plus utility classes, reducing the main service to ~400 lines while improving testability, maintainability, and code clarity.

### Current State

- **File Size**: 2,508 lines
- **Method Count**: 52 methods (48 lines average)
- **Code Duplication**: ~980 lines (39% of file)
- **Longest Method**: 178 lines (`uploadDirtyRecords`)
- **Dependencies**: 7 injected (1 unused)
- **Concerns**: Doing the work of 6+ services

### Target State (After Refactoring)

- **Main Service**: ~400 lines (orchestration only)
- **Specialized Services**: 6 services × 300-500 lines each
- **Utility Classes**: 3 classes × 100-150 lines each
- **Code Duplication**: ~0% (eliminated via utilities and base patterns)
- **Testability**: Each service independently testable
- **Onboarding Time**: Reduced from 2-3 days to 2-3 hours per service

---

## Key Problems Identified

### 1. **Monolithic Design**
- Single file handles user sync, calendar sync, carb loading sync, coach sync, data integrity, and upload orchestration
- Makes testing difficult (can't test individual concerns)
- High cognitive load for developers

### 2. **Significant Code Duplication (39%)**
- DateTime parsing repeated ~35 times (~140 lines)
- Entity upsert pattern repeated for 7 entities (~250 lines)
- Error handling pattern repeated ~20 times (~180 lines)
- Entity-to-JSON conversion repeated for 4 entities (~100 lines)
- Duplicate cleanup logic repeated twice (~150 lines)

### 3. **Tight Coupling**
- 100+ direct database calls scattered throughout
- Raw SQL in 20+ places
- Direct coupling to table schemas
- UI-layer provider invalidation in sync service

### 4. **Mixed Concerns**
- Single methods handle parsing, validation, transformation, and persistence
- Example: `_syncDataFromEdgeFunction` handles 9 different entity types in 124 lines

---

## Documentation Structure

This refactoring plan is split across multiple documents:

### Core Documentation

1. **[README.md](./README.md)** (this file)
   - Executive summary
   - Problems and goals
   - Quick reference guide

2. **[code-analysis.md](./code-analysis.md)**
   - Detailed method inventory
   - Code duplication analysis
   - Dependency coupling analysis
   - Sync pattern analysis

3. **[refactoring-plan.md](./refactoring-plan.md)**
   - Phase 1: Quick Wins (utilities, integrity service)
   - Phase 2: Entity Services (calendar, carb loading, coach, user)
   - Phase 3: Core Refactoring (upload orchestrator, simplified main service)
   - Implementation code examples

4. **[implementation-checklist.md](./implementation-checklist.md)**
   - Step-by-step implementation tasks
   - Testing requirements
   - Code generation steps
   - Validation checklist

---

## Refactoring Phases Overview

### Phase 1: Quick Wins (1-2 days, Low Risk)
**Goal**: Extract utilities and self-contained services
**Lines Saved**: ~795 lines

- **1.1**: Create `TypeConverters` utility class (~380 lines saved)
- **1.2**: Extract `DataIntegrityService` (~300 lines saved)
- **1.3**: Extract `EntityJsonConverter` (~115 lines saved)

**Risk**: Very Low (pure utilities, no dependencies)
**Impact**: High (makes remaining refactoring easier)

---

### Phase 2: Entity Services (3-4 days, Medium Risk)
**Goal**: Extract entity-specific sync logic
**Lines Saved**: ~1,550 lines

- **2.1**: Create `CalendarSyncService` (~500 lines)
- **2.2**: Create `CarbLoadingSyncService` (~350 lines)
- **2.3**: Create `CoachDataSyncService` (~300 lines)
- **2.4**: Create `UserProfileSyncService` (~400 lines)

**Risk**: Medium (requires careful dependency injection)
**Impact**: High (clear separation of concerns)

---

### Phase 3: Core Refactoring (2-3 days, Higher Risk)
**Goal**: Simplify main orchestration service
**Lines Saved**: ~300 lines + simplification

- **3.1**: Create `UploadOrchestratorService` (~300 lines)
- **3.2**: Refactor main `DataSyncService` to ~400 lines

**Risk**: Medium-High (touches core sync flow)
**Impact**: Very High (achieves refactoring goals)

---

## Expected Benefits

### Maintainability
- **Before**: 2,508 lines in one file, 2-3 days to understand
- **After**: 6 services × 300-500 lines, 2-3 hours per service
- **Result**: 80% reduction in onboarding time

### Testability
- **Before**: Difficult to test individual sync concerns
- **After**: Each service independently testable with mocked dependencies
- **Result**: Can add unit tests for each service

### Code Quality
- **Before**: 39% code duplication, 4 methods over 100 lines
- **After**: 0% duplication via utilities, max method size ~60 lines
- **Result**: Cleaner, more maintainable code

### Future Extensibility
- **Before**: Adding new entity requires touching massive file
- **After**: Create new service (~300 lines), update orchestrator (~5 lines)
- **Result**: Low-risk entity additions

---

## Implementation Priority

| Phase | Effort | Risk | Impact | Order |
|-------|--------|------|--------|-------|
| **1.1 Utilities** | Low | Very Low | High | **1st** |
| **1.2 DataIntegrity** | Low | Very Low | Medium | **2nd** |
| **1.3 JSON Converters** | Low | Very Low | Low | **3rd** |
| **2.1 CalendarSync** | Medium | Low | High | **4th** |
| **2.2 CarbLoadingSync** | Medium | Low | Medium | **5th** |
| **2.3 CoachSync** | Medium | Low | Medium | **6th** |
| **2.4 UserProfileSync** | Medium | Medium | High | **7th** |
| **3.1 UploadOrchestrator** | High | Medium | High | **8th** |
| **3.2 Simplify Core** | Medium | Medium | Very High | **9th** |

---

## Quick Start Guide

### For Implementers

1. **Read [code-analysis.md](./code-analysis.md)** to understand the current structure
2. **Read [refactoring-plan.md](./refactoring-plan.md)** to see implementation details
3. **Follow [implementation-checklist.md](./implementation-checklist.md)** step-by-step
4. **Start with Phase 1** (utilities) - safest, highest ROI

### For Reviewers

1. Review one phase at a time
2. Verify tests exist for extracted services before approving
3. Check that original `DataSyncService` still passes integration tests
4. Ensure code generation was run (`*.g.dart` files updated)

### For Future Maintainers

- Each service has a single, clear responsibility
- New entities should get their own `*SyncService` class
- Common patterns should use utilities in `lib/shared/services/sync/utils/`
- Follow the same dependency injection pattern via Riverpod

---

## Success Criteria

- [ ] Main `DataSyncService` reduced to <500 lines
- [ ] All code duplication eliminated (via utilities)
- [ ] Each extracted service has unit tests
- [ ] Integration tests still pass
- [ ] No regression in sync functionality
- [ ] Code generation successful (`flutter pub run build_runner build`)
- [ ] Documentation updated

---

## Risk Mitigation

### Testing Strategy
- **Keep existing integration tests** running against refactored code
- Add unit tests for each new service
- Test dirty record upload flow extensively (critical for data integrity)
- Test edge function fallback to client-side sync

### Rollback Plan
- Each phase is independent - can rollback individual phases
- Keep DEPRECATED methods until confident in new implementation
- Use feature flags if needed for gradual rollout

### Known Risks
1. **Edge function response parsing**: Ensure all 9 entity types handled correctly
2. **Dirty record tracking**: Critical for data integrity - test thoroughly
3. **Timestamp handling**: Different formats (ISO8601, milliseconds) must work
4. **Multi-device sync**: Ensure user profile sync still works on new device login

---

## Timeline Estimate

| Phase | Duration | Cumulative |
|-------|----------|------------|
| Phase 1 | 1-2 days | 1-2 days |
| Phase 2 | 3-4 days | 4-6 days |
| Phase 3 | 2-3 days | 6-9 days |
| **Total** | **6-9 days** | **1.5-2 weeks** |

Add 2-3 days for comprehensive testing and documentation updates.

**Total Project Duration**: 2-2.5 weeks

---

## Related Documentation

- [Code Analysis](./code-analysis.md) - Detailed analysis of current implementation
- [Refactoring Plan](./refactoring-plan.md) - Phase-by-phase implementation guide
- [Implementation Checklist](./implementation-checklist.md) - Step-by-step tasks
- [Architecture Diagrams](./architecture-diagrams.md) - Before/after architecture visuals

---

## Contact

For questions about this refactoring plan, refer to:
- Original analysis date: 2026-01-09
- Analysis performed by: 4 specialized code research agents
- Approved by: [Pending]

---

**Status**: Ready for implementation. Start with Phase 1 when ready.
