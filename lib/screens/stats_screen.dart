// lib/screens/stats_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/period_provider.dart';
import '../utils/constants.dart';
import '../utils/date_helpers.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _isRegenerating = false;

  Future<void> _regeneratePrediction(PeriodProvider periodProvider) async {
    setState(() => _isRegenerating = true);

    try {
      await periodProvider.recalculatePrediction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prediction regenerated successfully'),
            duration: Duration(seconds: 2),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error regenerating prediction: ${e.toString()}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRegenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Statistics',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Consumer<PeriodProvider>(
        builder: (context, periodProvider, child) {
          final stats = periodProvider.getStatistics();
          final cycleStats = periodProvider.getCycleStats();
          final logs = periodProvider.chronologicalLogs;

          if (logs.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewCard(stats, cycleStats),
                const SizedBox(height: 16),
                if (periodProvider.currentPrediction != null)
                  _buildPredictionCard(
                    periodProvider,
                    onRegenerate: () => _regeneratePrediction(periodProvider),
                  ),
                const SizedBox(height: 16),
                _buildCycleHistoryCard(logs),
                const SizedBox(height: 16),
                _buildRecentLogsCard(periodProvider.periodLogs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Yet',
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging your periods to see statistics and insights',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(
    Map<String, dynamic> stats,
    Map<String, dynamic>? cycleStats,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildOverviewItem(
                  label: 'Total Logs',
                  value: '${stats['totalLogs']}',
                ),
                const SizedBox(width: 16),
                if (cycleStats != null)
                  _buildOverviewItem(
                    label: 'Average Cycle',
                    value: '${cycleStats['averageCycle']}',
                  ),
                const SizedBox(width: 16),
                if (cycleStats != null)
                  _buildOverviewItem(
                    label: 'Regularity',
                    value: _getRegularityGrade(cycleStats['regularity']),
                  ),
              ],
            ),
          ),
          if (stats['firstLogDate'] != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white54, thickness: 0.5),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tracking Since',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateHelpers.formatShortDate(stats['firstLogDate']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Last Logged',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateHelpers.formatShortDate(stats['lastLogDate']),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewItem({required String label, required String value}) {
    return SizedBox(
      width: 80,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _getRegularityGrade(String regularity) {
    switch (regularity) {
      case 'Very Regular':
        return '4/4';
      case 'Regular':
        return '3/4';
      case 'Somewhat Irregular':
        return '2/4';
      case 'Irregular':
        return '1/4';
      default:
        return '0/4';
    }
  }

  Widget _buildPredictionCard(
    PeriodProvider periodProvider, {
    required VoidCallback onRegenerate,
  }) {
    final prediction = periodProvider.currentPrediction!;

    return _buildCard(
      title: 'Prediction Details',
      icon: Icons.psychology,
      children: [
        _buildInfoRow(
          'Next Period',
          DateHelpers.formatLongDate(prediction.predictedDate),
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Average Cycle',
          '${prediction.averageCycleLength} days',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Confidence',
          '${(prediction.confidence * 100).toStringAsFixed(0)}%',
        ),
        const SizedBox(height: 8),
        _buildInfoRow(
          'Calculated',
          DateHelpers.getRelativeTime(prediction.calculatedAt),
        ),
        if (prediction.reasoning != null &&
            prediction.reasoning!.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Reasoning',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                prediction.reasoning!,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRegenerating ? null : onRegenerate,
            icon: _isRegenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _isRegenerating ? 'Regenerating...' : 'Regenerate Prediction',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCycleHistoryCard(List<dynamic> logs) {
    if (logs.length < 2) {
      return const SizedBox.shrink();
    }

    List<Widget> cycleWidgets = [];
    for (int i = 1; i < logs.length; i++) {
      final days = logs[i].startDate.difference(logs[i - 1].startDate).inDays;
      cycleWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle $i',
                style: AppTextStyles.body,
              ),
              Text(
                '$days days',
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return _buildCard(
      title: 'Cycle History',
      icon: Icons.history,
      children: cycleWidgets,
    );
  }

  Widget _buildRecentLogsCard(List<dynamic> logs) {
    final recentLogs = logs.take(5).toList();

    return _buildCard(
      title: 'Recent Logs',
      icon: Icons.event_note,
      children: recentLogs.map((log) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateHelpers.formatLongDate(log.startDate),
                style: AppTextStyles.body,
              ),
              Text(
                DateHelpers.getRelativeTime(log.startDate),
                style: AppTextStyles.caption,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTextStyles.subheading,
                  ),
                ],
              ),
              if (badge != null) badge,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextStyles.body),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
