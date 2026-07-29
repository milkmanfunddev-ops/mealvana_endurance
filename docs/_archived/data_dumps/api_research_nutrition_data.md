# Nutrition Data API Research

## Executive Summary

Research completed on two nutrition data sources:

1. **The Feed (thefeed.com)**: Uses **Shopify Storefront GraphQL API**, NOT Algolia. Already have working implementation in `scripts/scrape_thefeed_products.js`.
2. **FDA FoodData Central API**: Free government API with comprehensive nutrition data, supports UPC barcode search via keyword matching.

## Key Findings

### The Feed API

**Discovery**: The Feed uses Shopify's Storefront GraphQL API, not Algolia search.

**Working Implementation**:
- Endpoint: `https://thefeed.myshopify.com/api/2024-10/graphql.json`
- Access Token: `ee5c8524ec06e62d02701486c1b3a1f3` (public storefront token)
- Data Available: Product metadata (title, vendor, type, tags, price, inventory)
- **Limitation**: Does NOT include nutrition data (carbs, protein, fat, calories, sodium)

**Why No Nutrition Data**: Shopify's product data is focused on e-commerce (pricing, inventory, variants), not nutritional content. Nutrition facts would need to be in metafields, which aren't exposed in this API.

### FDA FoodData Central API

**Base URL**: `https://api.nal.usda.gov/fdc/v1/`

**Key Features**:
- **Free**: No cost, just sign up for API key at https://fdc.nal.usda.gov/api-key-signup/
- **Rate Limit**: 1,000 requests/hour per IP (higher available on request)
- **UPC Search**: Search by keyword (including UPC codes embedded in product names)
- **Comprehensive Nutrition**: Energy, macros, micros, vitamins, minerals

**Important Nutrient IDs**:
- `1003`: Protein
- `1004`: Total Fat
- `1005`: Carbohydrate
- `1008`: Energy (calories)
- `1093`: Sodium
- `2047`: Metabolizable Energy (Atwater General Factor - 4/9/4 calculation)

## Detailed Analysis

### 1. The Feed - Shopify Storefront GraphQL

**Current Implementation** (already working in `scripts/scrape_thefeed_products.js`):

