// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FoodItemAdapter extends TypeAdapter<FoodItem> {
  @override
  final int typeId = 0;

  @override
  FoodItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodItem(
      id: fields[0] as String,
      name: fields[1] as String,
      description: fields[2] as String,
      category: fields[3] as FoodCategory,
      servingSize: fields[4] as String,
      servingAmount: fields[5] as double,
      servingUnit: fields[6] as String,
      nutrition: fields[7] as NutritionInfo,
      imageUrl: fields[8] as String?,
      tags: (fields[9] as List).cast<String>(),
      additionalInfo: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FoodItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.servingSize)
      ..writeByte(5)
      ..write(obj.servingAmount)
      ..writeByte(6)
      ..write(obj.servingUnit)
      ..writeByte(7)
      ..write(obj.nutrition)
      ..writeByte(8)
      ..write(obj.imageUrl)
      ..writeByte(9)
      ..write(obj.tags)
      ..writeByte(10)
      ..write(obj.additionalInfo);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class NutritionInfoAdapter extends TypeAdapter<NutritionInfo> {
  @override
  final int typeId = 2;

  @override
  NutritionInfo read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return NutritionInfo(
      calories: fields[0] as double,
      carbs: fields[1] as double,
      protein: fields[2] as double,
      fat: fields[3] as double,
      fiber: fields[4] as double,
      sodium: fields[5] as double,
      sugar: fields[6] as double,
      fluids: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, NutritionInfo obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.calories)
      ..writeByte(1)
      ..write(obj.carbs)
      ..writeByte(2)
      ..write(obj.protein)
      ..writeByte(3)
      ..write(obj.fat)
      ..writeByte(4)
      ..write(obj.fiber)
      ..writeByte(5)
      ..write(obj.sodium)
      ..writeByte(6)
      ..write(obj.sugar)
      ..writeByte(7)
      ..write(obj.fluids);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NutritionInfoAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodCategoryAdapter extends TypeAdapter<FoodCategory> {
  @override
  final int typeId = 1;

  @override
  FoodCategory read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FoodCategory.preRun;
      case 1:
        return FoodCategory.duringRun;
      case 2:
        return FoodCategory.postRun;
      default:
        return FoodCategory.preRun;
    }
  }

  @override
  void write(BinaryWriter writer, FoodCategory obj) {
    switch (obj) {
      case FoodCategory.preRun:
        writer.writeByte(0);
        break;
      case FoodCategory.duringRun:
        writer.writeByte(1);
        break;
      case FoodCategory.postRun:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
