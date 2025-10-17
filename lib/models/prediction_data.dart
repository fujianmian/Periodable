import 'package:hive/hive.dart';

part 'prediction_data.g.dart';

@HiveType(typeId: 1)
class PredictionData extends HiveObject {
  @HiveField(0)
  DateTime predictedDate;

  @HiveField(1)
  int averageCycleLength;

  @HiveField(2)
  double confidence; // 0.0 to 1.0

  @HiveField(3)
  DateTime calculatedAt;

  @HiveField(4)
  int? minCycle; // Optional: minimum cycle length observed

  @HiveField(5)
  int? maxCycle; // Optional: maximum cycle length observed

  @HiveField(6)
  String? reasoning;

  PredictionData({
    required this.predictedDate,
    required this.averageCycleLength,
    required this.confidence,
    required this.calculatedAt,
    this.minCycle,
    this.maxCycle,
    this.reasoning,
  });

  // Get prediction range (±2 days)
  DateTime get earliestDate => predictedDate.subtract(const Duration(days: 2));
  DateTime get latestDate => predictedDate.add(const Duration(days: 2));

  // Check if prediction is still valid (calculated within last 30 days)
  bool get isValid {
    final daysSinceCalculation = DateTime.now().difference(calculatedAt).inDays;
    return daysSinceCalculation <= 30;
  }

  // Get confidence level as text
  String get confidenceLevel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  Map<String, dynamic> toJson() {
    return {
      'predictedDate': predictedDate.toIso8601String(),
      'averageCycleLength': averageCycleLength,
      'confidence': confidence,
      'calculatedAt': calculatedAt.toIso8601String(),
      'minCycle': minCycle,
      'maxCycle': maxCycle,
      'reasoning': reasoning,
    };
  }

  factory PredictionData.fromJson(Map<String, dynamic> json) {
    return PredictionData(
      predictedDate: DateTime.parse(json['predictedDate']),
      averageCycleLength: json['averageCycleLength'],
      confidence: json['confidence'],
      calculatedAt: DateTime.parse(json['calculatedAt']),
      minCycle: json['minCycle'],
      maxCycle: json['maxCycle'],
      reasoning: json['reasoning'],
    );
  }

  @override
  String toString() {
    return 'PredictionData(predicted: $predictedDate, avgCycle: $averageCycleLength, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
  }
}
