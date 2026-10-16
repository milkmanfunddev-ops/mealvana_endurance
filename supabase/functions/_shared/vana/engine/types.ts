/**
 * Vana engine — the shapes (proposal v7 §2, §4, §5; ratified 2026-10-15).
 *
 * A flow is a declaration the engine reads, not a prompt the model holds. A step is a shape plus a declaration:
 * which prompt section, which tools, which cards, which arguments code binds, which checks run on its words, and a
 * code reader for its status. Nothing in this file touches a database or a model: the engine is pure, and the callers
 * (the ops harness, the future `vana-chat` edge function) supply adapters (adapters.ts).
 *
 * Source of truth: ops/design/diagrams/2026-10-09-router/vana-framework-proposal.html and
 * ops/experiments/setup-chat/v7/README.md. Ledger: ops/docs/vana.md, 2026-10-15 row.
 */

export type FlowId = 'orientation' | 'meal_planning' | 'debrief' | 'none';

/** The six exchange shapes (§2). Steps consolidate by shape, never by subject. */
export type Shape = 'answer' | 'set_value' | 'draft_record' | 'choose' | 'hand_off' | 'scripted';

/** Read's labels (v7/prompts/read.md). `chat` is the seventh (ruled 2026-10-15, E4). `declines` targets: step, all_connections, visit. */
export type IntentLabel = 'answers' | 'declines' | 'asks' | 'leaves_flow' | 'feedback' | 'chat' | 'safety';
export interface Intent { label: IntentLabel; target?: string }
export interface ReadResult { intents: Intent[]; facts: string[] }

export type Weekday = 'Monday' | 'Tuesday' | 'Wednesday' | 'Thursday' | 'Friday' | 'Saturday' | 'Sunday';
export type Sport = 'run' | 'ride' | 'swim' | 'strength';

// ---------------------------------------------------------------- what the engine reads about the athlete
export interface Workout { id: string; date: string; title: string; type: Sport; minutes: number; fueled?: boolean; fueledWithPin?: string | null; source?: 'plan' | 'calendar' }
export interface Race { id?: string; name: string; date: string; distance?: string; source?: 'app' | 'plan' }
export interface Pin { id: string; name: string; phase: 'before' | 'during' | 'after'; activities: string[]; brackets: string[] }
export interface WeekDay { day: Weekday; minutes: number; sports: Sport[] }
export interface HistoryPattern { weekday: Weekday; sport: Sport; typicalMinutes: number; confidence: 'clear' | 'weak' }

export type StepMemory = 'done' | 'declined' | 'declined_for_good';

/** One read of the athlete's rows, as the DataReader returns it. The engine never fetches on its own. */
export interface Snapshot {
  today: string;                                        // YYYY-MM-DD, the athlete's local day
  profile: { firstName: string | null; gutTraining: 'low' | 'moderate' | 'high' | null; metVana: boolean };
  connections: { plan: string | null; wearable: string | null; wearableJustConnected: boolean; historySynced: boolean };
  workouts: Workout[];                                  // upcoming, from today, plan + calendar, by date
  history: Workout[];                                   // past synced workouts (empty until the backfill lands)
  race: Race | null;
  pins: Pin[];
  week: WeekDay[] | null;                               // what the athlete put in the week planner
  memories: string[];                                   // the newest margin notes (MEMORIES line)
  /** Lee's Doll lines (buildAthleteContext → contextBlock), built by the caller. Empty in tests. */
  doll: string[];
  /** Orientation memory from earlier visits: keyed settings (box 8). `declined` is offered again next visit; a second
   *  decline makes it `declined_for_good`, never offered again (ruled 2026-10-15, Q7a). */
  steps: Partial<Record<string, StepMemory>>;
}

// ---------------------------------------------------------------- the client's situation line (box 1)
export interface Situation { route: string; entityId?: string | null; date?: string | null; opened?: 'orientation' | 'plan_button' | 'banner' | 'push' | null }

