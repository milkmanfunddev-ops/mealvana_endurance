// Ingredient-name normalization for the meal image tile bank.
// Turns free-text ingredient names from meal_library.ingredients_json into a
// stable slug so many phrasings collapse onto one photo.

// Words describing preparation / provenance / diet that never change what the
// ingredient LOOKS like, so they must not fork the slug.
const QUALIFIERS = [
  // Compounds first: a bare 'whole' would otherwise match inside 'whole-grain'
  // (hyphens are word boundaries) and leave "-grain crackers".
  'whole-grain','whole grain','whole-wheat','whole wheat','wholegrain','wholewheat',
  'wholemeal','multigrain','multi-grain','stone-ground','sprouted',
  'gluten-free','gluten free','lactose-free','lactose free','dairy-free','dairy free',
  'low-fodmap','low fodmap','fat-free','fat free','low-fat','low fat','reduced-fat',
  'reduced fat','non-fat','nonfat','no-added-sugar','unsweetened','sweetened','plain',
  'fresh','frozen','canned','tinned','dried','raw','cooked','leftover','ripe','organic',
  'free-range','free range','grass-fed','grass fed','wild-caught','wild caught',
  'skinless','boneless','lean','extra-lean','firm','extra-firm','silken','smooth',
  'crunchy','natural','light','full-fat','full fat','whole','skim','semi-skimmed',
  'large','small','medium','baby','mini','thick','thin','hot','cold','warm','instant',
  'quick','old-fashioned','steel-cut','rolled','pre-cooked','ready-to-eat','store-bought',
  'homemade','optional','good-quality','quality','best',
];

// Preparation participles trailing the head noun.
const PREP = [
  'chopped','diced','sliced','minced','grated','shredded','crumbled','mashed','cubed',
  'halved','quartered','torn','trimmed','peeled','pitted','drained','rinsed','beaten',
  'whisked','melted','softened','toasted','roasted','grilled','steamed','boiled','baked',
  'scrambled','poached','fried','sauteed','sautéed','warmed','chilled','thawed','packed',
  'divided','to taste','to serve','for serving','for garnish','garnish','plus more',
];

// Things that are seasoning/condiment/liquid — real ingredients, but they make
// terrible tiles, so they are ranked last and only used if nothing else exists.
const LOW_VALUE = new Set([
  'salt','sea salt','kosher salt','pepper','black pepper','white pepper','water',
  'ice','ice cubes','oil','olive oil','cooking spray','nonstick spray','vegetable oil',
  'sugar','brown sugar','flour','baking powder','baking soda','vanilla','vanilla extract',
  'cinnamon','nutmeg','paprika','cumin','coriander','turmeric','oregano','thyme','basil',
  'parsley','cilantro','dill','mint','rosemary','sage','bay leaf','chilli flakes',
  'chili flakes','red pepper flakes','garlic','garlic clove','ginger','onion powder',
  'garlic powder','spices','seasoning','herbs','stock','broth','stock cube','lemon juice',
  'lime juice','lemon','lime','vinegar','soy sauce','tamari','hot sauce','sriracha',
  'mustard','ketchup','mayonnaise','honey','maple syrup','syrup','jam','zest','lemon zest',
  'orange zest','cornstarch','cornflour','yeast','food colouring','sprinkles',
]);

