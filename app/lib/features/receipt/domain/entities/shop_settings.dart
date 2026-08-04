import 'package:equatable/equatable.dart';

/// ShopSettings entity representing store information for receipts
class ShopSettings extends Equatable {
  /// Matches the column default in the database, so a shop that has never
  /// touched the setting reads the same number here and there.
  static const int defaultPaymentProofRetentionDays = 90;

  /// The range the database CHECK constraint allows.
  ///
  /// The floor is 7 rather than 1: a window short enough to delete a proof
  /// before the weekend it was taken on is a data-loss bug wearing a settings
  /// row, and the app has no business offering it.
  static const int minPaymentProofRetentionDays = 7;
  static const int maxPaymentProofRetentionDays = 3650;
  /// Unique identifier (UUID from Supabase)
  final String id;

  /// Shop/store name
  final String name;

  /// What kind of shop this is, as chosen during onboarding
  /// (`warung_makan`, `kedai_kopi`, ...). Null for shops created before
  /// onboarding existed.
  ///
  /// A plain string rather than an enum so this layer does not have to know
  /// the onboarding feature's catalogue of trades - see `BusinessType`.
  final String? businessType;

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

  /// Days a payment proof is kept before `storage-janitor` deletes it.
  ///
  /// A dispute window, not a technical setting: the photo exists so a human can
  /// settle an argument about whether a customer paid, and it stops earning its
  /// storage once the sale is too old to argue about.
  ///
  /// Worth setting deliberately if the shop takes a lot of QRIS. At roughly
  /// 150 KB a proof, 50 a day over 90 days is ~675 MB - most of a free Supabase
  /// project for one shop. Thirty days puts the same shop near 225 MB.
  ///
  /// The database constrains this to 7..3650; see
  /// `20260804010002_core_schema.sql`.
  final int paymentProofRetentionDays;

  /// Record creation timestamp
  final DateTime createdAt;

  /// Record update timestamp
  final DateTime updatedAt;

  const ShopSettings({
    required this.id,
    required this.name,
    this.businessType,
    this.address,
    this.phone,
    this.logoUrl,
    this.receiptHeader,
    this.receiptFooter,
    this.currency = 'IDR',
    this.lowStockThreshold = 5,
    this.paymentProofRetentionDays = defaultPaymentProofRetentionDays,
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
    String? businessType,
    String? address,
    String? phone,
    String? logoUrl,
    String? receiptHeader,
    String? receiptFooter,
    String? currency,
    int? lowStockThreshold,
    int? paymentProofRetentionDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ShopSettings(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      logoUrl: logoUrl ?? this.logoUrl,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      currency: currency ?? this.currency,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      paymentProofRetentionDays:
          paymentProofRetentionDays ?? this.paymentProofRetentionDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, name];

  @override
  String toString() => 'ShopSettings(id: $id, name: $name)';
}
