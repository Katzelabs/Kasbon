import 'package:flutter/material.dart';

/// The kinds of shop the onboarding wizard offers, and what each one starts
/// with.
///
/// This exists to answer step 2 before the user has to. A blank category list
/// is the single worst thing a new POS can show someone - it makes every other
/// screen look empty too - and a warung owner should not have to invent the
/// word "Sembako" to get going. Picking a trade fills the list with the four or
/// five categories that trade actually uses, and every one of them stays
/// editable.
///
/// [id] is what reaches `shop_settings.business_type`, so **the ids are
/// storage**: renaming one orphans every row that holds the old value. Labels
/// and starter lists are free to change.
enum BusinessType {
  warungMakan(
    id: 'warung_makan',
    label: 'Warung Makan',
    icon: Icons.restaurant_rounded,
    starterCategories: ['Makanan', 'Minuman', 'Snack'],
  ),
  kedaiKopi(
    id: 'kedai_kopi',
    label: 'Kedai Kopi',
    icon: Icons.local_cafe_rounded,
    starterCategories: ['Kopi', 'Non-Kopi', 'Snack', 'Makanan'],
  ),
  tokoKelontong(
    id: 'toko_kelontong',
    label: 'Toko Kelontong',
    icon: Icons.storefront_rounded,
    starterCategories: [
      'Sembako',
      'Minuman',
      'Rokok',
      'Snack',
      'Perawatan',
    ],
  ),
  tokoPakaian(
    id: 'toko_pakaian',
    label: 'Toko Pakaian',
    icon: Icons.checkroom_rounded,
    starterCategories: ['Atasan', 'Bawahan', 'Aksesoris'],
  ),
  jasa(
    id: 'jasa',
    label: 'Jasa',
    icon: Icons.handyman_rounded,
    starterCategories: ['Layanan', 'Produk'],
  ),
  lainnya(
    id: 'lainnya',
    label: 'Lainnya',
    icon: Icons.category_rounded,
    starterCategories: ['Makanan', 'Minuman', 'Lainnya'],
  );

  const BusinessType({
    required this.id,
    required this.label,
    required this.icon,
    required this.starterCategories,
  });

  /// Stored in `shop_settings.business_type`. Do not rename.
  final String id;

  /// Shown on the chip, in Bahasa Indonesia.
  final String label;

  final IconData icon;

  /// Pre-checked on the category step. Order is the order they appear in.
  final List<String> starterCategories;

  /// Resolve a stored id, or null if it is unrecognised.
  ///
  /// Unrecognised rather than throwing: the column is free-form TEXT and a
  /// value written by a newer build has no business crashing an older one.
  static BusinessType? fromId(String? id) {
    if (id == null) return null;
    for (final type in BusinessType.values) {
      if (type.id == id) return type;
    }
    return null;
  }
}
