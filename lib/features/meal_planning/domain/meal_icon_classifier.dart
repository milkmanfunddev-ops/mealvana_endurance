import 'meal_icon.dart';

/// Meal → icon. Deterministic, no model. Port of the prototype's
/// `lib/vana/meal-icon.ts` — keep the keyword lists byte-for-byte in sync
/// with it (the same code seeds `meal_library.icon` server-side, so a drift
/// here shows up as a different glyph for the same meal on web vs app).
///
/// Classification order: name (tiers 0→4), then the ingredient line (same
/// tiers), then a pattern hint, else [MealIcon.utensils]. Within a tier the
/// **earliest** match in the text wins ("Greek yogurt with granola" → yogurt;
/// "Granola with yogurt" → oats).
class MealIconClassifier {
  const MealIconClassifier._();

  /// Stored key wins if it is a known [MealIcon]; otherwise classify.
  static MealIcon resolve(
    String? stored, {
    required String name,
    String? ingredients,
    String? pattern,
  }) =>
      MealIcon.fromWire(stored) ??
      classify(name: name, ingredients: ingredients, pattern: pattern);

  static MealIcon classify({
    required String name,
    String? ingredients,
    String? pattern,
  }) {
    final n = name.toLowerCase();
    for (final tier in _tiers) {
      final k = _earliest(n, tier);
      if (k != null) return k;
    }
    final ing = (ingredients ?? '').toLowerCase();
    if (ing.isNotEmpty) {
      for (final tier in _tiers) {
        final k = _earliest(ing, tier);
        if (k != null) return k;
      }
    }
    final p = (pattern ?? '').toLowerCase();
    if (p.contains('protein')) return MealIcon.chicken;
    if (p.contains('starch') || p.contains('grain')) return MealIcon.bowl;
    if (p.contains('fruit')) return MealIcon.fruit;
    if (p.contains('veg') || p.contains('green')) return MealIcon.salad;
    return MealIcon.utensils;
  }

  static MealIcon? _earliest(String text, List<_Rule> rules) {
    MealIcon? best;
    var bestAt = -1;
    for (final rule in rules) {
      final m = rule.re.firstMatch(text);
      if (m != null && (best == null || m.start < bestAt)) {
        best = rule.icon;
        bestAt = m.start;
      }
    }
    return best;
  }

  static _Rule _w(MealIcon icon, String s) =>
      _Rule(icon, RegExp('\\b(?:$s)', caseSensitive: false));

  // Tier 0 — headline dishes that beat everything else in the name
  // ("Chicken noodle soup" → soup, "Jacket potato with beans" → potato).
  static final List<_Rule> _headline = [
    _w(
      MealIcon.potato,
      r'jacket potato|baked potato|loaded potato|stuffed (?:sweet )?potato|potato skins|hash\b',
    ),
    _w(MealIcon.pizza, r'pizza'),
    _w(
      MealIcon.drink,
      r'smoothie|shake|latte|juice|coffee|espresso|chai\b|tea\b|hot chocolate|cocoa|chocolate milk|glass of milk|kefir|drink|lassi|electrolyte|kombucha',
    ),
    _w(
      MealIcon.soup,
      r'soup|stew|chil+i\b|curry|dal\b|dahl|daal|congee|okayu|ramen|pho\b|broth|goulash|tagine|jambalaya|gumbo',
    ),
  ];

  // Tier 1 — the dish form.
  static final List<_Rule> _dish = [
    _w(
      MealIcon.pasta,
      r'pasta|spaghetti|penne|fusilli|rigatoni|linguine|fettuccine|tagliatelle|macaroni|mac (?:and|&|n)|lasagn|gnocchi|noodle|udon|soba|ravioli|tortellini|orzo|carbonara|bolognese|ragu',
    ),
    _w(
      MealIcon.wrap,
      r'wrap|burrito|taco|quesadilla|tortilla|fajita|shawarma|gyro|kebab|souvlaki|pita pocket|lettuce cups?',
    ),
    _w(
      MealIcon.bread,
      r'sandwich|toast|toastie|bagel|bread|crispbread|knekkebr|panini|sub\b|hoagie|english muffin|pita\b|naan|roti\b|chapati|crumpet|cracker|rice cake|corn cake|baguette|ciabatta|sourdough|bun\b|roll\b(?! oats| up)|arepa|injera',
    ),
    _w(
      MealIcon.salad,
      r'salad|slaw|leafy greens|mixed greens|caprese|tabbouleh|poke',
    ),
    _w(
      MealIcon.oats,
      r'oat|porridge|oatmeal|muesli|granola|cereal|overnight|bircher|grits|cream of wheat|weetabix',
    ),
    _w(
      MealIcon.yogurt,
      r'yog(?:h)?urt|skyr|cottage cheese|quark|kefir|parfait',
    ),
    _w(
      MealIcon.snack,
      r'pretzel|popcorn|crisps|tortilla chips|energy bar|protein bar|granola bar|gel\b|gels|chews',
    ),
    _w(
      MealIcon.baked,
      r'pancake|waffle|muffin|scone|cake\b(?!s? with)|crepe|crêpe|loaf|banana bread|brownie|flapjack|biscuit|mandazi|dosa|idli|bao\b|dumpling|pierogi|empanada|samosa|frittata|quiche',
    ),
  ];

