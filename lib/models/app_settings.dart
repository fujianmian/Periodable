import 'package:hive/hive.dart';

part 'app_settings.g.dart';

@HiveType(typeId: 2)
class AppSettings extends HiveObject {
  @HiveField(0)
  bool notificationsEnabled;

  @HiveField(1)
  int reminderDaysBefore;

  @HiveField(2)
  String theme;

  @HiveField(3)
  bool firstTimeUser;

  @HiveField(4)
  DateTime? lastNotificationTime;

  // *** NEW: AI prediction preference ***
  @HiveField(5)
  bool useAIPrediction; // User can toggle AI on/off

  AppSettings({
    this.notificationsEnabled = true,
    this.reminderDaysBefore = 3,
    this.theme = 'light',
    this.firstTimeUser = true,
    this.lastNotificationTime,
    this.useAIPrediction = true, // Default to enabled
  });

  factory AppSettings.defaultSettings() {
    return AppSettings(
      notificationsEnabled: true,
      reminderDaysBefore: 3,
      theme: 'light',
      firstTimeUser: true,
      useAIPrediction: true,
    );
  }

  AppSettings copyWith({
    bool? notificationsEnabled,
    int? reminderDaysBefore,
    String? theme,
    bool? firstTimeUser,
    DateTime? lastNotificationTime,
    bool? useAIPrediction,
  }) {
    return AppSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      theme: theme ?? this.theme,
      firstTimeUser: firstTimeUser ?? this.firstTimeUser,
      lastNotificationTime: lastNotificationTime ?? this.lastNotificationTime,
      useAIPrediction: useAIPrediction ?? this.useAIPrediction,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'notificationsEnabled': notificationsEnabled,
      'reminderDaysBefore': reminderDaysBefore,
      'theme': theme,
      'firstTimeUser': firstTimeUser,
      'lastNotificationTime': lastNotificationTime?.toIso8601String(),
      'useAIPrediction': useAIPrediction,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      reminderDaysBefore: json['reminderDaysBefore'] ?? 3,
      theme: json['theme'] ?? 'light',
      firstTimeUser: json['firstTimeUser'] ?? true,
      lastNotificationTime: json['lastNotificationTime'] != null
          ? DateTime.parse(json['lastNotificationTime'])
          : null,
      useAIPrediction: json['useAIPrediction'] ?? true,
    );
  }
}
