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

// Sport configurations
export * from './sport-configs/index.ts';
