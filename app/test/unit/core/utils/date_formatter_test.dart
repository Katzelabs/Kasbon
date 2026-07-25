import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasbon_pos/core/utils/date_formatter.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('DateFormatter', () {
    group('formatDate', () {
      test('formats date as dd/MM/yyyy', () {
        final date = DateTime(2026, 1, 26);
        expect(DateFormatter.formatDate(date), '26/01/2026');
      });

      test('pads single digit day and month', () {
        final date = DateTime(2026, 5, 3);
        expect(DateFormatter.formatDate(date), '03/05/2026');
      });
    });

    group('formatTime', () {
      test('formats time as HH:mm', () {
        final date = DateTime(2026, 1, 26, 14, 30);
        expect(DateFormatter.formatTime(date), '14:30');
      });

      test('pads single digit hour and minute', () {
        final date = DateTime(2026, 1, 26, 9, 5);
        expect(DateFormatter.formatTime(date), '09:05');
      });

      test('formats midnight correctly', () {
        final date = DateTime(2026, 1, 26, 0, 0);
        expect(DateFormatter.formatTime(date), '00:00');
      });
    });

    group('formatDateTime', () {
      test('formats date and time as dd/MM/yyyy HH:mm', () {
        final date = DateTime(2026, 1, 26, 14, 30);
        expect(DateFormatter.formatDateTime(date), '26/01/2026 14:30');
      });
    });

    group('formatMonthYear', () {
      test('formats as Indonesian month and year', () {
        final date = DateTime(2026, 1, 26);
        expect(DateFormatter.formatMonthYear(date), 'Januari 2026');
      });

      test('formats February correctly', () {
        final date = DateTime(2026, 2, 15);
        expect(DateFormatter.formatMonthYear(date), 'Februari 2026');
      });

      test('formats December correctly', () {
        final date = DateTime(2026, 12, 31);
        expect(DateFormatter.formatMonthYear(date), 'Desember 2026');
      });
    });

    group('formatDayMonth', () {
      test('formats as day and Indonesian month', () {
        final date = DateTime(2026, 1, 15);
        expect(DateFormatter.formatDayMonth(date), '15 Januari');
      });

      test('formats first day of month', () {
        final date = DateTime(2026, 3, 1);
        expect(DateFormatter.formatDayMonth(date), '1 Maret');
      });
    });

    group('getRelativeTime', () {
      test('returns "Hari ini" for today', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day, 10, 0);
        expect(DateFormatter.getRelativeTime(today), 'Hari ini');
      });

      test('returns "Kemarin" for yesterday', () {
        final now = DateTime.now();
        final yesterday = DateTime(now.year, now.month, now.day - 1, 10, 0);
        expect(DateFormatter.getRelativeTime(yesterday), 'Kemarin');
      });

      test('returns "X hari lalu" for 2-6 days ago', () {
        final now = DateTime.now();
        final threeDaysAgo = DateTime(now.year, now.month, now.day - 3);
        expect(DateFormatter.getRelativeTime(threeDaysAgo), '3 hari lalu');
      });

      test('returns "X minggu lalu" for 7-29 days ago', () {
        final now = DateTime.now();
        final twoWeeksAgo = DateTime(now.year, now.month, now.day - 14);
        expect(DateFormatter.getRelativeTime(twoWeeksAgo), '2 minggu lalu');
      });

      test('returns formatted date for 30+ days ago', () {
        final date = DateTime(2025, 10, 15);
        // This will return the formatted date for dates more than 30 days ago
        expect(DateFormatter.getRelativeTime(date), '15/10/2025');
      });
    });

    group('startOfDay', () {
      test('returns start of day (00:00:00.000)', () {
        final date = DateTime(2026, 1, 26, 14, 30, 45, 123);
        final result = DateFormatter.startOfDay(date);

        expect(result.year, 2026);
        expect(result.month, 1);
        expect(result.day, 26);
        expect(result.hour, 0);
        expect(result.minute, 0);
        expect(result.second, 0);
        expect(result.millisecond, 0);
      });
    });

    group('endOfDay', () {
      test('returns end of day (23:59:59.999)', () {
        final date = DateTime(2026, 1, 26, 14, 30, 45, 123);
        final result = DateFormatter.endOfDay(date);

        expect(result.year, 2026);
        expect(result.month, 1);
        expect(result.day, 26);
        expect(result.hour, 23);
        expect(result.minute, 59);
        expect(result.second, 59);
        expect(result.millisecond, 999);
      });
    });

    group('startOfWeek', () {
      test('returns Monday for a Wednesday', () {
        // Jan 29, 2026 is a Thursday
        final thursday = DateTime(2026, 1, 29);
        final result = DateFormatter.startOfWeek(thursday);

        expect(result.weekday, DateTime.monday);
        expect(result.day, 26);
        expect(result.month, 1);
        expect(result.year, 2026);
      });

      test('returns same day for a Monday', () {
        // Jan 26, 2026 is a Monday
        final monday = DateTime(2026, 1, 26, 14, 30);
        final result = DateFormatter.startOfWeek(monday);

        expect(result.weekday, DateTime.monday);
        expect(result.day, 26);
        expect(result.hour, 0);
        expect(result.minute, 0);
      });

      test('returns previous Monday for a Sunday', () {
        // Feb 1, 2026 is a Sunday
        final sunday = DateTime(2026, 2, 1);
        final result = DateFormatter.startOfWeek(sunday);

        expect(result.weekday, DateTime.monday);
        expect(result.day, 26);
        expect(result.month, 1);
      });
    });

    group('startOfMonth', () {
      test('returns first day of month', () {
        final date = DateTime(2026, 1, 26, 14, 30);
        final result = DateFormatter.startOfMonth(date);

        expect(result.day, 1);
        expect(result.month, 1);
        expect(result.year, 2026);
        expect(result.hour, 0);
        expect(result.minute, 0);
      });

      test('returns first day for last day of month', () {
        final date = DateTime(2026, 1, 31);
        final result = DateFormatter.startOfMonth(date);

        expect(result.day, 1);
        expect(result.month, 1);
      });
    });
  });
}
