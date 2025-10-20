import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/logger.dart';
import 'dart:developer' as developer;

class SettingsProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final NotificationService _notificationService = NotificationService();

  AppSettings _settings = AppSettings.defaultSettings();

  AppSettings get settings => _settings;

  // Getters for individual settings
  bool get notificationsEnabled => _settings.notificationsEnabled;
  int get reminderDaysBefore => _settings.reminderDaysBefore;
  String get theme => _settings.theme;
  bool get firstTimeUser => _settings.firstTimeUser;
  bool get useAIPrediction => _settings.useAIPrediction;
  String? get userEmail => _settings.userEmail; // NEW

  /// Initialize and load settings from database
  Future<void> init() async {
    try {
      _settings = _databaseService.getSettings();
      FileLogger.log(
          'Settings loaded: notifications=${_settings.notificationsEnabled}, AI=${_settings.useAIPrediction}, email=${_settings.userEmail}');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error loading settings: $e');
    }
  }

  /// Update user email (called after login)
  Future<void> updateUserEmail(String email) async {
    try {
      _settings = _settings.copyWith(userEmail: email);
      await _databaseService.saveSettings(_settings);
      FileLogger.log('User email updated: $email');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error updating user email: $e');
      rethrow;
    }
  }

  /// Clear user email (called on logout)
  Future<void> clearUserEmail() async {
    try {
      _settings = _settings.copyWith(userEmail: null);
      await _databaseService.saveSettings(_settings);
      FileLogger.log('User email cleared');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error clearing user email: $e');
      rethrow;
    }
  }

  /// Toggle notifications on/off
  Future<void> toggleNotifications(bool enabled) async {
    try {
      _settings = _settings.copyWith(notificationsEnabled: enabled);
      await _databaseService.saveSettings(_settings);

      if (!enabled) {
        // Cancel all notifications if disabled
        await _notificationService.cancelAllReminders();
        FileLogger.log('Notifications disabled, all reminders cancelled');
      } else {
        FileLogger.log('Notifications enabled');
      }

      notifyListeners();
    } catch (e) {
      FileLogger.log('Error toggling notifications: $e');
      rethrow;
    }
  }

  /// Update reminder days before period
  Future<void> updateReminderDays(int days) async {
    try {
      if (days < 1 || days > 7) {
        throw Exception('Reminder days must be between 1 and 7');
      }

      _settings = _settings.copyWith(reminderDaysBefore: days);
      await _databaseService.saveSettings(_settings);

      FileLogger.log('Reminder days updated to $days');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error updating reminder days: $e');
      rethrow;
    }
  }

  /// Toggle AI prediction on/off
  Future<void> toggleAIPrediction(bool enabled) async {
    try {
      _settings = _settings.copyWith(useAIPrediction: enabled);
      await _databaseService.saveSettings(_settings);

      FileLogger.log('AI prediction ${enabled ? "enabled" : "disabled"}');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error toggling AI prediction: $e');
      rethrow;
    }
  }

  /// Change theme
  Future<void> changeTheme(String newTheme) async {
    try {
      if (newTheme != 'light' && newTheme != 'dark') {
        throw Exception('Invalid theme: $newTheme');
      }

      _settings = _settings.copyWith(theme: newTheme);
      await _databaseService.saveSettings(_settings);

      FileLogger.log('Theme changed to $newTheme');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error changing theme: $e');
      rethrow;
    }
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    try {
      _settings = _settings.copyWith(firstTimeUser: false);
      await _databaseService.saveSettings(_settings);

      FileLogger.log('Onboarding completed');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error completing onboarding: $e');
      rethrow;
    }
  }

  /// Update last notification time
  Future<void> updateLastNotificationTime() async {
    try {
      _settings = _settings.copyWith(lastNotificationTime: DateTime.now());
      await _databaseService.saveSettings(_settings);
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error updating last notification time: $e');
    }
  }

  /// Reset all settings to default
  Future<void> resetToDefaults() async {
    try {
      _settings = AppSettings.defaultSettings();
      await _databaseService.saveSettings(_settings);

      FileLogger.log('Settings reset to defaults');
      notifyListeners();
    } catch (e) {
      FileLogger.log('Error resetting settings: $e');
      rethrow;
    }
  }

  /// Test notification (send immediately)
  Future<void> testNotification() async {
    try {
      await _notificationService.showImmediateNotification(
        title: '🩸 Test Notification',
        body: 'Your notifications are working correctly!',
      );
      FileLogger.log('Test notification sent');
    } catch (e) {
      FileLogger.log('Error sending test notification: $e');
      rethrow;
    }
  }

  /// Check if notifications are actually enabled on device
  Future<bool> checkNotificationPermissions() async {
    try {
      return await _notificationService.areNotificationsEnabled();
    } catch (e) {
      FileLogger.log('Error checking notification permissions: $e');
      return false;
    }
  }
}
