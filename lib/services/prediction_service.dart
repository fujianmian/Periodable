// lib/services/prediction_service.dart

import '../models/period_log.dart';
import '../models/prediction_data.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';
import 'gemini_service.dart';
import 'dart:developer' as developer;

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  final GeminiService _geminiService = GeminiService();

  // Premium user emails
  static const List<String> PREMIUM_USER_EMAILS = [
    'jun379e@gmail.com',
    'junyong112204@gmail.com',
  ];

  /// Main prediction method - uses AI for premium user, local calculation for others
  Future<PredictionData> predictNextPeriod(
    List<PeriodLog> logs,
    AppSettings settings,
  ) async {
    FileLogger.log('[PredictionService] predictNextPeriod called.');

    if (logs.isEmpty) {
      throw Exception('No period logs available for prediction');
    }

    logs.sort((a, b) => a.startDate.compareTo(b.startDate));

    FileLogger.log(
        '[PredictionService] Settings received: userEmail=${settings.userEmail}, useAI=${settings.useAIPrediction}');

    final isPremiumUser = _isPremiumUser(settings);

    FileLogger.log(
        '[PredictionService] isPremiumUser check returned: $isPremiumUser');

    if (isPremiumUser) {
      return _predictWithAI(logs);
    } else {
      return _predictLocally(logs);
    }
  }

  /// Check if the user is the premium user AND has AI enabled
  bool _isPremiumUser(AppSettings settings) {
    final email = settings.userEmail;
    final result = settings.useAIPrediction &&
        email != null &&
        PREMIUM_USER_EMAILS.contains(email.toLowerCase());
    FileLogger.log(
        '[PredictionService] _isPremiumUser check: useAI=${settings.useAIPrediction}, email=${settings.userEmail}, result=$result');
    return result;
  }

  /// AI-powered prediction
  Future<PredictionData> _predictWithAI(List<PeriodLog> logs) async {
    FileLogger.log('-----> [PredictionService] Path selected: _predictWithAI');

    if (AppConfig.geminiApiKey.isEmpty ||
        AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      FileLogger.log(
          '[PredictionService] AI prediction failed: Gemini API key not configured.');
      throw Exception(
          'Gemini API key not configured. Please check your .env file or Remote Config.');
    }

    try {
      final aiResult = await _geminiService.predictNextPeriod(logs);

      if (aiResult == null) {
        throw Exception(
            'Gemini API returned null. Check your API key and internet connection.');
      }

      FileLogger.log(
          '[PredictionService] AI prediction successful: ${aiResult['predicted_date']}');

      return PredictionData(
        predictedDate: aiResult['predicted_date'],
        averageCycleLength: aiResult['average_cycle_length'],
        confidence: aiResult['confidence'],
        calculatedAt: DateTime.now(),
        reasoning: aiResult['reasoning'],
      );
    } catch (e) {
      FileLogger.log('[PredictionService] AI prediction failed: $e');
      rethrow;
    }
  }

  /// Local prediction (no AI required)
  Future<PredictionData> _predictLocally(List<PeriodLog> logs) async {
    FileLogger.log('-----> [PredictionService] Path selected: _predictLocally');

    final cycleStats = calculateCycleStats(logs);

    if (cycleStats == null) {
      return _predictWithDefaultCycle(logs.last.startDate);
    }

    final averageCycle = cycleStats['averageCycle'] as int;
    final regularity = cycleStats['regularity'] as String;

    final nextPeriodDate =
        logs.last.startDate.add(Duration(days: averageCycle));

    double confidence = _getConfidenceFromRegularity(regularity);

    String reasoning = _buildLocalReasoning(
      averageCycle,
      logs.length,
      regularity,
    );

    developer
        .log('Local prediction: $nextPeriodDate with confidence $confidence');

    return PredictionData(
      predictedDate: nextPeriodDate,
      averageCycleLength: averageCycle,
      confidence: confidence,
      calculatedAt: DateTime.now(),
      reasoning: reasoning,
    );
  }

  PredictionData _predictWithDefaultCycle(DateTime lastPeriodDate) {
    const defaultCycle = 28;
    final nextPeriodDate =
        lastPeriodDate.add(const Duration(days: defaultCycle));

    return PredictionData(
      predictedDate: nextPeriodDate,
      averageCycleLength: defaultCycle,
      confidence: 0.3,
      calculatedAt: DateTime.now(),
      reasoning:
          'Based on standard 28-day cycle. Log more periods for better accuracy.',
    );
  }

  double _getConfidenceFromRegularity(String regularity) {
    switch (regularity) {
      case 'Very Regular':
        return 0.85;
      case 'Regular':
        return 0.70;
      case 'Somewhat Irregular':
        return 0.55;
      case 'Irregular':
        return 0.40;
      default:
        return 0.30;
    }
  }

  String _buildLocalReasoning(
      int averageCycle, int logsCount, String regularity) {
    if (logsCount < 2) {
      return 'Based on standard 28-day cycle. Add more logs for accurate predictions.';
    }

    if (logsCount == 2) {
      return 'Based on your 2 logged cycles averaging $averageCycle days. Cycle is $regularity.';
    }

    return 'Based on ${logsCount - 1} cycle(s) averaging $averageCycle days. Your cycle is $regularity. Minimum 2 consecutive months required for reliable predictions.';
  }

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
    final minCycle = cycleLengths.reduce((a, b) => a < b ? a : b);
    final maxCycle = cycleLengths.reduce((a, b) => a > b ? a : b);

    double variance = 0;
    for (var length in cycleLengths) {
      variance += (length - avgCycle) * (length - avgCycle);
    }
    double stdDev = (variance / cycleLengths.length).toDouble();
    stdDev = (stdDev * stdDev).toDouble();

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

  bool shouldRecalculate(
      PredictionData? currentPrediction, List<PeriodLog> logs) {
    if (currentPrediction == null) return true;
    if (DateTime.now().difference(currentPrediction.calculatedAt).inDays > 30) {
      return true;
    }
    if (logs.isNotEmpty) {
      final lastLog =
          logs.reduce((a, b) => a.startDate.isAfter(b.startDate) ? a : b);
      if (lastLog.createdAt.isAfter(currentPrediction.calculatedAt)) {
        return true;
      }
    }
    if (currentPrediction.predictedDate.isBefore(DateTime.now())) {
      return true;
    }
    return false;
  }

  Future<bool> testGeminiConnection() async {
    if (AppConfig.geminiApiKey.isEmpty ||
        AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE') {
      FileLogger.log('Gemini API key not configured');
      return false;
    }
    try {
      return await _geminiService.testConnection();
    } catch (e) {
      FileLogger.log('Gemini connection test failed: $e');
      return false;
    }
  }
}
