import 'package:equatable/equatable.dart';

/// ShopSettings entity representing store information for receipts
class ShopSettings extends Equatable {
  /// Unique identifier (UUID from Supabase)
  final String id;

  /// Shop/store name
  final String name;

  /// Shop address (optional)
  final String? address;

  /// Shop phone number (optional)
  final String? phone;

  /// Shop logo URL (optional)
  final String? logoUrl;

  /// Custom receipt header text (optional)
  final String? receiptHeader;

  /// Custom receipt footer text (optional)
  final String? receiptFooter;

  /// Currency code (default: IDR)
  final String currency;

  /// Low stock threshold for alerts (default: 5)
  final int lowStockThreshold;

  /// Record creation timestamp
  final DateTime createdAt;

  /// Record update timestamp
  final DateTime updatedAt;

  const ShopSettings({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.logoUrl,
    this.receiptHeader,
    this.receiptFooter,
    this.currency = 'IDR',
    this.lowStockThreshold = 5,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Default shop settings when none exist in database
  factory ShopSettings.defaultSettings() {
    final now = DateTime.now();
    return ShopSettings(
      id: '',
      name: 'Toko Saya',
      currency: 'IDR',
      lowStockThreshold: 5,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Create a copy with updated fields
  ShopSettings copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? logoUrl,
    String? receiptHeader,
    String? receiptFooter,
    String? currency,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currency: currency ?? this.currency,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name];

  @override
  String toString() => 'ShopSettings(id: $id, name: $name)';
}
