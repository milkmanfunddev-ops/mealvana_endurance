/**
 * `none`: the lobby between flows (proposal v7 §5 "none"). Four shape steps plus the shared three, no lines of its own,
 * the situation line as its prior. Drafted here only as far as the README's second Route case needs it ("remember I
 * hate cilantro, what's for dinner" = Set a value then Choose); Read's option list for the lobby is not in v7/prompts
 * yet, so the targets below are a draft for Xuan: `memory` / `setting` → set_value, `meal` / `dinner` → choose,
 * `race` / `workout` / `log` → draft_record, `screen` → hand_off.
 */
import type { FlowDeclaration, StepDeclaration } from '../types.ts';
import { ANSWER } from './shared.ts';

const react = { name: 'react', kind: 'react' as const };
const every: StepDeclaration['checks'] = ['name_from_data', 'one_question', 'same_words_twice', 'no_app_claims'];

const steps: Record<string, StepDeclaration> = {
  set_value: { id: 'set_value', shape: 'set_value', section: null, tools: [{ name: 'rememberFact', kind: 'write' }, { name: 'setSetting', kind: 'write' }, { name: 'forgetFact', kind: 'write' }, react], cards: ['value_draft'], checks: every, reply: 'model', status: () => 'open', steer: '' },
  draft_record: { id: 'draft_record', shape: 'draft_record', section: null, tools: [{ name: 'showRaceCard', kind: 'card' }, { name: 'showWorkoutCard', kind: 'card' }, { name: 'logMeal', kind: 'card' }, react], cards: ['race_card', 'workout_card', 'meal_log'], checks: every, reply: 'model', status: () => 'open', steer: '' },
  choose: { id: 'choose', shape: 'choose', section: null, tools: [{ name: 'suggestMeals', kind: 'card' }, { name: 'searchMeals', kind: 'read' }, { name: 'recallFacts', kind: 'read' }, react], cards: ['meal_picker'], forcedFirstTool: 'suggestMeals', checks: every, reply: 'model', status: () => 'open', steer: '' },
  hand_off: { id: 'hand_off', shape: 'hand_off', section: null, tools: [{ name: 'handOff', kind: 'card' }], cards: ['hand_off'], checks: every, reply: 'model', status: () => 'open', steer: '' },
};

/** Which lobby step an `asks` target lands on. Unknown targets fall to Answer. */
export const NONE_TARGETS: Record<string, keyof typeof steps> = {
  memory: 'set_value', remember: 'set_value', setting: 'set_value', weight: 'set_value',
  meal: 'choose', dinner: 'choose', lunch: 'choose', breakfast: 'choose',
  race: 'draft_record', workout: 'draft_record', log: 'draft_record',
  screen: 'hand_off',
};

export const NONE: FlowDeclaration = {
  id: 'none',
  starts: () => true,
  lines: () => [],
  allowsJump: true,
  maxPasses: 4,
  order: [],
  steps,
  answerStep: ANSWER,
};
