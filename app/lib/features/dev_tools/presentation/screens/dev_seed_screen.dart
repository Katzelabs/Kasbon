import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../config/theme/app_dimensions.dart';
import '../../../../shared/modern/modern.dart';

/// Dev Tools screen for seeding sample data via Supabase.
///
/// IMPORTANT: This is for development use only.
class DevSeedScreen extends StatefulWidget {
  const DevSeedScreen({super.key});

  @override
  State<DevSeedScreen> createState() => _DevSeedScreenState();
}

class _DevSeedScreenState extends State<DevSeedScreen> {
  bool _isLoading = false;
  String? _loadingAction;

  SupabaseClient get _client => Supabase.instance.client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  Future<void> _seedAllData() async {
    setState(() {
      _isLoading = true;
      _loadingAction = 'Seeding all data...';
    });
    try {
      await _seedCategoriesInternal();
      await _seedProductsInternal();
      await _seedTransactionsInternal();
      if (mounted) {
        ModernToast.success(context, 'Data berhasil di-seed');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal seed data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _seedProductsOnly() async {
    setState(() {
      _isLoading = true;
      _loadingAction = 'Seeding products...';
    });
    try {
      await _seedCategoriesInternal();
      await _seedProductsInternal();
      if (mounted) {
        ModernToast.success(context, 'Produk berhasil di-seed');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal seed produk: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingAction = null;
        });
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await ModernDialog.confirm(
      context,
      title: 'Hapus Semua Data?',
      message:
          'Semua produk dan transaksi akan dihapus. Kategori tetap dipertahankan.',
      confirmLabel: 'Hapus',
      isDestructive: true,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _loadingAction = 'Clearing data...';
    });
    try {
      final userId = _userId;
      // Delete in order: transaction_items → transactions → products
      await _client
          .from('transaction_items')
          .delete()
          .eq('user_id', userId);
      await _client
          .from('transactions')
          .delete()
          .eq('user_id', userId);
      await _client
          .from('products')
          .delete()
          .eq('user_id', userId);
      if (mounted) {
        ModernToast.success(context, 'Data berhasil dihapus');
      }
    } catch (e) {
      if (mounted) {
        ModernToast.error(context, 'Gagal hapus data: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingAction = null;
        });
      }
    }
  }

  // -- Internal seed helpers --

  Future<void> _seedCategoriesInternal() async {
    final userId = _userId;
    final categories = [
      {'name': 'Makanan', 'description': 'Aneka makanan', 'user_id': userId},
      {'name': 'Minuman', 'description': 'Aneka minuman', 'user_id': userId},
      {
        'name': 'Kebutuhan Rumah',
        'description': 'Peralatan rumah tangga',
        'user_id': userId,
      },
      {'name': 'Lainnya', 'description': 'Kategori lainnya', 'user_id': userId},
    ];

    // Upsert categories (skip if already exist by checking count)
    final existing = await _client
        .from('categories')
        .select('id')
        .eq('user_id', userId);
    if ((existing as List).isEmpty) {
      await _client.from('categories').insert(categories);
    }
  }

  Future<void> _seedProductsInternal() async {
    final userId = _userId;

    // Get categories for this user
    final catRows = await _client
        .from('categories')
        .select('id, name')
        .eq('user_id', userId);
    final cats = <String, String>{};
    for (final c in catRows as List) {
      cats[c['name'] as String] = c['id'] as String;
    }

    final makananId = cats['Makanan'] ?? '';
    final minumanId = cats['Minuman'] ?? '';
    final rumahtanggaId = cats['Kebutuhan Rumah'] ?? '';

    // Clear existing products first
    await _client.from('products').delete().eq('user_id', userId);

    final products = [
      _product('Nasi Goreng', 'SKU-00001', makananId, 8000, 15000, 50, userId),
      _product('Mie Goreng', 'SKU-00002', makananId, 6000, 12000, 40, userId),
      _product('Ayam Goreng', 'SKU-00003', makananId, 10000, 20000, 30, userId),
      _product('Bakso', 'SKU-00004', makananId, 7000, 15000, 25, userId),
      _product('Sate Ayam', 'SKU-00005', makananId, 12000, 25000, 20, userId),
      _product('Es Teh', 'SKU-00006', minumanId, 1000, 3000, 100, userId),
      _product('Es Jeruk', 'SKU-00007', minumanId, 1500, 4000, 80, userId),
      _product('Kopi', 'SKU-00008', minumanId, 2000, 5000, 60, userId),
      _product('Air Mineral', 'SKU-00009', minumanId, 1000, 3000, 200, userId),
      _product('Jus Alpukat', 'SKU-00010', minumanId, 5000, 10000, 30, userId),
      _product('Sabun Mandi', 'SKU-00011', rumahtanggaId, 3000, 5000, 50, userId),
      _product('Shampo', 'SKU-00012', rumahtanggaId, 5000, 8000, 40, userId),
      _product('Deterjen', 'SKU-00013', rumahtanggaId, 4000, 7000, 35, userId),
      _product('Tisu', 'SKU-00014', rumahtanggaId, 2000, 4000, 60, userId),
      _product('Sikat Gigi', 'SKU-00015', rumahtanggaId, 2000, 5000, 45, userId),
    ];

    await _client.from('products').insert(products);
  }

  Map<String, dynamic> _product(
    String name,
    String sku,
    String categoryId,
    double costPrice,
    double sellingPrice,
    int stock,
    String userId,
  ) {
    return {
      'name': name,
      'sku': sku,
      'category_id': categoryId,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'min_stock': 5,
      'is_active': true,
      'user_id': userId,
    };
  }

  Future<void> _seedTransactionsInternal() async {
    final userId = _userId;

    // Get products
    final productRows = await _client
        .from('products')
        .select('id, selling_price, cost_price')
        .eq('user_id', userId)
        .limit(10);

    if ((productRows as List).isEmpty) {
      throw Exception('Seed produk terlebih dahulu');
    }

    // Create 10 sample transactions using RPC
    final now = DateTime.now();
    for (int i = 0; i < 10; i++) {
      final txnDate = now.subtract(Duration(days: i));
      final product = productRows[i % productRows.length];
      final qty = (i % 3) + 1;
      final sellingPrice = (product['selling_price'] as num).toDouble();
      final costPrice = (product['cost_price'] as num).toDouble();
      final subtotal = sellingPrice * qty;
      final isDebt = i >= 8; // last 2 are debts

      final txnData = {
        'transaction_number': 'TRX-${txnDate.year}${txnDate.month.toString().padLeft(2, '0')}${txnDate.day.toString().padLeft(2, '0')}-${(i + 1).toString().padLeft(4, '0')}',
        'total_amount': subtotal,
        'total_profit': (sellingPrice - costPrice) * qty,
        'discount_amount': 0,
        'final_amount': subtotal,
        'payment_method': 'cash',
        'payment_status': isDebt ? 'debt' : 'paid',
        'customer_name': isDebt ? 'Pelanggan ${i + 1}' : null,
        'notes': null,
        'created_at': txnDate.toIso8601String(),
      };

      final itemsData = [
        {
          'product_id': product['id'],
          'quantity': qty,
          'unit_price': sellingPrice,
          'cost_price': costPrice,
          'subtotal': subtotal,
        },
      ];

      await _client.rpc('create_pos_transaction', params: {
        'txn_data': txnData,
        'items_data': itemsData,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ModernAppBar.backWithActions(
        title: 'Dev Seed Data',
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ModernLoading(),
                  const SizedBox(height: AppDimensions.spacing16),
                  Text(
                    _loadingAction ?? 'Loading...',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Info card
                  ModernCard.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: AppDimensions.spacing8),
                              Text(
                                'Database Seeding',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing12),
                          Text(
                            'Seed data ke Supabase untuk development dan testing. '
                            'Data di-seed ke akun Anda saat ini.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Seed All Data
                  ModernCard.elevated(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.rocket_launch,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seed All Data',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      '15 produk + 10 transaksi',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          SizedBox(
                            width: double.infinity,
                            child: ModernButton.primary(
                              onPressed: _seedAllData,
                              child: const Text('Seed All Data'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing16),

                  // Seed Products Only
                  ModernCard.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.inventory_2,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Seed Products Only',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    Text(
                                      '15 produk sample',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          SizedBox(
                            width: double.infinity,
                            child: ModernButton.outline(
                              onPressed: _seedProductsOnly,
                              child: const Text('Seed Products'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Danger Zone
                  ModernCard.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.warning_amber,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacing12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Danger Zone',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(color: Colors.red),
                                    ),
                                    Text(
                                      'Hapus semua data produk dan transaksi',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          SizedBox(
                            width: double.infinity,
                            child: ModernButton.destructive(
                              onPressed: _clearAllData,
                              child: const Text('Clear All Data'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacing24),

                  // Sample Data Info
                  ModernCard.filled(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.spacing16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sample Data Info',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppDimensions.spacing12),
                          _buildInfoRow(
                              context, 'Produk', '15 (3 kategori)'),
                          _buildInfoRow(context, 'Transaksi', '10'),
                          _buildInfoRow(context, 'Cash', '8 transaksi'),
                          _buildInfoRow(context, 'Hutang', '2 transaksi'),
                          _buildInfoRow(
                              context, 'Range tanggal', '10 hari terakhir'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
