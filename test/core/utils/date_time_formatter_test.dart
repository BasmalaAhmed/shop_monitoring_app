import 'package:flutter_test/flutter_test.dart';
import 'package:shop_monitoring_app/core/utils/date_time_formatter.dart';

void main() {
  group('DateTimeFormatter.time (Cairo time)', () {
    test('formats morning time in winter (UTC+2)', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 11, 21, 7, 5)),
        '9:05 ص',
      );
    });

    test('formats midnight as 12 AM', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 11, 20, 22, 30)),
        '12:30 ص',
      );
    });

    test('formats noon as 12 PM', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 11, 21, 10, 0)),
        '12:00 م',
      );
    });

    test('formats afternoon time', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 11, 21, 12, 35)),
        '2:35 م',
      );
    });

    test('gives the same result for UTC and local DateTime of one instant', () {
      final utc = DateTime.utc(2026, 11, 21, 12, 35);

      expect(
        DateTimeFormatter.time(utc),
        DateTimeFormatter.time(utc.toLocal()),
      );
    });

    test('uses summer time (UTC+3) in July', () {
      expect(DateTimeFormatter.time(DateTime.utc(2026, 7, 1, 12, 0)), '3:00 م');
    });

    test('switches to summer time at midnight on the last Friday of April', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 4, 23, 21, 59)),
        '11:59 م',
      );
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 4, 23, 22, 0)),
        '1:00 ص',
      );
    });

    test('switches back at the end of the last Thursday of October', () {
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 10, 29, 20, 59)),
        '11:59 م',
      );
      expect(
        DateTimeFormatter.time(DateTime.utc(2026, 10, 29, 21, 0)),
        '11:00 م',
      );
    });
  });

  group('DateTimeFormatter.timeOrDateTime', () {
    final now = DateTime.utc(2026, 11, 21, 16, 0);

    test('shows time only when the Cairo date is today', () {
      final result = DateTimeFormatter.timeOrDateTime(
        DateTime.utc(2026, 11, 21, 12, 35),
        now: now,
      );

      expect(result, '2:35 م');
    });

    test('shows date and time when the date is not today', () {
      final result = DateTimeFormatter.timeOrDateTime(
        DateTime.utc(2026, 11, 20, 12, 35),
        now: now,
      );

      expect(result, '20/11 2:35 م');
    });

    test('decides "today" by the Cairo date, not the UTC date', () {
      final result = DateTimeFormatter.timeOrDateTime(
        DateTime.utc(2026, 11, 21, 22, 30),
        now: DateTime.utc(2026, 11, 22, 5, 0),
      );

      expect(result, '12:30 ص');
    });
  });
  group('DateTimeFormatter.dateTime', () {
    test('formats full date and time in Cairo time', () {
      expect(
        DateTimeFormatter.dateTime(DateTime.utc(2026, 11, 21, 12, 35)),
        '21/11/2026 - 2:35 م',
      );
    });

    test('moves to the next day when Cairo time passes midnight', () {
      expect(
        DateTimeFormatter.dateTime(DateTime.utc(2026, 11, 21, 22, 30)),
        '22/11/2026 - 12:30 ص',
      );
    });
  });
}
