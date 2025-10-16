// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'period_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PeriodLogAdapter extends TypeAdapter<PeriodLog> {
  @override
  final int typeId = 0;

  @override
  PeriodLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PeriodLog(
      id: fields[0] as String,
      startDate: fields[1] as DateTime,
      duration: fields[2] as int?,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PeriodLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.startDate)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeriodLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
