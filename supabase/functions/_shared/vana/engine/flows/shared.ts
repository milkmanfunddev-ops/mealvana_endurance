/**
 * The shared steps every flow carries (proposal v7 §2; the check-in added 2026-10-15), plus the Answer step `asks(app)` routes to. No flow has
 * to declare them; Route picks them like any other step.
 */
import type { StepDeclaration } from '../types.ts';

export const ANSWER: StepDeclaration = {
  id: 'answer', shape: 'answer', section: null,
  tools: [{ name: 'appGuide', kind: 'read' }, { name: 'getWorkouts', kind: 'read' }, { name: 'recallFacts', kind: 'read' }, { name: 'askChoice', kind: 'card' }],
  cards: ['choices'], checks: ['name_from_data', 'same_words_twice', 'no_app_claims'], reply: 'model',
  status: () => 'open', steer: '',
};

export const SENSITIVE: StepDeclaration = {
  id: 'sensitive', shape: 'answer', section: 'sensitive',
  tools: [{ name: 'flagSensitive', kind: 'flag' }, { name: 'askChoice', kind: 'card' }],
  cards: ['choices'], checks: ['name_from_data'], reply: 'model',
  status: () => 'open', steer: '',
};

export const FEEDBACK: StepDeclaration = {
  id: 'feedback', shape: 'scripted', section: null,
  tools: [{ name: 'saveFeedback', kind: 'write' }], cards: [], checks: [], reply: 'scripted', scripted: 'feedback',
  status: () => 'open', steer: '',
};

export const OFF_FLOW: StepDeclaration = {
  id: 'off_flow', shape: 'scripted', section: null,
  tools: [], cards: [], checks: [], reply: 'scripted', scripted: 'off_flow',
  status: () => 'open', steer: '',
};

/** The second off-flow ask of a visit: the scripted check-in instead of the steer, once per visit (Q1a, 2026-10-15). */
export const CHECK_IN: StepDeclaration = {
  id: 'check_in', shape: 'scripted', section: null,
  tools: [], cards: [], checks: [], reply: 'scripted', scripted: 'check_in',
  status: () => 'open', steer: '',
};

export const SHARED = { answer: ANSWER, sensitive: SENSITIVE, feedback: FEEDBACK, off_flow: OFF_FLOW, check_in: CHECK_IN } as const;
