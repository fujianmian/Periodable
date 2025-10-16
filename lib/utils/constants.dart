import 'package:flutter/material.dart';

// App Colors
class AppColors {
  static const primary = Color(0xFFFF6B9D);
  static const secondary = Color(0xFFFFB6C1);
  static const background = Color(0xFFFFFAF5);
  static const textPrimary = Color(0xFF2D2D2D);
  static const textSecondary = Color(0xFF8E8E8E);
  static const periodDay = Color(0xFFFF6B9D);
  static const predictedDay = Color(0xFFFFE5EC);
  static const white = Color(0xFFFFFFFF);
}

// Text Styles
class AppTextStyles {
  static const heading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const subheading = TextStyle(
    fontFamily: 'Inter',
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const caption = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

// App Configuration
class AppConfig {
  static const String appName = 'My Cycle';
  static const int defaultReminderDays = 3;
  static const int defaultCycleLength = 28;
  static const int minCycleLength = 21;
  static const int maxCycleLength = 35;

  // Notification
  static const String notificationChannelId = 'period_reminder';
  static const String notificationChannelName = 'Period Reminders';
  static const String notificationChannelDescription =
      'Notifications for upcoming periods';

  // Database
  static const String periodLogBoxName = 'period_logs';
  static const String settingsBoxName = 'app_settings';
  static const String predictionBoxName = 'predictions';

  // *** NEW: Gemini API Configuration ***
  static const String geminiApiKey =
      'YOUR_GEMINI_API_KEY_HERE'; // Replace with your actual API key
  static const String geminiModel =
      'gemini-1.5-flash'; // or 'gemini-1.5-pro' for better accuracy

  // AI Prediction Settings
  static const bool useAIPrediction =
      true; // Set to false to use statistical method only
  static const int minLogsForAI = 3; // Minimum logs needed before using AI
}
