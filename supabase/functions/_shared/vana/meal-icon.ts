/** Meal → icon. Deterministic, no model. Shared by the seed/backfill script, the server (persisted on meal_library.icon /
 *  plan_meals.icon) and the UI (fallback when a row predates the column). Keys mirror the Flutter app's KyleFoodType
 *  where one exists (rice → bowl, protein → chicken/meat, fruit, snack, drink, sandwich → bread, pasta) so the app can
 *  render the same column with Font Awesome. */
export type MealIconKey =
  | "bowl" | "oats" | "chicken" | "meat" | "fish" | "egg" | "salad" | "bread" | "wrap" | "pasta" | "soup" | "pizza"
  | "drink" | "fruit" | "nuts" | "yogurt" | "potato" | "beans" | "tofu" | "baked" | "snack" | "sweet" | "utensils";

export const MEAL_ICON_KEYS: MealIconKey[] = ["bowl", "oats", "chicken", "meat", "fish", "egg", "salad", "bread", "wrap", "pasta", "soup", "pizza", "drink", "fruit", "nuts", "yogurt", "potato", "beans", "tofu", "baked", "snack", "sweet", "utensils"];

export const mealIconLabel: Record<MealIconKey, string> = {
  bowl: "Grain bowl", oats: "Oats", chicken: "Poultry", meat: "Meat", fish: "Fish & seafood", egg: "Eggs", salad: "Salad", bread: "Bread & toast", wrap: "Wrap", pasta: "Pasta & noodles", soup: "Soup & stew", pizza: "Pizza",
  drink: "Drink", fruit: "Fruit", nuts: "Nuts & seeds", yogurt: "Dairy", potato: "Potato", beans: "Beans & lentils", tofu: "Tofu & tempeh", baked: "Baked", snack: "Snack", sweet: "Sweet", utensils: "Meal",
};

type Rule = [MealIconKey, RegExp];
const w = (s: string) => new RegExp(`\\b(?:${s})`, "i");

