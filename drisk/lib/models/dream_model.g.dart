// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dream_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DreamAdapter extends TypeAdapter<Dream> {
  @override
  final int typeId = 0;

  @override
  Dream read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Dream(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      date: fields[3] as DateTime,
      mood: fields[4] as DreamMood,
      type: fields[5] as DreamType,
      thrillLevel: fields[6] as double,
      clarity: fields[7] as double,
      tags: (fields[8] as List).cast<String>(),
      isFavorite: fields[9] as bool?,
      recurringDreamGroupId: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Dream obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.mood)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.thrillLevel)
      ..writeByte(7)
      ..write(obj.clarity)
      ..writeByte(8)
      ..write(obj.tags)
      ..writeByte(9)
      ..write(obj.isFavorite)
      ..writeByte(10)
      ..write(obj.recurringDreamGroupId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DreamAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DreamMoodAdapter extends TypeAdapter<DreamMood> {
  @override
  final int typeId = 1;

  @override
  DreamMood read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DreamMood.nightmare;
      case 1:
        return DreamMood.bad;
      case 2:
        return DreamMood.neutral;
      case 3:
        return DreamMood.good;
      case 4:
        return DreamMood.excellent;
      default:
        return DreamMood.nightmare;
    }
  }

  @override
  void write(BinaryWriter writer, DreamMood obj) {
    switch (obj) {
      case DreamMood.nightmare:
        writer.writeByte(0);
        break;
      case DreamMood.bad:
        writer.writeByte(1);
        break;
      case DreamMood.neutral:
        writer.writeByte(2);
        break;
      case DreamMood.good:
        writer.writeByte(3);
        break;
      case DreamMood.excellent:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DreamMoodAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DreamTypeAdapter extends TypeAdapter<DreamType> {
  @override
  final int typeId = 2;

  @override
  DreamType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DreamType.normal;
      case 1:
        return DreamType.lucid;
      case 2:
        return DreamType.daydream;
      case 3:
        return DreamType.falseAwakening;
      case 4:
        return DreamType.recurring;
      default:
        return DreamType.normal;
    }
  }

  @override
  void write(BinaryWriter writer, DreamType obj) {
    switch (obj) {
      case DreamType.normal:
        writer.writeByte(0);
        break;
      case DreamType.lucid:
        writer.writeByte(1);
        break;
      case DreamType.daydream:
        writer.writeByte(2);
        break;
      case DreamType.falseAwakening:
        writer.writeByte(3);
        break;
      case DreamType.recurring:
        writer.writeByte(4);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DreamTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
