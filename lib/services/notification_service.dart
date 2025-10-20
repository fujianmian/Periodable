import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/prediction_data.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import '../utils/date_helpers.dart';
import 'dart:developer' as developer;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> init() async {
    if (_initialized) return;

    try {
      // Initialize timezone
      tz.initializeTimeZones();

      // Android initialization settings
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions for iOS
      await _requestPermissions();

      _initialized = true;
      FileLogger.log('Notification service initialized');
    } catch (e) {
      FileLogger.log('Error initializing notifications: $e');
      rethrow;
    }
  }

  /// Request notification permissions (iOS and Android)
  Future<bool> _requestPermissions() async {
    if (_notifications.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>() !=
        null) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()!
          .requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    }

    if (_notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>() !=
        null) {
      final result = await _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestNotificationsPermission();
      return result ?? false;
    }

    return true;
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    FileLogger.log('Notification tapped: ${response.payload}');
  }

  /// Schedule a reminder notification with fallback
  Future<void> scheduleReminder(
    PredictionData prediction,
    int daysBefore,
  ) async {
    if (!_initialized) {
      await init();
    }

    try {
      // Calculate notification date (X days before predicted date)
      final notificationDate = prediction.predictedDate.subtract(
        Duration(days: daysBefore),
      );

      // Don't schedule if date is in the past
      if (notificationDate.isBefore(DateTime.now())) {
        FileLogger.log('Notification date is in the past, skipping');
        return;
      }

      // Cancel existing notifications
      await cancelAllReminders();

      // Convert to TZDateTime
      final scheduledDate = tz.TZDateTime.from(
        DateTime(
          notificationDate.year,
          notificationDate.month,
          notificationDate.day,
          9, // 9 AM
          0,
        ),
        tz.local,
      );

      // Create notification details
      const androidDetails = AndroidNotificationDetails(
        AppConfig.notificationChannelId,
        AppConfig.notificationChannelName,
        channelDescription: AppConfig.notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: AppColors.primary,
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final notificationMessage = daysBefore == 1
          ? 'Your period is expected tomorrow (${DateHelpers.formatShortDate(prediction.predictedDate)})'
          : 'Your period is expected in $daysBefore days (${DateHelpers.formatShortDate(prediction.predictedDate)})';

      try {
        // Try scheduling with exact alarms first
        await _notifications.zonedSchedule(
          0,
          '🩸 Period Reminder',
          notificationMessage,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'period_reminder',
        );

        FileLogger.log(
            'Reminder scheduled (EXACT) for ${DateHelpers.formatLongDate(notificationDate)} at 9:00 AM');
      } catch (e) {
        FileLogger.log('Exact alarm failed, falling back to inexact: $e');

        // Fallback to inexact alarms if exact fails
        await _notifications.zonedSchedule(
          0,
          '🩸 Period Reminder',
          notificationMessage,
          scheduledDate,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'period_reminder',
        );

        FileLogger.log(
            'Reminder scheduled (INEXACT) for ${DateHelpers.formatLongDate(notificationDate)} at 9:00 AM');
      }
    } catch (e) {
      FileLogger.log('Error scheduling reminder: $e');
      rethrow;
    }
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAllReminders() async {
    try {
      await _notifications.cancelAll();
      FileLogger.log('All reminders cancelled');
    } catch (e) {
      FileLogger.log('Error cancelling reminders: $e');
      rethrow;
    }
  }

  /// Cancel a specific reminder
  Future<void> cancelReminder(int id) async {
    try {
      await _notifications.cancel(id);
      FileLogger.log('Reminder $id cancelled');
    } catch (e) {
      FileLogger.log('Error cancelling reminder: $e');
      rethrow;
    }
  }

  /// Show an immediate notification (for testing)
  Future<void> showImmediateNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification',
  }) async {
    if (!_initialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId,
      AppConfig.notificationChannelName,
      channelDescription: AppConfig.notificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: AppColors.primary,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      title,
      body,
      notificationDetails,
      payload: 'test',
    );

    FileLogger.log('Immediate notification shown');
  }

  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (_notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>() !=
        null) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()!
              .areNotificationsEnabled() ??
          false;
    }

    return true;
  }
}
