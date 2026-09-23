/** The chip labels Vana names that the app acts on at once, with no model turn (mp-464 clause 1, ticket 11).
 *
 *  These are the ONLY labels the persona may use for these answers: the app recognises a tap by its label and runs the
 *  fixed step itself (draft the week, copy last time, record a setting, lay the week out, open the shopping list), so a
 *  label that drifts becomes a chip that costs a full planning turn again. The app's own copy of this list lives in
 *  `lib/features/meal_planning/domain/vana_fixed_chip.dart`; change both, and the tests on each side.
 *
 *  A leaf module on purpose: persona.ts interpolates these into prompt text at load time, and chips.ts imports plan
 *  and log modules, so the labels sit where neither pulls the other in. */
export const CHIP_LABELS = {
  /** The opener's "build on last time" answer → `same_as_last_time`. */
  sameAsLastTime: 'Same as last time',
  /** The batch-cooking fork (persona rule 4a) → `set_setting batch_cooking`. */
  batchOn: 'Batch cook',
  batchOff: 'Cook most nights',
  /** The coverage fork (persona rule 4b) → `set_setting coverage_scope`. */
  coverageDinners: 'Dinners only',
  coverageDinnersLunches: 'Dinners and lunches',
  coverageAll: 'Every meal',
  /** After confirmPlan (persona rule 7): the app opens the list / runs `plan_week`; "Adjust" still reaches Vana. */
  openShoppingList: 'Open shopping list',
  layAcrossWeek: 'Lay it across the week',
  adjust: 'Adjust',
} as const;
