// Formula Kit V3 — Editable formula primitives.
// Food catalog + per-base-unit macros + parser + edit-state UI components.

// ---------- Food catalog ----------
// category: "solid" (orange utensils) | "gel" (teal droplet) | "fluid" (teal bottle)
//         | "mix"   (teal beaker)    | "pill" (teal capsule)
// macros are per ONE base unit. Multiply by qty for live totals.
// unit: optional unit string (e.g. "tbsp", "cup", "slice", "oz"). null = bare count.
// step: smallest qty increment. namePlural / unitPlural fall back to <name>s / <unit>s.

const FOOD_CATALOG = {
  // ---- SOLIDS ----
  bagel:         { name: "Bagel",          namePlural: "Bagels",         unit: null,    step: 0.5,  category: "solid", macros: { c: 48, p: 10, f: 1, s: 430, fl: 0 } },
  peanut_butter: { name: "Peanut Butter",                                unit: "tbsp",  step: 0.5,  category: "solid", macros: { c: 4,  p: 4,  f: 8, s: 75,  fl: 0 } },
  jam:           { name: "Jam",                                          unit: "tbsp",  step: 0.5,  category: "solid", macros: { c: 13, p: 0,  f: 0, s: 6,   fl: 0 } },
  cereal:        { name: "Cereal",                                       unit: "cup",   step: 0.25, category: "solid", macros: { c: 24, p: 2,  f: 1, s: 200, fl: 0 } },
  oatmeal:       { name: "Oatmeal",                                      unit: "cup",   step: 0.25, category: "solid", macros: { c: 27, p: 3,  f: 1, s: 0,   fl: 0 } },
  raisins:       { name: "Raisins",                                      unit: "tbsp",  step: 0.5,  category: "solid", macros: { c: 8,  p: 0,  f: 0, s: 1,   fl: 0 } },
  honey:         { name: "Honey",                                        unit: "tbsp",  step: 0.5,  category: "solid", macros: { c: 17, p: 0,  f: 0, s: 1,   fl: 0 } },
  banana:        { name: "Banana",         namePlural: "Bananas",        unit: null,    step: 0.5,  category: "solid", macros: { c: 25, p: 1,  f: 0, s: 1,   fl: 0 } },
  date:          { name: "Medjool Date",   namePlural: "Medjool Dates",  unit: null,    step: 1,    category: "solid", macros: { c: 15, p: 0,  f: 0, s: 0,   fl: 0 } },
  mixed_berries: { name: "Mixed Berries",                                unit: "cup",   step: 0.25, category: "solid", macros: { c: 16, p: 1,  f: 0, s: 1,   fl: 0 } },
  berries:       { name: "Berries",                                      unit: "cup",   step: 0.25, category: "solid", macros: { c: 16, p: 1,  f: 0, s: 1,   fl: 0 } },
  potato:        { name: "Baked Potato",   namePlural: "Baked Potatoes", unit: null,    step: 0.5,  category: "solid", macros: { c: 37, p: 4,  f: 0, s: 0,   fl: 0 } },
  rice_cake:     { name: "Rice Cake",      namePlural: "Rice Cakes",     unit: null,    step: 1,    category: "solid", macros: { c: 7,  p: 1,  f: 0, s: 29,  fl: 0 } },
  white_toast:   { name: "White Toast",                                  unit: "slice", unitPlural: "slices", step: 1, category: "solid", macros: { c: 14, p: 2, f: 1, s: 120, fl: 0 } },
  toast:         { name: "Toast",                                        unit: "slice", unitPlural: "slices", step: 1, category: "solid", macros: { c: 14, p: 2, f: 1, s: 120, fl: 0 } },
  pancake:       { name: "Pancake",        namePlural: "Pancakes",       unit: null,    step: 1,    category: "solid", macros: { c: 16, p: 2,  f: 2, s: 150, fl: 0 } },
  syrup:         { name: "Syrup",                                        unit: "tbsp",  step: 0.5,  category: "solid", macros: { c: 13, p: 0,  f: 0, s: 2,   fl: 0 } },
  greek_yogurt:  { name: "Greek Yogurt",                                 unit: "cup",   step: 0.25, category: "solid", macros: { c: 9,  p: 22, f: 0, s: 70,  fl: 0 } },
  granola:       { name: "Granola",                                      unit: "cup",   step: 0.25, category: "solid", macros: { c: 50, p: 8,  f: 10,s: 70,  fl: 0 } },
  trail_mix:     { name: "Trail Mix",                                    unit: "cup",   step: 0.25, category: "solid", macros: { c: 88, p: 24, f: 56,s: 380, fl: 0 } },
  applesauce:    { name: "Applesauce Pouch", namePlural: "Applesauce Pouches", unit: null, step: 1, category: "solid", macros: { c: 22, p: 0, f: 0, s: 5, fl: 90 } },
  granola_bar:   { name: "Granola Bar",    namePlural: "Granola Bars",   unit: null,    step: 1,    category: "solid", macros: { c: 28, p: 4,  f: 6, s: 130, fl: 0 } },
  fig_bar:       { name: "Fig Bar",        namePlural: "Fig Bars",       unit: null,    step: 1,    category: "solid", macros: { c: 15, p: 1,  f: 1, s: 60,  fl: 0 } },
  graham:        { name: "Graham Cracker", namePlural: "Graham Crackers",unit: null,    step: 1,    category: "solid", macros: { c: 6,  p: 1,  f: 1, s: 43,  fl: 0 } },
  pretzels:      { name: "Pretzels",                                     unit: "oz",    step: 0.5,  category: "solid", macros: { c: 22, p: 3,  f: 1, s: 320, fl: 0 } },
  apple:         { name: "Apple",          namePlural: "Apples",         unit: null,    step: 0.5,  category: "solid", macros: { c: 25, p: 0, f: 0, s: 2, fl: 0 } },
  energy_bar:    { name: "Energy Bar",     namePlural: "Energy Bars",    unit: null,    step: 1,    category: "solid", macros: { c: 32, p: 7, f: 7, s: 140, fl: 0 } },
  stroopwafel:   { name: "Stroopwafel",    namePlural: "Stroopwafels",   unit: null,    step: 1,    category: "solid", macros: { c: 23, p: 1, f: 5, s: 65, fl: 0 } },
  bonk_bar:      { name: "Bonk Bar",       namePlural: "Bonk Bars",      unit: null,    step: 1,    category: "solid", macros: { c: 30, p: 5, f: 6, s: 100, fl: 0 } },
  pbj_quarter:   { name: "PB&J Quarter",   namePlural: "PB&J Quarters",  unit: null,    step: 1,    category: "solid", macros: { c: 18, p: 5, f: 7, s: 180, fl: 0 } },
  saltine:       { name: "Saltine Cracker", namePlural: "Saltine Crackers", unit: null, step: 1,    category: "solid", macros: { c: 4, p: 0, f: 0, s: 35, fl: 0 } },

  // ---- FLUIDS ----
  milk:          { name: "Milk",                                         unit: "cup",   step: 0.25, category: "fluid", macros: { c: 12, p: 8, f: 5, s: 120, fl: 240 } },
  oat_milk:      { name: "Oat Milk",                                     unit: "cup",   step: 0.25, category: "fluid", macros: { c: 16, p: 3, f: 5, s: 100, fl: 240 } },
  sports_drink:  { name: "Sports Drink",                                 unit: "oz",    step: 1,    category: "fluid", macros: { c: 1.75,p: 0,f: 0, s: 14,  fl: 30 } },
  coconut_water: { name: "Coconut Water",                                unit: "oz",    step: 1,    category: "fluid", macros: { c: 1.1, p: 0,f: 0, s: 32,  fl: 30 } },
  juice_box:     { name: "Juice Box",      namePlural: "Juice Boxes",    unit: null,    step: 1,    category: "fluid", macros: { c: 22, p: 0, f: 0, s: 15,  fl: 200 } },
  water:         { name: "Water",                                        unit: "cup",   step: 0.25, category: "fluid", macros: { c: 0, p: 0, f: 0, s: 0, fl: 240 } },
  chocolate_milk:{ name: "Chocolate Milk",                               unit: "cup",   step: 0.25, category: "fluid", macros: { c: 26, p: 8, f: 5, s: 150, fl: 240 } },
  juice:         { name: "Juice",                                        unit: "cup",   step: 0.25, category: "fluid", macros: { c: 28, p: 0, f: 0, s: 10, fl: 240 } },

  // ---- GELS ----
  energy_gel:        { name: "Energy Gel",     namePlural: "Energy Gels", unit: null, step: 1, category: "gel", macros: { c: 25, p: 0, f: 0, s: 50, fl: 0 } },
  energy_chews:      { name: "Energy Chews",                              unit: "packet", unitPlural: "packets", step: 1, category: "gel", macros: { c: 24, p: 0, f: 0, s: 60, fl: 0 } },
  honey_packet:      { name: "Honey Packet",   namePlural: "Honey Packets", unit: null, step: 1, category: "gel", macros: { c: 17, p: 0, f: 0, s: 1, fl: 0 } },
  electrolyte_packet:{ name: "Electrolyte Packet", namePlural: "Electrolyte Packets", unit: null, step: 1, category: "gel", macros: { c: 11, p: 0, f: 0, s: 320, fl: 0 } },

  // ---- DRINK MIXES ----
  high_carb_mix:        { name: "High Carb Drink Mix",   unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 30, p: 0, f: 0, s: 40, fl: 0 } },
  electrolyte_drink_mix:{ name: "Electrolyte Drink Mix", unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 15, p: 0, f: 0, s: 220, fl: 0 } },
  sports_drink_mix:     { name: "Sports Drink Mix",      unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 15, p: 0, f: 0, s: 100, fl: 0 } },
  maltodextrin:         { name: "Maltodextrin",          unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 25, p: 0, f: 0, s: 5,  fl: 0 } },
  tailwind:             { name: "Tailwind Mix",          unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 25, p: 0, f: 0, s: 310, fl: 0 } },
  recovery_mix:         { name: "Recovery Drink Mix",    unit: "scoop", unitPlural: "scoops", step: 1, category: "mix", macros: { c: 30, p: 20, f: 2, s: 200, fl: 0 } },

  // ---- PILLS / CAPSULES ----
  electrolyte_tablet:  { name: "Electrolyte Tablet",  namePlural: "Electrolyte Tablets",  unit: null, step: 1, category: "pill", macros: { c: 2, p: 0, f: 0, s: 300, fl: 0 } },
  electrolyte_capsule: { name: "Electrolyte Capsule", namePlural: "Electrolyte Capsules", unit: null, step: 1, category: "pill", macros: { c: 0, p: 0, f: 0, s: 250, fl: 0 } },
  salt_tablet:         { name: "Salt Tablet",         namePlural: "Salt Tablets",         unit: null, step: 1, category: "pill", macros: { c: 0, p: 0, f: 0, s: 300, fl: 0 } },
  salt:                { name: "Pinch of Salt",       namePlural: "Pinches of Salt",      unit: null, step: 1, category: "pill", macros: { c: 0, p: 0, f: 0, s: 250, fl: 0 } },
};

