// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nutrition_plan.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class NutritionPlanAdapter extends TypeAdapter<NutritionPlan> {
  @override
  final int typeId = 7;

  @override
  NutritionPlan read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionPlan(
      id: fields[0] as String,
      userId: fields[1] as String,
      distanceMiles: fields[2] as double,
      paceMinutesPerMile: fields[3] as double,
      durationHours: fields[4] as double,
      totalCarbs: fields[5] as double,
      totalSodium: fields[6] as double,
      totalFluids: fields[7] as double,
      carbsPerHour: fields[8] as double,
      sodiumPerHour: fields[9] as double,
      fluidsPerHour: fields[10] as double,
      preRunMeals: (fields[11] as List).cast<PlannedMeal>(),
      duringRunMeals: (fields[12] as List).cast<PlannedMeal>(),
      postRunMeals: (fields[13] as List).cast<PlannedMeal>(),
      createdAt: fields[14] as DateTime,
      updatedAt: fields[15] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionPlan obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.distanceMiles)
      ..writeByte(3)
      ..write(obj.paceMinutesPerMile)
      ..writeByte(4)
      ..write(obj.durationHours)
      ..writeByte(5)
      ..write(obj.totalCarbs)
      ..writeByte(6)
      ..write(obj.totalSodium)
      ..writeByte(7)
      ..write(obj.totalFluids)
      ..writeByte(8)
      ..write(obj.carbsPerHour)
      ..writeByte(9)
      ..write(obj.sodiumPerHour)
      ..writeByte(10)
      ..write(obj.fluidsPerHour)
      ..writeByte(11)
      ..write(obj.preRunMeals)
      ..writeByte(12)
      ..write(obj.duringRunMeals)
      ..writeByte(13)
      ..write(obj.postRunMeals)
      ..writeByte(14)
      ..write(obj.createdAt)
      ..writeByte(15)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionPlanAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PlannedMealAdapter extends TypeAdapter<PlannedMeal> {
  @override
  final int typeId = 8;

  @override
  PlannedMeal read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PlannedMeal(
      id: fields[0] as String,
      name: fields[1] as String,
      servings: (fields[2] as List).cast<FoodServing>(),
      timingMinutes: fields[3] as int,
      timingLabel: fields[4] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PlannedMeal obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.servings)
      ..writeByte(3)
      ..write(obj.timingMinutes)
      ..writeByte(4)
      ..write(obj.timingLabel);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedMealAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodServingAdapter extends TypeAdapter<FoodServing> {
  @override
  final int typeId = 9;

  @override
  FoodServing read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodServing(
      foodId: fields[0] as String,
      foodName: fields[1] as String,
      servingMultiplier: fields[2] as double,
      servingDescription: fields[3] as String,
      baseNutrition: fields[4] as NutritionInfo,
    );
  }

  @override
  void write(BinaryWriter writer, FoodServing obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.foodId)
      ..writeByte(1)
      ..write(obj.foodName)
      ..writeByte(2)
      ..write(obj.servingMultiplier)
      ..writeByte(3)
      ..write(obj.servingDescription)
      ..writeByte(4)
      ..write(obj.baseNutrition);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodServingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
