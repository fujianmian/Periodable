import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/period_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/period_calendar.dart';
import '../widgets/cycle_info_card.dart';
import '../widgets/log_period_bottom_sheet.dart';
import '../utils/constants.dart';
import '../utils/date_helpers.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({Key? key}) : super(key: key);

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          AppConfig.appName,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Refresh button
          Consumer<PeriodProvider>(
            builder: (context, periodProvider, child) {
              return IconButton(
                icon: periodProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: periodProvider.isLoading
                    ? null
                    : () => periodProvider.recalculatePrediction(),
                tooltip: 'Recalculate Prediction',
              );
            },
          ),
        ],
      ),
      body: Consumer<PeriodProvider>(
        builder: (context, periodProvider, child) {
          if (periodProvider.error != null) {
            return _buildErrorState(periodProvider.error!);
          }

          return RefreshIndicator(
            onRefresh: () => periodProvider.refresh(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Cycle Info Card
                  CycleInfoCard(
                    prediction: periodProvider.currentPrediction,
                    lastLog: periodProvider.lastLog,
                    cycleStats: periodProvider.getCycleStats(),
                  ),

                  // Calendar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PeriodCalendar(
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _handleDayTap(selectedDay, periodProvider);
                      },
                      periodLogs: periodProvider.periodLogs,
                      prediction: periodProvider.currentPrediction,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Legend
                  _buildLegend(),

                  const SizedBox(height: 24),

                  // Quick Stats
                  _buildQuickStats(periodProvider),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Handle day tap - show bottom sheet
  void _handleDayTap(DateTime selectedDay, PeriodProvider periodProvider) {
    final hasLog = periodProvider.hasLogOnDate(selectedDay);

    showLogPeriodSheet(
      context: context,
      selectedDate: selectedDay,
      hasExistingLog: hasLog,
      onConfirm: () async {
        try {
          await periodProvider.addPeriodLog(selectedDay);
          // Recalculate prediction after adding log
          await periodProvider.recalculatePrediction();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Period logged for ${DateHelpers.formatLongDate(selectedDay)}',
                ),
                backgroundColor: AppColors.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${e.toString()}'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      onDelete: () async {
        final log = periodProvider.getLogForDate(selectedDay);
        if (log != null) {
          try {
            await periodProvider.deletePeriodLog(log.id);
            // Recalculate prediction after deleting log
            await periodProvider.recalculatePrediction();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Period log deleted'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        }
      },
    );
  }

  /// Build legend explaining calendar colors
  Widget _buildLegend() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(
            color: AppColors.periodDay,
            label: 'Logged',
          ),
          _buildLegendItem(
            color: AppColors.predictedDay,
            label: 'Predicted',
            isBordered: true,
          ),
          _buildLegendItem(
            color: AppColors.secondary.withOpacity(0.3),
            label: 'Today',
            isBordered: true,
            borderColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  /// Build individual legend item
  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isBordered = false,
    Color? borderColor,
  }) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: isBordered
                ? Border.all(
                    color: borderColor ?? color,
                    width: 2,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  /// Convert regularity text to numeric grade
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

  /// Build quick stats section
  Widget _buildQuickStats(PeriodProvider periodProvider) {
    final stats = periodProvider.getStatistics();
    final cycleStats = periodProvider.getCycleStats();

    if (stats['totalLogs'] == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
            children: [
              const Icon(
                Icons.bar_chart,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Cycle Stats',
                style: AppTextStyles.subheading.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                label: 'Total Logs',
                value: '${stats['totalLogs']}',
                icon: Icons.event_note,
              ),
              if (cycleStats != null) ...[
                _buildStatItem(
                  label: 'Avg Cycle',
                  value: '${cycleStats['averageCycle']}d',
                  icon: Icons.sync,
                ),
                _buildStatItem(
                  label: 'Regularity',
                  value: _getRegularityGrade(cycleStats['regularity']),
                  icon: Icons.trending_up,
                ),
              ],
            ],
          ),
          if (cycleStats != null && cycleStats['totalCycles'] > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Range: ${cycleStats['minCycle']}-${cycleStats['maxCycle']} days',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    'σ: ${cycleStats['standardDeviation']}',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build individual stat item
  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: AppTextStyles.heading,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                context.read<PeriodProvider>().refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
