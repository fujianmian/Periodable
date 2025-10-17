// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 2;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      notificationsEnabled: fields[0] as bool,
      reminderDaysBefore: fields[1] as int,
      theme: fields[2] as String,
      firstTimeUser: fields[3] as bool,
      lastNotificationTime: fields[4] as DateTime?,
      useAIPrediction: fields[5] as bool,
      userEmail: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.notificationsEnabled)
      ..writeByte(1)
      ..write(obj.reminderDaysBefore)
      ..writeByte(2)
      ..write(obj.theme)
      ..writeByte(3)
      ..write(obj.firstTimeUser)
      ..writeByte(4)
      ..write(obj.lastNotificationTime)
      ..writeByte(5)
      ..write(obj.useAIPrediction)
      ..writeByte(6)
      ..write(obj.userEmail);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
