import 'package:flutter_test/flutter_test.dart';
import 'package:kasbon_pos/core/utils/validators.dart';

void main() {
  group('Validators', () {
    group('required', () {
      test('returns error for null value', () {
        expect(Validators.required(null), 'Field wajib diisi');
      });

      test('returns error for empty string', () {
        expect(Validators.required(''), 'Field wajib diisi');
      });

      test('returns error for whitespace-only string', () {
        expect(Validators.required('   '), 'Field wajib diisi');
      });

      test('returns null for valid value', () {
        expect(Validators.required('test'), null);
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.required(null, fieldName: 'Nama Produk'),
          'Nama Produk wajib diisi',
        );
      });
    });

    group('minLength', () {
      test('returns error for null value', () {
        expect(Validators.minLength(null, 3), 'Field minimal 3 karakter');
      });

      test('returns error for string shorter than min', () {
        expect(Validators.minLength('ab', 3), 'Field minimal 3 karakter');
      });

      test('returns null for string equal to min', () {
        expect(Validators.minLength('abc', 3), null);
      });

      test('returns null for string longer than min', () {
        expect(Validators.minLength('abcd', 3), null);
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.minLength('a', 3, fieldName: 'SKU'),
          'SKU minimal 3 karakter',
        );
      });
    });

    group('maxLength', () {
      test('returns null for null value', () {
        expect(Validators.maxLength(null, 10), null);
      });

      test('returns null for string shorter than max', () {
        expect(Validators.maxLength('abc', 10), null);
      });

      test('returns null for string equal to max', () {
        expect(Validators.maxLength('abcdefghij', 10), null);
      });

      test('returns error for string longer than max', () {
        expect(
          Validators.maxLength('abcdefghijk', 10),
          'Field maksimal 10 karakter',
        );
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.maxLength('a' * 101, 100, fieldName: 'Deskripsi'),
          'Deskripsi maksimal 100 karakter',
        );
      });
    });

    group('positiveNumber', () {
      test('returns error for null value', () {
        expect(Validators.positiveNumber(null), 'Field wajib diisi');
      });

      test('returns error for empty string', () {
        expect(Validators.positiveNumber(''), 'Field wajib diisi');
      });

      test('returns error for non-numeric string', () {
        expect(Validators.positiveNumber('abc'), 'Field harus berupa angka');
      });

      test('returns error for zero', () {
        expect(Validators.positiveNumber('0'), 'Field harus lebih dari 0');
      });

      test('returns error for negative number', () {
        expect(Validators.positiveNumber('-5'), 'Field harus lebih dari 0');
      });

      test('returns null for positive number', () {
        expect(Validators.positiveNumber('10'), null);
      });

      test('handles formatted number with dots', () {
        expect(Validators.positiveNumber('10.000'), null);
      });

      test('handles formatted number with comma decimal', () {
        expect(Validators.positiveNumber('10,5'), null);
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.positiveNumber('0', fieldName: 'Harga'),
          'Harga harus lebih dari 0',
        );
      });
    });

    group('nonNegativeNumber', () {
      test('returns error for null value', () {
        expect(Validators.nonNegativeNumber(null), 'Field wajib diisi');
      });

      test('returns error for empty string', () {
        expect(Validators.nonNegativeNumber(''), 'Field wajib diisi');
      });

      test('returns error for non-numeric string', () {
        expect(Validators.nonNegativeNumber('abc'), 'Field harus berupa angka');
      });

      test('returns null for zero', () {
        expect(Validators.nonNegativeNumber('0'), null);
      });

      test('returns error for negative number', () {
        expect(Validators.nonNegativeNumber('-5'), 'Field tidak boleh negatif');
      });

      test('returns null for positive number', () {
        expect(Validators.nonNegativeNumber('10'), null);
      });

      test('uses custom field name in error message', () {
        expect(
          Validators.nonNegativeNumber('-1', fieldName: 'Stok'),
          'Stok tidak boleh negatif',
        );
      });
    });

    group('integer', () {
      test('returns error for null value', () {
        expect(Validators.integer(null), 'Field wajib diisi');
      });

      test('returns error for empty string', () {
        expect(Validators.integer(''), 'Field wajib diisi');
      });

      test('returns error for non-numeric string', () {
        expect(
          Validators.integer('abc'),
          'Field harus berupa bilangan bulat',
        );
      });

      test('returns error for decimal number with comma', () {
        // Indonesian format uses comma for decimals, dot for thousands
        // So '10,5' (10.5 in Indonesian) should fail as non-integer
        expect(
          Validators.integer('10,5'),
          'Field harus berupa bilangan bulat',
        );
      });

      test('treats dot as thousand separator (10.5 becomes 105)', () {
        // Dot is treated as thousand separator in Indonesian format
        // So '10.5' is parsed as '105' which is a valid integer
        expect(Validators.integer('10.5'), null);
      });

      test('returns null for integer', () {
        expect(Validators.integer('10'), null);
      });

      test('returns null for negative integer', () {
        expect(Validators.integer('-5'), null);
      });

      test('handles formatted integer with dots', () {
        expect(Validators.integer('10.000'), null);
      });

      test('uses custom field name in error message', () {
        // Use comma decimal format which should fail
        expect(
          Validators.integer('10,5', fieldName: 'Kuantitas'),
          'Kuantitas harus berupa bilangan bulat',
        );
      });
    });

    group('phoneNumber', () {
      test('returns null for null value (optional)', () {
        expect(Validators.phoneNumber(null), null);
      });

      test('returns null for empty string (optional)', () {
        expect(Validators.phoneNumber(''), null);
      });

      test('returns error for too short phone number', () {
        expect(Validators.phoneNumber('08123'), 'Nomor telepon tidak valid');
      });

      test('returns error for too long phone number', () {
        expect(
          Validators.phoneNumber('0812345678901234'),
          'Nomor telepon tidak valid',
        );
      });

      test('returns error for phone not starting with 0 or 62', () {
        expect(
          Validators.phoneNumber('1234567890'),
          'Nomor telepon harus diawali 0 atau 62',
        );
      });

      test('returns null for valid phone starting with 0', () {
        expect(Validators.phoneNumber('081234567890'), null);
      });

      test('returns null for valid phone starting with 62', () {
        expect(Validators.phoneNumber('6281234567890'), null);
      });

      test('strips non-numeric characters before validation', () {
        expect(Validators.phoneNumber('0812-3456-7890'), null);
      });

      test('strips spaces before validation', () {
        expect(Validators.phoneNumber('0812 3456 7890'), null);
      });
    });

    group('barcode', () {
      test('returns null for null value (optional)', () {
        expect(Validators.barcode(null), null);
      });

      test('returns null for empty string (optional)', () {
        expect(Validators.barcode(''), null);
      });

      test('returns error for barcode shorter than 8 digits', () {
        expect(Validators.barcode('1234567'), 'Barcode harus 8-14 digit');
      });

      test('returns error for barcode longer than 14 digits', () {
        expect(Validators.barcode('123456789012345'), 'Barcode harus 8-14 digit');
      });

      test('returns error for barcode with non-numeric characters', () {
        expect(
          Validators.barcode('1234567A'),
          'Barcode hanya boleh berisi angka',
        );
      });

      test('returns null for valid 8-digit barcode', () {
        expect(Validators.barcode('12345678'), null);
      });

      test('returns null for valid 13-digit barcode (EAN-13)', () {
        expect(Validators.barcode('1234567890123'), null);
      });

      test('returns null for valid 14-digit barcode', () {
        expect(Validators.barcode('12345678901234'), null);
      });
    });

    group('compose', () {
      test('returns null when all validators pass', () {
        expect(
          Validators.compose([
            () => Validators.required('test'),
            () => Validators.minLength('test', 2),
            () => Validators.maxLength('test', 10),
          ]),
          null,
        );
      });

      test('returns first error when validators fail', () {
        expect(
          Validators.compose([
            () => Validators.required(null),
            () => Validators.minLength(null, 2),
          ]),
          'Field wajib diisi',
        );
      });

      test('stops at first error', () {
        // If compose continues after first error, it would crash on minLength
        expect(
          Validators.compose([
            () => Validators.required(''),
            () => Validators.minLength('a', 10),
          ]),
          'Field wajib diisi',
        );
      });

      test('returns error from second validator if first passes', () {
        expect(
          Validators.compose([
            () => Validators.required('a'),
            () => Validators.minLength('a', 3),
          ]),
          'Field minimal 3 karakter',
        );
      });
    });
  });
}