```javascript
const ENDPOINT = "https://thefeed.myshopify.com/api/2024-10/graphql.json";
const TOKEN = "ee5c8524ec06e62d02701486c1b3a1f3";

const PRODUCTS_QUERY = `
  query ProductsPage($first: Int!, $after: String) {
    products(first: $first, after: $after, sortKey: ID) {
      edges {
        cursor
        node {
          id
          handle
          title
          vendor
          productType
          tags
          totalInventory
          availableForSale
          onlineStoreUrl
          updatedAt
          featuredImage { url }
          priceRange {
            minVariantPrice { amount currencyCode }
            maxVariantPrice { amount currencyCode }
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
`;

async function fetchProducts() {
  const res = await fetch(ENDPOINT, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-shopify-storefront-access-token": TOKEN,
    },
    body: JSON.stringify({
      query: PRODUCTS_QUERY,
      variables: { first: 250, after: null }
    }),
  });

  return await res.json();
}
```

**Available Fields**:
- `id`, `handle`, `title`, `vendor`, `productType`
- `tags` (category classifications like "Category:Nutrition>Protein")
- `totalInventory`, `availableForSale`, `onlineStoreUrl`
- `priceRange.minVariantPrice.amount`
- `featuredImage.url`

**Missing**: Nutrition data (carbs, protein, fat, calories, sodium)

**Pagination**: Uses cursor-based pagination with `pageInfo.endCursor` and `pageInfo.hasNextPage`

**Rate Limits**: Shopify Storefront API uses cost-based throttling (monitor `extensions.cost.throttleStatus.currentlyAvailable`)

---

### 2. FDA FoodData Central API

**Authentication**: API key required (query parameter)

**Endpoints**:
- `/foods/search` - Search by keywords (GET or POST)
- `/food/{fdcId}` - Get single food by FDC ID
- `/foods` - Get multiple foods by FDC IDs
- `/foods/list` - Paginated list

**UPC Barcode Search Strategy**:

The API doesn't have a dedicated UPC endpoint, but branded foods include `gtinUpc` field. Two approaches:

1. **Search by UPC as keyword**: `query=077034085228` (searches all text fields)
2. **Filter branded foods**: Add `dataType=Branded` to restrict to commercial products

**Example: Search by UPC**

```javascript
const FDC_API_KEY = "YOUR_API_KEY_HERE"; // Get from https://fdc.nal.usda.gov/api-key-signup/
const BASE_URL = "https://api.nal.usda.gov/fdc/v1";

async function searchByUPC(upc) {
  const url = `${BASE_URL}/foods/search?api_key=${FDC_API_KEY}&query=${upc}&dataType=Branded`;

  const response = await fetch(url);
  const data = await response.json();

  return data.foods; // Array of matching foods
}

// Usage
const results = await searchByUPC("077034085228");
console.log(results[0]); // First matching product
```

**Example: Get Food Details with Specific Nutrients**

```javascript
async function getFoodDetails(fdcId, nutrientIds = [1003, 1004, 1005, 1008, 1093]) {
  // nutrientIds: 1003=Protein, 1004=Fat, 1005=Carbs, 1008=Energy, 1093=Sodium
  const nutrientsParam = nutrientIds.join(',');
  const url = `${BASE_URL}/food/${fdcId}?api_key=${FDC_API_KEY}&nutrients=${nutrientsParam}`;

  const response = await fetch(url);
  const data = await response.json();

  return data;
}

// Usage
const food = await getFoodDetails(173395, [1003, 1004, 1005]);
console.log(food.description); // "Apple, raw"
console.log(food.foodNutrients); // Array of nutrient objects
```

**Example: Advanced Search with Filters**

```javascript
async function searchFoods(query, options = {}) {
  const params = new URLSearchParams({
    api_key: FDC_API_KEY,
    query: query,
    dataType: options.dataType || 'Branded', // Branded, Foundation, Survey (FNDDS), SR Legacy
    pageSize: options.pageSize || 50,
    pageNumber: options.pageNumber || 1,
    sortBy: options.sortBy || 'dataType.keyword',
    sortOrder: options.sortOrder || 'asc',
  });

  if (options.brandOwner) {
    params.append('brandOwner', options.brandOwner);
  }

  const url = `${BASE_URL}/foods/search?${params}`;
  const response = await fetch(url);
  const data = await response.json();

  return {
    totalHits: data.totalHits,
    currentPage: data.currentPage,
    totalPages: data.totalPages,
    foods: data.foods,
  };
}

// Usage
const results = await searchFoods("chocolate protein powder", {
  dataType: "Branded",
  pageSize: 25,
  brandOwner: "Ascent"
});
```

**Example: Extract Nutrition Data**

```javascript
function extractNutrition(foodData) {
  const nutrients = {};

  // Map nutrient IDs to friendly names
  const nutrientMap = {
    1003: 'protein',
    1004: 'fat',
    1005: 'carbohydrate',
    1008: 'energy',
    1093: 'sodium',
    1087: 'calcium',
    1089: 'iron',
    1258: 'saturatedFat',
  };

  for (const nutrient of foodData.foodNutrients) {
    const key = nutrientMap[nutrient.nutrientId];
    if (key) {
      nutrients[key] = {
        value: nutrient.value,
        unit: nutrient.unitName,
        nutrientId: nutrient.nutrientId,
      };
    }
  }

  return {
    fdcId: foodData.fdcId,
    description: foodData.description,
    brandOwner: foodData.brandOwner,
    gtinUpc: foodData.gtinUpc,
    servingSize: foodData.servingSize,
    servingSizeUnit: foodData.servingSizeUnit,
    nutrients,
  };
}

// Usage
const food = await getFoodDetails(173395);
const nutrition = extractNutrition(food);
console.log(nutrition);
// Output:
// {
//   fdcId: 173395,
//   description: "Apple, raw",
//   nutrients: {
//     protein: { value: 0.26, unit: "g", nutrientId: 1003 },
//     fat: { value: 0.17, unit: "g", nutrientId: 1004 },
//     carbohydrate: { value: 13.81, unit: "g", nutrientId: 1005 },
//     energy: { value: 52, unit: "kcal", nutrientId: 1008 }
//   }
// }
```

**Response Structure** (typical food object):

```javascript
{
  "fdcId": 534358,
  "description": "Whey Protein Isolate Powder",
  "dataType": "Branded",
  "gtinUpc": "077034085228",
  "brandOwner": "Premier Nutrition Company",
  "ingredients": "Whey Protein Isolate, Natural Flavors...",
  "servingSize": 30,
  "servingSizeUnit": "g",
  "foodNutrients": [
    {
      "nutrientId": 1008,
      "nutrientName": "Energy",
      "value": 120,
      "unitName": "kcal"
    },
    {
      "nutrientId": 1003,
      "nutrientName": "Protein",
      "value": 25,
      "unitName": "g"
    },
    {
      "nutrientId": 1004,
      "nutrientName": "Total lipid (fat)",
      "value": 1.5,
      "unitName": "g"
    },
    {
      "nutrientId": 1005,
      "nutrientName": "Carbohydrate, by difference",
      "value": 3,
      "unitName": "g"
    },
    {
      "nutrientId": 1093,
      "nutrientName": "Sodium, Na",
      "value": 170,
      "unitName": "mg"
    }
  ]
}
```

## Recommendations

### For Endurance Nutrition Product Database

**Primary Data Source**: FDA FoodData Central API
- **Pros**: Free, comprehensive nutrition data, supports UPC search, 1000 req/hr sufficient
- **Cons**: Search by UPC is keyword-based (not guaranteed exact match), requires parsing response

**Implementation Strategy**:

1. **Barcode Scan Flow**:
   - User scans UPC → Search FDC API with `query={upc}&dataType=Branded`
   - Filter results where `gtinUpc === scanned_upc` (exact match)
   - Extract nutrition data using `extractNutrition()` helper
   - Cache results locally (Drift database) to reduce API calls

2. **Product Search Flow**:
   - User searches "whey protein chocolate" → FDC API search
   - Display results with nutrition facts
   - Allow filtering by brand, category (using tags)

3. **Rate Limit Management**:
   - Cache all FDC API responses in Drift database with 30-day TTL
   - Check local cache before making API request
   - Implement retry with exponential backoff for 429 errors
   - Monitor usage via analytics (aim for <500 requests/day)

**The Feed Integration** (secondary):
- Use existing scraper to build product catalog (2,300+ products)
- Cross-reference with FDC API using product names/brands
- Manual curation for nutrition data (if not in FDC)

### Next Steps

1. **Get FDC API Key**: Sign up at https://fdc.nal.usda.gov/api-key-signup/
2. **Test UPC Search**: Validate accuracy with known products (GU gels, Maurten, SIS)
3. **Schema Design**: Add `fdc_id`, `gtin_upc`, `nutrition_source` columns to foods table
4. **Build Cache Layer**: Implement local storage with TTL
5. **Create Service**: `lib/features/nutrition_plan/application/fdc_nutrition_service.dart`

## Sources

- [USDA FoodData Central API Guide](https://fdc.nal.usda.gov/api-guide/)
- [FDC API OpenAPI Specification](https://fdc.nal.usda.gov/api-spec/fdc_api.html)
- [FDC API Key Signup](https://fdc.nal.usda.gov/api-key-signup/)
- [Algolia JavaScript Search Client](https://www.algolia.com/developers/search-api-javascript)
- [Node.js FoodData Central Client](https://github.com/metonym/fooddata-central)
- [FoodData Central Foundation Foods Documentation](https://fdc.nal.usda.gov/Foundation_Foods_Documentation/)

## Research Limitations

1. **The Feed Nutrition Data**: Not available via Shopify Storefront API (would require web scraping individual product pages or metafields access)
2. **UPC Exact Match**: FDC API doesn't guarantee exact UPC matches (requires filtering response)
3. **Algolia Investigation**: The Feed does NOT use Algolia (confirmed via frontend inspection)
4. **Complete Nutrient List**: FDA documentation doesn't publish full nutrient ID mapping (requires manual discovery or CSV download)
