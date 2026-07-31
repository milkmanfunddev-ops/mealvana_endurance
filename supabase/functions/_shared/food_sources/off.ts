/**
 * Open Food Facts client. Extracted from lookup-product/index.ts (2026-07-16).
 * Behaviour unchanged — a pure move.
 *
 * This is the *product lookup* endpoint (api/v0/product/{barcode}), which is
 * current. OFF's legacy *search* backend is separately being superseded by
 * Search-a-licious — see the audit doc §9c.
 *
 * ODbL: OFF data is share-alike. Rows sourced here must keep
 * source = 'open_food_facts' so nutrition_products.resale_ok (a generated
 * column) excludes them from any resold/licensed API tier.
 */

/**
 * Best-effort fetch of the raw Open Food Facts product by barcode. Serves two
 * roles: the image for a USDA hit (USDA has no images), and the full nutrition
 * fallback when USDA misses. Never throws — returns null on any miss/error.
 */
async function fetchOffProduct(barcode: string): Promise<any | null> {
  try {
    const resp = await fetch(`https://world.openfoodfacts.org/api/v0/product/${barcode}.json`);
    if (!resp.ok) return null;
    const data = await resp.json();
    if (data.status === 1 && data.product) return data.product;
  } catch (e) {
    console.error('⚠️ OFF fetch failed:', e);
  }
  return null;
}

/** Extract the best available image URL from a raw OFF product. */
function offImage(offProduct: any | null): string | null {
  if (!offProduct) return null;
  return offProduct.image_url || offProduct.image_front_url || null;
}

export { fetchOffProduct, offImage };
