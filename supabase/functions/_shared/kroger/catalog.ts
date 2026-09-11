export type Modality = "PICKUP" | "DELIVERY";
export interface Product {
  upc: string;
  name: string;
  brand: string;
  size: string;
  price: number | null;
  available: boolean;
  image: string | null;
}
export class KrogerError extends Error {
  constructor(public code: string, public status = 400) {
    super(code);
  }
}
// What the function answers for anything it throws. A throw that is not a
// KrogerError is a bug here, never Kroger's: the client turns every failure
// to reach Kroger into `kroger_unavailable` before it gets this far.
export function failure(e: unknown): KrogerError {
  return e instanceof KrogerError ? e : new KrogerError("internal_error", 500);
}
// Kroger's `filter.fulfillment` code for a Modality: delivery-to-home, or
// curbside pickup.
export const fulfillmentFilter = (mode: Modality) =>
  mode === "DELIVERY" ? "dth" : "csp";
export function modality(value: unknown): Modality {
  if (value !== "PICKUP" && value !== "DELIVERY") {
    throw new KrogerError("invalid_modality");
  }
  return value;
}
export function textInput(value: unknown, max = 100): string {
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new KrogerError("invalid_input");
  }
  return value.trim();
}
// Reads a product Kroger returned for an already-filtered request.
//
// Availability is that filter's answer, never the per-item `fulfillment`
// booleans: a Spoke reports `curbside: true` on items the curbside filter
// returns nothing for. The product being in the response is the only
// Location-truthful evidence that it can be had that way. So the caller owes
// this function a `filter.fulfillment` on the request.
export function productFromApi(raw: any): Product | null {
  if (!raw || typeof raw.upc !== "string" || !/^\d{8,14}$/.test(raw.upc)) {
    return null;
  }
  const item = (raw.items ?? []).flat()[0];
  if (!item) return null;
  const price = item.price?.promo > 0 ? item.price.promo : item.price?.regular;
  const image = (raw.images ?? []).find((i: any) => i.featured) ??
    raw.images?.[0];
  const imageUrl = image?.sizes?.find((s: any) => s.size === "medium")?.url ??
    image?.sizes?.[0]?.url;
  return {
    upc: raw.upc,
    name: raw.description ?? "",
    brand: raw.brand ?? "",
    size: item.size ?? "",
    price: typeof price === "number" && Number.isFinite(price) ? price : null,
    available: item.inventory?.stockLevel !== "TEMPORARILY_OUT_OF_STOCK",
    image: typeof imageUrl === "string" && imageUrl.startsWith("https://")
      ? imageUrl
      : null,
  };
}
const words = (s: string) =>
  s.toLowerCase().replace(/[^a-z0-9 ]/g, " ").split(/\s+/).filter(Boolean);
export function rankProducts(query: string, products: Product[]): Product[] {
  const tokens = words(query);
  const score = (p: Product) => {
    const candidate = words(p.name);
    const overlap =
      tokens.filter((t) =>
        candidate.includes(t) || candidate.includes(t.replace(/s$/, ""))
      ).length / Math.max(1, tokens.length);
    const wrongForm = ["frozen", "canned", "dried", "powder", "sweetened"].some(
      (t) => candidate.includes(t) && !tokens.includes(t),
    );
    return overlap * 10 + (p.available ? 2 : -10) - (wrongForm ? 4 : 0);
  };
  return [...products].sort((a, b) =>
    score(b) - score(a) || (a.price ?? Infinity) - (b.price ?? Infinity)
  );
}
export interface CartLine {
  upc: string;
  quantity: number;
  modality: Modality;
}
export function cartLines(raw: unknown, mode: Modality): CartLine[] {
  if (!Array.isArray(raw) || raw.length === 0 || raw.length > 100) {
    throw new KrogerError("invalid_items");
  }
  const totals = new Map<string, number>();
  for (const item of raw) {
    if (
      typeof item?.upc !== "string" || !/^\d{8,14}$/.test(item.upc) ||
      !Number.isInteger(item?.quantity) || item.quantity < 1 ||
      item.quantity > 99
    ) throw new KrogerError("invalid_items");
    totals.set(item.upc, (totals.get(item.upc) ?? 0) + item.quantity);
  }
  if ([...totals.values()].some((q) => q > 99)) {
    throw new KrogerError("invalid_items");
  }
  return [...totals].sort(([a], [b]) => a.localeCompare(b)).map((
    [upc, quantity],
  ) => ({ upc, quantity, modality: mode }));
}
export async function fingerprint(
  store: string,
  lines: CartLine[],
): Promise<string> {
  const data = new TextEncoder().encode(JSON.stringify({ store, lines }));
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", data))].map(
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
