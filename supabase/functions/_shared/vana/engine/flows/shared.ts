/**
 * The three shared steps every flow carries (proposal v7 §2), plus the Answer step `asks(app)` routes to. No flow has
 * to declare them; Route picks them like any other step.
 */
import type { StepDeclaration } from '../types.ts';

export const ANSWER: StepDeclaration = {
  id: 'answer', shape: 'answer', section: null,
  tools: [{ name: 'appGuide', kind: 'read' }, { name: 'getWorkouts', kind: 'read' }, { name: 'recallFacts', kind: 'read' }, { name: 'askChoice', kind: 'card' }],
  cards: ['choices'], checks: ['name_from_data', 'one_question', 'same_words_twice', 'no_app_claims'], reply: 'model',
  status: () => 'open', steer: '',
};

export const SENSITIVE: StepDeclaration = {
  id: 'sensitive', shape: 'answer', section: 'sensitive',
  tools: [{ name: 'flagSensitive', kind: 'flag' }, { name: 'askChoice', kind: 'card' }],
  cards: ['choices'], checks: ['name_from_data', 'one_question'], reply: 'model',
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

export const SHARED = { answer: ANSWER, sensitive: SENSITIVE, feedback: FEEDBACK, off_flow: OFF_FLOW } as const;
