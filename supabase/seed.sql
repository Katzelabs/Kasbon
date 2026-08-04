-- =============================================================================
-- KASBON POS - Seed Data for Local Development
-- =============================================================================
-- Test user: test@kasbon.id / password123
-- Mirrors dev_seed_data.dart: 4 categories, 25 products, 20 transactions
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. TEST USER
-- ---------------------------------------------------------------------------
-- Fixed UUID for deterministic seed data
-- Password: password123 (bcrypt hash)

INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000',
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  'authenticated',
  'authenticated',
  'test@kasbon.id',
  crypt('password123', gen_salt('bf')),
  NOW(),
  '{"provider": "email", "providers": ["email"]}',
  -- onboarding_completed_at keeps the seed user out of the setup wizard. It is
  -- written here rather than by a migration because migrations run before seeds:
  -- this row does not exist yet while they are applying.
  -- `onboarding_marker_test.dart` asserts the app reads this exact key.
  '{"full_name": "Pak Adi", "phone": "081234567890", "tier": "free", "onboarding_completed_at": "2026-07-31T00:00:00Z"}',
  NOW(),
  NOW(),
  '', '', '', ''
);

INSERT INTO auth.identities (
  id, user_id, identity_data, provider, provider_id,
  last_sign_in_at, created_at, updated_at
) VALUES (
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  '{"sub": "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d", "email": "test@kasbon.id"}',
  'email',
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  NOW(),
  NOW(),
  NOW()
);

-- user_profiles is auto-created by the on_auth_user_created trigger

-- ---------------------------------------------------------------------------
-- 2. SHOP SETTINGS
-- ---------------------------------------------------------------------------

INSERT INTO public.shop_settings (
  id, user_id, name, business_type, address, phone,
  receipt_header, receipt_footer, currency, low_stock_threshold
) VALUES (
  'b1000000-0000-0000-0000-000000000001',
  'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d',
  'Warung Pak Adi',
  'warung_makan',
  'Jl. Merdeka No. 10, Jakarta Selatan',
  '081234567890',
  'Terima kasih sudah berbelanja!',
  'Barang yang sudah dibeli tidak dapat dikembalikan.',
  'IDR',
  5
);

-- ---------------------------------------------------------------------------
-- 3. CATEGORIES (4 default categories)
-- ---------------------------------------------------------------------------

INSERT INTO public.categories (id, user_id, name, color, icon, sort_order) VALUES
  ('c1000000-0000-0000-0000-000000000001', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'Makanan',         '#FF6B35', 'restaurant', 1),
  ('c1000000-0000-0000-0000-000000000002', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'Minuman',         '#1E88E5', 'local_cafe', 2),
  ('c1000000-0000-0000-0000-000000000003', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'Kebutuhan Rumah', '#43A047', 'home',       3),
  ('c1000000-0000-0000-0000-000000000004', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'Lainnya',         '#757575', 'category',   4);

-- ---------------------------------------------------------------------------
-- 4. PRODUCTS (25 total)
-- ---------------------------------------------------------------------------

