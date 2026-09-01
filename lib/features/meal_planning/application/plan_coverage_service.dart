/// Application-layer entry point for plan coverage (05 §1). The
/// implementation lives in the domain (`PlanCoverageService.compute`) since
/// `MealPlan.fromJson` needs it too; this re-export keeps imports at the
/// layer the file tree names.
library;

export '../domain/plan_coverage.dart'
    show PlanCoverage, PlanCoveragePerDay, PlanCoverageService;
