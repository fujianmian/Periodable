import 'package:hive/hive.dart';

part 'period_log.g.dart';

@HiveType(typeId: 0)
class PeriodLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime startDate;

  @HiveField(2)
  int? duration;

  @HiveField(3)
  DateTime createdAt;

  @HiveField(4)
  DateTime? updatedAt;

  @HiveField(5) // NEW FIELD
  String? userEmail; // Email of the user who created this log

  PeriodLog({
    required this.id,
    required this.startDate,
    this.duration,
    required this.createdAt,
    this.updatedAt,
    this.userEmail, // NEW
  });

  PeriodLog copyWith({
    String? id,
    DateTime? startDate,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userEmail, // NEW
  }) {
    return PeriodLog(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userEmail: userEmail ?? this.userEmail, // NEW
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'duration': duration,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'userEmail': userEmail, // NEW
    };
  }

  factory PeriodLog.fromJson(Map<String, dynamic> json) {
    return PeriodLog(
      id: json['id'],
      startDate: DateTime.parse(json['startDate']),
      duration: json['duration'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      userEmail: json['userEmail'], // NEW
    );
  }

  @override
  String toString() {
    return 'PeriodLog(id: $id, startDate: $startDate, duration: $duration, userEmail: $userEmail)';
  }
}