// Aliases used by parser to map cleaned-up component strings to catalog keys.
const COMPONENT_TAIL_TO_KEY = [
  // multi-word, more specific first
  ["tbsp peanut butter",     "peanut_butter"],
  ["tbsp jam",               "jam"],
  ["tbsp raisins",           "raisins"],
  ["tbsp honey",             "honey"],
  ["tbsp syrup",             "syrup"],
  ["cup cereal",             "cereal"],
  ["cup milk",               "milk"],
  ["cup oatmeal",            "oatmeal"],
  ["cup mixed berries",      "mixed_berries"],
  ["cup berries",            "berries"],
  ["cup greek yogurt",       "greek_yogurt"],
  ["cup granola",            "granola"],
  ["cup oat milk",           "oat_milk"],
  ["cup trail mix",          "trail_mix"],
  ["cup water",              "water"],
  ["slices white toast",     "white_toast"],
  ["slice white toast",      "white_toast"],
  ["slices toast",           "toast"],
  ["slice toast",            "toast"],
  ["small pancakes",         "pancake"],
  ["small pancake",          "pancake"],
  ["graham cracker squares", "graham"],
  ["graham cracker square",  "graham"],
  ["oz pretzels",            "pretzels"],
  ["oz sports drink",        "sports_drink"],
  ["oz coconut water",       "coconut_water"],
  ["packet energy chews",    "energy_chews"],
  ["energy chews",           "energy_chews"],
  ["honey packet",           "honey_packet"],
  ["electrolyte packet",     "electrolyte_packet"],
  ["electrolyte drink mix",  "electrolyte_drink_mix"],
  ["high carb drink mix",    "high_carb_mix"],
  ["sports drink mix",       "sports_drink_mix"],
  ["recovery drink mix",     "recovery_mix"],
  ["medjool dates",          "date"],
  ["medjool date",           "date"],
  ["medium banana",          "banana"],
  ["baked potato",           "potato"],
  ["rice cakes",             "rice_cake"],
  ["rice cake",              "rice_cake"],
  ["savory rice cake",       "rice_cake"],
  ["pinch of salt",          "salt"],
  ["applesauce pouch",       "applesauce"],
  ["granola bar",            "granola_bar"],
  ["fig bars",               "fig_bar"],
  ["fig bar",                "fig_bar"],
  ["juice box (200ml)",      "juice_box"],
  ["juice box",              "juice_box"],
  ["electrolyte tablet",     "electrolyte_tablet"],
  ["electrolyte capsule",    "electrolyte_capsule"],
  ["salt tablet",            "salt_tablet"],
  ["salt tab",               "salt_tablet"],
  ["energy gel",             "energy_gel"],
  ["energy bar",             "energy_bar"],
  ["bonk bar",               "bonk_bar"],
  ["pb&j quarter",           "pbj_quarter"],
  ["coconut water",          "coconut_water"],
  ["sports drink",           "sports_drink"],
  ["stroopwafel",            "stroopwafel"],
  ["chocolate milk",         "chocolate_milk"],
  ["water",                  "water"],
  ["juice",                  "juice"],
  ["apple",                  "apple"],
  // single-word fallbacks
  ["bananas",                "banana"],
  ["banana",                 "banana"],
  ["dates",                  "date"],
  ["date",                   "date"],
  ["bagel",                  "bagel"],
];

