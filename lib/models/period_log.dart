import 'package:hive/hive.dart';

part 'period_log.g.dart'; // Generated file for Hive

@HiveType(typeId: 0)
class PeriodLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime startDate;

  @HiveField(2)
  int? duration; // Duration in days (optional)

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? updatedAt;

  PeriodLog({
    required this.id,
    required this.startDate,
    this.duration,
    required this.createdAt,
    this.updatedAt,
  });

  // Create a copy with updated fields
  PeriodLog copyWith({
    String? id,
    DateTime? startDate,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PeriodLog(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convert to Map (for JSON export)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  // Create from Map (for JSON import)
  factory PeriodLog.fromJson(Map<String, dynamic> json) {
    return PeriodLog(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      duration: json['duration'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  @override
  String toString() {
    return 'PeriodLog(id: $id, startDate: $startDate, duration: $duration)';
  }
}
