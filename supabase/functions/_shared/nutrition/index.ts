/**
 * Nutrition Module Index
 *
 * Central export for all nutrition planning functionality
 */

// Types
export * from './types.ts';

// Constants
export * from './constants.ts';

// Utilities
export * from './food-utils.ts';

// Database queries
export * from './food-queries.ts';

// LP Solver
export { buildLPModel, solveLPModel } from './lp-solver.ts';

// Greedy fallback
export { greedyFallback } from './greedy-fallback.ts';

// Post-solve target reconciliation (LP lands on range edges; this pulls
// sodium/fluid back toward the point target without breaching the ceiling)
export { reconcilePhaseHydrationAndSodium } from './phase-target-reconcile.ts';

// Sport configurations
export * from './sport-configs/index.ts';
