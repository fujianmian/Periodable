// lib/providers/period_provider.dart

import 'package:flutter/foundation.dart';
import '../models/period_log.dart';
import '../models/prediction_data.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../utils/date_helpers.dart';
import '../utils/logger.dart';
import 'dart:developer' as developer;
import './auth_provider.dart';

class PeriodProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final PredictionService _predictionService = PredictionService();
  final NotificationService _notificationService = NotificationService();
  SettingsProvider _settingsProvider;
  AuthProvider _authProvider;

  List<PeriodLog> _periodLogs = [];
  PredictionData? _currentPrediction;
  bool _isLoading = false;
  String? _error;
  String? _currentUserEmail; // Track current user

  PeriodProvider(this._settingsProvider, this._authProvider);

  // Getters
  List<PeriodLog> get periodLogs => _periodLogs;
  PredictionData? get currentPrediction => _currentPrediction;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserEmail => _currentUserEmail;

  void updateDependencies(
      SettingsProvider newSettingsProvider, AuthProvider newAuthProvider) {
    _settingsProvider = newSettingsProvider;
    _authProvider = newAuthProvider;
  }

  List<PeriodLog> get chronologicalLogs {
    final logs = List<PeriodLog>.from(_periodLogs);
    logs.sort((a, b) => a.startDate.compareTo(b.startDate));
    return logs;
  }

  PeriodLog? get lastLog => _periodLogs.isNotEmpty ? _periodLogs.first : null;

  /// Initialize provider with user-specific data
  Future<void> init({String? userEmail}) async {
    try {
      _isLoading = true;
      notifyListeners();

      if (userEmail != null) {
        _currentUserEmail = userEmail;
        _periodLogs = _databaseService.getPeriodLogsForUser(userEmail);
        _currentPrediction =
            _databaseService.getLatestPredictionForUser(userEmail);
        FileLogger.log(
            '[PeriodProvider] Initialized for user $userEmail: ${_periodLogs.length} logs loaded.');
      } else {
        _currentUserEmail = null;
        _periodLogs = [];
        _currentPrediction = null;
        FileLogger.log('[PeriodProvider] Initialized without user email.');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load data: $e';
      _isLoading = false;
      FileLogger.log('[PeriodProvider] Error initializing: $e');
      notifyListeners();
    }
  }

  /// Add a new period log for the current user
  Future<void> addPeriodLog(DateTime date, {String? userEmail}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Use provided email or current user email
      final emailToUse = userEmail ?? _currentUserEmail;
      if (emailToUse == null) {
        _error = 'No user email available. Please login first.';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final existingLog =
          _databaseService.getPeriodLogByDate(date, userEmail: emailToUse);
      if (existingLog != null) {
        _error = 'A period log already exists for this date';
        _isLoading = false;
        notifyListeners();
        return;
      }

      final log = PeriodLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startDate: DateHelpers.startOfDay(date),
        createdAt: DateTime.now(),
        userEmail: emailToUse,
      );

      await _databaseService.addPeriodLog(log, userEmail: emailToUse);
      _periodLogs = _databaseService.getPeriodLogsForUser(emailToUse);

      FileLogger.log(
          'Period log added for ${DateHelpers.formatLongDate(date)} by $emailToUse');
      await recalculatePrediction(userEmail: emailToUse);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add period log: $e';
      _isLoading = false;
      FileLogger.log('Error adding period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Update an existing period log
  Future<void> updatePeriodLog(PeriodLog log) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.updatePeriodLog(log);

      // Reload logs for current user
      if (_currentUserEmail != null) {
        _periodLogs = _databaseService.getPeriodLogsForUser(_currentUserEmail!);
      }

      FileLogger.log('Period log updated: ${log.id}');
      await recalculatePrediction(userEmail: _currentUserEmail);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update period log: $e';
      _isLoading = false;
      FileLogger.log('Error updating period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Delete a period log
  Future<void> deletePeriodLog(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.deletePeriodLog(id);

      // Reload logs for current user
      if (_currentUserEmail != null) {
        _periodLogs = _databaseService.getPeriodLogsForUser(_currentUserEmail!);
      }

      FileLogger.log('Period log deleted: $id');
      await recalculatePrediction(userEmail: _currentUserEmail);

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete period log: $e';
      _isLoading = false;
      FileLogger.log('Error deleting period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Manually recalculate prediction
  Future<void> recalculatePrediction({
    AppSettings? updatedSettings,
    String? userEmail,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_periodLogs.isEmpty) {
        FileLogger.log(
            '[PeriodProvider] Recalculation skipped: No period logs available.');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Use provided updated settings if available, otherwise use the existing ones.
      final settingsToUse = updatedSettings ?? _settingsProvider.settings;

      // Use provided email or current user email
      final emailToUse = userEmail ?? _currentUserEmail;

      FileLogger.log('[PeriodProvider] Force recalculating prediction...');
      FileLogger.log(
          '[PeriodProvider] Settings being used for prediction: userEmail=${settingsToUse.userEmail}, useAI=${settingsToUse.useAIPrediction}');

      final prediction = await _predictionService.predictNextPeriod(
        chronologicalLogs,
        settingsToUse,
      );

      // Add user email to prediction
      final predictionWithEmail = prediction.copyWith(userEmail: emailToUse);

      await _databaseService.savePrediction(predictionWithEmail,
          userEmail: emailToUse);
      _currentPrediction = predictionWithEmail;

      FileLogger.log(
          '[PeriodProvider] New prediction saved for user $emailToUse: ${DateHelpers.formatLongDate(prediction.predictedDate)}');

      if (_settingsProvider.notificationsEnabled) {
        await _notificationService.scheduleReminder(
          _currentPrediction!,
          _settingsProvider.reminderDaysBefore,
        );
        FileLogger.log(
            '[PeriodProvider] Reminder scheduled for ${_settingsProvider.reminderDaysBefore} days before');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to recalculate prediction: $e';
      _isLoading = false;
      FileLogger.log('[PeriodProvider] Error recalculating prediction: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Check if user has a log on specific date
  bool hasLogOnDate(DateTime date) {
    return _periodLogs.any((log) => DateHelpers.isSameDay(log.startDate, date));
  }

  /// Get log for specific date
  PeriodLog? getLogForDate(DateTime date) {
    try {
      return _periodLogs.firstWhere(
        (log) => DateHelpers.isSameDay(log.startDate, date),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get cycle statistics
  Map<String, dynamic>? getCycleStats() {
    return _predictionService.calculateCycleStats(chronologicalLogs);
  }

  /// Get days until next period
  int? getDaysUntilNextPeriod() {
    if (_currentPrediction == null) return null;
    return DateHelpers.daysUntil(_currentPrediction!.predictedDate);
  }

  /// Check if date is in predicted range
  bool isPredictedDate(DateTime date) {
    if (_currentPrediction == null) return false;
    final daysFromPredicted =
        DateHelpers.daysBetween(_currentPrediction!.predictedDate, date).abs();
    return daysFromPredicted <= 2;
  }

  /// Get statistics for current user
  Map<String, dynamic> getStatistics() {
    if (_currentUserEmail != null) {
      return _databaseService.getStatisticsForUser(_currentUserEmail!);
    }
    return {
      'totalLogs': 0,
      'firstLogDate': null,
      'lastLogDate': null,
      'averageCycle': null,
    };
  }

  /// Clear all data for current user
  Future<void> clearAllData() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_currentUserEmail != null) {
        await _databaseService.clearUserData(_currentUserEmail!);
        FileLogger.log('All data cleared for user: $_currentUserEmail');
      } else {
        await _databaseService.clearAllPeriodLogs();
        FileLogger.log('All data cleared');
      }

      await _notificationService.cancelAllReminders();

      _periodLogs = [];
      _currentPrediction = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear data: $e';
      _isLoading = false;
      FileLogger.log('Error clearing data: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Export data for current user
  Map<String, dynamic> exportData() {
    if (_currentUserEmail != null) {
      return _databaseService.exportDataForUser(_currentUserEmail!);
    }
    return _databaseService.exportData();
  }

  /// Import data for current user
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.importData(data, userEmail: _currentUserEmail);
      await init(userEmail: _currentUserEmail);

      FileLogger.log('Data imported successfully for user: $_currentUserEmail');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to import data: $e';
      _isLoading = false;
      FileLogger.log('Error importing data: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Test Gemini connection
  Future<bool> testGeminiConnection() async {
    try {
      return await _predictionService.testGeminiConnection();
    } catch (e) {
      FileLogger.log('Error testing Gemini connection: $e');
      return false;
    }
  }

  /// Refresh provider data for current user
  Future<void> refresh() async {
    await init(userEmail: _currentUserEmail);
  }

  /// Clear current user email (call on logout)
  void clearCurrentUser() {
    _currentUserEmail = null;
    _periodLogs = [];
    _currentPrediction = null;
    notifyListeners();
  }
}