// ---------------------------------------------------------------- tools, cards, receipts
export type ToolKind = 'card' | 'write' | 'read' | 'react' | 'flag';
export interface ToolRef { name: string; kind: ToolKind }
export interface ToolSpec { name: string; description: string; inputSchema: Record<string, unknown>; kind: ToolKind }
export interface ToolCall { name: string; input: Record<string, unknown> }

export type Milestone = 'formula_pinned' | 'long_workout_fueled' | 'race_added' | 'setup_done';

export interface Card { id: string; kind: string; step: string; caption?: string; payload: unknown }
export interface Receipt { what: string; line: string; step?: string; milestone?: Milestone }

/** What a tool run comes back as. A card ends the turn; a receipt rides to the next step; a view goes back to the model. */
export type ToolOutcome =
  | { type: 'card'; card: Card }
  | { type: 'receipt'; receipt: Receipt }
  | { type: 'view'; data: unknown; view: string }
  | { type: 'error'; message: string };

/** A tap on a card. The app already did the write; the tap tells the engine what happened (box 1 → box 7). */
export interface Tap {
  step: string;
  card: string;
  /** dismiss: closed without Save or Not-now (swiped away). Shown once this visit, never a decline (E3). */
  action: 'save' | 'decline' | 'dismiss' | 'connect' | 'pin' | 'choice';
  /** save / connect / pin: what the app saved, in words code can put in a receipt. */
  saved?: { what: string; when?: string };
  choice?: string;
}

// ---------------------------------------------------------------- the declaration (§2, §5)
export type CheckRule =
  | 'status_truthful' | 'actions_backed' | 'no_computed_number' | 'write_without_yes' | 'after_safety' | 'one_question' | 'pattern_from_data'   // the seven hard rules
  | 'pin_covers' | 'race_question_narrow' | 'name_from_data' | 'same_words_twice' | 'lead_in_names_step' | 'no_app_claims';

/** Universal: every reply, every flow (ruled 2026-10-15, Q4a: v4's five, plus one question per reply and no history pattern without a tool result). */
export const HARD_RULES: readonly CheckRule[] = ['status_truthful', 'actions_backed', 'no_computed_number', 'write_without_yes', 'after_safety', 'one_question', 'pattern_from_data'];

export interface StepDeclaration {
  id: string;
  shape: Shape;
  /** Prompt stem for the step's section (`step-plan`), or null for a scripted / shared step. */
  section: string | null;
  tools: ToolRef[];
  cards: string[];
  /** Arguments code binds per tool, removed from what the model may set (box 1). null = nothing known. */
  bound?: Record<string, (d: Snapshot) => Record<string, unknown> | null>;
  /** The tool pass one must call (prepareStep job 2). */
  forcedFirstTool?: string;
  checks: CheckRule[];
  reply: 'model' | 'scripted';
  /** scripted steps: the key in scripted.md. */
  scripted?: 'off_flow' | 'check_in' | 'feedback' | 'wrap';
  /** The code reader. 'done' means the data shows it; declined / skipped is state, not data. */
  status: (d: Snapshot) => 'open' | 'done';
  /** One short clause Route appends to scripted lines: "Want to keep going with {step}?" Xuan edits. */
  steer: string;
  stores?: string[];
  /** Declining this step also declines these (the week planner's "Not now" is the long workout's no). */
  onDecline?: { alsoDecline?: string[] };
  /** Fired by Save, once, when the status flips to done. */
  milestone?: Milestone;
  /** false: not one of the client's 0/N setup widget tiles (the week planner; ruled 2026-10-15, E1). */
  widget?: boolean;
}

export interface FlowDeclaration {
  id: FlowId;
  /** Fills Route's `starts:` from the situation, only when no flow is active (box 4). */
  starts: (situation: Situation | null, d: Snapshot) => boolean;
  /** The flow's lines for the block, fetched on entry and cached on the row (box 2). */
  lines: (d: Snapshot) => string[];
  allowsJump: boolean;
  maxPasses: number;
  order: string[];
  steps: Record<string, StepDeclaration>;
  /** The step that answers an `asks(app)` inside this flow (the shared Answer step). */
  answerStep: StepDeclaration;
}

