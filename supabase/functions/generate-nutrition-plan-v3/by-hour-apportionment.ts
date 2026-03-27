/**
 * By-Hour Apportionment (Server-Side)
 *
 * @deprecated No longer used for during phase (rule solver returns no by-hour data).
 * Kept for potential future use. Client creates empty buckets for user-driven placement.
 */

import { deriveTimingCategory, type FoodResult } from "../_shared/nutrition/index.ts";
import type { ByHourAssignment, ByHourData, ByHourTimeSlot } from "./types.ts";

const QUIET_ZONE_MINUTES = 30;
const END_CUTOFF_MINUTES = 15;
const SIP_INCREMENT = 0.5;
const QUICK_INCREMENT = 0.5;

function gelIntervalMinutes(gutTrainingLevel: string): number {
  switch (gutTrainingLevel) {
    case "low":
      return 45;
    case "high":
      return 25;
    default:
      return 30; // moderate
  }
}

function minuteToTimeSlot(absoluteMinutes: number): ByHourTimeSlot {
  const hourIndex = Math.floor(absoluteMinutes / 60);
  const minuteInHour = absoluteMinutes % 60;
  const slotIndex = Math.min(Math.floor(minuteInHour / 15), 3);
  return { hourIndex, slotIndex };
}

function sipPlacementCount(originalQty: number, totalHours: number): number {
  let placementCount = totalHours;
  const perHourQty = placementCount > 0 ? originalQty / placementCount : 0;
  if (perHourQty < SIP_INCREMENT && originalQty > 0) {
    placementCount = Math.min(
      totalHours,
      Math.max(1, Math.floor(originalQty / SIP_INCREMENT)),
    );
  }
  return placementCount;
}

function splitSipQuantity(
  originalQty: number,
  placementCount: number,
): number[] {
  if (placementCount <= 0) return [];

  // Snap to 0.5 increments while preserving total quantity.
  const baseQty = Math.floor((originalQty / placementCount) / SIP_INCREMENT) *
    SIP_INCREMENT;
  const quantities = Array.from(
    { length: placementCount },
    () => Math.round(baseQty * 10) / 10,
  );

  const assignedTotal = quantities.reduce((sum, q) => sum + q, 0);
  let extraUnits = Math.floor(
    (originalQty - assignedTotal + 1e-9) / SIP_INCREMENT,
  );
  extraUnits = Math.max(0, Math.min(extraUnits, placementCount));

  // Add remainder to later hours (e.g., 8 over 3h => 2.5, 2.5, 3.0).
  for (let i = 0; i < extraUnits; i++) {
    const idx = placementCount - 1 - i;
    quantities[idx] = Math.round((quantities[idx] + SIP_INCREMENT) * 10) / 10;
  }

  return quantities;
}

function eventPlacementCount(
  originalQty: number,
  availableSlots: number,
  minIncrement: number,
  isIndivisible: boolean,
): number {
  if (availableSlots <= 0) return 0;
  const qty = originalQty < 1 ? 1 : originalQty;

  if (isIndivisible) {
    return Math.min(availableSlots, Math.max(1, Math.round(qty)));
  }

  let placementCount = availableSlots;
  const perSlotQty = qty / placementCount;
  if (perSlotQty < minIncrement) {
    placementCount = Math.min(
      availableSlots,
      Math.max(1, Math.floor(qty / minIncrement)),
    );
  }
  return placementCount;
}

function selectEvenlySpacedMinutes(minutes: number[], count: number): number[] {
  if (count <= 0 || minutes.length === 0) return [];
  if (count >= minutes.length) return [...minutes];
  if (count === 1) return [minutes[0]];

  const selectedIdx: number[] = [];
  const used = new Set<number>();
  const maxIndex = minutes.length - 1;

  for (let i = 0; i < count; i++) {
    let idx = Math.round((i * maxIndex) / (count - 1));
    if (!used.has(idx)) {
      used.add(idx);
      selectedIdx.push(idx);
      continue;
    }

    let offset = 1;
    let placed = false;
    while (!placed) {
      const left = idx - offset;
      const right = idx + offset;
      if (left >= 0 && !used.has(left)) {
        used.add(left);
        selectedIdx.push(left);
        placed = true;
      } else if (right <= maxIndex && !used.has(right)) {
        used.add(right);
        selectedIdx.push(right);
        placed = true;
      } else {
        offset += 1;
      }
    }
  }

  selectedIdx.sort((a, b) => a - b);
  return selectedIdx.map((idx) => minutes[idx]);
}

function omitLastAllowedPlacement(minutes: number[]): number[] {
  if (minutes.length <= 1) return minutes;
  return minutes.slice(0, minutes.length - 1);
}

/**
 * @deprecated No longer used for during phase (rule solver returns no by-hour data).
 * Kept for potential future use. Client creates empty buckets for user-driven placement.
 *
 * Generate by-hour time slot assignments for during-phase foods.
 *
 * Same 4-phase algorithm as client-side ByHourApportionmentService:
 * Phase 1: SIP_THROUGHOUT — drinks at :00 every hour
 * Phase 2: ELECTROLYTES — every 60 min starting at minute 60 (skip if <90 min)
 * Phase 3: QUICK_CONSUME — gels/chews after quiet zone, spaced by gut training
 * Phase 4: SLOW_CONSUME — bars/real food after quiet zone
 */