  // Tier 2 — the protein.
  static final List<_Rule> _protein = [
    _w(MealIcon.chicken, r'chicken|turkey|poultry|drumstick|duck\b'),
    _w(
      MealIcon.meat,
      r'beef|steak|pork|lamb|bacon|sausage|ham\b|mince|burger|meatball|bison|venison|brisket|chorizo|prosciutto|salami|kielbasa|carnitas|pulled|ribs|jerky|biltong|pepperoni',
    ),
    _w(
      MealIcon.fish,
      r'salmon|tuna|fish|cod\b|shrimp|prawn|sardine|herring|mackerel|trout|seafood|sushi|anchov|halibut|tilapia|scallop|mussel|clam|crab|lobster|calamari|squid|octopus|poke',
    ),
    _w(MealIcon.egg, r'egg|omelet|omelette|scramble|shakshuka|huevos'),
    _w(MealIcon.tofu, r'tofu|tempeh|seitan|edamame|paneer'),
    _w(
      MealIcon.beans,
      r'bean|lentil|chickpea|hummus|falafel|dal\b|dahl|refried|black-eyed',
    ),
  ];

  // Tier 3 — the starch base.
  static final List<_Rule> _starch = [
    _w(MealIcon.potato, r'potato|fries|tater|hash brown|yam\b'),
    _w(
      MealIcon.bowl,
      r'rice|quinoa|couscous|grain|bowl|farro|barley|bulgur|polenta|risotto|freekeh|millet|sorghum|teff|buckwheat|pilaf|biryani|paella|poha|upma|amaranth|ugali|fufu|plantain',
    ),
  ];

  // Tier 4 — fruit, nuts, dairy, snacks.
  static final List<_Rule> _other = [
    _w(
      MealIcon.snack,
      r'energy bar|protein bar|granola bar|gel\b|gels|chews|clif|bar\b|stroopwafel|popcorn|pretzel|crisps|chips|olives',
    ),
    _w(
      MealIcon.fruit,
      r'banana|apple|berr|mango|date|fruit|orange|grape|melon|kiwi|pineapple|peach|pear\b|plum|cherr|raisin|fig\b|apricot|papaya|pomegranate|citrus|clementine|avocado|coconut',
    ),
    _w(
      MealIcon.nuts,
      r'nut\b|nuts|almond|walnut|cashew|peanut|pistachio|pecan|hazelnut|macadamia|seed|trail mix|tahini',
    ),
    _w(
      MealIcon.yogurt,
      r'cheese|cheddar|feta|parmesan|mozzarella|brie|halloumi|milk|dairy|whey|casein|protein powder|butter',
    ),
    _w(
      MealIcon.sweet,
      r'cookie|chocolate|candy|sweet|honey|jam\b|jelly|gummy|gummies|marshmallow|cake|pastry|croissant|donut|doughnut|ice cream|sorbet|pudding|maple|sugar',
    ),
    _w(
      MealIcon.salad,
      r'veg|broccoli|spinach|kale|carrot|pepper|tomato|cucumber|zucchini|courgette|asparagus|green beans|lettuce|greens|cabbage|mushroom|squash|beet|celery|onion',
    ),
  ];

  static final List<List<_Rule>> _tiers = [
    _headline,
    _dish,
    _protein,
    _starch,
    _other,
  ];
}

class _Rule {
  const _Rule(this.icon, this.re);

  final MealIcon icon;
  final RegExp re;
}
