// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prediction_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PredictionDataAdapter extends TypeAdapter<PredictionData> {
  @override
  final int typeId = 1;

  @override
  PredictionData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PredictionData(
      predictedDate: fields[0] as DateTime,
      averageCycleLength: fields[1] as int,
      confidence: fields[2] as double,
      calculatedAt: fields[3] as DateTime,
      minCycle: fields[4] as int?,
      maxCycle: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, PredictionData obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.predictedDate)
      ..writeByte(1)
      ..write(obj.averageCycleLength)
      ..writeByte(2)
      ..write(obj.confidence)
      ..writeByte(3)
      ..write(obj.calculatedAt)
      ..writeByte(4)
      ..write(obj.minCycle)
      ..writeByte(5)
      ..write(obj.maxCycle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PredictionDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