export function generateByHourData(
  foods: FoodResult[],
  durationMinutes: number,
  activityType: string,
  gutTrainingLevel: string = "moderate",
): ByHourData | null {
  if (durationMinutes < 60) return null;
  if (foods.length === 0) {
    return { durationMinutes, assignments: [] };
  }

  const totalHours = Math.max(1, Math.ceil(durationMinutes / 60));
  const assignments: ByHourAssignment[] = [];

  // Categorize foods
  const sipItems: FoodResult[] = [];
  const electrolyteItems: FoodResult[] = [];
  const quickItems: FoodResult[] = [];
  const slowItems: FoodResult[] = [];

  for (const food of foods) {
    const tc = food.timing_category ?? "slow_consume";
    switch (tc) {
      case "sip_throughout":
      case "fuel_drink":
        sipItems.push(food);
        break;
      case "electrolyte":
        electrolyteItems.push(food);
        break;
      case "quick_consume":
        quickItems.push(food);
        break;
      default:
        slowItems.push(food);
        break;
    }
  }

  // Phase 1: SIP_THROUGHOUT + FUEL_DRINK — drinks at :00 every hour
  for (const drink of sipItems) {
    const originalQty = drink.quantity;
    const placementCount = sipPlacementCount(originalQty, totalHours);
    const splitQuantities = splitSipQuantity(originalQty, placementCount);
    const hourStep = placementCount < totalHours
      ? Math.floor(totalHours / placementCount)
      : 1;

    const tc = drink.timing_category ?? "sip_throughout";
    const assignmentCategory = tc === "fuel_drink"
      ? "fuelDrink"
      : "sipThroughout";
    const isSip = tc !== "fuel_drink";

    for (let i = 0; i < placementCount; i++) {
      const h = Math.min(i * hourStep, totalHours - 1);
      assignments.push({
        foodItemId: drink.food_id,
        timeSlot: { hourIndex: h, slotIndex: 0 },
        isSipThroughout: isSip,
        adjustedQuantity: splitQuantities[i],
        timingCategory: assignmentCategory,
      });
    }
  }

  // Phase 2: ELECTROLYTES — every 60 min starting at minute 60, skip if <90 min
  if (durationMinutes >= 90) {
    for (const elec of electrolyteItems) {
      const allMinutes: number[] = [];
      for (let m = 60; m < durationMinutes; m += 60) {
        allMinutes.push(m);
      }
      if (allMinutes.length === 0) continue;

      const wholeQty = Math.max(1, Math.round(elec.quantity));
      const placementCount = Math.min(allMinutes.length, wholeQty);
      const usedMinutes = allMinutes.slice(0, placementCount);

      for (const minute of usedMinutes) {
        assignments.push({
          foodItemId: elec.food_id,
          timeSlot: minuteToTimeSlot(minute),
          isSipThroughout: false,
          adjustedQuantity: 1.0,
          timingCategory: "electrolyte",
        });
      }
    }
  }

  // Phase 3: QUICK_CONSUME — gels/chews after quiet zone, spaced by gut training
  if (quickItems.length > 0) {
    const interval = gelIntervalMinutes(gutTrainingLevel);
    const endCutoff = durationMinutes - END_CUTOFF_MINUTES;

    const placementMinutes: number[] = [];
    for (let m = QUIET_ZONE_MINUTES; m <= endCutoff; m += interval) {
      placementMinutes.push(m);
    }
    const trimmedPlacementMinutes = omitLastAllowedPlacement(placementMinutes);

    if (trimmedPlacementMinutes.length > 0) {
      for (const food of quickItems) {
        const originalQty = food.quantity;
        const placementCount = eventPlacementCount(
          originalQty,
          trimmedPlacementMinutes.length,
          QUICK_INCREMENT,
          food.is_indivisible === true,
        );
        const selectedMinutes = selectEvenlySpacedMinutes(
          trimmedPlacementMinutes,
          placementCount,
        );
        const splitQuantities = food.is_indivisible
          ? Array.from({ length: placementCount }, () => 1.0)
          : splitSipQuantity(originalQty, placementCount);

        for (let i = 0; i < selectedMinutes.length; i++) {
          assignments.push({
            foodItemId: food.food_id,
            timeSlot: minuteToTimeSlot(selectedMinutes[i]),
            isSipThroughout: false,
            adjustedQuantity: splitQuantities[i],
            timingCategory: "quickConsume",
          });
        }
      }
    }
  }

  // Phase 4: SLOW_CONSUME — bars/real food after quiet zone
  if (slowItems.length > 0) {
    let endCutoff = durationMinutes - END_CUTOFF_MINUTES;

    // Cycling: solids only in first 2/3
    if (activityType === "cycling") {
      const twoThirds = Math.round(durationMinutes * 2 / 3);
      endCutoff = Math.min(endCutoff, twoThirds);
    }

    const placementMinutes: number[] = [];
    for (let m = QUIET_ZONE_MINUTES; m <= endCutoff; m += 30) {
      if (m % 60 === 0) continue;
      placementMinutes.push(m);
    }

    if (placementMinutes.length > 0) {
      for (let i = 0; i < slowItems.length; i++) {
        const food = slowItems[i];
        const foodPlacements: number[] = [];
        for (let j = i; j < placementMinutes.length; j += slowItems.length) {
          foodPlacements.push(placementMinutes[j]);
        }

        if (foodPlacements.length === 0) {
          foodPlacements.push(QUIET_ZONE_MINUTES);
        }

        const originalQty = food.is_indivisible
          ? Math.max(1, Math.round(food.quantity))
          : food.quantity;
        let remaining = originalQty < 1 ? 1 : originalQty;

        for (const minute of foodPlacements) {
          if (remaining <= 0) break;
          assignments.push({
            foodItemId: food.food_id,
            timeSlot: minuteToTimeSlot(minute),
            isSipThroughout: false,
            adjustedQuantity: 1.0,
            timingCategory: "slowConsume",
          });
          remaining -= 1;
        }
      }
    }
  }

  return { durationMinutes, assignments };
}
