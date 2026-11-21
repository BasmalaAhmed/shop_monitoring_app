abstract final class DateTimeFormatter {
  static String time(DateTime dateTime) {
    final local = dateTime.toLocal();

    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'ص' : 'م';

    return '$hour12:$minute $period';
  }

  static String timeOrDateTime(DateTime dateTime, {DateTime? now}) {
    final local = dateTime.toLocal();
    final reference = now ?? DateTime.now();

    final isToday = local.year == reference.year &&
        local.month == reference.month &&
        local.day == reference.day;

    if (isToday) return time(local);

    final date =
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}';

    return '$date ${time(local)}';
  }
}