// Canonical aliases: many spellings -> one bank entry.
const ALIASES = new Map(Object.entries({
  'yoghurt':'yogurt','greek yoghurt':'greek yogurt','natural yoghurt':'yogurt',
  'oats':'rolled oats','oatmeal':'rolled oats','porridge oats':'rolled oats',
  'jumbo oats':'rolled oats','oat':'rolled oats',
  'chickpeas':'chickpea','garbanzo beans':'chickpea','garbanzo':'chickpea',
  'aubergine':'eggplant','courgette':'zucchini','capsicum':'bell pepper',
  'coriander leaves':'cilantro','spring onion':'green onion','scallion':'green onion',
  'scallions':'green onion','rocket':'arugula','beetroot':'beet',
  'mince':'ground beef','beef mince':'ground beef','minced beef':'ground beef',
  'chicken breasts':'chicken breast','chicken thighs':'chicken thigh',
  'peanut butter':'peanut butter','pb':'peanut butter',
  'wholemeal bread':'whole wheat bread','wholegrain bread':'whole wheat bread',
  'brown bread':'whole wheat bread','toast':'bread',
  'sweet potatoes':'sweet potato','potatoes':'potato','tomatoes':'tomato',
  'bananas':'banana','apples':'apple','eggs':'egg','egg whites':'egg white',
  'berries':'mixed berries','blueberries':'blueberry','strawberries':'strawberry',
  'raspberries':'raspberry','blackberries':'blackberry','grapes':'grape',
  'walnuts':'walnut','almonds':'almond','cashews':'cashew','pecans':'pecan',
  'dates':'date','raisins':'raisin','lentils':'lentil','black beans':'black bean',
  'kidney beans':'kidney bean','pinto beans':'pinto bean','white beans':'white bean',
  'cannellini beans':'cannellini bean','edamame beans':'edamame',
  'noodles':'noodle','carrots':'carrot','mushrooms':'mushroom','olives':'olive',
  'cucumbers':'cucumber','peppers':'bell pepper','red pepper':'bell pepper',
  'onions':'onion','red onion':'onion','peas':'pea','green beans':'green bean',
  'rice cakes':'rice cake','tortillas':'tortilla','crackers':'cracker',
  'protein powder':'protein powder','whey':'protein powder',
  'cottage cheese':'cottage cheese','feta cheese':'feta','cheddar cheese':'cheddar',
  'parmesan cheese':'parmesan','mozzarella cheese':'mozzarella',
  'milk':'milk','soy milk':'soy milk','almond milk':'almond milk','oat milk':'oat milk',
}));

export function normalizeName(raw) {
  if (!raw) return null;
  let s = String(raw).toLowerCase();

  s = s.replace(/\([^)]*\)/g, ' ');          // drop parentheticals
  s = s.split(',')[0];                        // "walnuts, chopped" -> "walnuts"
  s = s.split(/\bor\b/)[0];                   // "tofu or tempeh" -> "tofu"
  s = s.replace(/[""'`]/g, ' ');
  s = s.replace(/\d+([./]\d+)?\s*(g|kg|ml|l|oz|lb|cup|cups|tbsp|tsp|slice|slices|scoop|scoops|handful|piece|pieces|can|cans|tin|tins)\b/g, ' ');
  s = s.replace(/[¼-¾⅐-⅞]/g, ' '); // vulgar fractions
  s = s.replace(/\d+/g, ' ');

  for (const p of PREP)       s = s.replace(new RegExp(`\\b${p}\\b`, 'g'), ' ');
  for (const q of QUALIFIERS) s = s.replace(new RegExp(`\\b${q}\\b`, 'g'), ' ');

  s = s.replace(/[^a-z\s-]/g, ' ').replace(/\s+/g, ' ').trim();
  s = s.replace(/^(of|the|a|an|and|with|plus)\s+/g, '').trim();
  // A stripped qualifier can leave a dangling hyphen ("-grain crackers").
  s = s.replace(/(^|\s)-+/g, '$1').replace(/-+(\s|$)/g, '$1').replace(/\s+/g, ' ').trim();
  if (!s || s.length < 2) return null;

  if (ALIASES.has(s)) s = ALIASES.get(s);
  // light singularization only when it doesn't mangle the word
  if (!ALIASES.has(s) && /[^s]s$/.test(s) && !/(ss|us|is)$/.test(s)) {
    const sing = s.replace(/s$/, '');
    if (ALIASES.has(sing)) s = ALIASES.get(sing);
  }
  return s;
}

export const toSlug = (name) => name.replace(/\s+/g, '-').replace(/-+/g, '-');
export const isLowValue = (name) => LOW_VALUE.has(name);

// Roles that make the best tiles, best first. Used to order a meal's tiles.
const ROLE_RANK = { protein: 0, starch: 1, carb: 1, veg: 2, vegetable: 2, fruit: 3, dairy: 4, fat: 5, other: 6 };
export const roleRank = (role) => ROLE_RANK[String(role || '').toLowerCase()] ?? 6;
