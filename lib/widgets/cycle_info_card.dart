import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/date_helpers.dart';
import '../models/prediction_data.dart';
import '../models/period_log.dart';

class CycleInfoCard extends StatelessWidget {
  final PredictionData? prediction;
  final PeriodLog? lastLog;
  final Map<String, dynamic>? cycleStats;

  const CycleInfoCard({
    Key? key,
    this.prediction,
    this.lastLog,
    this.cycleStats,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
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
          _buildMainInfo(),
          if (prediction != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white, thickness: 0.5),
            const SizedBox(height: 16),
            _buildDetailedInfo(),
          ],
        ],
      ),
    );
  }

  /// Main prediction info
  Widget _buildMainInfo() {
    if (prediction == null) {
      return _buildNoDataState();
    }

    final daysUntil = DateHelpers.daysUntil(prediction!.predictedDate);
    final isPast = daysUntil < 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Next Period',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isPast)
          const Text(
            'Prediction date has passed\nPlease log your period',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          )
        else
          Text(
            daysUntil == 0
                ? 'Expected Today'
                : daysUntil == 1
                    ? 'Expected Tomorrow'
                    : 'In $daysUntil days',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          DateHelpers.formatLongDate(prediction!.predictedDate),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Detailed cycle information
  Widget _buildDetailedInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildInfoItem(
          icon: Icons.sync,
          label: 'Avg Cycle',
          value: '${prediction!.averageCycleLength} days',
        ),
        Container(
          width: 1,
          height: 40,
          color: Colors.white.withOpacity(0.3),
        ),
        _buildInfoItem(
          icon: Icons.trending_up,
          label: 'Confidence',
          value: prediction!.confidenceLevel,
        ),
        if (lastLog != null) ...[
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withOpacity(0.3),
          ),
          _buildInfoItem(
            icon: Icons.history,
            label: 'Last Period',
            value: DateHelpers.getRelativeTime(lastLog!.startDate),
          ),
        ],
      ],
    );
  }

  /// Individual info item
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// No data state
  Widget _buildNoDataState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text(
              'Getting Started',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'No prediction yet',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lastLog != null
              ? 'Log at least one more period to get predictions'
              : 'Tap a date on the calendar to log your first period',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
