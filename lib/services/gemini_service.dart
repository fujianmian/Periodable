// lib/services/gemini_service.dart

import 'package:google_generative_ai/google_generative_ai.dart';
import '../utils/constants.dart';
import '../models/period_log.dart';
import 'dart:developer' as developer;

class GeminiService {
  late final GenerativeModel _model;

  GeminiService() {
    _model = GenerativeModel(
      model: AppConfig.geminiModel,
      apiKey: AppConfig.geminiApiKey,
    );
  }

  /// Predict next period date using Gemini AI (ALWAYS uses AI, no fallback)
  Future<Map<String, dynamic>?> predictNextPeriod(List<PeriodLog> logs) async {
    if (logs.isEmpty) {
      developer.log('No logs available for AI prediction');
      return null;
    }

    try {
      // Sort logs chronologically
      logs.sort((a, b) => a.startDate.compareTo(b.startDate));

      // Build the prompt
      final prompt = _buildPrompt(logs);

      developer.log('Sending prompt to Gemini API for AI prediction...');

      // Call Gemini API
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.isEmpty) {
        developer.log('Empty response from Gemini API');
        return null;
      }

      developer.log('Gemini AI response received: ${response.text}');

      // Parse the response
      final result = _parseGeminiResponse(response.text!, logs.last.startDate);

      if (result != null) {
        developer.log('AI prediction successfully generated: $result');
      }

      return result;
    } catch (e) {
      developer.log('Error calling Gemini API: $e');
      rethrow; // Let caller handle the error
    }
  }

  /// Build the prompt for Gemini with clear AI prediction instructions
  String _buildPrompt(List<PeriodLog> logs) {
    // Format the cycle data
    StringBuffer cycleData = StringBuffer();
    List<int> cycleLengths = [];

    for (int i = 0; i < logs.length; i++) {
      cycleData.write(
          'Period ${i + 1}: ${logs[i].startDate.toString().split(' ')[0]}');

      if (i > 0) {
        final daysBetween =
            logs[i].startDate.difference(logs[i - 1].startDate).inDays;
        cycleData.write(' (${daysBetween} days from previous)');
        cycleLengths.add(daysBetween);
      }

      cycleData.write('\n');
    }

    // Calculate stats to give AI context
    double averageCycle = cycleLengths.isEmpty
        ? 28.0
        : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;

    return '''
You are an advanced AI menstrual cycle prediction specialist with expertise in pattern recognition and medical data analysis.

HISTORICAL PERIOD DATA:
$cycleData

ANALYSIS CONTEXT:
- Total periods logged: ${logs.length}
- Cycle lengths observed: ${cycleLengths.isEmpty ? 'N/A' : cycleLengths.join(', ')} days
- Average cycle length (preliminary): ${averageCycle.toStringAsFixed(1)} days
- Last period start date: ${logs.last.startDate.toString().split(' ')[0]}

YOUR TASK:
Analyze this menstrual cycle data and provide a precise prediction for the NEXT period start date. Consider:
1. Overall cycle regularity and consistency
2. Any trends (increasing/decreasing cycle length)
3. Outliers or irregular cycles (filter if needed)
4. Statistical confidence in the prediction

RESPONSE FORMAT (MUST be valid JSON only):
{
  "predicted_date": "YYYY-MM-DD",
  "average_cycle_length": <integer>,
  "confidence": <float between 0.0 and 1.0>,
  "reasoning": "<string explaining the prediction logic>"
}

CRITICAL REQUIREMENTS:
- Return ONLY the JSON object with no additional text or explanation
- Do NOT include markdown formatting or code blocks
- Use ISO 8601 date format (YYYY-MM-DD)
- predicted_date MUST be in the future
- predicted_date should be approximately average_cycle_length days after the last period
- confidence should be 0.0-1.0 (1.0 = very confident, 0.0 = very uncertain)
- Base confidence on cycle consistency: regular cycles = higher confidence, irregular = lower confidence
- Include brief reasoning explaining your calculation method

Generate the prediction now:
''';
  }

  /// Parse Gemini's JSON response - handles various response formats
  Map<String, dynamic>? _parseGeminiResponse(
      String responseText, DateTime lastPeriodDate) {
    try {
      developer.log('Parsing Gemini response: $responseText');

      // Clean the response
      String cleanedText = responseText.trim();

      // Remove markdown code blocks if present
      if (cleanedText.contains('```json')) {
        cleanedText = cleanedText.replaceAll(RegExp(r'```json\n?'), '');
      }
      if (cleanedText.contains('```')) {
        cleanedText = cleanedText.replaceAll(RegExp(r'```\n?'), '');
      }

      cleanedText = cleanedText.trim();

      // Find JSON object
      final jsonStart = cleanedText.indexOf('{');
      final jsonEnd = cleanedText.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1) {
        developer.log('ERROR: No JSON object found in response');
        return null;
      }

      final jsonString = cleanedText.substring(jsonStart, jsonEnd + 1);
      developer.log('Extracted JSON: $jsonString');

      // Extract fields using regex
      final predictedDateMatch =
          RegExp(r'"predicted_date"\s*:\s*"([^"]+)"').firstMatch(jsonString);
      final avgCycleMatch =
          RegExp(r'"average_cycle_length"\s*:\s*(\d+)').firstMatch(jsonString);
      final confidenceMatch =
          RegExp(r'"confidence"\s*:\s*([\d.]+)').firstMatch(jsonString);
      final reasoningMatch =
          RegExp(r'"reasoning"\s*:\s*"([^"]+)"').firstMatch(jsonString);

      if (predictedDateMatch == null ||
          avgCycleMatch == null ||
          confidenceMatch == null) {
        developer.log('ERROR: Missing required fields in JSON');
        developer.log('Date match: $predictedDateMatch');
        developer.log('Cycle match: $avgCycleMatch');
        developer.log('Confidence match: $confidenceMatch');
        return null;
      }

      final predictedDate = DateTime.parse(predictedDateMatch.group(1)!);
      final avgCycle = int.parse(avgCycleMatch.group(1)!);
      final confidence = double.parse(confidenceMatch.group(1)!);
      final reasoning = reasoningMatch?.group(1) ?? 'AI-generated prediction';

      // Validate prediction is reasonable
      final daysSinceLastPeriod =
          predictedDate.difference(lastPeriodDate).inDays;

      developer.log(
          'Validation: Days since last period = $daysSinceLastPeriod, min = ${AppConfig.minCycleLength}, max = ${AppConfig.maxCycleLength + 10}');

      if (daysSinceLastPeriod < AppConfig.minCycleLength ||
          daysSinceLastPeriod > AppConfig.maxCycleLength + 10) {
        developer.log(
            'WARNING: Predicted date seems unrealistic ($daysSinceLastPeriod days), but returning anyway per AI result');
      }

      final result = {
        'predicted_date': predictedDate,
        'average_cycle_length': avgCycle,
        'confidence': confidence.clamp(0.0, 1.0),
        'reasoning': reasoning,
      };

      developer.log('Successfully parsed AI prediction: $result');
      return result;
    } catch (e) {
      developer.log('ERROR parsing Gemini response: $e');
      developer.log('Response text was: $responseText');
      return null;
    }
  }

  /// Test if Gemini API key is working
  Future<bool> testConnection() async {
    try {
      developer.log('Testing Gemini API connection...');

      final response = await _model.generateContent(
          [Content.text('Respond with ONLY the word: SUCCESS')]);

      final text = response.text?.toUpperCase().trim() ?? '';
      final isConnected = text.contains('SUCCESS');

      developer.log(
          'Gemini connection test result: $isConnected (response: "$text")');
      return isConnected;
    } catch (e) {
      developer.log('Gemini API connection test FAILED: $e');
      return false;
    }
  }
}
