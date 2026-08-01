import '../../domain/entities/shop_settings.dart';

/// Data model for ShopSettings with Supabase JSON serialization
class ShopSettingsModel extends ShopSettings {
  const ShopSettingsModel({
    required super.id,
    required super.name,
    super.businessType,
    super.address,
    super.phone,
    super.logoUrl,
    super.receiptHeader,
    super.receiptFooter,
    super.currency,
    super.lowStockThreshold,
    super.paymentProofRetentionDays,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create from Supabase JSON
  factory ShopSettingsModel.fromJson(Map<String, dynamic> json) {
    return ShopSettingsModel(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: json['business_type'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logo_url'] as String?,
      receiptHeader: json['receipt_header'] as String?,
      receiptFooter: json['receipt_footer'] as String?,
      currency: json['currency'] as String? ?? 'IDR',
      lowStockThreshold: json['low_stock_threshold'] as int? ?? 5,
      paymentProofRetentionDays: json['payment_proof_retention_days'] as int? ??
          ShopSettings.defaultPaymentProofRetentionDays,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Convert to Supabase JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'logo_url': logoUrl,
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
      'currency': currency,
      'low_stock_threshold': lowStockThreshold,
      'payment_proof_retention_days': paymentProofRetentionDays,
    };
  }

  /// Create from entity
  factory ShopSettingsModel.fromEntity(ShopSettings entity) {
    return ShopSettingsModel(
      id: entity.id,
      name: entity.name,
      businessType: entity.businessType,
      address: entity.address,
      phone: entity.phone,
      logoUrl: entity.logoUrl,
      receiptHeader: entity.receiptHeader,
      receiptFooter: entity.receiptFooter,
      currency: entity.currency,
      lowStockThreshold: entity.lowStockThreshold,
      paymentProofRetentionDays: entity.paymentProofRetentionDays,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert to entity
  ShopSettings toEntity() {
    return ShopSettings(
      id: id,
      name: name,
      businessType: businessType,
      address: address,
      phone: phone,
      logoUrl: logoUrl,
      receiptHeader: receiptHeader,
      receiptFooter: receiptFooter,
      currency: currency,
      lowStockThreshold: lowStockThreshold,
      paymentProofRetentionDays: paymentProofRetentionDays,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
