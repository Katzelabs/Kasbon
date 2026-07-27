import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/business_time.dart';

void main() {
  group('BusinessTime.toInstant', () {
    test('resolves a business midnight to the correct UTC instant', () {
      // 1 July 00:00 in Jakarta (UTC+7) is 30 June 17:00 UTC.
      final instant = BusinessTime.toInstant(DateTime(2026, 7));

      expect(instant.isUtc, isTrue);
      expect(instant, DateTime.utc(2026, 6, 30, 17));
    });

    test('ignores the input flag and reads only calendar fields', () {
      // The whole point: the same calendar date must resolve to the same
      // instant no matter what zone the device (or the DateTime) claims.
      final fromLocal = BusinessTime.toInstant(DateTime(2026, 7, 15, 9, 30));
      final fromUtc = BusinessTime.toInstant(DateTime.utc(2026, 7, 15, 9, 30));

      expect(fromLocal, fromUtc);
      expect(fromUtc, DateTime.utc(2026, 7, 15, 2, 30));
    });

    test('round-trips through fromInstant', () {
      final wall = DateTime(2026, 7, 15, 14, 45, 30);
      final roundTripped = BusinessTime.fromInstant(
        BusinessTime.toInstant(wall),
      );

      expect(roundTripped.year, wall.year);
      expect(roundTripped.month, wall.month);
      expect(roundTripped.day, wall.day);
      expect(roundTripped.hour, wall.hour);
      expect(roundTripped.minute, wall.minute);
    });

    test('serialises an RPC argument with an explicit UTC offset', () {
      final arg = BusinessTime.toRpcArgument(DateTime(2026, 7));

      // The trailing Z is what stops Postgres reading the literal in the
      // server's own zone.
      expect(arg, endsWith('Z'));
      expect(arg, startsWith('2026-06-30T17:00:00.000'));
    });
  });

  group('BusinessTime boundaries', () {
    test('startOfDay strips the time from a reference', () {
      expect(
        BusinessTime.startOfDay(DateTime(2026, 7, 15, 23, 59)),
        DateTime(2026, 7, 15),
      );
    });

    test('startOfWeek lands on Monday', () {
      // 2026-07-15 is a Wednesday; its week starts Monday the 13th.
      final start = BusinessTime.startOfWeek(DateTime(2026, 7, 15, 10));

      expect(start, DateTime(2026, 7, 13));
      expect(start.weekday, DateTime.monday);
    });

    test('startOfWeek on a Sunday stays in the week that began Monday', () {
      // 2026-07-19 is a Sunday - the last day of its week, not the first.
      final start = BusinessTime.startOfWeek(DateTime(2026, 7, 19));

      expect(start, DateTime(2026, 7, 13));
    });

    test('startOfWeek crosses a month boundary correctly', () {
      // 2026-07-01 is a Wednesday, so its week began Monday 29 June.
      expect(
        BusinessTime.startOfWeek(DateTime(2026, 7)),
        DateTime(2026, 6, 29),
      );
    });

    test('startOfMonth lands on the 1st', () {
      expect(
        BusinessTime.startOfMonth(DateTime(2026, 7, 31, 23)),
        DateTime(2026, 7),
      );
    });
  });

  group('BusinessTime.now', () {
    test('is the current instant shifted into the business zone', () {
      final before = DateTime.now().toUtc();
      final businessNow = BusinessTime.now();
      final after = DateTime.now().toUtc();

      // Compare as instants: business "now" is UTC now plus the offset.
      final asInstant = businessNow.subtract(BusinessTime.offset);

      expect(asInstant.isAfter(before.subtract(const Duration(seconds: 2))),
          isTrue);
      expect(asInstant.isBefore(after.add(const Duration(seconds: 2))), isTrue);
    });

    test('agrees with the offset the RPCs bucket in', () {
      // If this ever diverges from the p_tz default in the report migration,
      // ranges and buckets stop describing the same day.
      expect(BusinessTime.zoneName, 'Asia/Jakarta');
      expect(BusinessTime.offset, const Duration(hours: 7));
    });
  });
}
