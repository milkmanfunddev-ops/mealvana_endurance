// Local adaptation of get-foods edge function
// Returns the food database for client caching

// Extended mock food database
const FOODS_DATABASE = [
  {
    id: 'oatmeal',
    name: 'Oatmeal',
    categories: ['before_run'],
    per_serving: {
      carbs_g: 30,
      protein_g: 5,
      fat_g: 3,
      sodium_mg: 5,
      water_ml: 0
    },
    serving_description: '1 cup cooked',
    timing_notes: 'Best 2-4 hours before run',
    brand: null
  },
  {
    id: 'banana',
    name: 'Banana', 
    categories: ['before_run', 'after_run'],
    per_serving: {
      carbs_g: 27,
      protein_g: 1,
      fat_g: 0,
      sodium_mg: 1,
      water_ml: 0
    },
    serving_description: '1 large banana',
    timing_notes: 'Good pre-run or recovery fuel',
    brand: null
  },
  {
    id: 'sports_drink',
    name: 'Sports Drink',
    categories: ['during_run', 'after_run'],
    per_serving: {
      carbs_g: 14,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 110,
      water_ml: 240
    },
    serving_description: '8 fl oz',
    timing_notes: 'Essential for runs >1 hour',
    brand: 'Gatorade'
  },
  {
    id: 'energy_gel',
    name: 'Energy Gel',
    categories: ['during_run'],
    per_serving: {
      carbs_g: 22,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 50,
      water_ml: 0
    },
    serving_description: '1 packet',
    timing_notes: 'Fast-acting carbs during run',
    brand: 'GU Energy'
  },
  {
    id: 'protein_shake',
    name: 'Protein Shake',
    categories: ['after_run'],
    per_serving: {
      carbs_g: 15,
      protein_g: 25,
      fat_g: 2,
      sodium_mg: 160,
      water_ml: 240
    },
    serving_description: '8 fl oz prepared',
    timing_notes: 'Optimal recovery within 30 minutes',
    brand: 'Premier Protein'
  },
  {
    id: 'bagel',
    name: 'Bagel',
    categories: ['before_run'],
    per_serving: {
      carbs_g: 45,
      protein_g: 8,
      fat_g: 2,
      sodium_mg: 380,
      water_ml: 0
    },
    serving_description: '1 medium bagel',
    timing_notes: '2-3 hours before run for best digestion',
    brand: null
  },
  {
    id: 'energy_chews',
    name: 'Energy Chews',
    categories: ['during_run'],
    per_serving: {
      carbs_g: 16,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 45,
      water_ml: 0
    },
    serving_description: '4 pieces',
    timing_notes: 'Easy to consume on the go',
    brand: 'Clif Shot Bloks'
  },
  {
    id: 'coconut_water',
    name: 'Coconut Water',
    categories: ['after_run'],
    per_serving: {
      carbs_g: 9,
      protein_g: 2,
      fat_g: 0,
      sodium_mg: 64,
      water_ml: 240
    },
    serving_description: '8 fl oz',
    timing_notes: 'Natural electrolyte replacement',
    brand: 'Vita Coco'
  },
  {
    id: 'greek_yogurt',
    name: 'Greek Yogurt',
    categories: ['after_run'],
    per_serving: {
      carbs_g: 20,
      protein_g: 15,
      fat_g: 0,
      sodium_mg: 60,
      water_ml: 0
    },
    serving_description: '1 cup',
    timing_notes: 'Excellent protein for recovery',
    brand: 'Chobani'
  },
  {
    id: 'coffee',
    name: 'Coffee',
    categories: ['before_run'],
    per_serving: {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 5,
      water_ml: 240
    },
    serving_description: '8 fl oz black',
    timing_notes: '30-60 minutes before run for caffeine boost',
    brand: null
  }
];

/**
 * Main function to get foods database
 */
export async function getFoods(requestData = {}) {
  try {
    // Optional filtering by category
    const { category, include_brands } = requestData;
    
    let foods = FOODS_DATABASE;
    
    // Filter by category if specified
    if (category) {
      foods = foods.filter(food => 
        food.categories.includes(category)
      );
    }
    
    // Optionally filter out brand information
    if (!include_brands) {
      foods = foods.map(food => ({
        ...food,
        brand: undefined
      }));
    }
    
    // Add metadata
    const metadata = {
      total_count: foods.length,
      categories: [...new Set(FOODS_DATABASE.flatMap(f => f.categories))],
      last_updated: new Date().toISOString(),
      version: '1.0.0'
    };
    
    return {
      success: true,
      foods,
      metadata
    };
    
  } catch (error) {
    console.error('Error getting foods:', error);
    return {
      success: false,
      error: error.message,
      detailed_message: `Local foods database error: ${error.message}`
    };
  }
}

/**
 * HTTP handler function
 */
export async function handleRequest(request) {
  try {
    const requestData = typeof request === 'object' && request.body 
      ? request.body 
      : request || {};
      
    const response = await getFoods(requestData);
    
    return {
      status: response.success ? 200 : 400,
      data: response
    };
  } catch (error) {
    return {
      status: 500,
      data: {
        success: false,
        error: error.message
      }
    };
  }
}