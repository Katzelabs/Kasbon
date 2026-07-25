/// Utility class for input validation
class Validators {
  Validators._();

  /// Validate that a string is not empty
  static String? required(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    return null;
  }

  /// Validate minimum length
  static String? minLength(String? value, int min,
      {String fieldName = 'Field'}) {
    if (value == null || value.length < min) {
      return '$fieldName minimal $min karakter';
    }
    return null;
  }

  /// Validate maximum length
  static String? maxLength(String? value, int max,
      {String fieldName = 'Field'}) {
    if (value != null && value.length > max) {
      return '$fieldName maksimal $max karakter';
    }
    return null;
  }

  /// Validate positive number
  static String? positiveNumber(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final number = num.tryParse(value.replaceAll('.', '').replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName harus berupa angka';
    }
    if (number <= 0) {
      return '$fieldName harus lebih dari 0';
    }
    return null;
  }

  /// Validate non-negative number
  static String? nonNegativeNumber(String? value,
      {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final number = num.tryParse(value.replaceAll('.', '').replaceAll(',', '.'));
    if (number == null) {
      return '$fieldName harus berupa angka';
    }
    if (number < 0) {
      return '$fieldName tidak boleh negatif';
    }
    return null;
  }

  /// Validate integer
  static String? integer(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName wajib diisi';
    }
    final number = int.tryParse(value.replaceAll('.', ''));
    if (number == null) {
      return '$fieldName harus berupa bilangan bulat';
    }
    return null;
  }

  /// Validate phone number (Indonesian format)
  static String? phoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Phone is optional
    }
    final phone = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 10 || phone.length > 15) {
      return 'Nomor telepon tidak valid';
    }
    if (!phone.startsWith('0') && !phone.startsWith('62')) {
      return 'Nomor telepon harus diawali 0 atau 62';
    }
    return null;
  }

  /// Validate email format
  static bool isValidEmail(String value) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(value.trim());
  }

  /// Validate email with error message
  static String? email(String? value, {bool isRequired = true}) {
    if (value == null || value.trim().isEmpty) {
      return isRequired ? 'Email wajib diisi' : null;
    }
    if (!isValidEmail(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  /// Validate password with strength requirements.
  /// When [requireStrong] is true, enforces uppercase, lowercase, and number.
  static String? password(String? value, {bool requireStrong = true}) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.length < 8) {
      return 'Password minimal 8 karakter';
    }
    if (requireStrong) {
      if (!RegExp(r'[a-z]').hasMatch(value)) {
        return 'Password harus mengandung huruf kecil';
      }
      if (!RegExp(r'[A-Z]').hasMatch(value)) {
        return 'Password harus mengandung huruf besar';
      }
      if (!RegExp(r'[0-9]').hasMatch(value)) {
        return 'Password harus mengandung angka';
      }
    }
    return null;
  }

  /// Validate full name (2-100 characters)
  static String? fullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama lengkap wajib diisi';
    }
    if (value.trim().length < 2) {
      return 'Nama minimal 2 karakter';
    }
    if (value.trim().length > 100) {
      return 'Nama maksimal 100 karakter';
    }
    return null;
  }

  /// Validate barcode format
  static String? barcode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Barcode is optional
    }
    if (value.length < 8 || value.length > 14) {
      return 'Barcode harus 8-14 digit';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Barcode hanya boleh berisi angka';
    }
    return null;
  }

  /// Combine multiple validators
  static String? compose(List<String? Function()> validators) {
    for (final validator in validators) {
      final error = validator();
      if (error != null) {
        return error;
      }
    }
    return null;
  }
}
