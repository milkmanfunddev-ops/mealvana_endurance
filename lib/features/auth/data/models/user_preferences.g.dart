// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_preferences.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 3;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      id: fields[0] as String,
      gender: fields[1] as Gender,
      birthday: fields[2] as DateTime,
      heightFeet: fields[3] as int,
      heightInches: fields[4] as int,
      weightPounds: fields[5] as double,
      runsWithWaterBottle: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.gender)
      ..writeByte(2)
      ..write(obj.birthday)
      ..writeByte(3)
      ..write(obj.heightFeet)
      ..writeByte(4)
      ..write(obj.heightInches)
      ..writeByte(5)
      ..write(obj.weightPounds)
      ..writeByte(6)
      ..write(obj.runsWithWaterBottle)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodPreferencesAdapter extends TypeAdapter<FoodPreferences> {
  @override
  final int typeId = 5;

  @override
  FoodPreferences read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FoodPreferences(
      userId: fields[0] as String,
      preferences: (fields[1] as Map).cast<String, FoodPreference>(),
      createdAt: fields[2] as DateTime,
      updatedAt: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FoodPreferences obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.preferences)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodPreferencesAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class GenderAdapter extends TypeAdapter<Gender> {
  @override
  final int typeId = 4;

  @override
  Gender read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return Gender.male;
      case 1:
        return Gender.female;
      case 2:
        return Gender.other;
      default:
        return Gender.male;
    }
  }

  @override
  void write(BinaryWriter writer, Gender obj) {
    switch (obj) {
      case Gender.male:
        writer.writeByte(0);
        break;
      case Gender.female:
        writer.writeByte(1);
        break;
      case Gender.other:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GenderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FoodPreferenceAdapter extends TypeAdapter<FoodPreference> {
  @override
  final int typeId = 6;

  @override
  FoodPreference read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FoodPreference.like;
      case 1:
        return FoodPreference.dislike;
      case 2:
        return FoodPreference.willingToTry;
      case 3:
        return FoodPreference.neutral;
      default:
        return FoodPreference.like;
    }
  }

  @override
  void write(BinaryWriter writer, FoodPreference obj) {
    switch (obj) {
      case FoodPreference.like:
        writer.writeByte(0);
        break;
      case FoodPreference.dislike:
        writer.writeByte(1);
        break;
      case FoodPreference.willingToTry:
        writer.writeByte(2);
        break;
      case FoodPreference.neutral:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoodPreferenceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
