class Food {
  final String id;
  final String name;
  final String? imageAddress;
  final String? description;
  final String? instructions;
  final double? servingAmount;
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
      beforeRunSuitable: json['before_run_suitable'] as bool? ?? false,
      duringRunSuitable: json['during_run_suitable'] as bool? ?? false,
      runPortable: json['run_portable'] as bool? ?? false,
      requiresPreparation: json['requires_preparation'] as bool? ?? false,
      aidStationAvailable: json['aid_station_available'] as bool? ?? false,
      maxServingsBefore: json['max_servings_before'] as int?,
      maxServingsDuring: json['max_servings_during'] as int?,
    );
  }

  /// Get the full S3 image URL for this food
  /// Constructs URL from S3 bucket base URL + image_address field
  String? get imageUrl {
    if (imageAddress == null || imageAddress!.isEmpty) {
      return null;
    }
    return 'https://milkman-dev.s3.us-east-2.amazonaws.com/foods/$imageAddress';
  }

  /// Generate quantity display string with amount, unit, qualifier, and name
  /// Examples: "1 cup cooked oatmeal", "2 medium bananas sliced", "4 energy gels"
  String generateQuantityDisplay({double? customAmount}) {
    final amount = customAmount ?? servingAmount ?? 1.0;
    final amountStr = amount == amount.toInt() ? amount.toInt().toString() : amount.toStringAsFixed(1);
    
    // Determine unit (singular vs plural)
    final unit = amount > 1 && servingUnitPlural != null && servingUnitPlural!.isNotEmpty
        ? servingUnitPlural!
        : servingUnit ?? 'serving';
    
    // Build the complete description
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