/**
 * In-season produce lookup — northern hemisphere US default.
 *
 * Returns a list of produce items that are typically at peak quality and
 * lowest cost during the requested month. Useful for meal suggestions,
 * grocery guidance, and budget-friendly fueling recommendations.
 *
 * Data source: static table compiled from USDA seasonal availability guides.
 */

export interface ProduceItem {
  name: string;
  category: 'fruit' | 'vegetable' | 'grain' | 'legume';
  /** Endurance-relevant benefit, e.g. "high-carb", "electrolyte-rich" */
  fueling_note?: string;
}

/** Month number → peak-season produce (1 = January, 12 = December) */
const SEASONAL_PRODUCE: Record<number, ProduceItem[]> = {
  1: [
    { name: 'citrus (oranges, grapefruit)', category: 'fruit', fueling_note: 'vitamin C + electrolytes' },
    { name: 'kale', category: 'vegetable', fueling_note: 'iron + anti-inflammatory' },
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'beets', category: 'vegetable', fueling_note: 'nitrate-rich, endurance boost' },
    { name: 'parsnips', category: 'vegetable' },
    { name: 'winter squash', category: 'vegetable', fueling_note: 'high-carb' },
  ],
  2: [
    { name: 'citrus (blood oranges, clementines)', category: 'fruit', fueling_note: 'vitamin C + electrolytes' },
    { name: 'kale', category: 'vegetable', fueling_note: 'iron + anti-inflammatory' },
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'beets', category: 'vegetable', fueling_note: 'nitrate-rich, endurance boost' },
    { name: 'cabbage', category: 'vegetable' },
    { name: 'leeks', category: 'vegetable' },
  ],
  3: [
    { name: 'asparagus', category: 'vegetable', fueling_note: 'folate + anti-inflammatory' },
    { name: 'artichokes', category: 'vegetable' },
    { name: 'peas', category: 'legume', fueling_note: 'plant protein + carbs' },
    { name: 'spinach', category: 'vegetable', fueling_note: 'iron + nitrate-rich' },
    { name: 'strawberries (early)', category: 'fruit', fueling_note: 'antioxidants' },
    { name: 'radishes', category: 'vegetable' },
  ],
  4: [
    { name: 'asparagus', category: 'vegetable', fueling_note: 'folate + anti-inflammatory' },
    { name: 'peas', category: 'legume', fueling_note: 'plant protein + carbs' },
    { name: 'spinach', category: 'vegetable', fueling_note: 'iron + nitrate-rich' },
    { name: 'strawberries', category: 'fruit', fueling_note: 'antioxidants, quick carbs' },
    { name: 'lettuce/arugula', category: 'vegetable' },
    { name: 'broccoli', category: 'vegetable' },
  ],
  5: [
    { name: 'strawberries', category: 'fruit', fueling_note: 'antioxidants, quick carbs' },
    { name: 'cherries (early)', category: 'fruit', fueling_note: 'anti-inflammatory, recovery' },
    { name: 'asparagus', category: 'vegetable' },
    { name: 'peas', category: 'legume', fueling_note: 'plant protein + carbs' },
    { name: 'zucchini', category: 'vegetable' },
    { name: 'green beans', category: 'vegetable' },
    { name: 'rhubarb', category: 'vegetable' },
  ],
  6: [
    { name: 'cherries', category: 'fruit', fueling_note: 'anti-inflammatory, recovery' },
    { name: 'blueberries', category: 'fruit', fueling_note: 'antioxidants, brain fuel' },
    { name: 'strawberries', category: 'fruit', fueling_note: 'antioxidants, quick carbs' },
    { name: 'peaches', category: 'fruit', fueling_note: 'natural sugars, hydrating' },
    { name: 'zucchini', category: 'vegetable' },
    { name: 'corn', category: 'grain', fueling_note: 'high-carb' },
    { name: 'tomatoes', category: 'vegetable', fueling_note: 'lycopene, potassium' },
  ],
  7: [
    { name: 'blueberries', category: 'fruit', fueling_note: 'antioxidants, brain fuel' },
    { name: 'peaches', category: 'fruit', fueling_note: 'natural sugars, hydrating' },
    { name: 'watermelon', category: 'fruit', fueling_note: 'hydrating, citrulline' },
    { name: 'corn', category: 'grain', fueling_note: 'high-carb' },
    { name: 'tomatoes', category: 'vegetable', fueling_note: 'lycopene, potassium' },
    { name: 'cucumbers', category: 'vegetable', fueling_note: 'hydrating' },
    { name: 'bell peppers', category: 'vegetable', fueling_note: 'vitamin C' },
    { name: 'eggplant', category: 'vegetable' },
  ],
  8: [
    { name: 'watermelon', category: 'fruit', fueling_note: 'hydrating, citrulline' },
    { name: 'cantaloupe', category: 'fruit', fueling_note: 'hydrating, potassium' },
    { name: 'peaches / nectarines', category: 'fruit', fueling_note: 'natural sugars, hydrating' },
    { name: 'tomatoes', category: 'vegetable', fueling_note: 'lycopene, potassium' },
    { name: 'corn', category: 'grain', fueling_note: 'high-carb' },
    { name: 'figs', category: 'fruit', fueling_note: 'quick carbs, potassium' },
    { name: 'eggplant', category: 'vegetable' },
    { name: 'bell peppers', category: 'vegetable' },
  ],
  9: [
    { name: 'apples', category: 'fruit', fueling_note: 'fiber, natural sugars' },
    { name: 'pears', category: 'fruit', fueling_note: 'fiber, natural sugars' },
    { name: 'grapes', category: 'fruit', fueling_note: 'quick carbs, antioxidants' },
    { name: 'figs', category: 'fruit', fueling_note: 'quick carbs, potassium' },
    { name: 'winter squash (early)', category: 'vegetable', fueling_note: 'high-carb' },
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'broccoli', category: 'vegetable' },
  ],
  10: [
    { name: 'apples', category: 'fruit', fueling_note: 'fiber, natural sugars' },
    { name: 'pears', category: 'fruit', fueling_note: 'fiber, natural sugars' },
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'winter squash (butternut, acorn)', category: 'vegetable', fueling_note: 'high-carb' },
    { name: 'beets', category: 'vegetable', fueling_note: 'nitrate-rich, endurance boost' },
    { name: 'Brussels sprouts', category: 'vegetable', fueling_note: 'anti-inflammatory' },
    { name: 'cranberries', category: 'fruit', fueling_note: 'antioxidants' },
  ],
  11: [
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'winter squash', category: 'vegetable', fueling_note: 'high-carb' },
    { name: 'beets', category: 'vegetable', fueling_note: 'nitrate-rich, endurance boost' },
    { name: 'Brussels sprouts', category: 'vegetable', fueling_note: 'anti-inflammatory' },
    { name: 'pomegranate', category: 'fruit', fueling_note: 'antioxidants, anti-inflammatory' },
    { name: 'pears', category: 'fruit', fueling_note: 'fiber, natural sugars' },
    { name: 'kale', category: 'vegetable', fueling_note: 'iron + anti-inflammatory' },
  ],
  12: [
    { name: 'citrus (oranges, tangerines)', category: 'fruit', fueling_note: 'vitamin C + electrolytes' },
    { name: 'sweet potatoes', category: 'vegetable', fueling_note: 'high-carb, potassium-rich' },
    { name: 'winter squash', category: 'vegetable', fueling_note: 'high-carb' },
    { name: 'beets', category: 'vegetable', fueling_note: 'nitrate-rich, endurance boost' },
    { name: 'pomegranate', category: 'fruit', fueling_note: 'antioxidants, anti-inflammatory' },
    { name: 'kale', category: 'vegetable', fueling_note: 'iron + anti-inflammatory' },
    { name: 'pears', category: 'fruit', fueling_note: 'fiber, natural sugars' },
  ],
};

/**
 * Returns peak-season produce for a given month (1–12).
 * Defaults to the current month if none provided.
 */
export function getInSeasonProduce(month?: number): {
  month: number;
  month_name: string;
  items: ProduceItem[];
} {
  const MONTH_NAMES = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  const m = month ?? (new Date().getMonth() + 1);
  const clamped = Math.max(1, Math.min(12, m));

  return {
    month: clamped,
    month_name: MONTH_NAMES[clamped],
    items: SEASONAL_PRODUCE[clamped] ?? [],
  };
}
