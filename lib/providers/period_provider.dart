// lib/providers/period_provider.dart

import 'package:flutter/foundation.dart';
import '../models/period_log.dart';
import '../models/prediction_data.dart';
import '../models/app_settings.dart'; // Import AppSettings
import '../services/database_service.dart';
import '../services/prediction_service.dart';
import '../services/notification_service.dart';
import '../providers/settings_provider.dart';
import '../utils/date_helpers.dart';
import 'dart:developer' as developer;

class PeriodProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final PredictionService _predictionService = PredictionService();
  final NotificationService _notificationService = NotificationService();
  SettingsProvider _settingsProvider;

  List<PeriodLog> _periodLogs = [];
  PredictionData? _currentPrediction;
  bool _isLoading = false;
  String? _error;

  PeriodProvider(this._settingsProvider);

  // Getters
  List<PeriodLog> get periodLogs => _periodLogs;
  PredictionData? get currentPrediction => _currentPrediction;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void updateDependencies(SettingsProvider newSettingsProvider) {
    _settingsProvider = newSettingsProvider;
  }

  List<PeriodLog> get chronologicalLogs {
    final logs = List<PeriodLog>.from(_periodLogs);
    logs.sort((a, b) => a.startDate.compareTo(b.startDate));
    return logs;
  }

  PeriodLog? get lastLog => _periodLogs.isNotEmpty ? _periodLogs.first : null;

  Future<void> init() async {
    try {
      _isLoading = true;
      notifyListeners();
      _periodLogs = _databaseService.getAllPeriodLogs();
      _currentPrediction = _databaseService.getLatestPrediction();
      developer.log(
          '[PeriodProvider] Initialized: ${_periodLogs.length} logs loaded.');
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load data: $e';
      _isLoading = false;
      developer.log('[PeriodProvider] Error initializing: $e');
      notifyListeners();
    }
  }

  // ... [Keep addPeriodLog, updatePeriodLog, deletePeriodLog, etc. the same]
  Future<void> addPeriodLog(DateTime date) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final existingLog = _databaseService.getPeriodLogByDate(date);
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
      );

      await _databaseService.addPeriodLog(log);
      _periodLogs = _databaseService.getAllPeriodLogs();
      developer.log('Period log added for ${DateHelpers.formatLongDate(date)}');
      await recalculatePrediction();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to add period log: $e';
      _isLoading = false;
      developer.log('Error adding period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Manually recalculate prediction
  Future<void> recalculatePrediction({AppSettings? updatedSettings}) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_periodLogs.isEmpty) {
        developer.log(
            '[PeriodProvider] Recalculation skipped: No period logs available.');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Use the provided updated settings if available, otherwise use the existing ones.
      final settingsToUse = updatedSettings ?? _settingsProvider.settings;

      developer.log('[PeriodProvider] Force recalculating prediction...');
      developer.log(
          '[PeriodProvider] Settings being used for prediction: userEmail=${settingsToUse.userEmail}, useAI=${settingsToUse.useAIPrediction}');

      final prediction = await _predictionService.predictNextPeriod(
        chronologicalLogs,
        settingsToUse, // Pass the correct settings object
      );

      await _databaseService.savePrediction(prediction);
      _currentPrediction = prediction;

      developer.log(
          '[PeriodProvider] New prediction saved: ${DateHelpers.formatLongDate(prediction.predictedDate)}');

      if (_settingsProvider.notificationsEnabled) {
        await _notificationService.scheduleReminder(
          prediction,
          _settingsProvider.reminderDaysBefore,
        );
        developer.log(
            '[PeriodProvider] Reminder scheduled for ${_settingsProvider.reminderDaysBefore} days before');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to recalculate prediction: $e';
      _isLoading = false;
      developer.log('[PeriodProvider] Error recalculating prediction: $e');
      notifyListeners();
      rethrow;
    }
  }

  // ... [Keep all other methods the same]
  Future<void> updatePeriodLog(PeriodLog log) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.updatePeriodLog(log);
      _periodLogs = _databaseService.getAllPeriodLogs();

      developer.log('Period log updated: ${log.id}');
      await recalculatePrediction();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to update period log: $e';
      _isLoading = false;
      developer.log('Error updating period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deletePeriodLog(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.deletePeriodLog(id);
      _periodLogs = _databaseService.getAllPeriodLogs();

      developer.log('Period log deleted: $id');
      await recalculatePrediction();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to delete period log: $e';
      _isLoading = false;
      developer.log('Error deleting period log: $e');
      notifyListeners();
      rethrow;
    }
  }

  bool hasLogOnDate(DateTime date) {
    return _periodLogs.any((log) => DateHelpers.isSameDay(log.startDate, date));
  }

  PeriodLog? getLogForDate(DateTime date) {
    try {
      return _periodLogs.firstWhere(
        (log) => DateHelpers.isSameDay(log.startDate, date),
      );
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? getCycleStats() {
    return _predictionService.calculateCycleStats(chronologicalLogs);
  }

  int? getDaysUntilNextPeriod() {
    if (_currentPrediction == null) return null;
    return DateHelpers.daysUntil(_currentPrediction!.predictedDate);
  }

  bool isPredictedDate(DateTime date) {
    if (_currentPrediction == null) return false;
    final daysFromPredicted =
        DateHelpers.daysBetween(_currentPrediction!.predictedDate, date).abs();
    return daysFromPredicted <= 2;
  }

  Map<String, dynamic> getStatistics() {
    return _databaseService.getStatistics();
  }

  Future<void> clearAllData() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.clearAllPeriodLogs();
      await _notificationService.cancelAllReminders();

      _periodLogs = [];
      _currentPrediction = null;

      developer.log('All data cleared');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear data: $e';
      _isLoading = false;
      developer.log('Error clearing data: $e');
      notifyListeners();
      rethrow;
    }
  }

  Map<String, dynamic> exportData() {
    return _databaseService.exportData();
  }

  Future<void> importData(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.importData(data);
      await init();

      developer.log('Data imported successfully');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to import data: $e';
      _isLoading = false;
      developer.log('Error importing data: $e');
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> testGeminiConnection() async {
    try {
      return await _predictionService.testGeminiConnection();
    } catch (e) {
      developer.log('Error testing Gemini connection: $e');
      return false;
    }
  }

  Future<void> refresh() async {
    await init();
  }
}
