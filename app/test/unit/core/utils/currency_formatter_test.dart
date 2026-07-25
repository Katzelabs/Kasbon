import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    group('format', () {
      test('formats 0 as Rp0', () {
        expect(CurrencyFormatter.format(0), 'Rp0');
      });

      test('formats 1000 as Rp1.000', () {
        expect(CurrencyFormatter.format(1000), 'Rp1.000');
      });

      test('formats 10000 as Rp10.000', () {
        expect(CurrencyFormatter.format(10000), 'Rp10.000');
      });

      test('formats 100000 as Rp100.000', () {
        expect(CurrencyFormatter.format(100000), 'Rp100.000');
      });

      test('formats 1000000 as Rp1.000.000', () {
        expect(CurrencyFormatter.format(1000000), 'Rp1.000.000');
      });

      test('formats negative numbers correctly', () {
        expect(CurrencyFormatter.format(-10000), '-Rp10.000');
      });

      test('formats decimal numbers (truncated)', () {
        expect(CurrencyFormatter.format(10000.50), 'Rp10.001');
      });
    });

    group('formatWithDecimal', () {
      test('formats with 2 decimal places', () {
        expect(CurrencyFormatter.formatWithDecimal(10000.50), 'Rp10.000,50');
      });

      test('formats whole numbers with .00', () {
        expect(CurrencyFormatter.formatWithDecimal(10000), 'Rp10.000,00');
      });
    });

    group('formatCompact', () {
      test('formats values below 1000 normally', () {
        expect(CurrencyFormatter.formatCompact(500), 'Rp500');
      });

      test('formats thousands with rb suffix', () {
        expect(CurrencyFormatter.formatCompact(5000), 'Rp5.0rb');
      });

      test('formats tens of thousands with rb suffix', () {
        expect(CurrencyFormatter.formatCompact(50000), 'Rp50.0rb');
      });

      test('formats hundreds of thousands with rb suffix', () {
        expect(CurrencyFormatter.formatCompact(500000), 'Rp500.0rb');
      });

      test('formats millions with jt suffix', () {
        expect(CurrencyFormatter.formatCompact(1000000), 'Rp1.0jt');
      });

      test('formats 5 million with jt suffix', () {
        expect(CurrencyFormatter.formatCompact(5000000), 'Rp5.0jt');
      });

      test('formats billions with M suffix', () {
        expect(CurrencyFormatter.formatCompact(1000000000), 'Rp1.0M');
      });

      test('formats 5 billion with M suffix', () {
        expect(CurrencyFormatter.formatCompact(5000000000), 'Rp5.0M');
      });

      test('handles decimal values in compact format', () {
        expect(CurrencyFormatter.formatCompact(1500000), 'Rp1.5jt');
      });
    });

    group('parse', () {
      test('parses Rp10.000 to 10000', () {
        expect(CurrencyFormatter.parse('Rp10.000'), 10000);
      });

      test('parses Rp1.000.000 to 1000000', () {
        expect(CurrencyFormatter.parse('Rp1.000.000'), 1000000);
      });

      test('parses value without Rp prefix', () {
        expect(CurrencyFormatter.parse('10.000'), 10000);
      });

      test('parses value with spaces', () {
        expect(CurrencyFormatter.parse(' Rp10.000 '), 10000);
      });

      test('parses value with comma decimal', () {
        expect(CurrencyFormatter.parse('Rp10.000,50'), 10000.50);
      });

      test('returns null for invalid input', () {
        expect(CurrencyFormatter.parse('invalid'), null);
      });

      test('returns null for empty string', () {
        expect(CurrencyFormatter.parse(''), null);
      });

      test('parses Rp0 to 0', () {
        expect(CurrencyFormatter.parse('Rp0'), 0);
      });
    });
  });
}
