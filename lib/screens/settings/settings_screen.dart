import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/period_provider.dart';
import '../../utils/constants.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_tiles.dart';
import 'widgets/dialogs/feedback_dialog.dart';
import 'widgets/dialogs/clear_data_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationsSection(context),
            const SizedBox(height: 24),
            _buildAIPredictionSection(context),
            const SizedBox(height: 24),
            _buildDataManagementSection(context),
            const SizedBox(height: 24),
            _buildFeedbackSection(context),
            const SizedBox(height: 24),
            _buildAboutSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsSection(BuildContext context) {
    return SettingsSection(
      title: 'Notifications',
      icon: Icons.notifications_outlined,
      children: [
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            return SettingsTiles.buildSwitchTile(
              title: 'Enable Reminders',
              subtitle: 'Get notified before your period starts',
              value: settingsProvider.notificationsEnabled,
              onChanged: (value) {
                settingsProvider.toggleNotifications(value);
              },
            );
          },
        ),
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            if (!settingsProvider.notificationsEnabled) {
              return const SizedBox.shrink();
            }
            return SettingsTiles.buildSliderTile(
              title: 'Reminder Days Before',
              subtitle:
                  'Remind me ${settingsProvider.reminderDaysBefore} ${settingsProvider.reminderDaysBefore == 1 ? 'day' : 'days'} before',
              value: settingsProvider.reminderDaysBefore.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              onChanged: (value) {
                settingsProvider.updateReminderDays(value.round());
              },
            );
          },
        ),
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            return SettingsTiles.buildActionTile(
              title: 'Test Notification',
              subtitle: 'Send a test notification now',
              icon: Icons.send,
              onTap: () async {
                try {
                  await settingsProvider.testNotification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test notification sent!'),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildAIPredictionSection(BuildContext context) {
    return SettingsSection(
      title: 'AI Prediction',
      icon: Icons.psychology_outlined,
      children: [
        Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            return SettingsTiles.buildSwitchTile(
              title: 'Use AI Prediction',
              subtitle: AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE'
                  ? 'API key not configured'
                  : 'Enhanced predictions using Gemini AI',
              value: settingsProvider.useAIPrediction,
              onChanged: AppConfig.geminiApiKey == 'YOUR_GEMINI_API_KEY_HERE'
                  ? null
                  : (value) {
                      settingsProvider.toggleAIPrediction(value);
                      context.read<PeriodProvider>().recalculatePrediction();
                    },
            );
          },
        ),
        SettingsTiles.buildActionTile(
          title: 'Test AI Connection',
          subtitle: 'Check if Gemini API is working',
          icon: Icons.cloud_sync,
          onTap: () async {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            );

            final isConnected =
                await context.read<PeriodProvider>().testGeminiConnection();

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isConnected
                        ? '✓ AI connection successful!'
                        : '✗ AI connection failed. Check API key.',
                  ),
                  backgroundColor: isConnected ? Colors.green : Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    return SettingsSection(
      title: 'Data Management',
      icon: Icons.storage_outlined,
      children: [
        Consumer<PeriodProvider>(
          builder: (context, periodProvider, child) {
            final stats = periodProvider.getStatistics();
            return SettingsTiles.buildInfoTile(
              title: 'Total Period Logs',
              subtitle: '${stats['totalLogs']} entries',
              icon: Icons.event_note,
            );
          },
        ),
        SettingsTiles.buildActionTile(
          title: 'Recalculate Prediction',
          subtitle: 'Manually update cycle prediction',
          icon: Icons.refresh,
          onTap: () async {
            try {
              await context.read<PeriodProvider>().recalculatePrediction();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prediction recalculated!'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
        ),
        SettingsTiles.buildActionTile(
          title: 'Clear All Data',
          subtitle: 'Delete all period logs and predictions',
          icon: Icons.delete_forever,
          iconColor: Colors.red,
          onTap: () {
            ClearDataDialog.show(context);
          },
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(BuildContext context) {
    return SettingsSection(
      title: 'Feedback & Support',
      icon: Icons.mail_outline,
      children: [
        SettingsTiles.buildActionTile(
          title: 'Send Feedback',
          subtitle: 'Share your thoughts and suggestions',
          icon: Icons.mail_outline,
          onTap: () {
            FeedbackDialog.show(context);
          },
        ),
      ],
    );
  }

  Widget _buildAboutSection() {
    return SettingsSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        SettingsTiles.buildInfoTile(
          title: 'App Version',
          subtitle: '1.0.0',
          icon: Icons.app_settings_alt,
        ),
        SettingsTiles.buildInfoTile(
          title: 'Privacy',
          subtitle: 'All data stored locally on your device',
          icon: Icons.lock_outline,
        ),
        SettingsTiles.buildInfoTile(
          title: AppConfig.appName,
          subtitle: 'Your private cycle tracker',
          icon: Icons.favorite_border,
        ),
      ],
    );
  }
}