function parseQty(s) {
  if (!s) return null;
  if (s.includes("/")) {
    const [a, b] = s.split("/").map(parseFloat);
    if (!isNaN(a) && !isNaN(b) && b !== 0) return a / b;
    return null;
  }
  const n = parseFloat(s);
  return isNaN(n) ? null : n;
}

function parseComponentString(str) {
  const lower = str.trim().toLowerCase();
  if (lower === "pinch of salt") return { qty: 1, foodKey: "salt" };

  // try leading qty
  const m = lower.match(/^([\d./]+)\s+(.+)$/);
  let qty = 1, tail = lower;
  if (m) {
    qty = parseQty(m[1]) || 1;
    tail = m[2];
  }
  const sorted = [...COMPONENT_TAIL_TO_KEY].sort((a, b) => b[0].length - a[0].length);
  for (const [t, key] of sorted) {
    if (tail === t) return { qty, foodKey: key };
  }
  for (const [t, key] of sorted) {
    if (tail.endsWith(t)) return { qty, foodKey: key };
  }
  return { qty, foodKey: null, raw: str };
}

function componentsToItems(formula) {
  return formula.components.map((str, i) => {
    const parsed = parseComponentString(str);
    return {
      id: `${formula.id}-${i}-${parsed.foodKey || "raw"}`,
      qty: parsed.qty || 1,
      foodKey: parsed.foodKey,
      raw: parsed.foodKey ? null : str,
    };
  });
}

