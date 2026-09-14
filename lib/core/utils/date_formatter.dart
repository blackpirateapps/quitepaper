import 'package:intl/intl.dart';

abstract final class DateFormatter {
  /// Returns a group bucket label for a given date relative to [now].
  /// Buckets: "Today", "Yesterday", Weekday (e.g., "Monday"), "Previous week", "Older".
  static String getGroupBucket(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final localDateTime = dateTime.toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final noteDay = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );

    final differenceInDays = today.difference(noteDay).inDays;

    if (differenceInDays == 0) {
      return 'Today';
    } else if (differenceInDays == 1) {
      return 'Yesterday';
    } else if (differenceInDays > 1 && differenceInDays < 7) {
      return DateFormat('EEEE').format(localDateTime);
    } else if (differenceInDays >= 7 && differenceInDays < 14) {
      return 'Previous week';
    } else if (today.year == localDateTime.year) {
      return DateFormat('MMMM').format(localDateTime);
    } else {
      return DateFormat('yyyy').format(localDateTime);
    }
  }

  /// Formats note modified time for note row preview.
  /// E.g. "3:45 PM" for today, "Yesterday" for yesterday, "Oct 12" for this year, "Oct 12, 2024" for earlier.
  static String formatNoteTileTime(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final localDateTime = dateTime.toLocal();
    final today = DateTime(reference.year, reference.month, reference.day);
    final noteDay = DateTime(
      localDateTime.year,
      localDateTime.month,
      localDateTime.day,
    );

    final differenceInDays = today.difference(noteDay).inDays;

    if (differenceInDays == 0) {
      return DateFormat('h:mm a').format(localDateTime);
    } else if (differenceInDays == 1) {
      return 'Yesterday';
    } else if (today.year == localDateTime.year) {
      return DateFormat('MMM d').format(localDateTime);
    } else {
      return DateFormat('MMM d, y').format(localDateTime);
    }
  }

  /// Full formatted date string for stats/details (e.g. "August 18, 2026 at 1:30 PM")
  static String formatFullDate(DateTime dateTime) {
    return DateFormat('MMMM d, y • h:mm a').format(dateTime.toLocal());
  }

  /// Formats relative time for devices / sessions (e.g. "Just now", "5m ago", "2h ago", "3d ago", "May 12").
  static String formatRelative(DateTime dateTime, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 45) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (reference.year == dateTime.year) {
      return DateFormat('MMM d').format(dateTime.toLocal());
    } else {
      return DateFormat('MMM d, y').format(dateTime.toLocal());
    }
  }
}
