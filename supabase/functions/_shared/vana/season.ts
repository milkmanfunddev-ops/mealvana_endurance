/** Seasonal produce — a static month table (US, temperate; plan Phase 2.1 "no API"). One context line so Vana can say
 *  "peaches and corn are in season" without inventing it. Not regional yet: the athlete's location is not on the profile. */
const BY_MONTH: Record<number, string[]> = {
  1: ['citrus', 'kale', 'sweet potatoes', 'winter squash', 'brussels sprouts', 'cabbage'],
  2: ['citrus', 'kale', 'sweet potatoes', 'cauliflower', 'leeks', 'pears'],
  3: ['spinach', 'asparagus', 'peas', 'radishes', 'leeks', 'citrus'],
  4: ['asparagus', 'spinach', 'strawberries', 'peas', 'rhubarb', 'artichokes'],
  5: ['strawberries', 'asparagus', 'peas', 'lettuce', 'spring onions', 'cherries'],
  6: ['cherries', 'blueberries', 'zucchini', 'green beans', 'apricots', 'cucumbers'],
  7: ['blueberries', 'peaches', 'corn', 'tomatoes', 'zucchini', 'melon'],
  8: ['peaches', 'tomatoes', 'corn', 'peppers', 'eggplant', 'plums'],
  9: ['apples', 'tomatoes', 'peppers', 'grapes', 'sweet potatoes', 'figs'],
  10: ['apples', 'pumpkin', 'sweet potatoes', 'pears', 'brussels sprouts', 'kale'],
  11: ['sweet potatoes', 'winter squash', 'cranberries', 'kale', 'pears', 'cauliflower'],
  12: ['citrus', 'winter squash', 'sweet potatoes', 'pomegranate', 'kale', 'cabbage'],
};
export function seasonalProduce(iso: string): string[] { return BY_MONTH[new Date(iso + 'T00:00:00Z').getUTCMonth() + 1] ?? []; }
export const seasonLine = (iso: string) => `SEASON ${new Date(iso + 'T00:00:00Z').toLocaleDateString('en-US', { month: 'long', timeZone: 'UTC' })} · in season: ${seasonalProduce(iso).join(', ')}`;