function macrosFromItems(items, customFoods) {
  const customMap = {};
  (customFoods || []).forEach(cf => { customMap[cf.key] = cf; });
  const total = { carbs: 0, protein: 0, fat: 0, sodium: 0, fluid: 0 };
  for (const it of items) {
    const food = FOOD_CATALOG[it.foodKey] || customMap[it.foodKey];
    if (!food) continue;
    total.carbs   += (food.macros.c  || 0) * it.qty;
    total.protein += (food.macros.p  || 0) * it.qty;
    total.fat     += (food.macros.f  || 0) * it.qty;
    total.sodium  += (food.macros.s  || 0) * it.qty;
    total.fluid   += (food.macros.fl || 0) * it.qty;
  }
  return {
    carbs:   Math.round(total.carbs),
    protein: Math.round(total.protein),
    fat:     Math.round(total.fat),
    sodium:  Math.round(total.sodium),
    fluid:   Math.round(total.fluid),
  };
}

function fmtQty(q) {
  if (Number.isInteger(q)) return String(q);
  return String(parseFloat(q.toFixed(2)));
}

function lookupFood(foodKey, customFoods) {
  if (!foodKey) return null;
  if (FOOD_CATALOG[foodKey]) return FOOD_CATALOG[foodKey];
  return (customFoods || []).find(cf => cf.key === foodKey) || null;
}

