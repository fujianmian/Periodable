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

  /// Predict next period date using Gemini AI
  Future<Map<String, dynamic>?> predictNextPeriod(List<PeriodLog> logs) async {
    if (logs.length < AppConfig.minLogsForAI) {
      developer.log(
          'Not enough logs for AI prediction (need ${AppConfig.minLogsForAI}, have ${logs.length})');
      return null;
    }

    try {
      // Sort logs chronologically
      logs.sort((a, b) => a.startDate.compareTo(b.startDate));

      // Build the prompt
      final prompt = _buildPrompt(logs);

      developer.log('Sending prompt to Gemini API...');

      // Call Gemini API
      final response = await _model.generateContent([Content.text(prompt)]);

      if (response.text == null || response.text!.isEmpty) {
        developer.log('Empty response from Gemini API');
        return null;
      }

      developer.log('Gemini response: ${response.text}');

      // Parse the response
      return _parseGeminiResponse(response.text!, logs.last.startDate);
    } catch (e) {
      developer.log('Error calling Gemini API: $e');
      return null;
    }
  }

  /// Build the prompt for Gemini
  String _buildPrompt(List<PeriodLog> logs) {
    // Format the cycle data
    StringBuffer cycleData = StringBuffer();

    for (int i = 0; i < logs.length; i++) {
      cycleData.write(
          'Period ${i + 1}: ${logs[i].startDate.toString().split(' ')[0]}');

      if (i > 0) {
        final daysBetween =
            logs[i].startDate.difference(logs[i - 1].startDate).inDays;
        cycleData.write(' (${daysBetween} days from previous)');
      }

      cycleData.write('\n');
    }

    return '''
You are a menstrual cycle prediction assistant. Analyze the following period start dates and predict the next period date.

Historical Period Data:
$cycleData

Task:
1. Calculate the average cycle length
2. Identify any patterns or irregularities
3. Predict the EXACT date of the next period start
4. Provide a confidence score (0.0 to 1.0)

Response Format (MUST be valid JSON):
{
  "predicted_date": "YYYY-MM-DD",
  "average_cycle_length": <number>,
  "confidence": <0.0-1.0>,
  "reasoning": "<brief explanation>"
}

Important:
- Return ONLY the JSON object, no additional text
- Use ISO date format (YYYY-MM-DD)
- Confidence should reflect prediction certainty based on cycle regularity
- If cycles are irregular (standard deviation > 3 days), lower the confidence

Example Response:
{
  "predicted_date": "2025-02-15",
  "average_cycle_length": 28,
  "confidence": 0.85,
  "reasoning": "Cycles are very regular with minimal variation"
}
''';
  }

  /// Parse Gemini's JSON response
  Map<String, dynamic>? _parseGeminiResponse(
      String responseText, DateTime lastPeriodDate) {
    try {
      // Clean the response - remove markdown code blocks if present
      String cleanedText = responseText.trim();

      // Remove ```json and ``` if present
      if (cleanedText.startsWith('```json')) {
        cleanedText = cleanedText.substring(7);
      }
      if (cleanedText.startsWith('```')) {
        cleanedText = cleanedText.substring(3);
      }
      if (cleanedText.endsWith('```')) {
        cleanedText = cleanedText.substring(0, cleanedText.length - 3);
      }

      cleanedText = cleanedText.trim();

      // Try to find JSON object in the response
      final jsonStart = cleanedText.indexOf('{');
      final jsonEnd = cleanedText.lastIndexOf('}');

      if (jsonStart == -1 || jsonEnd == -1) {
        developer.log('No JSON object found in response');
        return null;
      }

      final jsonString = cleanedText.substring(jsonStart, jsonEnd + 1);

      // Parse JSON manually since we're avoiding dart:convert for simplicity
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
        developer.log('Missing required fields in JSON response');
        return null;
      }

      final predictedDate = DateTime.parse(predictedDateMatch.group(1)!);
      final avgCycle = int.parse(avgCycleMatch.group(1)!);
      final confidence = double.parse(confidenceMatch.group(1)!);
      final reasoning = reasoningMatch?.group(1) ?? 'No reasoning provided';

      // Validate the prediction makes sense
      final daysSinceLastPeriod =
          predictedDate.difference(lastPeriodDate).inDays;

      if (daysSinceLastPeriod < AppConfig.minCycleLength ||
          daysSinceLastPeriod > AppConfig.maxCycleLength + 10) {
        developer.log(
            'Predicted date is unrealistic: $daysSinceLastPeriod days from last period');
        return null;
      }

      return {
        'predicted_date': predictedDate,
        'average_cycle_length': avgCycle,
        'confidence': confidence.clamp(0.0, 1.0),
        'reasoning': reasoning,
      };
    } catch (e) {
      developer.log('Error parsing Gemini response: $e');
      developer.log('Response text: $responseText');
      return null;
    }
  }

  /// Test if API key is working
  Future<bool> testConnection() async {
    try {
      final response = await _model.generateContent(
          [Content.text('Reply with just "OK" if you can read this.')]);

      return response.text?.toLowerCase().contains('ok') ?? false;
    } catch (e) {
      developer.log('Gemini API connection test failed: $e');
      return false;
    }
  }
}