// ---------------------------------------------------------------- the plan (box 4) and the loop (box 5)
export interface PlanStep {
  flow: FlowId;
  step: StepDeclaration;
  intents: Intent[];
  /** Bracketed notes code writes in front of the message: [opener], [declined: …], [then: …], [just done: …]. */
  notes: string[];
  /** The step may run a write tool: the athlete said yes, or asked for the write itself (hard rule 4). */
  writeAllowed: boolean;
}
export interface Plan { steps: PlanStep[]; pending: Intent[]; why: string[]; flowChanged: boolean }

export interface Line { role: 'athlete' | 'vana'; text: string; cards?: string[] }

// ---------------------------------------------------------------- the row (box 2 caches here; box 7 invalidates)
export interface Block { text: string; day: string; flow: FlowId | null }
export interface ConversationState {
  conversationId: string;
  userId: string;
  flow: FlowId | null;
  step: string | null;
  declinedThisVisit: string[];
  /** Declined this visit AND in an earlier one: never offered again (Q7a). Written to memory as declined_for_good. */
  declinedForGood: string[];
  /** Cards closed without Save or Not-now this visit, by step: shown once, the step stays open, not re-offered (E3). */
  shownThisVisit: string[];
  /** Set by declines(all_connections), declines(visit) or feedback(flow): no steer, no card, for the rest of the visit. */
  offersEnded: boolean;
  /** Off-flow asks this visit; the second fires the scripted check-in, once (Q1a: the count fires the question, never the stop). */
  offFlowAsks: number;
  checkInAsked: boolean;
  /** Kept when the athlete types instead of tapping, named once per reply via [then: …], dropped only on a decline (Q3c). */
  pending: Intent[];
  pendingWords: string | null;
  /** The last safety label. Eating-disorder signs or distress also set flowEnded; a medical hit clears on the next turn (Q6). */
  safetyHit: string | null;
  /** Hard rule 5: the flow ended for this conversation; only the sensitive agent speaks from here. */
  flowEnded: boolean;
  history: Line[];
  block: Block | null;
  blockDirty: boolean;
  celebrated: Milestone[];
  cardOnScreen: { step: string; card: string; id: string } | null;
  turn: number;
  /** Demand captured for the team, with the athlete's words (box 7). */
  demand: { turn: number; words: string; target: string }[];
}

// ---------------------------------------------------------------- the turn
export interface TurnInput { conversationId: string; userId: string; message?: string; tap?: Tap; situation?: Situation | null }

export interface ModelCallLog { role: 'read' | 'step' | 'guard'; step?: string; pass?: number; inputTokens: number; outputTokens: number; cachedTokens: number }

export interface TurnReply { receipts: string[]; card: Card | null; text: string; reactions: string[]; confetti: Milestone[] }

export interface TurnResult {
  reply: TurnReply;
  read: ReadResult | null;
  plan: Plan | null;
  counters: Counters;
  calls: ModelCallLog[];
  state: ConversationState;
  /** D9: what the silent paths did, one line each. The caller writes it where PROD can read it. */
  trail: string[];
}

/** §12: the production counters each box emits, per turn. The caller writes them to Langfuse. */
export interface Counters {
  check_catches: Partial<Record<CheckRule, number>>;
  check_retry_fixed: number;
  check_safe_line: number;
  /** Lines of a card drawn in words (markdown table, "(card: …)" note) removed before the check. */
  drawn_card_stripped: number;
  route_reroute: number;
  intents_pending: number;
  bound_arg_disagreement: number;
  pass_cap_hit: number;
  forced_landing: number;
  tokens_per_pass: number[];
  read_label: string[];
  model_calls: number;
  steps_run: number;
  cards_shown: number;
  receipts: number;
}
