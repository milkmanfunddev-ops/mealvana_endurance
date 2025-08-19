// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_content.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppContentAdapter extends TypeAdapter<AppContent> {
  @override
  final int typeId = 10;

  @override
  AppContent read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppContent(
      version: fields[0] as int,
      environment: fields[1] as String,
      locale: fields[2] as String,
      content: (fields[3] as Map).cast<String, dynamic>(),
      lastUpdated: fields[4] as DateTime,
      isActive: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppContent obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.version)
      ..writeByte(1)
      ..write(obj.environment)
      ..writeByte(2)
      ..write(obj.locale)
      ..writeByte(3)
      ..write(obj.content)
      ..writeByte(4)
      ..write(obj.lastUpdated)
      ..writeByte(5)
      ..write(obj.isActive);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppContentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
