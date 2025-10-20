import 'package:hive_flutter/hive_flutter.dart';
import '../models/period_log.dart';
import '../models/prediction_data.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'dart:developer' as developer;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Box<PeriodLog>? _periodBox;
  Box<PredictionData>? _predictionBox;
  Box<AppSettings>? _settingsBox;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    try {
      // Initialize Hive
      await Hive.initFlutter();

      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PeriodLogAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PredictionDataAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(AppSettingsAdapter());
      }

      // Open boxes
      _periodBox = await Hive.openBox<PeriodLog>(AppConfig.periodLogBoxName);
      _predictionBox =
          await Hive.openBox<PredictionData>(AppConfig.predictionBoxName);
      _settingsBox = await Hive.openBox<AppSettings>(AppConfig.settingsBoxName);

      FileLogger.log('Database initialized successfully');

      // Initialize default settings if first time
      if (_settingsBox!.isEmpty) {
        await saveSettings(AppSettings.defaultSettings());
        FileLogger.log('Default settings created');
      }
    } catch (e) {
      FileLogger.log('Error initializing database: $e');
      rethrow;
    }
  }

  // ==================== PERIOD LOG OPERATIONS ====================

  /// Add a new period log with user email binding
  Future<void> addPeriodLog(PeriodLog log, {String? userEmail}) async {
    try {
      // Attach the current user's email to the log
      final logWithEmail = log.copyWith(userEmail: userEmail ?? log.userEmail);
      await _periodBox!.put(logWithEmail.id, logWithEmail);
      FileLogger.log('Period log added for user $userEmail: ${log.startDate}');
    } catch (e) {
      FileLogger.log('Error adding period log: $e');
      rethrow;
    }
  }

  /// Get all period logs for a specific user (newest first)
  List<PeriodLog> getPeriodLogsForUser(String userEmail) {
    try {
      final logs = _periodBox!.values
          .where(
              (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .toList();
      logs.sort((a, b) => b.startDate.compareTo(a.startDate));
      return logs;
    } catch (e) {
      FileLogger.log('Error getting period logs for user: $e');
      return [];
    }
  }

  /// Get period logs for a specific user in chronological order (oldest first)
  List<PeriodLog> getPeriodLogsChronologicalForUser(String userEmail) {
    try {
      final logs = _periodBox!.values
          .where(
              (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .toList();
      logs.sort((a, b) => a.startDate.compareTo(b.startDate));
      return logs;
    } catch (e) {
      FileLogger.log('Error getting chronological logs for user: $e');
      return [];
    }
  }

  /// Get all period logs sorted by date (newest first) - DEPRECATED
  /// Use getPeriodLogsForUser instead for user-specific data
  @Deprecated('Use getPeriodLogsForUser instead')
  List<PeriodLog> getAllPeriodLogs() {
    try {
      final logs = _periodBox!.values.toList();
      logs.sort((a, b) => b.startDate.compareTo(a.startDate));
      return logs;
    } catch (e) {
      FileLogger.log('Error getting period logs: $e');
      return [];
    }
  }

  /// Get period logs in chronological order (oldest first) - DEPRECATED
  /// Use getPeriodLogsChronologicalForUser instead for user-specific data
  @Deprecated('Use getPeriodLogsChronologicalForUser instead')
  List<PeriodLog> getPeriodLogsChronological() {
    try {
      final logs = _periodBox!.values.toList();
      logs.sort((a, b) => a.startDate.compareTo(b.startDate));
      return logs;
    } catch (e) {
      FileLogger.log('Error getting chronological period logs: $e');
      return [];
    }
  }

  /// Get period log by specific date for a user
  PeriodLog? getPeriodLogByDate(DateTime date, {String? userEmail}) {
    try {
      final allLogs = userEmail != null
          ? _periodBox!.values.where(
              (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase())
          : _periodBox!.values;

      return allLogs.firstWhere(
        (log) =>
            log.startDate.year == date.year &&
            log.startDate.month == date.month &&
            log.startDate.day == date.day,
        orElse: () => throw StateError('Not found'),
      );
    } catch (e) {
      return null;
    }
  }

  /// Update an existing period log
  Future<void> updatePeriodLog(PeriodLog log) async {
    try {
      log.updatedAt = DateTime.now();
      await _periodBox!.put(log.id, log);
      FileLogger.log('Period log updated: ${log.startDate}');
    } catch (e) {
      FileLogger.log('Error updating period log: $e');
      rethrow;
    }
  }

  /// Delete a period log
  Future<void> deletePeriodLog(String id) async {
    try {
      await _periodBox!.delete(id);
      FileLogger.log('Period log deleted: $id');
    } catch (e) {
      FileLogger.log('Error deleting period log: $e');
      rethrow;
    }
  }

  /// Get the most recent period log for a user
  PeriodLog? getLastPeriodLogForUser(String userEmail) {
    try {
      final logs = getPeriodLogsForUser(userEmail);
      return logs.isNotEmpty ? logs.first : null;
    } catch (e) {
      FileLogger.log('Error getting last period log: $e');
      return null;
    }
  }

  /// Get the most recent period log (all users) - DEPRECATED
  @Deprecated('Use getLastPeriodLogForUser instead')
  PeriodLog? getLastPeriodLog() {
    final logs = getAllPeriodLogs();
    return logs.isNotEmpty ? logs.first : null;
  }

  /// Get period logs within a date range (all users) - Consider making user-specific
  List<PeriodLog> getPeriodLogsByDateRange(DateTime start, DateTime end,
      {String? userEmail}) {
    try {
      var logs = _periodBox!.values.where((log) {
        return log.startDate.isAfter(start.subtract(const Duration(days: 1))) &&
            log.startDate.isBefore(end.add(const Duration(days: 1)));
      });

      // Filter by user if provided
      if (userEmail != null) {
        logs = logs.where(
            (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase());
      }

      return logs.toList();
    } catch (e) {
      FileLogger.log('Error getting period logs by date range: $e');
      return [];
    }
  }

  /// Check if a date has a logged period for a user
  bool hasLogOnDateForUser(DateTime date, String userEmail) {
    return getPeriodLogByDate(date, userEmail: userEmail) != null;
  }

  /// Get count of total logs for a user
  int getPeriodLogCountForUser(String userEmail) {
    try {
      return _periodBox!.values
          .where(
              (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .length;
    } catch (e) {
      FileLogger.log('Error getting period log count: $e');
      return 0;
    }
  }

  /// Get count of total logs (all users) - DEPRECATED
  @Deprecated('Use getPeriodLogCountForUser instead')
  int getPeriodLogCount() {
    return _periodBox!.length;
  }

  // ==================== PREDICTION OPERATIONS ====================

  /// Save prediction data for a user
  Future<void> savePrediction(PredictionData prediction,
      {String? userEmail}) async {
    try {
      // We keep only one prediction per user
      // Clear old predictions for this user
      if (userEmail != null) {
        final userPredictions = _predictionBox!.values
            .where((p) => p.userEmail?.toLowerCase() == userEmail.toLowerCase())
            .toList();

        for (var pred in userPredictions) {
          await pred.delete();
        }
      }

      // Save new prediction with user email
      final predictionWithEmail =
          prediction.copyWith(userEmail: userEmail ?? prediction.userEmail);
      await _predictionBox!.add(predictionWithEmail);
      FileLogger.log(
          'Prediction saved for user $userEmail: ${prediction.predictedDate}');
    } catch (e) {
      FileLogger.log('Error saving prediction: $e');
      rethrow;
    }
  }

  /// Get the latest prediction for a specific user
  PredictionData? getLatestPredictionForUser(String userEmail) {
    try {
      if (_predictionBox!.isEmpty) return null;
      final userPredictions = _predictionBox!.values
          .where((p) => p.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .toList();
      return userPredictions.isNotEmpty ? userPredictions.first : null;
    } catch (e) {
      FileLogger.log('Error getting prediction for user: $e');
      return null;
    }
  }

  /// Get the latest prediction (all users) - DEPRECATED
  @Deprecated('Use getLatestPredictionForUser instead')
  PredictionData? getLatestPrediction() {
    try {
      if (_predictionBox!.isEmpty) return null;
      return _predictionBox!.values.first;
    } catch (e) {
      FileLogger.log('Error getting prediction: $e');
      return null;
    }
  }

  /// Delete prediction data
  Future<void> deletePrediction() async {
    try {
      await _predictionBox!.clear();
      FileLogger.log('Prediction deleted');
    } catch (e) {
      FileLogger.log('Error deleting prediction: $e');
      rethrow;
    }
  }

  /// Clear all data for a specific user
  Future<void> clearUserData(String userEmail) async {
    try {
      // Delete period logs for this user
      final logsToDelete = _periodBox!.values
          .where(
              (log) => log.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .toList();
      for (var log in logsToDelete) {
        await log.delete();
      }

      // Delete predictions for this user
      final predictionsToDelete = _predictionBox!.values
          .where((p) => p.userEmail?.toLowerCase() == userEmail.toLowerCase())
          .toList();
      for (var pred in predictionsToDelete) {
        await pred.delete();
      }

      FileLogger.log('All data cleared for user: $userEmail');
    } catch (e) {
      FileLogger.log('Error clearing user data: $e');
      rethrow;
    }
  }

  // ==================== SETTINGS OPERATIONS ====================

  /// Save app settings
  Future<void> saveSettings(AppSettings settings) async {
    try {
      await _settingsBox!.clear();
      await _settingsBox!.add(settings);
      FileLogger.log('Settings saved');
    } catch (e) {
      FileLogger.log('Error saving settings: $e');
      rethrow;
    }
  }

  /// Get app settings
  AppSettings getSettings() {
    try {
      if (_settingsBox!.isEmpty) {
        return AppSettings.defaultSettings();
      }
      return _settingsBox!.values.first;
    } catch (e) {
      FileLogger.log('Error getting settings: $e');
      return AppSettings.defaultSettings();
    }
  }

  /// Update specific setting
  Future<void> updateSettings(AppSettings settings) async {
    await saveSettings(settings);
  }

  // ==================== DATA MANAGEMENT ====================

  /// Clear all period logs and predictions (all users)
  Future<void> clearAllPeriodLogs() async {
    try {
      await _periodBox!.clear();
      await _predictionBox!.clear();
      FileLogger.log('All period logs cleared');
    } catch (e) {
      FileLogger.log('Error clearing period logs: $e');
      rethrow;
    }
  }

  /// Export all data as JSON (all users)
  Map<String, dynamic> exportData() {
    try {
      return {
        'periodLogs': _periodBox!.values.map((log) => log.toJson()).toList(),
        'prediction': getLatestPrediction()?.toJson(),
        'settings': getSettings().toJson(),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      FileLogger.log('Error exporting data: $e');
      rethrow;
    }
  }

  /// Export data for a specific user
  Map<String, dynamic> exportDataForUser(String userEmail) {
    try {
      final userPrediction = getLatestPredictionForUser(userEmail);
      return {
        'periodLogs': _periodBox!.values
            .where((log) =>
                log.userEmail?.toLowerCase() == userEmail.toLowerCase())
            .map((log) => log.toJson())
            .toList(),
        'prediction': userPrediction?.toJson(),
        'settings': getSettings().toJson(),
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      FileLogger.log('Error exporting data for user: $e');
      rethrow;
    }
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data,
      {String? userEmail}) async {
    try {
      // If userEmail is provided, clear only that user's data
      if (userEmail != null) {
        await clearUserData(userEmail);
      } else {
        // Otherwise clear all data (backward compatibility)
        await clearAllPeriodLogs();
      }

      // Import period logs
      if (data['periodLogs'] != null) {
        for (var logJson in data['periodLogs']) {
          final log = PeriodLog.fromJson(logJson);
          // Override userEmail if provided
          final finalLog =
              userEmail != null ? log.copyWith(userEmail: userEmail) : log;
          await addPeriodLog(finalLog, userEmail: finalLog.userEmail);
        }
      }

      // Import prediction
      if (data['prediction'] != null) {
        final prediction = PredictionData.fromJson(data['prediction']);
        // Override userEmail if provided
        final finalPrediction = userEmail != null
            ? prediction.copyWith(userEmail: userEmail)
            : prediction;
        await savePrediction(finalPrediction,
            userEmail: finalPrediction.userEmail);
      }

      // Import settings
      if (data['settings'] != null) {
        final settings = AppSettings.fromJson(data['settings']);
        await saveSettings(settings);
      }

      FileLogger.log('Data imported successfully');
    } catch (e) {
      FileLogger.log('Error importing data: $e');
      rethrow;
    }
  }

  /// Close all boxes (call when app is disposed)
  Future<void> close() async {
    await _periodBox?.close();
    await _predictionBox?.close();
    await _settingsBox?.close();
    FileLogger.log('Database closed');
  }

  /// Get database statistics for all users
  @Deprecated('Use getStatisticsForUser instead')
  Map<String, dynamic> getStatistics() {
    final logs = getPeriodLogsChronological();

    if (logs.isEmpty) {
      return {
        'totalLogs': 0,
        'firstLogDate': null,
        'lastLogDate': null,
        'averageCycle': null,
      };
    }

    // Calculate average cycle
    int? avgCycle;
    if (logs.length >= 2) {
      List<int> cycles = [];
      for (int i = 1; i < logs.length; i++) {
        cycles.add(logs[i].startDate.difference(logs[i - 1].startDate).inDays);
      }
      avgCycle = (cycles.reduce((a, b) => a + b) / cycles.length).round();
    }

    return {
      'totalLogs': logs.length,
      'firstLogDate': logs.first.startDate,
      'lastLogDate': logs.last.startDate,
      'averageCycle': avgCycle,
    };
  }

  /// Get database statistics for a specific user
  Map<String, dynamic> getStatisticsForUser(String userEmail) {
    final logs = getPeriodLogsChronologicalForUser(userEmail);

    if (logs.isEmpty) {
      return {
        'totalLogs': 0,
        'firstLogDate': null,
        'lastLogDate': null,
        'averageCycle': null,
      };
    }

    // Calculate average cycle
    int? avgCycle;
    if (logs.length >= 2) {
      List<int> cycles = [];
      for (int i = 1; i < logs.length; i++) {
        cycles.add(logs[i].startDate.difference(logs[i - 1].startDate).inDays);
      }
      avgCycle = (cycles.reduce((a, b) => a + b) / cycles.length).round();
    }

    return {
      'totalLogs': logs.length,
      'firstLogDate': logs.first.startDate,
      'lastLogDate': logs.last.startDate,
      'averageCycle': avgCycle,
    };
  }
}
