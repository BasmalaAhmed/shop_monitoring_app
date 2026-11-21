import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/utils/date_time_formatter.dart';

void main() {
  group('DateTimeFormatter.time', () {
    test('formats morning time', () {
      expect(DateTimeFormatter.time(DateTime(2026, 11, 21, 9, 5)), '9:05 ص');
    });

    test('formats midnight as 12 AM', () {
      expect(DateTimeFormatter.time(DateTime(2026, 11, 21, 0, 30)), '12:30 ص');
    });

    test('formats noon as 12 PM', () {
      expect(DateTimeFormatter.time(DateTime(2026, 11, 21, 12, 0)), '12:00 م');
    });

    test('formats afternoon time', () {
      expect(DateTimeFormatter.time(DateTime(2026, 11, 21, 14, 35)), '2:35 م');
    });
  });

  group('DateTimeFormatter.timeOrDateTime', () {
    final now = DateTime(2026, 11, 21, 18, 0);

    test('shows time only when the date is today', () {
      final result = DateTimeFormatter.timeOrDateTime(
        DateTime(2026, 11, 21, 14, 35),
        now: now,
      );

      expect(result, '2:35 م');
    });

    test('shows date and time when the date is not today', () {
      final result = DateTimeFormatter.timeOrDateTime(
        DateTime(2026, 11, 20, 14, 35),
        now: now,
      );

      expect(result, '20/11 2:35 م');
    });
  });
}
