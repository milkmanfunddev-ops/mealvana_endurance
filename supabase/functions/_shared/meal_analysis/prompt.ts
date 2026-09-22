/**
 * The meal-logging prompts (ai-cost ticket 08, mp-473).
 *
 * Both meal-analysis functions send the same shape:
 *
 *   1. a `system` message holding the fixed instructions and nothing else,
 *      carrying a one-hour cache marker;
 *   2. a `user` message holding what the athlete gave us — their text, or
 *      their photo and the words they typed with it — and nothing else.
 *
 * Before this the athlete's description was interpolated into the middle of
 * the instructions, so no two calls shared a prefix and there was nothing a
 * cache could hold.
 *
 * A caveat worth knowing before reading a cache-read figure: Anthropic only
 * caches a prefix past a minimum length (about 1,024 tokens on Sonnet), and
 * these instruction blocks sit under that. The marker costs nothing and the
 * shape is now right, so the day the instructions grow — or the day the
 * minimum drops — the cache starts working with no further change. The saving
 * that is real today is the photo downscale, on the client.
 */

/**
 * The cache marker: a one-hour lifetime rather than the default five minutes,
 * because meal logging arrives in ones and twos through the day, not in a
 * conversation's bursts. Asserted by both functions' tests.
 */
export const MEAL_ANALYSIS_CACHE_OPTIONS = {
  anthropic: { cacheControl: { type: 'ephemeral' as const, ttl: '1h' as const } },
};

/** How items are grouped, and what each one must carry. Shared by both prompts. */
const SHARED_RULES = `- Group food into items the way a person logging their own meal would think
  about it — one item per DISH or line, not one item per raw ingredient.
  For example: "spaghetti and meatballs" is ONE item (its sauce, pasta, and
  meatballs are summed into one entry), while a side of "broccoli" is a
  SEPARATE item because it's a distinct component of the plate. Similarly,
  "a turkey sandwich with lettuce and mayo" is ONE item, not three. Only
  split into multiple items when the foods are genuinely separate parts of
  the meal (a side dish, a drink, a dessert) — never split a single dish's
  own ingredients apart.
- Each item's macros must be the SUM across everything that makes up that
  dish (e.g. the meatballs' and sauce's calories/carbs/protein/fat/sodium
  are combined into the "spaghetti and meatballs" item, not reported
  separately).
- Provide per-item macros: calories (kcal), carbohydrates (g), protein (g), fat (g), and sodium (mg). These must be non-null for every item.
- Do NOT compute totals. Leave the totals out; they are added up from your items.`;

/**
 * `describe-meal`'s fixed instructions. Never contains the athlete's words —
 * those are the whole of the user message.
 */
export const DESCRIBE_MEAL_INSTRUCTIONS =
  `You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

The athlete's message is a description of a meal they ate. Return a structured
meal breakdown for it.

INSTRUCTIONS:
${SHARED_RULES}
- If a quantity is mentioned (e.g. "two eggs", "large OJ"), use it; otherwise assume a single, realistic serving for an adult endurance athlete.
- Do NOT underestimate portions — athletes eat meaningfully sized meals.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods described.
- Set confidence to "high" if the description is precise (weights, brand names, counts); "medium" if typical portions can be inferred; "low" if too vague to estimate reliably.
- If the message does not describe food at all (e.g. a movie title, a random
  sentence), set "not_food" to true, return an empty items array, and invent
  nothing. Never return a placeholder item with guessed macros.

Return your answer as structured JSON matching the requested schema.`;

/**
 * `analyze-meal-photo`'s fixed instructions. The photo, and any words typed
 * with it, are the user message.
 */
export const MEAL_PHOTO_INSTRUCTIONS =
  `You are a sports nutrition assistant helping an endurance athlete log their meals accurately.

The athlete's message is a photo of a meal they ate, sometimes with a few
words of their own. Return a structured meal breakdown for it.

When words accompany the photo, treat the photo and the words as ONE meal. Use
the words to identify items that are unclear or not visible, and to refine
portion sizes — when the words and the photo disagree, trust the words for
what the food is and the photo for how much of it there is.

INSTRUCTIONS:
${SHARED_RULES}
- Estimate realistic portions for an adult endurance athlete — do NOT underestimate. If there is a full plate of pasta, estimate the full plate, not a small serving.
- Suggest the meal slot (breakfast, lunch, dinner, snack) based on the foods visible.
- Set confidence to "low" if the image is blurry, partially visible, or ambiguous; "medium" if items are visible but portions are uncertain; "high" if clear and well-portioned.
- If the image does not contain food at all (e.g. a landscape, a person's
  face, a document), set "not_food" to true, return an empty items array, and
  invent nothing. Never return a placeholder item with guessed macros.

Return your answer as structured JSON matching the requested schema.`;

// The AI SDK's message types are not imported here: this module is pure data and
// the functions pass its result straight to `generateObject`.
type TextPart = { type: 'text'; text: string };
type ImagePart = { type: 'image'; image: string; mediaType: string };
/** The cached, athlete-free prefix. */
export type InstructionMessage = {
  role: 'system';
  content: string;
  providerOptions: typeof MEAL_ANALYSIS_CACHE_OPTIONS;
};
/** What the athlete gave us, and nothing else. */
export type AthleteMessage = {
  role: 'user';
  content: Array<TextPart | ImagePart>;
};
/**
 * What a meal-analysis call sends: the cached instruction prefix in the SDK's
 * `system` slot, and one user message holding the athlete's own input.
 *
 * The instructions go in `system` rather than as a first entry in `messages`
 * because the SDK warns about the latter (prompt injection: an athlete's words
 * must never be able to look like instructions), and because the provider puts
 * a system message first by construction — which is exactly where the cache
 * breakpoint has to sit.
 */
export type MealAnalysisPrompt = {
  system: InstructionMessage;
  messages: [AthleteMessage];
};

function instructions(content: string): InstructionMessage {
  return { role: 'system', content, providerOptions: MEAL_ANALYSIS_CACHE_OPTIONS };
}

/** A described meal: fixed instructions, then the athlete's words and nothing else. */
export function describeMealPrompt(description: string): MealAnalysisPrompt {
  return {
    system: instructions(DESCRIBE_MEAL_INSTRUCTIONS),
    messages: [{ role: 'user', content: [{ type: 'text', text: description.trim() }] }],
  };
}

/** A meal photo: fixed instructions, then the photo and any words typed with it. */
export function mealPhotoPrompt(
  { base64Image, mediaType, description }: {
    base64Image: string;
    mediaType: string;
    description?: string;
  },
): MealAnalysisPrompt {
  const words = description?.trim() ?? '';
  return {
    system: instructions(MEAL_PHOTO_INSTRUCTIONS),
    messages: [{
      role: 'user',
      content: [
        { type: 'image', image: base64Image, mediaType },
        ...(words ? [{ type: 'text' as const, text: words }] : []),
      ],
    }],
  };
}
