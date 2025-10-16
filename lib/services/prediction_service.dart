import 'dart:math';
import '../models/period_log.dart';
import '../models/prediction_data.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import 'gemini_service.dart';
import 'dart:developer' as developer;

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  final GeminiService _geminiService = GeminiService();

  /// Main prediction method - tries AI first, falls back to statistical
  Future<PredictionData> predictNextPeriod(
    List<PeriodLog> logs,
    AppSettings settings,
  ) async {
    developer.log('Starting prediction with ${logs.length} logs');

    // Need at least 1 log to predict
    if (logs.isEmpty) {
      throw Exception('No period logs available for prediction');
    }

    // Sort logs chronologically
    logs.sort((a, b) => a.startDate.compareTo(b.startDate));

    // Try AI prediction if enabled and enough data
    if (settings.useAIPrediction &&
        logs.length >= AppConfig.minLogsForAI &&
        AppConfig.geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE') {
      developer.log('Attempting AI prediction...');

      try {
        final aiResult = await _geminiService.predictNextPeriod(logs);

        if (aiResult != null) {
          developer
              .log('AI prediction successful: ${aiResult['predicted_date']}');

          return PredictionData(
            predictedDate: aiResult['predicted_date'],
            averageCycleLength: aiResult['average_cycle_length'],
            confidence: aiResult['confidence'],
            calculatedAt: DateTime.now(),
          );
        } else {
          developer
              .log('AI prediction returned null, falling back to statistical');
        }
      } catch (e) {
        developer.log('AI prediction failed: $e, falling back to statistical');
      }
    } else {
      developer.log(
          'Using statistical prediction (AI disabled or insufficient data)');
    }

    // Fall back to statistical prediction
    return _statisticalPrediction(logs);
  }

  /// Statistical prediction algorithm (fallback when AI is unavailable)
  PredictionData _statisticalPrediction(List<PeriodLog> logs) {
    developer.log('Calculating statistical prediction');

    if (logs.length == 1) {
      // Only one log - use default cycle length
      final lastLog = logs.first;
      return PredictionData(
        predictedDate: lastLog.startDate.add(
          Duration(days: AppConfig.defaultCycleLength),
        ),
        averageCycleLength: AppConfig.defaultCycleLength,
        confidence: 0.3, // Low confidence with only 1 data point
        calculatedAt: DateTime.now(),
      );
    }

    // Calculate cycle lengths
    List<int> cycleLengths = [];
    for (int i = 1; i < logs.length; i++) {
      int daysBetween =
          logs[i].startDate.difference(logs[i - 1].startDate).inDays;

      // Filter out unrealistic cycles (data entry errors)
      if (daysBetween >= AppConfig.minCycleLength &&
          daysBetween <= AppConfig.maxCycleLength + 10) {
        cycleLengths.add(daysBetween);
      }
    }

    if (cycleLengths.isEmpty) {
      // All cycles were filtered out - use default
      final lastLog = logs.last;
      return PredictionData(
        predictedDate: lastLog.startDate.add(
          Duration(days: AppConfig.defaultCycleLength),
        ),
        averageCycleLength: AppConfig.defaultCycleLength,
        confidence: 0.3,
        calculatedAt: DateTime.now(),
      );
    }

    // Calculate average cycle length
    final avgCycle =
        (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();

    // Calculate standard deviation for confidence
    double variance = 0;
    for (var length in cycleLengths) {
      variance += pow(length - avgCycle, 2);
    }
    double stdDev = sqrt(variance / cycleLengths.length);

    // Calculate confidence based on:
    // 1. Consistency of cycles (lower std dev = higher confidence)
    // 2. Number of data points (more data = higher confidence)
    double consistencyScore =
        max(0.0, 1.0 - (stdDev / 5.0)); // Perfect if stdDev = 0
    double dataSufficiencyScore =
        min(1.0, cycleLengths.length / 6.0); // Ideal at 6+ cycles
    double confidence =
        (consistencyScore * 0.7 + dataSufficiencyScore * 0.3).clamp(0.3, 0.95);

    // Get min and max cycle lengths
    final minCycle = cycleLengths.reduce(min);
    final maxCycle = cycleLengths.reduce(max);

    // Predict next date
    final lastPeriod = logs.last.startDate;
    final predictedDate = lastPeriod.add(Duration(days: avgCycle));

    developer.log(
        'Statistical prediction: $predictedDate (avg: $avgCycle days, confidence: ${(confidence * 100).toStringAsFixed(0)}%)');

    return PredictionData(
      predictedDate: predictedDate,
      averageCycleLength: avgCycle,
      confidence: confidence,
      calculatedAt: DateTime.now(),
      minCycle: minCycle,
      maxCycle: maxCycle,
    );
  }

  /// Calculate cycle statistics without prediction
  Map<String, dynamic>? calculateCycleStats(List<PeriodLog> logs) {
    if (logs.length < 2) return null;

    logs.sort((a, b) => a.startDate.compareTo(b.startDate));

    List<int> cycleLengths = [];
    for (int i = 1; i < logs.length; i++) {
      int daysBetween =
          logs[i].startDate.difference(logs[i - 1].startDate).inDays;
      if (daysBetween >= AppConfig.minCycleLength &&
          daysBetween <= AppConfig.maxCycleLength + 10) {
        cycleLengths.add(daysBetween);
      }
    }

    if (cycleLengths.isEmpty) return null;

    final avgCycle =
        (cycleLengths.reduce((a, b) => a + b) / cycleLengths.length).round();
    final minCycle = cycleLengths.reduce(min);
    final maxCycle = cycleLengths.reduce(max);

    // Calculate standard deviation
    double variance = 0;
    for (var length in cycleLengths) {
      variance += pow(length - avgCycle, 2);
    }
    double stdDev = sqrt(variance / cycleLengths.length);

    // Determine regularity
    String regularity;
    if (stdDev <= 2) {
      regularity = 'Very Regular';
    } else if (stdDev <= 4) {
      regularity = 'Regular';
    } else if (stdDev <= 7) {
      regularity = 'Somewhat Irregular';
    } else {
      regularity = 'Irregular';
    }

    return {
      'averageCycle': avgCycle,
      'minCycle': minCycle,
      'maxCycle': maxCycle,
      'standardDeviation': stdDev.toStringAsFixed(1),
      'regularity': regularity,
      'totalCycles': cycleLengths.length,
    };
  }

  /// Check if a new prediction is needed
  bool shouldRecalculate(
      PredictionData? currentPrediction, List<PeriodLog> logs) {
    // No prediction exists
    if (currentPrediction == null) return true;

    // Prediction is old (more than 30 days)
    if (DateTime.now().difference(currentPrediction.calculatedAt).inDays > 30) {
      return true;
    }

    // New log was added after prediction was made
    if (logs.isNotEmpty) {
      final lastLog =
          logs.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
      if (lastLog.createdAt.isAfter(currentPrediction.calculatedAt)) {
        return true;
      }
    }

    // Predicted date has passed
    if (currentPrediction.predictedDate.isBefore(DateTime.now())) {
      return true;
    }

    return false;
  }

  /// Test Gemini API connection
  Future<bool> testGeminiConnection() async {
    if (AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      developer.log('Gemini API key not configured');
      return false;
    }

    try {
      return await _geminiService.testConnection();
    } catch (e) {
      developer.log('Gemini connection test failed: $e');
      return false;
    }
  }
}
