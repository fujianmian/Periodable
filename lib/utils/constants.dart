import 'package:flutter/material.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

// App Configuration with Remote Config Integration
class AppConfig {
  static const String appName = 'My Cycle';

  // Default values (used as fallbacks)
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

  // API Configuration (loaded from Remote Config or .env)
  static String _geminiApiKey = '';
  static String _apiUrl = '';
  static String _geminiModel = 'gemini-2.5-flash';
  static bool _useAIPrediction = true;
  static int _minLogsForAI = 3;
  static bool _initialized = false;

  // Getters to access values
  static String get geminiApiKey => _geminiApiKey;
  static String get apiUrl => _apiUrl;
  static String get geminiModel => _geminiModel;
  static bool get useAIPrediction => _useAIPrediction;
  static int get minLogsForAI => _minLogsForAI;
  static bool get isInitialized => _initialized;

  // Initialize Remote Config and load all configuration
  static Future<void> initialize() async {
    if (_initialized) return; // Prevent duplicate initialization

    try {
      // Try to load .env file but don't fail if it's not there.
      // This is useful for local development but not required for production.
      await dotenv.load(fileName: ".env");
      _setEnvValues();
      print('✓ .env file loaded (fallback for Remote Config)');
    } catch (e) {
      // This is expected if the .env file is not present.
      print('ℹ️ .env file not found, proceeding with Remote Config.');
    }

    // --- End of Changes ---

    try {
      // Initialize Firebase Remote Config
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Set Remote Config settings
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default values from .env or hardcoded defaults
      await remoteConfig.setDefaults({
        'gemini_api_key': _geminiApiKey,
        'gemini_api_url': _apiUrl,
        'gemini_model': _geminiModel,
        'use_ai_prediction': _useAIPrediction,
        'min_logs_for_ai': _minLogsForAI,
      });

      // Fetch and activate Remote Config
      await remoteConfig.fetchAndActivate();

      // Load configuration values from Remote Config
      _loadRemoteConfigValues(remoteConfig);

      _initialized = true;
      print('✓ AppConfig initialized successfully');
    } catch (e) {
      print('✗ Error initializing AppConfig: $e');
      _initialized = true;
    }
  }

  // Load values from .env
  static void _setEnvValues() {
    _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    _apiUrl = dotenv.env['GEMINI_API_URL'] ?? 'https://api.gemini.google.com';
    _geminiModel = dotenv.env['GEMINI_MODEL'] ?? 'gemini-2.5-flash';
  }

  // Load values from Remote Config with .env fallbacks
  static void _loadRemoteConfigValues(FirebaseRemoteConfig remoteConfig) {
    try {
      // Log all fetched remote config values
      print('✓ Remote Config fetched values:');
      remoteConfig.getAll().forEach((key, value) {});

      final remoteApiKey = remoteConfig.getString('gemini_api_key');
      if (remoteApiKey.isNotEmpty) {
        _geminiApiKey = remoteApiKey;
      }

      final remoteUrl = remoteConfig.getString('gemini_api_url');
      if (remoteUrl.isNotEmpty) {
        _apiUrl = remoteUrl;
      }

      final remoteModel = remoteConfig.getString('gemini_model');
      if (remoteModel.isNotEmpty) {
        _geminiModel = remoteModel;
      }

      _useAIPrediction = remoteConfig.getBool('use_ai_prediction');
      _minLogsForAI = remoteConfig.getInt('min_logs_for_ai');

      print('✓ Remote Config values loaded successfully');
    } catch (e) {
      print('⚠ Error loading Remote Config values (using .env): $e');
    }
  }
}
