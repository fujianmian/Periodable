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

  /// Add a new period log
  Future<void> addPeriodLog(PeriodLog log) async {
    try {
      await _periodBox!.put(log.id, log);
      FileLogger.log('Period log added: ${log.startDate}');
    } catch (e) {
      FileLogger.log('Error adding period log: $e');
      rethrow;
    }
  }

  /// Get all period logs sorted by date (newest first)
  List<PeriodLog> getAllPeriodLogs() {
    try {
      final logs = _periodBox!.values.toList();
      logs.sort((a, b) => b.startDate.compareTo(a.startDate)); // Newest first
      return logs;
    } catch (e) {
      FileLogger.log('Error getting period logs: $e');
      return [];
    }
  }

  /// Get period logs in chronological order (oldest first)
  List<PeriodLog> getPeriodLogsChronological() {
    try {
      final logs = _periodBox!.values.toList();
      logs.sort((a, b) => a.startDate.compareTo(b.startDate)); // Oldest first
      return logs;
    } catch (e) {
      FileLogger.log('Error getting chronological period logs: $e');
      return [];
    }
  }

  /// Get period log by date
  PeriodLog? getPeriodLogByDate(DateTime date) {
    try {
      return _periodBox!.values.firstWhere(
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

  /// Get the most recent period log
  PeriodLog? getLastPeriodLog() {
    final logs = getAllPeriodLogs();
    return logs.isNotEmpty ? logs.first : null;
  }

  /// Get period logs within a date range
  List<PeriodLog> getPeriodLogsByDateRange(DateTime start, DateTime end) {
    try {
      return _periodBox!.values.where((log) {
        return log.startDate.isAfter(start.subtract(const Duration(days: 1))) &&
            log.startDate.isBefore(end.add(const Duration(days: 1)));
      }).toList();
    } catch (e) {
      FileLogger.log('Error getting period logs by date range: $e');
      return [];
    }
  }

  /// Check if a date has a logged period
  bool hasLogOnDate(DateTime date) {
    return getPeriodLogByDate(date) != null;
  }

  /// Get count of total logs
  int getPeriodLogCount() {
    return _periodBox!.length;
  }

  // ==================== PREDICTION OPERATIONS ====================

  /// Save prediction data
  Future<void> savePrediction(PredictionData prediction) async {
    try {
      // We only keep the latest prediction
      await _predictionBox!.clear();
      await _predictionBox!.add(prediction);
      FileLogger.log('Prediction saved: ${prediction.predictedDate}');
    } catch (e) {
      FileLogger.log('Error saving prediction: $e');
      rethrow;
    }
  }

  /// Get the latest prediction
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

  /// Clear all period logs
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

  /// Export all data as JSON
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

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      // Clear existing data
      await clearAllPeriodLogs();

      // Import period logs
      if (data['periodLogs'] != null) {
        for (var logJson in data['periodLogs']) {
          final log = PeriodLog.fromJson(logJson);
          await addPeriodLog(log);
        }
      }

      // Import prediction
      if (data['prediction'] != null) {
        final prediction = PredictionData.fromJson(data['prediction']);
        await savePrediction(prediction);
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

  /// Get database statistics
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
}
