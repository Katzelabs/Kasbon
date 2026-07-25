/// SKU (Stock Keeping Unit) generator for products
class SkuGenerator {
  /// Generates a unique SKU based on product name
  ///
  /// Format: XXX-12345
  /// - XXX: First 3 letters of product name (uppercase, alphanumeric only)
  /// - 12345: Last 5 digits of current timestamp
  ///
  /// Example: "Mie Goreng" -> "MIE-12345"
  static String generate(String productName) {
    // Clean and extract prefix from product name
    final cleanedName = productName
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');

    final prefixLength = cleanedName.length > 3 ? 3 : cleanedName.length;
    final prefix =
        prefixLength > 0 ? cleanedName.substring(0, prefixLength) : 'SKU';

    // Generate timestamp-based suffix
    final timestamp = DateTime.now().millisecondsSinceEpoch % 100000;

    return '$prefix-$timestamp';
  }

  /// Validates if a string is a valid SKU format
  static bool isValid(String sku) {
    final pattern = RegExp(r'^[A-Z0-9]{1,3}-\d{1,5}$');
    return pattern.hasMatch(sku);
  }
}