-- Makanan (cat-1): 8 products
INSERT INTO public.products (id, user_id, category_id, sku, name, description, cost_price, selling_price, stock, min_stock, unit, is_active) VALUES
  ('d1000000-0000-0000-0000-000000000001', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'MIE-00001', 'Mie Goreng Instan',   'Mie goreng kemasan 85g',              2500,  3500,  50,  10, 'pcs',    TRUE),
  ('d1000000-0000-0000-0000-000000000002', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'NAS-00002', 'Nasi Goreng Frozen',  'Nasi goreng beku 200g',              12000, 18000,  20,   5, 'pcs',    TRUE),
  ('d1000000-0000-0000-0000-000000000003', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'ROT-00003', 'Roti Tawar',          'Roti tawar gandum 400g',             10000, 14000,  15,   5, 'pcs',    TRUE),
  ('d1000000-0000-0000-0000-000000000004', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'TEL-00004', 'Telur Ayam',          'Telur ayam kampung per butir',        2000,  2800, 100,  20, 'butir',  TRUE),
  ('d1000000-0000-0000-0000-000000000005', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'GUL-00005', 'Gula Pasir 1kg',      'Gula pasir putih premium',           12000, 15000,   3,   5, 'kg',     TRUE),
  ('d1000000-0000-0000-0000-000000000006', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'BER-00006', 'Beras Premium 5kg',   'Beras pulen premium',                60000, 75000,   0,   5, 'karung', TRUE),
  ('d1000000-0000-0000-0000-000000000007', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'KEJ-00007', 'Keju Cheddar Slice',  'Keju cheddar potong 10 lembar',      18000, 25000,  12,   3, 'pack',   TRUE),
  ('d1000000-0000-0000-0000-000000000008', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000001', 'SAR-00008', 'Sarden Kaleng',       'Sarden dalam saus tomat 155g',       10000, 14000,  25,   8, 'kaleng', TRUE);

-- Minuman (cat-2): 7 products
INSERT INTO public.products (id, user_id, category_id, sku, name, description, cost_price, selling_price, stock, min_stock, unit, is_active) VALUES
  ('d1000000-0000-0000-0000-000000000009', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'AQU-00009', 'Air Mineral 600ml',   'Air mineral kemasan botol',            2500,  4000,  48,  12, 'botol',  TRUE),
  ('d1000000-0000-0000-0000-000000000010', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'KOP-00010', 'Kopi Sachet',         'Kopi instan 3in1 sachet',             1500,  2500,  80,  20, 'sachet', TRUE),
  ('d1000000-0000-0000-0000-000000000011', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'TEH-00011', 'Teh Kotak 250ml',     'Teh manis kemasan kotak',             3000,  5000,  36,  10, 'kotak',  TRUE),
  ('d1000000-0000-0000-0000-000000000012', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'SUS-00012', 'Susu UHT 1L',         'Susu UHT full cream',                15000, 19000,   2,   5, 'kotak',  TRUE),
  ('d1000000-0000-0000-0000-000000000013', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'SIR-00013', 'Sirup Merah 630ml',   'Sirup rasa cocopandan',              12000, 18000,   8,   3, 'botol',  TRUE),
  ('d1000000-0000-0000-0000-000000000014', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'MIN-00014', 'Minuman Soda 390ml',  'Minuman bersoda',                     5000,  7500,  24,   8, 'kaleng', TRUE),
  ('d1000000-0000-0000-0000-000000000015', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000002', 'YOG-00015', 'Yogurt Cup',          'Yogurt rasa stroberi',                4000,  6000,   0,   6, 'cup',    TRUE);

-- Kebutuhan Rumah (cat-3): 6 products
INSERT INTO public.products (id, user_id, category_id, sku, name, description, cost_price, selling_price, stock, min_stock, unit, is_active) VALUES
  ('d1000000-0000-0000-0000-000000000016', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'SAB-00016', 'Sabun Cuci Piring 800ml', 'Sabun cuci piring cair',          8000, 12000,  18,   5, 'botol',  TRUE),
  ('d1000000-0000-0000-0000-000000000017', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'DET-00017', 'Deterjen Bubuk 900g',     'Deterjen bubuk wangi',           20000, 28000,  10,   4, 'pack',   TRUE),
  ('d1000000-0000-0000-0000-000000000018', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'TIS-00018', 'Tisu Wajah 250 lembar',   'Tisu wajah lembut',              10000, 15000,   4,   5, 'box',    TRUE),
  ('d1000000-0000-0000-0000-000000000019', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'PEM-00019', 'Pembalut Wanita',         'Pembalut wanita 10 pcs',          8000, 12000,  20,   8, 'pack',   TRUE),
  ('d1000000-0000-0000-0000-000000000020', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'SAM-00020', 'Sampo Sachet',            'Sampo anti ketombe sachet',       1000,  1500,  50,  15, 'sachet', TRUE),
  ('d1000000-0000-0000-0000-000000000021', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000003', 'PAS-00021', 'Pasta Gigi 120g',         'Pasta gigi whitening',           10000, 14000,   1,   5, 'tube',   TRUE);

-- Lainnya (cat-4): 4 products
INSERT INTO public.products (id, user_id, category_id, sku, name, description, cost_price, selling_price, stock, min_stock, unit, is_active) VALUES
  ('d1000000-0000-0000-0000-000000000022', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000004', 'ROK-00022', 'Rokok Filter',            'Rokok filter 16 batang',         25000, 30000,  30,  10, 'bungkus', TRUE),
  ('d1000000-0000-0000-0000-000000000023', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000004', 'KOR-00023', 'Korek Api Gas',           'Korek api gas isi ulang',         3000,  5000,  25,   8, 'pcs',     TRUE),
  ('d1000000-0000-0000-0000-000000000024', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000004', 'PUL-00024', 'Pulsa Elektrik 50rb',     'Voucher pulsa 50.000',           48000, 51000,   0,   5, 'voucher', TRUE),
  ('d1000000-0000-0000-0000-000000000025', 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d', 'c1000000-0000-0000-0000-000000000004', 'KAN-00025', 'Kantong Plastik 1kg',     'Kantong plastik ukuran sedang',  15000, 20000,   5,   5, 'pak',     TRUE);

-- ---------------------------------------------------------------------------
-- 5. TRANSACTIONS (20 total) & TRANSACTION ITEMS
-- ---------------------------------------------------------------------------
-- Dates use NOW() - INTERVAL to create realistic spread over 30 days

DO $$
DECLARE
  v_user_id UUID := 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';
  v_today   TIMESTAMPTZ := NOW();
BEGIN

  -- =========================================================================
  -- TXN-001: Today, cash, no discount
  -- Subtotal: 3500*3 + 4000*2 = 18500
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000001', v_user_id,
    'TRX-' || TO_CHAR(v_today, 'YYYYMMDD') || '-0001',
    18500, 0, 0, 0, 18500, 'cash', 'paid', 20000, 1500, 'Admin', v_today, v_today);

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0001-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000001', 'Mie Goreng Instan', 'MIE-00001', 3, 2500, 3500, 0, 10500, v_today),
    ('f1000000-0000-0000-0001-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000001', 'd1000000-0000-0000-0000-000000000009', 'Air Mineral 600ml',  'AQU-00009', 2, 2500, 4000, 0,  8000, v_today);

  -- =========================================================================
  -- TXN-002: Yesterday, cash, 10% discount
  -- Subtotal: 30000*2 + 5000*1 = 65000, discount=6500, total=58500
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000002', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '1 day', 'YYYYMMDD') || '-0001',
    65000, 6500, 10, 0, 58500, 'cash', 'paid', 60000, 1500, 'Admin', v_today - INTERVAL '1 day', v_today - INTERVAL '1 day');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0002-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000022', 'Rokok Filter',  'ROK-00022', 2, 25000, 30000, 0, 60000, v_today - INTERVAL '1 day'),
    ('f1000000-0000-0000-0002-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000002', 'd1000000-0000-0000-0000-000000000023', 'Korek Api Gas', 'KOR-00023', 1,  3000,  5000, 0,  5000, v_today - INTERVAL '1 day');

  -- =========================================================================
  -- TXN-003: 3 days ago, DEBT unpaid (Bu Siti)
  -- Subtotal: 75000*1 + 15000*2 + 2800*10 = 133000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, customer_name, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, notes, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000003', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '3 days', 'YYYYMMDD') || '-0001',
    'Bu Siti', 133000, 0, 0, 0, 133000, 'debt', 'debt', 'Bayar akhir bulan', 'Admin', v_today - INTERVAL '3 days', v_today - INTERVAL '3 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0003-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000006', 'Beras Premium 5kg', 'BER-00006', 1, 60000, 75000, 0, 75000, v_today - INTERVAL '3 days'),
    ('f1000000-0000-0000-0003-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000005', 'Gula Pasir 1kg',    'GUL-00005', 2, 12000, 15000, 0, 30000, v_today - INTERVAL '3 days'),
    ('f1000000-0000-0000-0003-000000000003', v_user_id, 'e1000000-0000-0000-0000-000000000003', 'd1000000-0000-0000-0000-000000000004', 'Telur Ayam',        'TEL-00004', 10, 2000,  2800, 0, 28000, v_today - INTERVAL '3 days');

  -- =========================================================================
  -- TXN-004: 5 days ago, cash with Rp5000 fixed discount
  -- Subtotal: 19000*2 + 14000*1 = 52000, discount=5000, total=47000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000004', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '5 days', 'YYYYMMDD') || '-0001',
    52000, 5000, 0, 0, 47000, 'cash', 'paid', 50000, 3000, 'Admin', v_today - INTERVAL '5 days', v_today - INTERVAL '5 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0004-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000012', 'Susu UHT 1L', 'SUS-00012', 2, 15000, 19000, 0, 38000, v_today - INTERVAL '5 days'),
    ('f1000000-0000-0000-0004-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000004', 'd1000000-0000-0000-0000-000000000003', 'Roti Tawar',  'ROT-00003', 1, 10000, 14000, 0, 14000, v_today - INTERVAL '5 days');

  -- =========================================================================
  -- TXN-005: 7 days ago, cash
  -- Subtotal: 2500*5 + 5000*3 = 27500
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000005', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '7 days', 'YYYYMMDD') || '-0001',
    27500, 0, 0, 0, 27500, 'cash', 'paid', 30000, 2500, 'Admin', v_today - INTERVAL '7 days', v_today - INTERVAL '7 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0005-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000010', 'Kopi Sachet',     'KOP-00010', 5, 1500, 2500, 0, 12500, v_today - INTERVAL '7 days'),
    ('f1000000-0000-0000-0005-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000005', 'd1000000-0000-0000-0000-000000000011', 'Teh Kotak 250ml', 'TEH-00011', 3, 3000, 5000, 0, 15000, v_today - INTERVAL '7 days');

  -- =========================================================================
  -- TXN-006: 10 days ago, DEBT unpaid (Pak Ahmad)
  -- Subtotal: 28000*1 + 12000*2 = 52000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, customer_name, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, notes, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000006', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '10 days', 'YYYYMMDD') || '-0001',
    'Pak Ahmad', 52000, 0, 0, 0, 52000, 'debt', 'debt', 'Hutang warung', 'Admin', v_today - INTERVAL '10 days', v_today - INTERVAL '10 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0006-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000017', 'Deterjen Bubuk 900g',      'DET-00017', 1, 20000, 28000, 0, 28000, v_today - INTERVAL '10 days'),
    ('f1000000-0000-0000-0006-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000006', 'd1000000-0000-0000-0000-000000000016', 'Sabun Cuci Piring 800ml', 'SAB-00016', 2,  8000, 12000, 0, 24000, v_today - INTERVAL '10 days');

  -- =========================================================================
  -- TXN-007: 12 days ago, cash with 5% discount
  -- Subtotal: 25000*2 + 7500*4 = 80000, discount=4000, total=76000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000007', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '12 days', 'YYYYMMDD') || '-0001',
    80000, 4000, 5, 0, 76000, 'cash', 'paid', 80000, 4000, 'Admin', v_today - INTERVAL '12 days', v_today - INTERVAL '12 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0007-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000007', 'd1000000-0000-0000-0000-000000000007', 'Keju Cheddar Slice', 'KEJ-00007', 2, 18000, 25000, 0, 50000, v_today - INTERVAL '12 days'),
    ('f1000000-0000-0000-0007-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000007', 'd1000000-0000-0000-0000-000000000014', 'Minuman Soda 390ml', 'MIN-00014', 4,  5000,  7500, 0, 30000, v_today - INTERVAL '12 days');

  -- =========================================================================
  -- TXN-008: 14 days ago, cash
  -- Subtotal: 14000*3 + 18000*1 = 60000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000008', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '14 days', 'YYYYMMDD') || '-0001',
    60000, 0, 0, 0, 60000, 'cash', 'paid', 60000, 0, 'Admin', v_today - INTERVAL '14 days', v_today - INTERVAL '14 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0008-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000008', 'Sarden Kaleng',      'SAR-00008', 3, 10000, 14000, 0, 42000, v_today - INTERVAL '14 days'),
    ('f1000000-0000-0000-0008-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000008', 'd1000000-0000-0000-0000-000000000002', 'Nasi Goreng Frozen', 'NAS-00002', 1, 12000, 18000, 0, 18000, v_today - INTERVAL '14 days');

  -- =========================================================================
  -- TXN-009: 15 days ago, DEBT paid (Ibu Rina) - paid 5 days ago
  -- Subtotal: 15000*2 + 1500*10 = 45000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, customer_name, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, notes, cashier_name, transaction_date, debt_paid_at, created_at, updated_at)
  VALUES ('e1000000-0000-0000-0000-000000000009', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '15 days', 'YYYYMMDD') || '-0001',
    'Ibu Rina', 45000, 0, 0, 0, 45000, 'debt', 'paid', 'Sudah lunas', 'Admin',
    v_today - INTERVAL '15 days', v_today - INTERVAL '5 days',
    v_today - INTERVAL '15 days', v_today - INTERVAL '5 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0009-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000009', 'd1000000-0000-0000-0000-000000000018', 'Tisu Wajah 250 lembar', 'TIS-00018',  2, 10000, 15000, 0, 30000, v_today - INTERVAL '15 days'),
    ('f1000000-0000-0000-0009-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000009', 'd1000000-0000-0000-0000-000000000020', 'Sampo Sachet',          'SAM-00020', 10,  1000,  1500, 0, 15000, v_today - INTERVAL '15 days');

  -- =========================================================================
  -- TXN-010: 17 days ago, cash
  -- Subtotal: 12000*2 + 14000*1 = 38000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000010', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '17 days', 'YYYYMMDD') || '-0001',
    38000, 0, 0, 0, 38000, 'cash', 'paid', 40000, 2000, 'Admin', v_today - INTERVAL '17 days', v_today - INTERVAL '17 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0010-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000010', 'd1000000-0000-0000-0000-000000000019', 'Pembalut Wanita', 'PEM-00019', 2,  8000, 12000, 0, 24000, v_today - INTERVAL '17 days'),
    ('f1000000-0000-0000-0010-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000010', 'd1000000-0000-0000-0000-000000000021', 'Pasta Gigi 120g', 'PAS-00021', 1, 10000, 14000, 0, 14000, v_today - INTERVAL '17 days');

  -- =========================================================================
  -- TXN-011: 18 days ago, cash
  -- Subtotal: 4000*6 + 3500*4 = 38000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000011', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '18 days', 'YYYYMMDD') || '-0001',
    38000, 0, 0, 0, 38000, 'cash', 'paid', 40000, 2000, 'Admin', v_today - INTERVAL '18 days', v_today - INTERVAL '18 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0011-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000011', 'd1000000-0000-0000-0000-000000000009', 'Air Mineral 600ml',  'AQU-00009', 6, 2500, 4000, 0, 24000, v_today - INTERVAL '18 days'),
    ('f1000000-0000-0000-0011-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000011', 'd1000000-0000-0000-0000-000000000001', 'Mie Goreng Instan',  'MIE-00001', 4, 2500, 3500, 0, 14000, v_today - INTERVAL '18 days');

  -- =========================================================================
  -- TXN-012: 20 days ago, cash with Rp10000 discount
  -- Subtotal: 75000*2 = 150000, discount=10000, total=140000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000012', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '20 days', 'YYYYMMDD') || '-0001',
    150000, 10000, 0, 0, 140000, 'cash', 'paid', 150000, 10000, 'Admin', v_today - INTERVAL '20 days', v_today - INTERVAL '20 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0012-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000012', 'd1000000-0000-0000-0000-000000000006', 'Beras Premium 5kg', 'BER-00006', 2, 60000, 75000, 0, 150000, v_today - INTERVAL '20 days');

  -- =========================================================================
  -- TXN-013: 22 days ago, DEBT unpaid (Mas Budi)
  -- Subtotal: 30000*3 + 20000*1 = 110000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, customer_name, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, notes, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000013', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '22 days', 'YYYYMMDD') || '-0001',
    'Mas Budi', 110000, 0, 0, 0, 110000, 'debt', 'debt', 'Janji bayar minggu depan', 'Admin', v_today - INTERVAL '22 days', v_today - INTERVAL '22 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0013-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000013', 'd1000000-0000-0000-0000-000000000022', 'Rokok Filter',        'ROK-00022', 3, 25000, 30000, 0, 90000, v_today - INTERVAL '22 days'),
    ('f1000000-0000-0000-0013-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000013', 'd1000000-0000-0000-0000-000000000025', 'Kantong Plastik 1kg', 'KAN-00025', 1, 15000, 20000, 0, 20000, v_today - INTERVAL '22 days');

  -- =========================================================================
  -- TXN-014: 23 days ago, cash
  -- Subtotal: 18000*2 + 2800*15 = 78000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000014', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '23 days', 'YYYYMMDD') || '-0001',
    78000, 0, 0, 0, 78000, 'cash', 'paid', 80000, 2000, 'Admin', v_today - INTERVAL '23 days', v_today - INTERVAL '23 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0014-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000014', 'd1000000-0000-0000-0000-000000000013', 'Sirup Merah 630ml', 'SIR-00013',  2, 12000, 18000, 0, 36000, v_today - INTERVAL '23 days'),
    ('f1000000-0000-0000-0014-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000014', 'd1000000-0000-0000-0000-000000000004', 'Telur Ayam',        'TEL-00004', 15,  2000,  2800, 0, 42000, v_today - INTERVAL '23 days');

  -- =========================================================================
  -- TXN-015: 25 days ago, cash
  -- Subtotal: 5000*5 + 2500*8 = 45000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000015', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '25 days', 'YYYYMMDD') || '-0001',
    45000, 0, 0, 0, 45000, 'cash', 'paid', 50000, 5000, 'Admin', v_today - INTERVAL '25 days', v_today - INTERVAL '25 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0015-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000015', 'd1000000-0000-0000-0000-000000000023', 'Korek Api Gas', 'KOR-00023', 5, 3000, 5000, 0, 25000, v_today - INTERVAL '25 days'),
    ('f1000000-0000-0000-0015-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000015', 'd1000000-0000-0000-0000-000000000010', 'Kopi Sachet',   'KOP-00010', 8, 1500, 2500, 0, 20000, v_today - INTERVAL '25 days');

  -- =========================================================================
  -- TXN-016: 26 days ago, DEBT paid (Mbak Dewi) - paid 10 days ago
  -- Subtotal: 15000*3 + 12000*1 = 57000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, customer_name, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, notes, cashier_name, transaction_date, debt_paid_at, created_at, updated_at)
  VALUES ('e1000000-0000-0000-0000-000000000016', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '26 days', 'YYYYMMDD') || '-0001',
    'Mbak Dewi', 57000, 0, 0, 0, 57000, 'debt', 'paid', 'Lunas', 'Admin',
    v_today - INTERVAL '26 days', v_today - INTERVAL '10 days',
    v_today - INTERVAL '26 days', v_today - INTERVAL '10 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0016-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000016', 'd1000000-0000-0000-0000-000000000005', 'Gula Pasir 1kg',           'GUL-00005', 3, 12000, 15000, 0, 45000, v_today - INTERVAL '26 days'),
    ('f1000000-0000-0000-0016-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000016', 'd1000000-0000-0000-0000-000000000016', 'Sabun Cuci Piring 800ml', 'SAB-00016', 1,  8000, 12000, 0, 12000, v_today - INTERVAL '26 days');

  -- =========================================================================
  -- TXN-017: 27 days ago, cash
  -- Subtotal: 14000*2 + 5000*6 = 58000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000017', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '27 days', 'YYYYMMDD') || '-0001',
    58000, 0, 0, 0, 58000, 'cash', 'paid', 60000, 2000, 'Admin', v_today - INTERVAL '27 days', v_today - INTERVAL '27 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0017-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000017', 'd1000000-0000-0000-0000-000000000003', 'Roti Tawar',      'ROT-00003', 2, 10000, 14000, 0, 28000, v_today - INTERVAL '27 days'),
    ('f1000000-0000-0000-0017-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000017', 'd1000000-0000-0000-0000-000000000011', 'Teh Kotak 250ml', 'TEH-00011', 6,  3000,  5000, 0, 30000, v_today - INTERVAL '27 days');

  -- =========================================================================
  -- TXN-018: 28 days ago, cash with 15% discount
  -- Subtotal: 28000*2 + 19000*2 = 94000, discount=14100, total=79900
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000018', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '28 days', 'YYYYMMDD') || '-0001',
    94000, 14100, 15, 0, 79900, 'cash', 'paid', 80000, 100, 'Admin', v_today - INTERVAL '28 days', v_today - INTERVAL '28 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0018-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000018', 'd1000000-0000-0000-0000-000000000017', 'Deterjen Bubuk 900g', 'DET-00017', 2, 20000, 28000, 0, 56000, v_today - INTERVAL '28 days'),
    ('f1000000-0000-0000-0018-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000018', 'd1000000-0000-0000-0000-000000000012', 'Susu UHT 1L',         'SUS-00012', 2, 15000, 19000, 0, 38000, v_today - INTERVAL '28 days');

  -- =========================================================================
  -- TXN-019: 29 days ago, cash
  -- Subtotal: 3500*10 + 4000*5 = 55000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000019', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '29 days', 'YYYYMMDD') || '-0001',
    55000, 0, 0, 0, 55000, 'cash', 'paid', 55000, 0, 'Admin', v_today - INTERVAL '29 days', v_today - INTERVAL '29 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0019-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000019', 'd1000000-0000-0000-0000-000000000001', 'Mie Goreng Instan', 'MIE-00001', 10, 2500, 3500, 0, 35000, v_today - INTERVAL '29 days'),
    ('f1000000-0000-0000-0019-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000019', 'd1000000-0000-0000-0000-000000000009', 'Air Mineral 600ml',  'AQU-00009',  5, 2500, 4000, 0, 20000, v_today - INTERVAL '29 days');

  -- =========================================================================
  -- TXN-020: 30 days ago, cash
  -- Subtotal: 2800*20 + 15000*1 = 71000
  -- =========================================================================
  INSERT INTO public.transactions (id, user_id, transaction_number, subtotal, discount_amount, discount_percentage, tax_amount, total, payment_method, payment_status, cash_received, cash_change, cashier_name, transaction_date, created_at)
  VALUES ('e1000000-0000-0000-0000-000000000020', v_user_id,
    'TRX-' || TO_CHAR(v_today - INTERVAL '30 days', 'YYYYMMDD') || '-0001',
    71000, 0, 0, 0, 71000, 'cash', 'paid', 75000, 4000, 'Admin', v_today - INTERVAL '30 days', v_today - INTERVAL '30 days');

  INSERT INTO public.transaction_items (id, user_id, transaction_id, product_id, product_name, product_sku, quantity, cost_price, selling_price, discount_amount, subtotal, created_at) VALUES
    ('f1000000-0000-0000-0020-000000000001', v_user_id, 'e1000000-0000-0000-0000-000000000020', 'd1000000-0000-0000-0000-000000000004', 'Telur Ayam',    'TEL-00004', 20, 2000,  2800, 0, 56000, v_today - INTERVAL '30 days'),
    ('f1000000-0000-0000-0020-000000000002', v_user_id, 'e1000000-0000-0000-0000-000000000020', 'd1000000-0000-0000-0000-000000000005', 'Gula Pasir 1kg', 'GUL-00005',  1, 12000, 15000, 0, 15000, v_today - INTERVAL '30 days');

END $$;
