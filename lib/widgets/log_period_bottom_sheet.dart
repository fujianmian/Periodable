import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../utils/date_helpers.dart';

class LogPeriodBottomSheet extends StatefulWidget {
  final DateTime selectedDate;
  final bool hasExistingLog;
  final VoidCallback onConfirm;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const LogPeriodBottomSheet({
    Key? key,
    required this.selectedDate,
    this.hasExistingLog = false,
    required this.onConfirm,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  @override
  State<LogPeriodBottomSheet> createState() => _LogPeriodBottomSheetState();
}

class _LogPeriodBottomSheetState extends State<LogPeriodBottomSheet> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: widget.hasExistingLog
                  ? AppColors.periodDay.withOpacity(0.1)
                  : AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.hasExistingLog
                  ? Icons.edit_calendar
                  : Icons.add_circle_outline,
              color: widget.hasExistingLog
                  ? AppColors.periodDay
                  : AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            widget.hasExistingLog ? 'Period Logged' : 'Log Period Start',
            style: AppTextStyles.heading.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 8),

          // Date
          Text(
            DateHelpers.formatLongDate(widget.selectedDate),
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          if (widget.hasExistingLog) ...[
            // Existing log - show delete option
            _buildButton(
              label: 'Delete Log',
              icon: Icons.delete_outline,
              color: Colors.red,
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      widget.onDelete?.call();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
            const SizedBox(height: 12),
            _buildButton(
              label: 'Close',
              icon: Icons.close,
              color: AppColors.textSecondary,
              isOutlined: true,
              onPressed: _isLoading ? null : () => Navigator.pop(context),
            ),
          ] else ...[
            // No log - show confirm option
            _buildButton(
              label: 'Confirm',
              icon: Icons.check_circle_outline,
              color: AppColors.primary,
              onPressed: _isLoading
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      widget.onConfirm();
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    },
            ),
            const SizedBox(height: 12),
            _buildButton(
              label: 'Cancel',
              icon: Icons.close,
              color: AppColors.textSecondary,
              isOutlined: true,
              onPressed: _isLoading ? null : () => Navigator.pop(context),
            ),
          ],

          if (_isLoading) ...[
            const SizedBox(height: 16),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  /// Build button widget
  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color color,
    bool isOutlined = false,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isOutlined ? Colors.white : color,
          foregroundColor: isOutlined ? color : Colors.white,
          elevation: isOutlined ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isOutlined
                ? BorderSide(color: color.withOpacity(0.3), width: 1.5)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the bottom sheet
Future<void> showLogPeriodSheet({
  required BuildContext context,
  required DateTime selectedDate,
  bool hasExistingLog = false,
  required VoidCallback onConfirm,
  VoidCallback? onDelete,
  VoidCallback? onEdit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => LogPeriodBottomSheet(
      selectedDate: selectedDate,
      hasExistingLog: hasExistingLog,
      onConfirm: onConfirm,
      onDelete: onDelete,
      onEdit: onEdit,
    ),
  );
}
