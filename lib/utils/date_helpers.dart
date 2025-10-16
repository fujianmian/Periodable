import 'package:intl/intl.dart';

class DateHelpers {
  // Format date as "January 15, 2025"
  static String formatLongDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  // Format date as "Jan 15"
  static String formatShortDate(DateTime date) {
    return DateFormat('MMM d').format(date);
  }

  // Format date as "2025-01-15"
  static String formatISODate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Check if two dates are the same day
  static bool isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Get the start of day (midnight)
  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // Calculate difference in days
  static int daysBetween(DateTime from, DateTime to) {
    from = startOfDay(from);
    to = startOfDay(to);
    return to.difference(from).inDays;
  }

  // Get days until a future date
  static int daysUntil(DateTime futureDate) {
    return daysBetween(DateTime.now(), futureDate);
  }

  // Check if date is in the past
  static bool isPast(DateTime date) {
    return startOfDay(date).isBefore(startOfDay(DateTime.now()));
  }

  // Check if date is today
  static bool isToday(DateTime date) {
    return isSameDay(date, DateTime.now());
  }

  // Check if date is in the future
  static bool isFuture(DateTime date) {
    return startOfDay(date).isAfter(startOfDay(DateTime.now()));
  }

  // Get readable relative time
  static String getRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = daysBetween(now, date);

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    if (difference == -1) return 'Yesterday';
    if (difference > 1) return 'in $difference days';
    if (difference < -1) return '${-difference} days ago';

    return formatShortDate(date);
  }
}