function itemLabel(item, opts = {}) {
  const { showQty = true, customFoods = [] } = opts;
  const food = lookupFood(item.foodKey, customFoods);
  if (!food) return item.raw || "Unknown";
  const q = item.qty;
  const parts = showQty ? [fmtQty(q)] : [];
  if (showQty && food.unit) {
    const u = q === 1 ? food.unit : (food.unitPlural || food.unit + "s");
    parts.push(u);
  } else if (!showQty && food.unit && !food.isPersonal) {
    // omit unit/qty in compact label
  }
  const name = (showQty && q !== 1 && food.namePlural) ? food.namePlural : food.name;
  parts.push(name);
  return parts.join(" ");
}

function itemMinQty(item, customFoods) {
  const food = lookupFood(item.foodKey, customFoods);
  if (!food) return 1;
  return Math.max(food.step || 1, 0.5);
}

// ---------- Icon primitives ----------
function CategoryIcon({ category, size = 18 }) {
  const baseProps = { width: size, height: size, viewBox: "0 0 24 24" };
  if (category === "solid") {
    return (
      <svg {...baseProps} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M8 3v8M6 3v4a2 2 0 0 0 2 2M10 3v4a2 2 0 0 1-2 2M8 11v10" />
        <path d="M16 3c-1.5 1.5-2 3-2 5v4h3.5V3L16 3zm0 11v7" />
      </svg>
    );
  }
  if (category === "gel") {
    return (
      <svg {...baseProps} fill="currentColor">
        <path d="M12 2.5c-.4 0-.8.2-1 .6C9.2 5.7 5 9.7 5 14.2c0 3.9 3.1 7 7 7s7-3.1 7-7c0-4.5-4.2-8.5-6-11.1-.2-.4-.6-.6-1-.6z" />
      </svg>
    );
  }
  if (category === "fluid") {
    return (
      <svg {...baseProps} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M10 3h4v2.2c0 .4.1.7.4 1l1.4 1.4c.4.4.7 1 .7 1.6V20a2 2 0 0 1-2 2h-5a2 2 0 0 1-2-2V9.2c0-.6.2-1.2.7-1.6L9.6 6.2c.3-.3.4-.6.4-1V3z" />
        <line x1="8.5" y1="14" x2="15.5" y2="14" />
      </svg>
    );
  }
  if (category === "mix") {
    // Erlenmeyer beaker / flask
    return (
      <svg {...baseProps} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M9.5 3h5M10 3v6L5.5 18A2 2 0 0 0 7.3 21h9.4A2 2 0 0 0 18.5 18L14 9V3" />
        <line x1="8" y1="14" x2="16" y2="14" />
      </svg>
    );
  }
  // pill
  return (
    <svg {...baseProps} fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="8" y="3" width="8" height="18" rx="4" transform="rotate(15 12 12)" />
      <line x1="8" y1="12" x2="16" y2="12" transform="rotate(15 12 12)" />
    </svg>
  );
}

