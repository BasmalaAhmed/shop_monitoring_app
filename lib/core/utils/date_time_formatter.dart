import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

abstract final class DateTimeFormatter {
  static tz.Location? _cairo;

  static tz.Location get _cairoLocation {
    if (_cairo == null) {
      tzdata.initializeTimeZones();
      _cairo = tz.getLocation('Africa/Cairo');
    }

    return _cairo!;
  }

  static tz.TZDateTime _toCairo(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, _cairoLocation);
  }

  static String time(DateTime dateTime) {
    final cairo = _toCairo(dateTime);

    final hour12 = cairo.hour % 12 == 0 ? 12 : cairo.hour % 12;
    final minute = cairo.minute.toString().padLeft(2, '0');
    final period = cairo.hour < 12 ? 'ص' : 'م';

    return '$hour12:$minute $period';
  }

  static String timeOrDateTime(DateTime dateTime, {DateTime? now}) {
    final cairo = _toCairo(dateTime);
    final reference = _toCairo(now ?? DateTime.now());

    final isToday =
        cairo.year == reference.year &&
        cairo.month == reference.month &&
        cairo.day == reference.day;

    if (isToday) return time(dateTime);

    final date =
        '${cairo.day.toString().padLeft(2, '0')}/'
        '${cairo.month.toString().padLeft(2, '0')}';

    return '$date ${time(dateTime)}';
  }

  static String dateTime(DateTime dateTime) {
    final cairo = _toCairo(dateTime);

    final date =
        '${cairo.day.toString().padLeft(2, '0')}/'
        '${cairo.month.toString().padLeft(2, '0')}/'
        '${cairo.year}';

    return '$date - ${time(dateTime)}';
  }
}
