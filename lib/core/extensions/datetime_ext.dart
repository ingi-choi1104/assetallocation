extension DateTimeExt on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);

  bool isSameDay(DateTime other) =>
      year == other.year && month == other.month && day == other.day;

  String toDateString() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  int get daysSinceEpoch =>
      DateTime(year, month, day)
          .difference(DateTime(1970, 1, 1))
          .inDays;

  bool get isToday {
    final now = DateTime.now();
    return isSameDay(now);
  }
}