function PersonPencilIcon({ size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="9.5" cy="7" r="3.3" />
      <path d="M3 21c0-3.6 3-6 7-6 1 0 1.9.1 2.7.4" />
      <path d="M19 13l2.5 2.5-5.5 5.5H13.5v-2.5z" />
    </svg>
  );
}

function CategoryChip({ category, isPersonal, size = 36 }) {
  // Personal foods get the orange person-with-pencil chip regardless of category.
  if (isPersonal) {
    return (
      <div style={{
        width: size, height: size, borderRadius: "50%",
        background: "var(--me-orange)", color: "var(--me-cream)",
        display: "flex", alignItems: "center", justifyContent: "center",
        flex: "0 0 auto",
      }}>
        <PersonPencilIcon size={Math.round(size * 0.55)} />
      </div>
    );
  }
  const bg = category === "solid" ? "var(--me-orange)" : "var(--me-electrolyte)";
  const fg = category === "solid" ? "var(--me-cream)" : "var(--me-blackberry)";
  return (
    <div style={{
      width: size, height: size, borderRadius: "50%",
      background: bg, color: fg,
      display: "flex", alignItems: "center", justifyContent: "center",
      flex: "0 0 auto",
    }}>
      <CategoryIcon category={category} size={Math.round(size * 0.55)} />
    </div>
  );
}

// ---------- Make-this-mine pill button ----------
function MakeMineButton({ onClick }) {
  return (
    <button onClick={onClick} aria-label="Make this mine" style={{
      height: 36, padding: "0 14px 0 10px", borderRadius: 100,
      background: "var(--me-cream)", color: "var(--me-blackberry)",
      border: "none", cursor: "pointer", display: "inline-flex",
      alignItems: "center", gap: 6,
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 12,
    }}>
      <svg width="13" height="13" viewBox="0 0 24 24" fill="none"
           stroke="currentColor" strokeWidth="2.6" strokeLinecap="square">
        <path d="M12 5v14M5 12h14" />
      </svg>
      Make this mine
    </button>
  );
}

// "Edit" pill (same shape, no "+" glyph) for personal-formula detail header
function EditPillButton({ onClick }) {
  return (
    <button onClick={onClick} aria-label="Edit formula" style={{
      height: 36, padding: "0 18px", borderRadius: 100,
      background: "var(--me-cream)", color: "var(--me-blackberry)",
      border: "none", cursor: "pointer",
      fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 12,
    }}>Edit</button>
  );
}

// Orange-outline pill button (IMG_7921 pattern) used to append a food in edit state
function AddFoodButton({ onClick }) {
  return (
    <button onClick={onClick} style={{
      height: 48, padding: "0 22px", borderRadius: 100,
      background: "transparent", color: "var(--me-orange)",
      border: "1.5px solid var(--me-orange)",
      cursor: "pointer",
      display: "inline-flex", alignItems: "center", gap: 10,
      fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 13,
      letterSpacing: "0.08em", textTransform: "uppercase",
    }}>
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none"
           stroke="currentColor" strokeWidth="2.8" strokeLinecap="round">
        <path d="M12 5v14M5 12h14" />
      </svg>
      Add Food
    </button>
  );
}