// Tier 0 — headline dishes that beat everything else in the name ("Chicken noodle soup" → soup, "Jacket potato with beans" → potato).
const HEADLINE: Rule[] = [
  ["potato", w("jacket potato|baked potato|loaded potato|stuffed (?:sweet )?potato|potato skins|hash\\b")],
  ["pizza", w("pizza")],
  ["drink", w("smoothie|shake|latte|juice|coffee|espresso|chai\\b|tea\\b|hot chocolate|cocoa|chocolate milk|glass of milk|kefir|drink|lassi|electrolyte|kombucha")],
  ["soup", w("soup|stew|chil+i\\b|curry|dal\\b|dahl|daal|congee|okayu|ramen|pho\\b|broth|goulash|tagine|jambalaya|gumbo")],
];
// Tier 1 — the dish form. Earliest match in the text wins ("Greek yogurt with granola" → yogurt; "Granola with yogurt" → oats).
const DISH: Rule[] = [
  ["pasta", w("pasta|spaghetti|penne|fusilli|rigatoni|linguine|fettuccine|tagliatelle|macaroni|mac (?:and|&|n)|lasagn|gnocchi|noodle|udon|soba|ravioli|tortellini|orzo|carbonara|bolognese|ragu")],
  ["wrap", w("wrap|burrito|taco|quesadilla|tortilla|fajita|shawarma|gyro|kebab|souvlaki|pita pocket|lettuce cups?")],
  ["bread", w("sandwich|toast|toastie|bagel|bread|crispbread|knekkebr|panini|sub\\b|hoagie|english muffin|pita\\b|naan|roti\\b|chapati|crumpet|cracker|rice cake|corn cake|baguette|ciabatta|sourdough|bun\\b|roll\\b(?! oats| up)|arepa|injera")],
  ["salad", w("salad|slaw|leafy greens|mixed greens|caprese|tabbouleh|poke")],
  ["oats", w("oat|porridge|oatmeal|muesli|granola|cereal|overnight|bircher|grits|cream of wheat|weetabix")],
  ["yogurt", w("yog(?:h)?urt|skyr|cottage cheese|quark|kefir|parfait")],
  ["snack", w("pretzel|popcorn|crisps|tortilla chips|energy bar|protein bar|granola bar|gel\\b|gels|chews")],
  ["baked", w("pancake|waffle|muffin|scone|cake\\b(?!s? with)|crepe|crêpe|loaf|banana bread|brownie|flapjack|biscuit|mandazi|dosa|idli|bao\\b|dumpling|pierogi|empanada|samosa|frittata|quiche")],
];
// Tier 2 — the protein.
const PROTEIN: Rule[] = [
  ["chicken", w("chicken|turkey|poultry|drumstick|duck\\b")],
  ["meat", w("beef|steak|pork|lamb|bacon|sausage|ham\\b|mince|burger|meatball|bison|venison|brisket|chorizo|prosciutto|salami|kielbasa|carnitas|pulled|ribs|jerky|biltong|pepperoni")],
  ["fish", w("salmon|tuna|fish|cod\\b|shrimp|prawn|sardine|herring|mackerel|trout|seafood|sushi|anchov|halibut|tilapia|scallop|mussel|clam|crab|lobster|calamari|squid|octopus|poke")],
  ["egg", w("egg|omelet|omelette|scramble|shakshuka|huevos")],
  ["tofu", w("tofu|tempeh|seitan|edamame|paneer")],
  ["beans", w("bean|lentil|chickpea|hummus|falafel|dal\\b|dahl|refried|black-eyed")],
];
// Tier 3 — the starch base.
const STARCH: Rule[] = [
  ["potato", w("potato|fries|tater|hash brown|yam\\b")],
  ["bowl", w("rice|quinoa|couscous|grain|bowl|farro|barley|bulgur|polenta|risotto|freekeh|millet|sorghum|teff|buckwheat|pilaf|biryani|paella|poha|upma|amaranth|ugali|fufu|plantain")],
];
// Tier 4 — fruit, nuts, dairy, snacks.
const OTHER: Rule[] = [
  ["snack", w("energy bar|protein bar|granola bar|gel\\b|gels|chews|clif|bar\\b|stroopwafel|popcorn|pretzel|crisps|chips|olives")],
  ["fruit", w("banana|apple|berr|mango|date|fruit|orange|grape|melon|kiwi|pineapple|peach|pear\\b|plum|cherr|raisin|fig\\b|apricot|papaya|pomegranate|citrus|clementine|avocado|coconut")],
  ["nuts", w("nut\\b|nuts|almond|walnut|cashew|peanut|pistachio|pecan|hazelnut|macadamia|seed|trail mix|tahini")],
  ["yogurt", w("cheese|cheddar|feta|parmesan|mozzarella|brie|halloumi|milk|dairy|whey|casein|protein powder|butter")],
  ["sweet", w("cookie|chocolate|candy|sweet|honey|jam\\b|jelly|gummy|gummies|marshmallow|cake|pastry|croissant|donut|doughnut|ice cream|sorbet|pudding|maple|sugar")],
  ["salad", w("veg|broccoli|spinach|kale|carrot|pepper|tomato|cucumber|zucchini|courgette|asparagus|green beans|lettuce|greens|cabbage|mushroom|squash|beet|celery|onion")],
];

function earliest(text: string, rules: Rule[]): MealIconKey | null {
  let best: { key: MealIconKey; at: number } | null = null;
  for (const [key, re] of rules) {
    const m = re.exec(text);
    if (m && (!best || m.index < best.at)) best = { key, at: m.index };
  }
  return best?.key ?? null;
}
const tiers = [HEADLINE, DISH, PROTEIN, STARCH, OTHER];

/** Classify by name first (tiers 1→4), then by ingredient list (same tiers), then a pattern hint, else utensils. */
export function mealIconFor(input: { name: string; ingredients?: string | null; pattern?: string | null }): MealIconKey {
  const name = (input.name ?? "").toLowerCase();
  for (const t of tiers) { const k = earliest(name, t); if (k) return k; }
  const ing = (input.ingredients ?? "").toLowerCase();
  if (ing) for (const t of tiers) { const k = earliest(ing, t); if (k) return k; }
  const p = (input.pattern ?? "").toLowerCase();
  if (/protein/.test(p)) return "chicken";
  if (/starch|grain/.test(p)) return "bowl";
  if (/fruit/.test(p)) return "fruit";
  if (/veg|green/.test(p)) return "salad";
  return "utensils";
}

/** Accepts a stored key (validated) or falls back to classification. */
export function resolveMealIcon(stored: string | null | undefined, input: { name: string; ingredients?: string | null; pattern?: string | null }): MealIconKey {
  if (stored && (MEAL_ICON_KEYS as string[]).includes(stored)) return stored as MealIconKey;
  return mealIconFor(input);
}
