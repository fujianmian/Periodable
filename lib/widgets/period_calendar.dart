import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../utils/constants.dart';
import '../utils/date_helpers.dart';
import '../models/period_log.dart';
import '../models/prediction_data.dart';

class PeriodCalendar extends StatefulWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Function(DateTime, DateTime) onDaySelected;
  final List<PeriodLog> periodLogs;
  final PredictionData? prediction;

  const PeriodCalendar({
    super.key,
    required this.focusedDay,
    this.selectedDay,
    required this.onDaySelected,
    required this.periodLogs,
    this.prediction,
  });

  @override
  State<PeriodCalendar> createState() => _PeriodCalendarState();
}

class _PeriodCalendarState extends State<PeriodCalendar> {
  late DateTime _focusedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: TableCalendar(
        firstDay: DateTime(2020, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) =>
            widget.selectedDay != null &&
            DateHelpers.isSameDay(day, widget.selectedDay!),
        calendarFormat: _calendarFormat,
        onDaySelected: widget.onDaySelected,
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
        calendarStyle: CalendarStyle(
          // Today's date
          todayDecoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),

          // Selected date
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),

          // Default date
          defaultDecoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          defaultTextStyle: const TextStyle(
            color: AppColors.textPrimary,
          ),

          // Weekend dates
          weekendDecoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          weekendTextStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.8),
          ),

          // Outside month dates
          outsideDecoration: const BoxDecoration(
            shape: BoxShape.circle,
          ),
          outsideTextStyle: TextStyle(
            color: AppColors.textSecondary.withOpacity(0.4),
          ),

          // Markers (dots below dates)
          markerDecoration: const BoxDecoration(
            color: AppColors.periodDay,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 1,
          markerSize: 8,
        ),
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          titleTextStyle: AppTextStyles.subheading,
          formatButtonTextStyle: const TextStyle(
            color: AppColors.primary,
            fontSize: 14,
          ),
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(8),
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppColors.primary,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppColors.primary,
          ),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          weekendStyle: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          // Custom builder for days with period logs
          defaultBuilder: (context, day, focusedDay) {
            return _buildDayCell(day);
          },
          todayBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isToday: true);
          },
          selectedBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isSelected: true);
          },
          outsideBuilder: (context, day, focusedDay) {
            return _buildDayCell(day, isOutside: true);
          },
        ),
      ),
    );
  }

  /// Custom day cell builder
  Widget _buildDayCell(
    DateTime day, {
    bool isToday = false,
    bool isSelected = false,
    bool isOutside = false,
  }) {
    final hasLog = _hasLogOnDay(day);
    final isPredicted = _isPredictedDay(day);
    final isPast = DateHelpers.isPast(day);

    Color? backgroundColor;
    Color? borderColor;
    Color textColor = AppColors.textPrimary;

    // Determine background color
    if (isSelected) {
      backgroundColor = AppColors.primary;
      textColor = Colors.white;
    } else if (hasLog) {
      backgroundColor = AppColors.periodDay;
      textColor = Colors.white;
    } else if (isPredicted && !isPast) {
      backgroundColor = AppColors.predictedDay;
    } else if (isToday) {
      backgroundColor = AppColors.secondary.withOpacity(0.3);
    }

    // Determine border
    if (isToday && !isSelected && !hasLog) {
      borderColor = AppColors.primary;
    }

    // Adjust opacity for outside dates
    if (isOutside) {
      textColor = textColor.withOpacity(0.4);
    }

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: Center(
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: textColor,
            fontWeight:
                hasLog || isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// Check if a day has a logged period
  bool _hasLogOnDay(DateTime day) {
    return widget.periodLogs.any(
      (log) => DateHelpers.isSameDay(log.startDate, day),
    );
  }

  /// Check if a day is in the predicted period range
  bool _isPredictedDay(DateTime day) {
    if (widget.prediction == null) return false;

    final predictedDate = widget.prediction!.predictedDate;
    final daysDiff = DateHelpers.daysBetween(predictedDate, day).abs();

    // Highlight ±2 days from predicted date
    return daysDiff <= 2;
  }
}
