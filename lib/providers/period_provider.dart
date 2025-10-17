import 'package:flutter/foundation.dart';
import '../models/period_log.dart';
import '../models/prediction_data.dart';
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
    // Add any logic here that needs to re-run when settings change
    // For example, you might want to recalculate predictions
    // notifyListeners(); // Call this if the update changes the UI
  }

  // Get logs in chronological order
  List<PeriodLog> get chronologicalLogs {
    final logs = List<PeriodLog>.from(_periodLogs);
    logs.sort((a, b) => a.startDate.compareTo(b.startDate));
    return logs;
  }

  // Get most recent log
  PeriodLog? get lastLog => _periodLogs.isNotEmpty ? _periodLogs.first : null;

  /// Initialize - load data from database
  Future<void> init() async {
    try {
      _isLoading = true;
      notifyListeners();

      _periodLogs = _databaseService.getAllPeriodLogs();
      _currentPrediction = _databaseService.getLatestPrediction();

      developer.log(
          'Period provider initialized: ${_periodLogs.length} logs loaded');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load data: $e';
      _isLoading = false;
      developer.log('Error initializing period provider: $e');
      notifyListeners();
    }
  }

  /// Add a new period log
  Future<void> addPeriodLog(DateTime date) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check if log already exists for this date
      final existingLog = _databaseService.getPeriodLogByDate(date);
      if (existingLog != null) {
        _error = 'A period log already exists for this date';
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Create new log
      final log = PeriodLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        startDate: DateHelpers.startOfDay(date),
        createdAt: DateTime.now(),
      );

      // Save to database
      await _databaseService.addPeriodLog(log);

      // Reload logs
      _periodLogs = _databaseService.getAllPeriodLogs();

      developer.log('Period log added for ${DateHelpers.formatLongDate(date)}');

      // Recalculate prediction
      await _updatePrediction();

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

  /// Update an existing period log
  Future<void> updatePeriodLog(PeriodLog log) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.updatePeriodLog(log);
      _periodLogs = _databaseService.getAllPeriodLogs();

      developer.log('Period log updated: ${log.id}');

      // Recalculate prediction
      await _updatePrediction();

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

  /// Delete a period log
  Future<void> deletePeriodLog(String id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.deletePeriodLog(id);
      _periodLogs = _databaseService.getAllPeriodLogs();

      developer.log('Period log deleted: $id');

      // Recalculate prediction
      await _updatePrediction();

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

  /// Check if a date has a logged period
  bool hasLogOnDate(DateTime date) {
    return _periodLogs.any((log) => DateHelpers.isSameDay(log.startDate, date));
  }

  /// Get log for a specific date
  PeriodLog? getLogForDate(DateTime date) {
    try {
      return _periodLogs.firstWhere(
        (log) => DateHelpers.isSameDay(log.startDate, date),
      );
    } catch (e) {
      return null;
    }
  }

  /// Update prediction (calculate new prediction and schedule notification)
  Future<void> _updatePrediction() async {
    try {
      if (_periodLogs.isEmpty) {
        _currentPrediction = null;
        await _databaseService.deletePrediction();
        await _notificationService.cancelAllReminders();
        developer.log('No logs available, prediction cleared');
        return;
      }

      // Check if recalculation is needed
      if (!_predictionService.shouldRecalculate(
          _currentPrediction, _periodLogs)) {
        developer.log('Prediction is still valid, skipping recalculation');
        return;
      }

      developer.log('Calculating new prediction...');

      // Calculate new prediction
      final prediction = await _predictionService.predictNextPeriod(
        chronologicalLogs,
        _settingsProvider.settings,
      );

      // Save prediction
      await _databaseService.savePrediction(prediction);
      _currentPrediction = prediction;

      developer.log(
          'New prediction: ${DateHelpers.formatLongDate(prediction.predictedDate)}');

      // Schedule notification if enabled
      if (_settingsProvider.notificationsEnabled) {
        await _notificationService.scheduleReminder(
          prediction,
          _settingsProvider.reminderDaysBefore,
        );
        developer.log(
            'Reminder scheduled for ${_settingsProvider.reminderDaysBefore} days before');
      }
    } catch (e) {
      developer.log('Error updating prediction: $e');
    }
  }

  /// Manually recalculate prediction
  Future<void> recalculatePrediction() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _updatePrediction();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to recalculate prediction: $e';
      _isLoading = false;
      developer.log('Error recalculating prediction: $e');
      notifyListeners();
      rethrow;
    }
  }

  /// Get cycle statistics
  Map<String, dynamic>? getCycleStats() {
    return _predictionService.calculateCycleStats(chronologicalLogs);
  }

  /// Get days until next predicted period
  int? getDaysUntilNextPeriod() {
    if (_currentPrediction == null) return null;
    return DateHelpers.daysUntil(_currentPrediction!.predictedDate);
  }

  /// Check if predicted date is in range (within ±2 days of a date)
  bool isPredictedDate(DateTime date) {
    if (_currentPrediction == null) return false;

    final daysFromPredicted = DateHelpers.daysBetween(
      _currentPrediction!.predictedDate,
      date,
    ).abs();

    return daysFromPredicted <= 2;
  }

  /// Get database statistics
  Map<String, dynamic> getStatistics() {
    return _databaseService.getStatistics();
  }

  /// Clear all data
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

  /// Export data as JSON
  Map<String, dynamic> exportData() {
    return _databaseService.exportData();
  }

  /// Import data from JSON
  Future<void> importData(Map<String, dynamic> data) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.importData(data);

      // Reload everything
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

  /// Test Gemini API connection
  Future<bool> testGeminiConnection() async {
    try {
      return await _predictionService.testGeminiConnection();
    } catch (e) {
      developer.log('Error testing Gemini connection: $e');
      return false;
    }
  }

  /// Refresh data from database
  Future<void> refresh() async {
    await init();
  }
}
