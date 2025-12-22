import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';

class Food {
  final String id;
  final String name;
  final String? imageAddress;
  final String? description;
  final String? instructions;
  final double? servingAmount;

  // Simplified display approach
  final String? displayName;        // e.g., "cup cooked oatmeal"
  final String? displayNamePlural;  // e.g., "cups cooked oatmeal"

  // Categories array (new approach)
  final List<String> categories; // e.g., ['before_run', 'during_run']

  // Allergen and dietary exclusion data (for food filtering)
  final List<Allergy> allergens; // e.g., [Allergy.dairy, Allergy.gluten]
  final List<DietaryPreference> excludedDiets; // e.g., [DietaryPreference.vegan, DietaryPreference.keto]

  // Deprecated fields (legacy compatibility)
  final String? servingUnit;
  final String? servingUnitPlural;
  final String? servingQualifier;
  final String? servingSize;
  final double? carbsPerServing;
  final int? sodiumMg;
  final double? fluidMlPerServing;
  final int? caloriesPerServing;
  final double? proteinPerServing;
  final double? fatPerServing;
  final int? caffeineMg;
  final int? potassiumMg;
  final String? productTypeId; // References product_types.id
  final bool beforeRunSuitable;
  final bool duringRunSuitable;
  final bool runPortable;
  final bool requiresPreparation;
  final bool aidStationAvailable;
  final int? maxServingsBefore;
  final int? maxServingsDuring;

  const Food({
    required this.id,
    required this.name,
    this.imageAddress,
    this.description,
    this.instructions,
    this.servingAmount,
    this.displayName,
    this.displayNamePlural,
    this.categories = const [],
    this.allergens = const [],
    this.excludedDiets = const [],
    this.servingUnit,
    this.servingUnitPlural,
    this.servingQualifier,
    this.servingSize,
    this.carbsPerServing,
    this.sodiumMg,
    this.fluidMlPerServing,
    this.caloriesPerServing,
    this.proteinPerServing,
    this.fatPerServing,
    this.caffeineMg,
    this.potassiumMg,
    this.productTypeId,
    this.beforeRunSuitable = false,
    this.duringRunSuitable = false,
    this.runPortable = false,
    this.requiresPreparation = false,
    this.aidStationAvailable = false,
    this.maxServingsBefore,
    this.maxServingsDuring,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    return Food(
      id: json['id'] as String,
      name: json['name'] as String,
      imageAddress: json['image_address'] as String?,
      description: json['description'] as String?,
      instructions: json['instructions'] as String?,
      servingAmount: (json['serving_amount'] as num?)?.toDouble(),
      displayName: json['display_name'] as String?,
      displayNamePlural: json['display_name_plural'] as String?,
      categories: json['categories'] != null
        ? List<String>.from(json['categories'])
        : [],
      allergens: Allergy.fromDbArray(json['allergens'] as String?),
      excludedDiets: DietaryPreference.fromDbArray(json['excluded_diets'] as String?),
      servingUnit: json['serving_unit'] as String?,
      servingUnitPlural: json['serving_unit_plural'] as String?,
      servingQualifier: json['serving_qualifier'] as String?,
      servingSize: json['serving_size'] as String?,
      carbsPerServing: (json['carbs_per_serving'] as num?)?.toDouble(),
      sodiumMg: json['sodium_mg'] as int?,
      fluidMlPerServing: (json['fluid_ml_per_serving'] as num?)?.toDouble(),
      caloriesPerServing: json['calories_per_serving'] as int?,
      proteinPerServing: (json['protein_per_serving'] as num?)?.toDouble(),
      fatPerServing: (json['fat_per_serving'] as num?)?.toDouble(),
      caffeineMg: json['caffeine_mg'] as int?,
      potassiumMg: json['potassium_mg'] as int?,
      productTypeId: json['product_type_id'] as String?,
      beforeRunSuitable: json['before_run_suitable'] as bool? ?? false,
      duringRunSuitable: json['during_run_suitable'] as bool? ?? false,
      runPortable: json['run_portable'] as bool? ?? false,
      requiresPreparation: json['requires_preparation'] as bool? ?? false,
      aidStationAvailable: json['aid_station_available'] as bool? ?? false,
      maxServingsBefore: json['max_servings_before'] as int?,
      maxServingsDuring: json['max_servings_during'] as int?,
    );
  }

  /// Get the full image URL for this food
  /// Returns Open Food Facts URLs directly, or constructs S3 URL for other images
  String? get imageUrl {
    if (imageAddress == null || imageAddress!.isEmpty) {
      return null;
    }

    // If the image address is already a full Open Food Facts URL, return it directly
    if (imageAddress!.startsWith('https://images.openfoodfacts.org/') ||
        imageAddress!.startsWith('https://static.openfoodfacts.org/')) {
      return imageAddress;
    }

    // Otherwise, construct S3 URL for legacy/existing foods
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/$imageAddress';
  }

  /// Generate quantity display string using simplified display approach
  /// Examples: "1 cup cooked oatmeal", "2 cups cooked oatmeal", "1 medium banana"
  String generateQuantityDisplay({double? customAmount}) {
    final amount = customAmount ?? servingAmount ?? 1.0;
    final amountStr = amount == amount.toInt() ? amount.toInt().toString() : amount.toStringAsFixed(1);

    // NEW SIMPLIFIED APPROACH: Use display names if available
    if (displayName != null && displayName!.isNotEmpty) {
      return amount == 1
          ? '$amountStr $displayName'
          : '$amountStr ${displayNamePlural ?? displayName}';
    }

    // LEGACY FALLBACK: Complex serving unit logic for compatibility
    final unit = amount > 1 && servingUnitPlural != null && servingUnitPlural!.isNotEmpty
        ? servingUnitPlural!
        : servingUnit ?? 'serving';

    final parts = <String>[];
    parts.add(amountStr);
    parts.add(unit);

    if (servingQualifier != null && servingQualifier!.isNotEmpty) {
      parts.add(servingQualifier!);
    }

    parts.add(name.toLowerCase());

    return parts.join(' ');
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_address': imageAddress,
      'description': description,
      'instructions': instructions,
      'serving_amount': servingAmount,
      'display_name': displayName,
      'display_name_plural': displayNamePlural,
      'categories': categories,
      'allergens': Allergy.toDbArray(allergens),
      'excluded_diets': DietaryPreference.toDbArray(excludedDiets),
      'serving_unit': servingUnit,
      'serving_unit_plural': servingUnitPlural,
      'serving_qualifier': servingQualifier,
      'serving_size': servingSize,
      'carbs_per_serving': carbsPerServing,
      'sodium_mg': sodiumMg,
      'fluid_ml_per_serving': fluidMlPerServing,
      'calories_per_serving': caloriesPerServing,
      'protein_per_serving': proteinPerServing,
      'fat_per_serving': fatPerServing,
      'caffeine_mg': caffeineMg,
      'potassium_mg': potassiumMg,
      'product_type_id': productTypeId,
      'before_run_suitable': beforeRunSuitable,
      'during_run_suitable': duringRunSuitable,
      'run_portable': runPortable,
      'requires_preparation': requiresPreparation,
      'aid_station_available': aidStationAvailable,
      'max_servings_before': maxServingsBefore,
      'max_servings_during': maxServingsDuring,
    };
  }
}