// ---------- Editable component row (Before: stepper+swap+remove. During: swap+remove only) ----------
function ComponentRow({ item, expanded, canRemove, variant, customFoods, onToggle, onIncrement, onDecrement, onSwap, onRemove }) {
  const food = lookupFood(item.foodKey, customFoods);
  const category = food?.category || "solid";
  const isPersonal = !!food?.isPersonal;
  const step = food?.step || 1;
  const min = itemMinQty(item, customFoods);
  const canDecrement = item.qty - step >= min - 0.0001;
  const showStepper = variant !== "during";
  // For During: label hides qty
  const label = variant === "during" ? (food?.name || item.raw || "Unknown") : itemLabel(item, { customFoods });

  return (
    <div style={{
      borderRadius: 14,
      background: expanded ? "rgba(248,246,235,0.05)" : "rgba(248,246,235,0.025)",
      border: `1px solid ${expanded ? "rgba(248,246,235,0.16)" : "rgba(248,246,235,0.10)"}`,
      transition: "background-color 180ms, border-color 180ms",
      overflow: "hidden",
    }}>
      <button onClick={onToggle} style={{
        width: "100%", background: "transparent", border: "none", cursor: "pointer",
        padding: "10px 12px", display: "flex", alignItems: "center", gap: 12, textAlign: "left",
      }}>
        <CategoryChip category={category} isPersonal={isPersonal} size={36} />
        <div style={{
          flex: 1, minWidth: 0,
          fontFamily: "Apercu, sans-serif", fontWeight: 500, fontSize: 15.5,
          color: "var(--me-cream)", lineHeight: 1.2,
          fontVariantNumeric: "tabular-nums",
        }}>{label}</div>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none"
             stroke="rgba(248,246,235,0.55)" strokeWidth="2.4" strokeLinecap="square"
             style={{
               flex: "0 0 auto", marginRight: 4,
               transform: expanded ? "rotate(180deg)" : "rotate(0deg)",
               transition: "transform 200ms cubic-bezier(0.2,0.8,0.2,1)",
             }}>
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {expanded && (
        <div style={{
          padding: "4px 12px 14px",
          display: "flex", flexDirection: "column", gap: 12,
          borderTop: "1px solid rgba(248,246,235,0.06)",
          marginTop: 0,
        }}>
          {showStepper && (
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingTop: 12 }}>
              <div style={{
                fontFamily: "Apercu, sans-serif", fontSize: 10, fontWeight: 500,
                letterSpacing: "0.1em", textTransform: "uppercase",
                color: "rgba(248,246,235,0.5)",
              }}>Quantity</div>
              <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
                <StepperBtn onClick={onDecrement} disabled={!canDecrement} symbol="−" />
                <div style={{
                  minWidth: 56, textAlign: "center",
                  fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 18,
                  color: "var(--me-cream)", fontVariantNumeric: "tabular-nums",
                }}>
                  {fmtQty(item.qty)}
                  {food?.unit && <span style={{
                    marginLeft: 4, fontSize: 11, fontWeight: 500,
                    fontFamily: "Apercu, sans-serif",
                    color: "rgba(248,246,235,0.6)",
                  }}>{item.qty === 1 ? food.unit : (food.unitPlural || food.unit + "s")}</span>}
                </div>
                <StepperBtn onClick={onIncrement} symbol="+" />
              </div>
            </div>
          )}
          <div style={{ display: "flex", alignItems: "center", gap: 10, paddingTop: showStepper ? 0 : 12 }}>
            <button onClick={onSwap} style={{
              flex: 1, height: 40, borderRadius: 100,
              background: "var(--me-electrolyte)", color: "var(--me-blackberry)",
              border: "none", cursor: "pointer",
              display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8,
              fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 14,
            }}>
              Swap
              <svg width="16" height="14" viewBox="0 0 24 20" fill="none" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round">
                <path d="M3 6h15M14 2l4 4-4 4" />
                <path d="M21 14H6M10 18l-4-4 4-4" />
              </svg>
            </button>
            {canRemove && (
              <button onClick={onRemove} style={{
                background: "transparent", border: "none",
                color: "rgba(248,246,235,0.55)", cursor: "pointer",
                fontFamily: "Apercu, sans-serif", fontSize: 12, fontWeight: 500,
                padding: "8px 10px", textDecoration: "underline", textUnderlineOffset: 3,
              }}>Remove</button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function StepperBtn({ onClick, disabled, symbol }) {
  return (
    <button onClick={onClick} disabled={disabled} style={{
      width: 32, height: 32, borderRadius: "50%",
      background: "transparent",
      border: `1px solid ${disabled ? "rgba(247,139,20,0.25)" : "var(--me-orange)"}`,
      color: disabled ? "rgba(248,246,235,0.35)" : "var(--me-cream)",
      cursor: disabled ? "not-allowed" : "pointer",
      display: "flex", alignItems: "center", justifyContent: "center",
      fontFamily: "Sansita, Georgia, serif", fontWeight: 700, fontSize: 18, lineHeight: 1,
      paddingBottom: 2,
      transition: "border-color 160ms, color 160ms",
    }}>{symbol}</button>
  );
}

// ---------- Tweened number ----------
function useTween(target, ms = 220) {
  const [v, setV] = React.useState(target);
  const vRef = React.useRef(target);
  const rafRef = React.useRef(null);
  React.useEffect(() => { vRef.current = v; }, [v]);
  React.useEffect(() => {
    const from = vRef.current;
    if (from === target) return;
    const start = performance.now();
    const tick = (now) => {
      const t = Math.min(1, (now - start) / ms);
      const e = 1 - Math.pow(1 - t, 3);
      const next = from + (target - from) * e;
      vRef.current = next;
      setV(next);
      if (t < 1) rafRef.current = requestAnimationFrame(tick);
    };
    cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(rafRef.current);
  }, [target, ms]);
  return v;
}

function AnimatedNumber({ value }) {
  const v = useTween(value, 220);
  return <>{Math.round(v)}</>;
}

function EditableMacroRow({ macros }) {
  const items = [
    { label: "Carbs",   value: macros.carbs,   unit: "g",  color: "var(--me-carbs)" },
    { label: "Protein", value: macros.protein, unit: "g",  color: "var(--me-dragonfruit)" },
    { label: "Fat",     value: macros.fat,     unit: "g",  color: "oklch(0.74 0.15 60)" },
    { label: "Sodium",  value: macros.sodium,  unit: "mg", color: "var(--me-electrolyte)" },
    { label: "Fluid",   value: macros.fluid,   unit: "ml", color: "oklch(0.65 0.13 240)" },
  ];
  return (
    <div style={{
      display: "grid", gridTemplateColumns: "repeat(5, 1fr)",
      gap: 6, padding: "10px 0",
      borderTop: "1px solid rgba(248,246,235,0.08)",
      borderBottom: "1px solid rgba(248,246,235,0.08)",
    }}>
      {items.map(it => (
        <div key={it.label} style={{ display: "flex", flexDirection: "column", gap: 3, alignItems: "flex-start" }}>
          <div style={{
            fontFamily: "'Apercu Mono', monospace", fontSize: 13, fontWeight: 500,
            color: "var(--me-cream)", fontVariantNumeric: "tabular-nums", lineHeight: 1,
          }}>
            <AnimatedNumber value={it.value} />
            <span style={{ fontSize: 10, color: "rgba(248,246,235,0.5)" }}>{it.unit}</span>
          </div>
          <div style={{
            display: "flex", alignItems: "center", gap: 4,
            fontFamily: "Apercu, sans-serif", fontSize: 9, fontWeight: 500,
            letterSpacing: "0.06em", textTransform: "uppercase",
            color: "rgba(248,246,235,0.55)",
          }}>
            <span style={{ width: 4, height: 4, borderRadius: "50%", background: it.color }} />
            {it.label}
          </div>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, {
  FOOD_CATALOG,
  parseComponentString, componentsToItems, macrosFromItems,
  itemLabel, fmtQty, itemMinQty, lookupFood,
  CategoryIcon, CategoryChip, PersonPencilIcon,
  MakeMineButton, EditPillButton, AddFoodButton,
  ComponentRow,
  AnimatedNumber, EditableMacroRow,
});
