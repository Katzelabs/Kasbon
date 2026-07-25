# KASBON - Feature Prioritization & Development Phases
## Refined MVP & Roadmap

> ⚠️ **HISTORICAL DOCUMENT (planning-phase).** Feature priorities remain useful
> context, but references to SQLite/offline-first/cloud-sync are outdated — the
> project is now **Supabase-only** (cloud-native, no local database, no sync layer;
> TASK_018 Cloud Sync is obsolete). For completed vs. remaining work see
> the ClickUp Kasbon space (see root `CLAUDE.md`); for current architecture see root `CLAUDE.md`.

---

## 📊 EXECUTIVE SUMMARY

**Original Plan:** 6 bulan, 20+ features di MVP  
**Refined Plan:** 2 bulan MVP (8 core features) → 1 bulan polish → Launch  
**Philosophy:** Ship fast, validate early, iterate based on real user feedback

**Key Changes:**
- ✅ Reduced MVP scope by 60% (focus on core value)
- ✅ Moved "nice-to-have" features to post-launch
- ✅ Prioritized features based on user pain points, not tech coolness
- ✅ Clear upgrade triggers for Pro tier

---

## 🎯 FEATURE CATEGORIZATION

### Legend:
- **P0 (Critical):** App tidak berguna tanpa ini
- **P1 (Core):** Fitur yang bikin user stay & love the app
- **P2 (Differentiator):** Fitur yang bikin menang vs competitor
- **P3 (Nice-to-Have):** Bagus ada, tapi bisa ditunda
- **P4 (Future):** Premature, distract dari core value

---

## ⚡ PHASE 0: TRUE MVP (Week 1-8)
**Goal:** Prove core value proposition - "Aplikasi kasir paling mudah untuk warung kecil"  
**Target:** 50-100 early adopters, 70%+ satisfaction rate

### P0: CRITICAL FEATURES (Must Have)

#### 1. Product Management (Basic)
**Priority:** P0  
**Complexity:** LOW  
**Development Time:** 1 week

**Features:**
- ✅ Add product (nama, harga jual, harga modal, stok awal)
- ✅ Edit product (all fields)
- ✅ Delete product (soft delete dengan confirmation)
- ✅ View product list (list view dengan search)
- ✅ Search product by name (real-time search)
- ❌ NO barcode scanner (v1.1)
- ❌ NO photo upload (v1.1)
- ❌ NO category management (auto "Lainnya")

**Database Schema:**
```sql
products
- id (UUID, PK)
- name (String) *required
- sku (String, auto-generated) *unique
- cost_price (Decimal) *required - Harga modal
- selling_price (Decimal) *required - Harga jual
- stock (Integer, default: 0)
- min_stock (Integer, default: 5)
- unit (String, default: 'pcs')
- is_active (Boolean, default: true)
- created_at (DateTime)
- updated_at (DateTime)
```

**User Story:**
> "Sebagai pemilik warung, saya ingin menambah produk dengan nama dan harga saja, tanpa ribet isi banyak field, sehingga saya bisa langsung mulai jualan."

**Success Metric:**
- User dapat menambah 10 produk dalam < 5 menit
- Search produk < 1 detik response time

---

#### 2. Point of Sale (POS) - Cash Only
**Priority:** P0  
**Complexity:** MEDIUM  
**Development Time:** 2 weeks

**Features:**
- ✅ Search produk by name (dengan autocomplete)
- ✅ Add product to cart
- ✅ Adjust quantity per item (+/- buttons)
- ✅ Show cart summary (subtotal, total)
- ✅ CASH payment ONLY
- ✅ Calculate change (uang diterima - total)
- ✅ Complete transaction (simpan ke database)
- ✅ Auto-reduce stock
- ❌ NO barcode scan (v1.1)
- ❌ NO discount per item (v1.1)
- ❌ NO multiple payment methods (Phase 2)

**UI/UX Requirements:**
```
Layout:
- Search bar (top, prominent)
- Product quick access (grid atau list)
- Cart (fixed bottom atau bottom sheet)
- Large "BAYAR" button (always visible)

Input Method:
- On-screen number pad untuk quantity
- Keyboard HP untuk search
- Quick buttons: +1, +5, +10 untuk quantity

Flow:
1. Search produk → 2. Add to cart → 3. Adjust quantity → 
4. Tap "Bayar" → 5. Input uang diterima → 6. Show change → 
7. Complete transaction
```

**User Story:**
> "Sebagai kasir, saya ingin transaksi selesai dalam < 30 detik untuk 3 item, sehingga antrian tidak panjang dan pembeli tidak kabur."

**Success Metric:**
- Transaction completion time: < 30 detik (median)
- Cart abandonment rate: < 5%
- User error rate (salah input): < 2%

---

#### 3. Transaction History
**Priority:** P0  
**Complexity:** LOW  
**Development Time:** 3 days

**Features:**
- ✅ List all transactions (newest first)
- ✅ Show transaction detail (items, total, date)
- ✅ Filter by date (today, yesterday, last 7 days, custom range)
- ✅ Search by transaction number
- ❌ NO filter by customer (Phase 1.5)
- ❌ NO export to Excel (v1.1)

**Database Schema:**
```sql
transactions
- id (UUID, PK)
- transaction_number (String, unique) - Format: TRX-YYYYMMDD-XXXX
- subtotal (Decimal)
- total (Decimal)
- payment_method (Enum: cash, transfer_manual, debt) - Default: cash
- payment_status (Enum: paid, debt) - Default: paid
- cash_received (Decimal, nullable)
- cash_change (Decimal, nullable)
- notes (Text, nullable) - For debt tracking
- transaction_date (DateTime)
- created_at (DateTime)

transaction_items
- id (UUID, PK)
- transaction_id (UUID, FK)
- product_id (UUID, FK)
- product_name (String) - Snapshot
- quantity (Integer)
- cost_price (Decimal) - Snapshot
- selling_price (Decimal) - Snapshot
- subtotal (Decimal) - quantity * selling_price
- created_at (DateTime)
```

**User Story:**
> "Sebagai pemilik toko, saya ingin melihat semua transaksi hari ini, sehingga saya tahu penjualan berjalan lancar atau tidak."

**Success Metric:**
- Page load time: < 2 detik (for 100 transactions)
- User checks history: min 2x per day

---

#### 4. Dashboard - Sales Summary
**Priority:** P0  
**Complexity:** LOW  
**Development Time:** 2 days

**Features:**
- ✅ Total penjualan hari ini (Rp)
- ✅ Jumlah transaksi hari ini
- ✅ Perbandingan dengan kemarin (% increase/decrease)
- ✅ Quick action buttons (Kasir, Tambah Produk)
- ❌ NO charts/graphs (v1.1)
- ❌ NO top products (v1.1)

**UI Layout:**
```
┌─────────────────────────────────────┐
│  KASBON Dashboard                    │
├─────────────────────────────────────┤
│                                      │
│  💰 Penjualan Hari Ini              │
│     Rp 1.250.000                    │
│     ▲ +15% dari kemarin             │
│                                      │
│  📦 Transaksi                       │
│     45 transaksi                     │
│                                      │
│  [Mulai Kasir]  [Tambah Produk]    │
│                                      │
└─────────────────────────────────────┘
```

**User Story:**
> "Sebagai pemilik warung, hal pertama yang saya lihat saat buka app adalah total jualan hari ini, sehingga saya langsung tahu 'gimana nih hari ini?'"

**Success Metric:**
- Dashboard loads in < 1 second
- User visits dashboard: 5+ times per day (sticky feature)

---

#### 5. Receipt / Struk (Digital)
**Priority:** P0  
**Complexity:** LOW  
**Development Time:** 2 days

**Features:**
- ✅ Generate text-based receipt
- ✅ Share via WhatsApp (or any app)
- ✅ Copy to clipboard
- ✅ Customizable shop info (nama, alamat, telp)
- ❌ NO PDF generation (v1.1)
- ❌ NO thermal print (v1.2)
- ❌ NO email receipt (not needed)

**Receipt Format:**
```
========================================
        WARUNG BU SITI
    Jl. Raya No. 123, Jakarta
        0812-3456-7890
========================================
TRX-20241124-0001
Tanggal: 24 Nov 2024, 14:30

----------------------------------------
Item                    Qty   Subtotal
----------------------------------------
Indomie Goreng           5    Rp 15.000
Aqua 600ml               3    Rp  9.000
Teh Botol                2    Rp  8.000
----------------------------------------
                    Total: Rp 32.000
              Uang Terima: Rp 50.000
               Kembalian: Rp 18.000
========================================
   Terima kasih atas kunjungannya!
       Powered by KASBON
========================================
```

**User Story:**
> "Sebagai pemilik warung, saya ingin kasih struk ke pembeli lewat WhatsApp, sehingga pembeli merasa dilayani dengan profesional."

**Success Metric:**
- Receipt share rate: > 30% of transactions
- WhatsApp share: > 90% of receipt shares

---

#### 6. Stock Tracking (Auto-Deduct)
**Priority:** P0  
**Complexity:** MEDIUM  
**Development Time:** 2 days

**Features:**
- ✅ Stock berkurang otomatis saat transaksi
- ✅ Show current stock di product list
- ✅ Visual indicator: Low stock (< min_stock) dengan warna merah/kuning
- ✅ Prevent negative stock (optional setting)
- ❌ NO stock adjustment UI (manual edit product for now)
- ❌ NO stock movement history (v1.1)

**Logic:**
```dart
// On transaction complete:
for (item in transaction_items) {
  product = getProduct(item.product_id);
  product.stock -= item.quantity;
  
  if (product.stock < 0 && preventNegativeStock) {
    throw Exception("Stok tidak cukup!");
  }
  
  updateProduct(product);
}
```

**User Story:**
> "Sebagai pemilik toko, saya ingin stok barang berkurang otomatis saat saya jual, sehingga saya tidak perlu catat manual dan tidak pernah salah hitung stok."

**Success Metric:**
- Stock accuracy: 100% (automated, no human error)
- User reports "stok salah": < 1% (mostly due to manual adjustment needed)

---

#### 7. Profit Calculation & Display
**Priority:** P1 (Core, but could be P0)  
**Complexity:** MEDIUM  
**Development Time:** 3 days

**Features:**
- ✅ Track harga modal per produk (cost_price)
- ✅ Calculate profit per transaction: (selling_price - cost_price) * quantity
- ✅ Show profit di dashboard (today, this week, this month)
- ✅ Show profit margin % per product
- ✅ Report: Produk mana yang paling menguntungkan
- ❌ NO COGS tracking (complicated, Phase 2)

**Dashboard Addition:**
```
┌─────────────────────────────────────┐
│  💰 Penjualan Hari Ini              │
│     Rp 1.250.000                    │
│                                      │
│  💵 Laba Bersih                     │
│     Rp   250.000 (20% margin)       │
│     ▲ +25% dari kemarin             │
└─────────────────────────────────────┘
```

**Calculation:**
```
Per Transaction:
- Revenue (Penjualan) = Σ (selling_price * quantity)
- COGS (Modal) = Σ (cost_price * quantity)
- Profit (Laba) = Revenue - COGS
- Margin % = (Profit / Revenue) * 100

Per Product:
- Profit per unit = selling_price - cost_price
- Total profit = (selling_price - cost_price) * quantity_sold
```

**User Story:**
> "Sebagai pemilik toko, saya ingin tahu UNTUNG saya berapa, bukan cuma JUALAN berapa, sehingga saya bisa evaluasi: apakah bisnis saya sehat atau tidak."

**Success Metric:**
- 100% products have cost_price filled (required field)
- Users check profit report: min 1x per day
- User feedback: "Ini fitur yang saya cari!" (testimonial)

**💡 DIFFERENTIATOR:**
This feature is RARE in free/cheap POS apps! Most competitors only show revenue, not profit. This could be your **KILLER FEATURE**.

---

#### 8. Offline-First Architecture
**Priority:** P0  
**Complexity:** LOW (if designed from start)  
**Development Time:** Embedded in all features

**Features:**
- ✅ All data stored locally (SQLite)
- ✅ ZERO internet required for core features
- ✅ Fast & responsive (no network latency)
- ✅ Clear offline indicator (if relevant)
- ❌ NO cloud sync (Phase 2)

**Technical Implementation:**
```dart
// Database: SQLite (via sqflite package)
// State Management: Riverpod/Bloc
// No API calls in MVP

Architecture:
lib/
├── data/
│   ├── local/
│   │   ├── database.dart (SQLite setup)
│   │   └── dao/ (Data Access Objects)
│   └── models/ (Product, Transaction, etc)
├── domain/
│   └── repositories/ (Abstract interfaces)
└── presentation/
    └── screens/
```

**User Story:**
> "Sebagai pemilik warung di pasar yang internetnya sering mati, saya ingin aplikasi kasir tetap jalan lancar tanpa internet, sehingga saya tidak kehilangan penjualan."

**Success Metric:**
- App works 100% offline (no internet required)
- Crash rate due to network issues: 0%
- App launch time: < 2 seconds (cold start)

**💡 DIFFERENTIATOR:**
Competitor apps (Kasir Pintar, Moka) often slow down or crash when internet is unstable. This is your **BIGGEST ADVANTAGE** for warung kecil market.

---

### P1: CORE FEATURES (Should Have - Pre-Launch Polish)

#### 9. Debt Tracking (Hutang Piutang) - Simple Version
**Priority:** P1  
**Complexity:** MEDIUM  
**Development Time:** 1 week

**Features:**
- ✅ Mark transaction as "Hutang" (debt payment)
- ✅ Add customer name to transaction (optional text field)
- ✅ Add notes (e.g., "Bayar tanggal 30")
- ✅ List of unpaid debts (filter: status = debt)
- ✅ Mark debt as "Lunas" (paid)
- ✅ Total hutang per customer (simple aggregation)
- ❌ NO customer database yet (Phase 1.5)
- ❌ NO payment installment (Phase 2)
- ❌ NO auto reminder (Phase 2)

**UI Flow:**
```
POS Screen:
- Add to cart → Tap "Bayar" → 
- Choose payment: [Cash] [Transfer] [Hutang]
- If Hutang:
  - Input: Nama pembeli (required)
  - Input: Catatan (optional, e.g., "Bayar akhir bulan")
  - Save as transaction with status = debt

Debt List Screen:
- List all unpaid transactions
- Group by customer name
- Show: Nama, Total hutang, Tanggal, Catatan
- Action: [Tandai Lunas]
```

**Database Schema Addition:**
```sql
transactions (modified)
- payment_status (Enum: paid, debt) - New field
- customer_name (String, nullable) - For debt tracking
- debt_paid_at (DateTime, nullable) - When debt was paid

Views:
- Unpaid debts: WHERE payment_status = 'debt'
- Total debt per customer: GROUP BY customer_name
```

**User Story:**
> "Sebagai pemilik warung, saya punya langganan yang sering 'bon dulu', saya ingin catat hutangnya di app, sehingga saya tidak lupa dan tidak salah hitung."

**Success Metric:**
- Debt tracking usage: > 20% of users (validates need)
- Debt collection rate: improved (subjective, need user feedback)
- User testimonial: "Fitur hutang sangat membantu!"

**💡 DIFFERENTIATOR:**
This is a **CULTURE-SPECIFIC FEATURE** for Indonesia! Very few competitors have this in free/cheap tier. This could be your **UNIQUE SELLING POINT** for warung market.

---

#### 10. Low Stock Alert
**Priority:** P1  
**Complexity:** LOW  
**Development Time:** 1 day

**Features:**
- ✅ Visual alert on dashboard: "5 produk stok menipis"
- ✅ List of low-stock products (stock <= min_stock)
- ✅ Tap to view detail
- ✅ Quick action: "Edit Produk" untuk restock
- ❌ NO push notification (v1.1)
- ❌ NO email alert (not needed)

**UI:**
```
Dashboard Addition:
┌─────────────────────────────────────┐
│  ⚠️  PERHATIAN                      │
│  5 produk stok menipis!             │
│  [Lihat Detail]                      │
└─────────────────────────────────────┘

Low Stock Screen:
┌─────────────────────────────────────┐
│  Stok Menipis                        │
├─────────────────────────────────────┤
│  🔴 Indomie Goreng (2 pcs)          │
│  🟡 Aqua 600ml (4 pcs)              │
│  🔴 Teh Botol (1 pcs)               │
└─────────────────────────────────────┘
```

**User Story:**
> "Sebagai pemilik warung, saya ingin dikasih tahu kalau stok hampir habis, sehingga saya bisa beli lagi sebelum kehabisan dan kehilangan penjualan."

**Success Metric:**
- Alert click-through rate: > 50%
- Stock-out incidents reduced (need user feedback)

---

#### 11. Search Product in POS
**Priority:** P1  
**Complexity:** LOW  
**Development Time:** 1 day

**Features:**
- ✅ Real-time search as user types
- ✅ Search by product name (case-insensitive)
- ✅ Highlight matched text
- ✅ Show max 20 results (pagination if needed)
- ✅ Tap to add to cart
- ❌ NO fuzzy search (exact match only for MVP)
- ❌ NO search by SKU/barcode (v1.1)

**Technical:**
```dart
// SQLite query
SELECT * FROM products 
WHERE name LIKE '%$query%' 
  AND is_active = true
ORDER BY name ASC
LIMIT 20;

// Optimization: Add index on name column
CREATE INDEX idx_products_name ON products(name);
```

**User Story:**
> "Sebagai kasir, saya ingin cepat cari produk dengan ketik beberapa huruf, sehingga transaksi selesai lebih cepat dan pembeli tidak menunggu lama."

**Success Metric:**
- Search usage rate: > 80% of transactions use search
- Search result time: < 500ms
- User satisfaction: "Kasir jadi cepat!"

---

#### 12. Basic Reports (Weekly/Monthly)
**Priority:** P1  
**Complexity:** MEDIUM  
**Development Time:** 3 days

**Features:**
- ✅ Report: Penjualan per hari (last 7 days, last 30 days)
- ✅ Report: Top 5 produk terlaris (by quantity sold)
- ✅ Report: Top 5 produk paling untung (by profit)
- ✅ Simple bar chart (using fl_chart)
- ✅ Export summary as text (copy to clipboard)
- ❌ NO Excel export (v1.1)
- ❌ NO PDF report (v1.1)

**Reports Included:**
```
1. Ringkasan Penjualan
   - Hari ini: Rp X (Y transaksi)
   - Minggu ini: Rp X (Y transaksi)
   - Bulan ini: Rp X (Y transaksi)
   - Perbandingan dengan periode sebelumnya

2. Produk Terlaris (Top 5)
   - Nama produk
   - Jumlah terjual
   - Total penjualan

3. Produk Paling Untung (Top 5)
   - Nama produk
   - Total profit
   - Profit margin %

4. Trend Penjualan (Chart)
   - Bar chart: Penjualan per hari (last 7 days)
```

**User Story:**
> "Sebagai pemilik toko, saya ingin lihat produk apa yang paling laku dan paling untung, sehingga saya bisa stock lebih banyak untuk produk tersebut."

**Success Metric:**
- Report view rate: > 40% users check reports weekly
- Actionable insights: User feedback on "helpful reports"

---

#### 13. Settings & Shop Profile
**Priority:** P1  
**Complexity:** LOW  
**Development Time:** 2 days

**Features:**
- ✅ Shop profile (nama, alamat, telepon)
- ✅ Receipt customization (header, footer)
- ✅ Currency format (default: Rp)
- ✅ Min stock threshold setting (default: 5)
- ✅ App preferences (theme: light/dark)
- ✅ Data management (backup, restore)
- ❌ NO multi-language (Indonesian only for MVP)

**Settings Screen:**
```
┌─────────────────────────────────────┐
│  Pengaturan                          │
├─────────────────────────────────────┤
│  🏪 Profil Toko                     │
│  🧾 Pengaturan Struk                │
│  💰 Mata Uang & Format              │
│  📦 Stok & Inventori                │
│  🎨 Tampilan App                    │
│  💾 Backup & Restore                │
│  ℹ️  Tentang KASBON                 │
└─────────────────────────────────────┘
```

**User Story:**
> "Sebagai pemilik toko, saya ingin mengatur nama toko dan nomor telepon yang muncul di struk, sehingga pembeli bisa kontak saya kalau ada masalah."

**Success Metric:**
- 100% users fill shop profile (onboarding requirement)
- Settings visit rate: > 1x per user (lifetime)

---

#### 14. Data Backup & Restore (Local)
**Priority:** P1  
**Complexity:** MEDIUM  
**Development Time:** 2 days

**Features:**
- ✅ Export database to JSON file
- ✅ Save to device storage (Documents/KASBON/)
- ✅ Share backup file (via WhatsApp, Drive, etc)
- ✅ Restore from JSON file
- ✅ Backup file naming: kasbon_backup_YYYYMMDD_HHMMSS.json
- ❌ NO auto backup (v1.1)
- ❌ NO cloud backup (Phase 2)

**Technical:**
```dart
// Export
Map<String, dynamic> backup = {
  'version': '1.0',
  'backup_date': DateTime.now().toIso8601String(),
  'shop': shopData,
  'products': allProducts,
  'transactions': allTransactions,
  'transaction_items': allTransactionItems,
};

String json = jsonEncode(backup);
File file = File('kasbon_backup_${timestamp}.json');
file.writeAsString(json);

// Restore
String json = file.readAsStringSync();
Map<String, dynamic> backup = jsonDecode(json);
// Validate version, then restore data
```

**User Story:**
> "Sebagai pemilik toko, saya ingin backup data saya, sehingga kalau HP hilang atau rusak, data saya tidak hilang."

**Success Metric:**
- Backup usage rate: > 30% users backup at least once
- Restore success rate: 100% (no data corruption)
- User trust: "Data saya aman"

---

## 📦 PHASE 1: POST-LAUNCH IMPROVEMENTS (Week 9-12)
**Goal:** Improve UX based on user feedback, add quick wins  
**Trigger:** After 100+ active users, collect feedback

### P3: NICE-TO-HAVE FEATURES (Quick Wins)

#### 15. Barcode Scanner
**Priority:** P3  
**Complexity:** MEDIUM  
**Development Time:** 3 days

**Features:**
- ✅ Scan barcode using camera (mobile_scanner)
- ✅ Search product by barcode
- ✅ Auto-add to cart if found
- ✅ Suggest to create product if not found
- ✅ Support EAN-13, UPC-A, Code 128
- ❌ NO QR code scanning (not needed for products)

**When to Build:**
- After validated: Users actually need this (survey/feedback)
- Target market: Minimarket, toko buku, apotek (not warung)

**User Story:**
> "Sebagai kasir di minimarket, saya ingin scan barcode produk dengan kamera HP, sehingga transaksi lebih cepat daripada ketik manual."

**Success Metric:**
- Barcode scan usage: > 30% of transactions (if validated)
- Scan success rate: > 95%

---

#### 16. Product Photo Upload
**Priority:** P3  
**Complexity:** MEDIUM  
**Development Time:** 2 days

**Features:**
- ✅ Take photo using camera (image_picker)
- ✅ Choose from gallery
- ✅ Image compression (max 500KB per image)
- ✅ Thumbnail generation (100x100px)
- ✅ Delete photo
- ❌ NO multiple photos (1 photo per product)
- ❌ NO cloud storage (local storage only for MVP)

**When to Build:**
- After validated: Toko baju, toko aksesoris users request this
- Storage concern: Monitor avg app size

**User Story:**
> "Sebagai pemilik toko baju, saya ingin foto produk saya, sehingga kasir tidak salah kasih barang (banyak model serupa)."

**Success Metric:**
- Photo upload rate: > 40% of products have photos (if validated)
- App size increase: < 200MB (monitor)

---

#### 17. Category Management
**Priority:** P3  
**Complexity:** LOW  
**Development Time:** 2 days

**Features:**
- ✅ Create category (nama, warna, icon)
- ✅ Edit/delete category
- ✅ Assign product to category
- ✅ Filter products by category (in POS)
- ✅ Category-based reports

**When to Build:**
- After validated: Users with 50+ products request this
- Default categories: Makanan, Minuman, Kebutuhan Rumah, Lainnya

**User Story:**
> "Sebagai pemilik toko dengan 200+ produk, saya ingin kelompokkan produk per kategori, sehingga lebih mudah cari dan kelola."

**Success Metric:**
- Category usage rate: > 50% users create at least 1 category
- Products categorized: > 70% of total products

---

#### 18. Print via Bluetooth Thermal Printer
**Priority:** P3  
**Complexity:** HIGH  
**Development Time:** 1 week

**Features:**
- ✅ Connect to Bluetooth printer
- ✅ Print receipt (ESC/POS format)
- ✅ Support popular brands (EPPOS, Iware, Zjiang)
- ✅ Test print function
- ⚠️ Device compatibility hell (many printer models)

**When to Build:**
- After validated: Cafe, restaurant, retail users request this
- Consider: Partnership with printer brands for testing

**User Story:**
> "Sebagai pemilik cafe, saya ingin print struk pakai printer thermal, sehingga pembeli dapat struk kertas seperti cafe modern lainnya."

**Success Metric:**
- Print usage rate: > 20% users connect printer (if validated)
- Print success rate: > 80% (compatibility issues expected)

**⚠️ CAUTION:**
Thermal printer support is HARD. Many printer models, inconsistent ESC/POS implementation. Consider outsourcing this to plugin developer or delay until Phase 2.

---

#### 19. Transaction Discount (Global)
**Priority:** P3  
**Complexity:** LOW  
**Development Time:** 1 day

**Features:**
- ✅ Apply discount to total transaction (Rp or %)
- ✅ Show discount amount in receipt
- ✅ Track discount in reports
- ❌ NO per-item discount yet (Phase 2)
- ❌ NO promo rules (Phase 3)

**When to Build:**
- After user feedback: "Saya sering kasih diskon, bisa gak?"

**User Story:**
> "Sebagai pemilik warung, saya ingin kasih diskon untuk pelanggan setia, sehingga mereka merasa dihargai dan balik lagi."

---

#### 20. Export Reports to Excel/PDF
**Priority:** P3  
**Complexity:** MEDIUM  
**Development Time:** 3 days

**Features:**
- ✅ Export transaction history to Excel (xlsx)
- ✅ Export sales report to PDF
- ✅ Email or share file
- ✅ Custom date range for export

**When to Build:**
- After user feedback: "Perlu laporan untuk akuntan/pajak"

**User Story:**
> "Sebagai pemilik toko, saya perlu export laporan untuk akuntan saya yang urus pajak, sehingga saya tidak perlu catat manual lagi."

---

## 🚀 PHASE 2: CLOUD SYNC & MONETIZATION (Month 4-5)
**Goal:** Enable Pro tier, start generating revenue  
**Trigger:** After 500+ free users, 50+ highly engaged users

### P2: DIFFERENTIATOR FEATURES (Upgrade Triggers)

#### 21. User Authentication & Account
**Priority:** P2 (Phase 2)  
**Complexity:** MEDIUM  
**Development Time:** 1 week

**Features:**
- ✅ Email/password registration
- ✅ Login with email
- ✅ Google Sign-In (optional)
- ✅ Phone verification via OTP (optional)
- ✅ Password reset (email link)
- ✅ Account profile (name, email, phone)
- ❌ NO social login (Facebook, Apple) yet

**Technical Stack:**
```
Option 1: Supabase Auth (Recommended)
- Built-in email/password
- Built-in Google OAuth
- JWT tokens
- Row Level Security (RLS)

Option 2: Firebase Auth
- Similar features
- More mature, but more expensive

Option 3: Custom Backend (Node.js + JWT)
- Full control, but more work
```

**User Story:**
> "Sebagai pengguna Pro, saya ingin daftar akun dengan email, sehingga data saya bisa disimpan di cloud dan diakses dari HP lain."

---

#### 22. Cloud Backup & Sync
**Priority:** P2 (Phase 2)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Auto backup to cloud (real-time or scheduled)
- ✅ Manual backup trigger
- ✅ Restore from cloud (on new device)
- ✅ Sync across multiple devices (max 2 for Pro)
- ✅ Conflict resolution (last-write-wins)
- ✅ Sync status indicator (synced, syncing, conflict)
- ⚠️ Sync logic is COMPLEX (handle offline edits, conflicts)

**Sync Strategy:**
```
Approach: Delta Sync (only sync changes, not full database)

Sync Log Table:
- entity_type (products, transactions, etc)
- entity_id
- action (create, update, delete)
- data (JSON snapshot)
- synced_at (timestamp)
- device_id

Conflict Resolution:
- Last-write-wins (based on timestamp)
- Critical conflicts: Show UI to resolve
```

**User Story:**
> "Sebagai pemilik toko dengan 2 HP (saya dan kasir), saya ingin data selalu sinkron, sehingga kami berdua bisa input transaksi tanpa khawatir data bentrok."

**Success Metric:**
- Sync success rate: > 99%
- Sync conflicts: < 1% of operations
- User reports "data hilang": 0%

**💡 THIS IS YOUR MAIN UPGRADE TRIGGER:**
Free users will hit pain point: "Data saya hilang karena HP rusak/hilang"  
→ Upgrade to Pro for cloud backup!

---

#### 23. Customer Database (Full)
**Priority:** P2 (Phase 2)  
**Complexity:** MEDIUM  
**Development Time:** 1 week

**Features:**
- ✅ Create customer profile (nama, phone, email, address)
- ✅ Link transaction to customer
- ✅ Customer transaction history (all purchases)
- ✅ Total spent per customer
- ✅ Total debt per customer (linked to debt tracking)
- ✅ Customer notes (e.g., "Suka beli banyak akhir bulan")
- ✅ Search customer
- ❌ NO loyalty program yet (Phase 3)

**Database Schema:**
```sql
customers
- id (UUID, PK)
- name (String) *required
- phone (String, unique)
- email (String, nullable)
- address (Text, nullable)
- total_spent (Decimal, default: 0) - Auto-calculated
- total_transactions (Integer, default: 0) - Auto-calculated
- total_debt (Decimal, default: 0) - From unpaid transactions
- notes (Text, nullable)
- created_at (DateTime)
- updated_at (DateTime)

transactions (modified):
- customer_id (UUID, FK -> customers.id, nullable)
```

**User Story:**
> "Sebagai pemilik toko, saya ingin simpan data pelanggan setia, sehingga saya bisa kasih promo khusus untuk mereka dan maintain relationship."

**Success Metric:**
- Customer database usage: > 30% Pro users
- Customers created: avg 20+ per user
- Transaction linking rate: > 50% of transactions linked to customer

---

#### 24. QRIS Payment Integration
**Priority:** P2 (Phase 2)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Generate QRIS code (via Xendit API)
- ✅ Display QR code for customer to scan
- ✅ Auto-verify payment (webhook)
- ✅ Update transaction status (pending → paid)
- ✅ Support: GoPay, Dana, OVO, ShopeePay, LinkAja
- ⚠️ Need business entity (CV/PT) for Xendit approval

**Technical Stack:**
```
Payment Gateway: Xendit (Indonesia-focused)
- QRIS: 0.7% fee per transaction
- No setup fee
- Webhook for payment verification
- API documentation: https://developers.xendit.co/

Alternative: Midtrans
- Similar features, similar pricing
- More established, but more complex

Flow:
1. User taps "Bayar QRIS"
2. App calls Xendit API: Create QR Code
3. Display QR code on screen
4. Customer scans with e-wallet
5. Xendit sends webhook: Payment success
6. App updates transaction status
```

**User Story:**
> "Sebagai pemilik cafe, saya ingin terima pembayaran QRIS, sehingga pembeli tidak perlu bawa cash dan saya tidak perlu kasih kembalian."

**Success Metric:**
- QRIS adoption rate: > 40% Pro users enable QRIS
- QRIS transaction volume: > 20% of total transactions
- Payment success rate: > 95%

**💡 REVENUE MODEL:**
- You can charge fee: Rp 2000 per QRIS transaction (on top of Pro subscription)
- Or: Negotiate revenue share with Xendit (if volume is high)

---

#### 25. Advanced Reports & Analytics
**Priority:** P2 (Phase 2)  
**Complexity:** MEDIUM  
**Development Time:** 1 week

**Features:**
- ✅ Sales trend chart (daily, weekly, monthly)
- ✅ Profit trend chart
- ✅ Best-selling products (by revenue & quantity)
- ✅ Sales by category (pie chart)
- ✅ Sales by payment method (cash vs transfer vs QRIS)
- ✅ Hourly sales pattern (peak hours)
- ✅ Customer segmentation (top 10%, active, inactive)
- ✅ Export all reports to Excel/PDF

**Charts Included:**
```
1. Sales Trend (Line Chart)
   - X-axis: Date
   - Y-axis: Revenue
   - Compare: This month vs last month

2. Profit Trend (Line Chart)
   - X-axis: Date
   - Y-axis: Profit
   - Show margin %

3. Product Performance (Bar Chart)
   - Top 10 products by revenue
   - Top 10 products by quantity sold
   - Bottom 10 products (slow movers)

4. Category Distribution (Pie Chart)
   - Revenue by category
   - Profit by category

5. Payment Method (Pie Chart)
   - Cash, Transfer, QRIS breakdown

6. Hourly Sales Pattern (Heatmap)
   - X-axis: Hour (0-23)
   - Y-axis: Day of week
   - Color: Sales volume
```

**User Story:**
> "Sebagai pemilik toko yang lebih serious, saya ingin analisa data penjualan, sehingga saya bisa buat keputusan bisnis yang lebih baik (misal: kapan harus restock, produk mana yang harus didiskon, dll)."

**Success Metric:**
- Analytics view rate: > 60% Pro users check analytics weekly
- Actionable insights: User feedback on "helpful for decision making"

---

#### 26. Multiple Payment Methods (Transfer, Debit, Credit)
**Priority:** P2 (Phase 2)  
**Complexity:** LOW  
**Development Time:** 1 day

**Features:**
- ✅ Payment method options: Cash, Transfer Manual, QRIS, Debit Card, Credit Card, Other
- ✅ Track payment method per transaction
- ✅ Report: Sales by payment method
- ❌ NO auto-verification for manual transfer (just mark as "Transfer")

**User Story:**
> "Sebagai kasir, saya ingin catat kalau pembeli bayar pakai transfer atau kartu, sehingga laporan saya akurat dan saya tahu payment method apa yang paling sering dipakai."

---

## 🏢 PHASE 3: BUSINESS TIER (Month 6+)
**Goal:** Serve growing businesses (multi-outlet, staff management)  
**Trigger:** After 100+ Pro users, some request advanced features

### P4: FUTURE FEATURES (For Scaling Businesses)

#### 27. Multi-Outlet Management
**Priority:** P4 (Phase 3)  
**Complexity:** HIGH  
**Development Time:** 3 weeks

**Features:**
- ✅ Add multiple outlets/branches
- ✅ Switch between outlets
- ✅ Per-outlet inventory (separate stock)
- ✅ Per-outlet reports
- ✅ Consolidated reports (all outlets)
- ✅ Stock transfer between outlets

**User Story:**
> "Sebagai pemilik toko dengan 3 cabang, saya ingin kelola semua cabang dari 1 akun, sehingga saya bisa lihat performa masing-masing cabang dan total keseluruhan."

---

#### 28. Employee/Staff Management
**Priority:** P4 (Phase 3)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Add staff accounts (name, email, phone, role)
- ✅ Role-based access control (Owner, Manager, Cashier)
- ✅ Staff permissions (apa yang bisa dilihat/edit)
- ✅ Staff activity log (who did what)
- ✅ Shift management (opening/closing balance)
- ✅ Commission tracking (optional)

**Roles & Permissions:**
```
Owner:
- Full access (semua fitur)
- Manage staff
- View all reports
- Edit settings

Manager:
- Manage products
- View reports
- Manage customers
- Cannot: Edit settings, manage staff

Cashier:
- Create transactions only
- View product list
- Cannot: Edit products, view reports, settings
```

---

#### 29. Advanced Inventory Management
**Priority:** P4 (Phase 3)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Supplier management (nama, contact, payment terms)
- ✅ Purchase orders (PO)
- ✅ Stock opname (physical count vs system)
- ✅ Stock adjustment with reasons
- ✅ Batch/lot tracking (expiry date for food/medicine)
- ✅ Reorder point automation (auto-suggest PO)

---

#### 30. Loyalty Program
**Priority:** P4 (Phase 3)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Point system (Rp 1000 = 1 point)
- ✅ Point redemption (100 points = Rp 10k discount)
- ✅ Member card (QR code/barcode)
- ✅ Member tiers (Bronze, Silver, Gold)
- ✅ Birthday rewards
- ✅ Referral rewards

---

#### 31. Marketplace Integration (Tokopedia, Shopee)
**Priority:** P4 (Phase 3)  
**Complexity:** VERY HIGH  
**Development Time:** 1 month

**Features:**
- ✅ Import orders from Tokopedia/Shopee
- ✅ Auto-sync inventory (stock update)
- ✅ Consolidated sales report (offline + online)
- ⚠️ Need API approval from marketplaces (difficult!)

**Complexity Note:**
This is VERY HARD to implement:
- Tokopedia/Shopee API approval process is strict (need legal entity, business verification)
- API rate limits
- Each marketplace has different API
- High maintenance (API changes frequently)

**Recommendation:**
- Consider partnership with existing solutions (JualanYuk, Ginee, etc)
- Or: Manual CSV import as workaround

---

#### 32. WhatsApp Business API Integration
**Priority:** P4 (Phase 3)  
**Complexity:** HIGH  
**Development Time:** 2 weeks

**Features:**
- ✅ Auto-send receipt via WhatsApp
- ✅ Low stock alert via WhatsApp
- ✅ Debt reminder via WhatsApp
- ✅ Broadcast promo to customers
- ⚠️ Need: WhatsApp Business API approval + cost (Rp 0.15-0.5 per message)

---

## 📊 FEATURE COMPARISON TABLE

| Feature | Free Tier | Pro Tier | Business Tier | Self-Hosted |
|---------|-----------|----------|---------------|-------------|
| **Core POS** |
| Product management | 200 products | 1000 products | Unlimited | Unlimited |
| Create transactions | ✅ | ✅ | ✅ | ✅ |
| Stock tracking | ✅ | ✅ | ✅ | ✅ |
| Transaction history | 30 days | Unlimited | Unlimited | Unlimited |
| Digital receipt (WA) | ✅ | ✅ | ✅ | ✅ |
| Dashboard & reports | Basic | Advanced | Advanced | Advanced |
| Profit calculation | ✅ | ✅ | ✅ | ✅ |
| **Advanced** |
| Debt tracking | Simple notes | Full tracking | Full tracking | Full tracking |
| Low stock alert | ✅ | ✅ + Push notif | ✅ + Push notif | ✅ + Push notif |
| Barcode scanner | ❌ | ✅ | ✅ | ✅ |
| Product photos | ❌ | ✅ | ✅ | ✅ |
| Category management | ❌ | ✅ | ✅ | ✅ |
| Export reports | ❌ | Excel/PDF | Excel/PDF | Excel/PDF |
| **Cloud & Sync** |
| Local storage only | ✅ | ❌ | ❌ | ❌ |
| Cloud backup | ❌ | ✅ | ✅ | Self-managed |
| Multi-device sync | 1 device | 2 devices | Unlimited | Unlimited |
| **Payment** |
| Cash payment | ✅ | ✅ | ✅ | ✅ |
| Manual transfer | ✅ | ✅ | ✅ | ✅ |
| QRIS integration | ❌ | ✅ | ✅ | ✅ |
| **Business** |
| Customer database | ❌ | ✅ | ✅ | ✅ |
| Multi-outlet | ❌ | ❌ | ✅ | ✅ |
| Staff management | ❌ | ❌ | ✅ | ✅ |
| Loyalty program | ❌ | ❌ | ✅ | ✅ |
| Marketplace integration | ❌ | ❌ | ✅ | ✅ |
| API access | ❌ | ❌ | Limited | Full |
| **Support** |
| Email support | Community | Priority | Priority | Priority |
| WhatsApp support | ❌ | ✅ | ✅ | ✅ |
| **Pricing** | Rp 0 | Rp 39k/mo | Rp 79k/mo | Rp 1.5jt (one-time) |

---

## 🗓️ REVISED DEVELOPMENT TIMELINE

### Month 1-2: MVP Development (8 weeks)

**Week 1: Project Setup**
- [ ] Flutter project initialization
- [ ] Setup architecture (Clean Architecture / MVVM)
- [ ] Setup state management (Riverpod)
- [ ] Setup SQLite database
- [ ] Create database schema & models
- [ ] Setup navigation (go_router)
- [ ] Create base UI components

**Week 2-3: Product Management**
- [ ] Product list screen (with search)
- [ ] Add product form (name, cost, selling price, stock)
- [ ] Edit product
- [ ] Delete product (soft delete)
- [ ] Stock tracking logic (auto-deduct)
- [ ] Low stock indicator

**Week 4-5: Point of Sale (POS)**
- [ ] POS screen UI
- [ ] Product search in POS
- [ ] Add to cart functionality
- [ ] Quantity adjustment (+/-)
- [ ] Cart summary (subtotal, total)
- [ ] Cash payment flow
- [ ] Change calculation
- [ ] Complete transaction
- [ ] Save to database

**Week 6: Receipt & History**
- [ ] Generate text receipt
- [ ] Share receipt via WhatsApp
- [ ] Copy receipt to clipboard
- [ ] Transaction history screen
- [ ] Transaction detail view
- [ ] Filter by date

**Week 7: Dashboard & Reports**
- [ ] Dashboard (sales today, transactions count)
- [ ] Profit calculation & display
- [ ] Comparison with yesterday
- [ ] Basic reports (weekly, monthly)
- [ ] Top products report
- [ ] Simple bar chart (fl_chart)

**Week 8: Debt Tracking & Polish**
- [ ] Debt payment option in POS
- [ ] Customer name input for debt
- [ ] Debt list screen
- [ ] Mark debt as paid
- [ ] Settings screen (shop profile)
- [ ] Data backup/restore (JSON)
- [ ] Bug fixes
- [ ] Beta testing preparation

---

### Month 3: Beta Testing & Iterations (4 weeks)

**Week 9-10: Private Beta (5-10 users)**
- [ ] Deploy to internal testing (Google Play)
- [ ] Collect feedback (Google Forms survey)
- [ ] Fix critical bugs
- [ ] UX improvements based on feedback
- [ ] Performance optimization

**Week 11-12: Public Beta (50-100 users)**
- [ ] Deploy to open beta (Google Play)
- [ ] Marketing push (social media, communities)
- [ ] Monitor analytics (Firebase)
- [ ] Monitor crashes (Sentry)
- [ ] Support users (WhatsApp)
- [ ] Iterate quickly based on feedback

---

### Month 4-5: Phase 2 - Cloud Sync & Monetization (8 weeks)

**Week 13-14: Backend Setup**
- [ ] Setup Supabase project
- [ ] Configure authentication (email/password)
- [ ] Setup PostgreSQL database (cloud)
- [ ] Configure Row Level Security (RLS)
- [ ] Setup Supabase Storage (for future photos)
- [ ] API testing

**Week 15-16: Authentication**
- [ ] Login screen
- [ ] Registration screen
- [ ] Forgot password flow
- [ ] Google Sign-In (optional)
- [ ] JWT token management
- [ ] Session management

**Week 17-19: Cloud Sync**
- [ ] Sync engine development
- [ ] Upload local data to cloud
- [ ] Download cloud data to device
- [ ] Conflict resolution logic
- [ ] Background sync worker
- [ ] Sync status indicators
- [ ] Multi-device testing

**Week 20: Monetization Setup**
- [ ] Integrate RevenueCat (subscription management)
- [ ] Integrate Xendit (payment gateway)
- [ ] In-app purchase flow (upgrade to Pro)
- [ ] Subscription management UI
- [ ] Payment webhook handling
- [ ] Testing payment flow

---

### Month 6+: Phase 3 - Business Tier & Self-Hosted

**Week 21-22: Business Features**
- [ ] Multi-outlet support
- [ ] Employee management
- [ ] Advanced inventory
- [ ] Loyalty program basics

**Week 23-24: Self-Hosted Version**
- [ ] Backend code cleanup
- [ ] Docker setup
- [ ] Deployment documentation
- [ ] Migration scripts
- [ ] API documentation (Swagger)

**Week 25-26: Launch Preparation**
- [ ] Performance optimization
- [ ] Security audit
- [ ] Play Store listing optimization (ASO)
- [ ] Marketing materials (screenshots, video)
- [ ] Landing page
- [ ] Support documentation

**Week 27-28: Public Launch**
- [ ] Soft launch (limited users)
- [ ] Monitor analytics & errors
- [ ] Collect feedback
- [ ] Quick iteration
- [ ] Public launch
- [ ] Marketing campaign

---

## 🎯 SUCCESS METRICS PER PHASE

### MVP Success Criteria (Month 2):
- [ ] 50+ beta users (friends, family, early adopters)
- [ ] 4.0+ star rating (internal feedback)
- [ ] Crash-free rate: > 99%
- [ ] Users complete first transaction: > 80%
- [ ] Users return Day 7: > 50%
- [ ] NPS (Net Promoter Score): > 40

### Public Beta Success Criteria (Month 3):
- [ ] 200+ active users
- [ ] 100+ transactions per day (total)
- [ ] 4.2+ star rating (Play Store)
- [ ] Users add 10+ products: > 60%
- [ ] Users check reports: > 40%
- [ ] User testimonials: 5+ positive reviews

### Phase 2 Launch Success Criteria (Month 5):
- [ ] 500+ free users
- [ ] 20+ Pro subscribers (4% conversion)
- [ ] MRR: Rp 780k (break even!)
- [ ] Cloud sync success rate: > 99%
- [ ] Churn rate: < 10% monthly
- [ ] NPS: > 50

### Full Launch Success Criteria (Month 6):
- [ ] 2,000+ downloads
- [ ] 1,000+ active users
- [ ] 50+ Pro subscribers
- [ ] MRR: Rp 1.95jt
- [ ] Featured on Play Store (Indonesia)
- [ ] Press coverage: 1-2 tech media

---

## ❓ DECISION FRAMEWORK: When to Build a Feature?

Use this framework to decide if a feature should be built NOW or LATER:

### Build NOW if:
1. ✅ It solves a critical user pain point (validated by user interviews)
2. ✅ Without it, the app is unusable (e.g., create transaction)
3. ✅ It's a quick win (< 3 days development, high impact)
4. ✅ It's a differentiator that competitors don't have (e.g., debt tracking)
5. ✅ It's an upgrade trigger for Pro tier (e.g., cloud sync)

### Build LATER if:
1. ❌ Only 1-2 users requested it (not validated)
2. ❌ It's complex (> 1 week development) and not critical
3. ❌ It's a "nice-to-have" feature (doesn't affect core value)
4. ❌ It requires external dependencies (API approval, partnerships)
5. ❌ You're not sure if users actually need it (no validation)

### DON'T BUILD if:
1. 🚫 It's a vanity feature (looks cool but no real value)
2. 🚫 It's premature optimization (solving problems you don't have yet)
3. 🚫 It distracts from core value proposition
4. 🚫 You can achieve the same goal with a simpler solution
5. 🚫 It's available as a third-party plugin (don't reinvent the wheel)

---

## 🔄 FEEDBACK LOOP & ITERATION

### User Feedback Collection:

**In-App Feedback (Built into MVP):**
- [ ] Feedback button in settings
- [ ] Rate app prompt (after 10 transactions)
- [ ] Feature request form
- [ ] Bug report form

**External Feedback:**
- [ ] Google Play reviews (monitor daily)
- [ ] WhatsApp support (direct user contact)
- [ ] Instagram DM (user questions)
- [ ] User interviews (monthly, 3-5 users)
- [ ] Survey (Google Forms, quarterly)

### Prioritization Process:

**Weekly:**
1. Collect all feedback (Play Store, WhatsApp, social media)
2. Categorize: Bug, Feature Request, UX Issue, Question
3. Prioritize using: Impact (H/M/L) × Effort (H/M/L)
4. Focus on: High Impact × Low Effort = Quick wins

**Monthly:**
1. Analyze usage data (Firebase Analytics)
   - Which features are used most?
   - Which features are never used? (consider removing)
   - Where do users drop off?
2. User interviews (3-5 users)
   - What do you love about KASBON?
   - What frustrates you?
   - What feature would make you upgrade to Pro?
3. Update roadmap based on learnings

---

## 🚀 LAUNCH READINESS CHECKLIST

### MVP Launch Checklist (Before Public Beta):

**Technical:**
- [ ] All P0 features working (8 core features)
- [ ] No critical bugs (P0 bugs = 0)
- [ ] Crash-free rate > 99%
- [ ] App size < 50MB
- [ ] App launch time < 3 seconds
- [ ] All screens responsive (tested on 3+ devices)
- [ ] Offline mode working 100%

**Content:**
- [ ] Play Store listing complete (title, description, screenshots)
- [ ] Privacy Policy published (on website or Google Docs)
- [ ] Terms of Service published
- [ ] Support email/WhatsApp set up
- [ ] FAQ page created

**Marketing:**
- [ ] Landing page live (or Carrd.co page)
- [ ] Instagram account created (@kasbon.id)
- [ ] TikTok account created (@kasbon.app)
- [ ] Initial content ready (10 posts)
- [ ] Early adopter list ready (50+ contacts)

**Analytics:**
- [ ] Firebase Analytics configured
- [ ] Sentry error tracking configured
- [ ] Key events tracked (signup, transaction, upgrade)
- [ ] Conversion funnel defined

### Phase 2 Launch Checklist (Before Monetization):

**Technical:**
- [ ] Cloud sync working (tested with 3+ devices)
- [ ] Payment integration working (Xendit + RevenueCat)
- [ ] Subscription management working
- [ ] Auto-renewal working
- [ ] Backup/restore tested (100% success rate)

**Business:**
- [ ] Pricing finalized (Rp 39k/mo confirmed)
- [ ] Refund policy defined
- [ ] Payment support process defined
- [ ] Invoicing system ready (if needed)
- [ ] Legal entity registered (NPWP, etc)

**Marketing:**
- [ ] Upgrade campaign ready (email + in-app)
- [ ] Feature comparison page ready
- [ ] Testimonials collected (3+ happy users)
- [ ] Demo video created (Pro features)

---

## 📝 NOTES FOR CLAUDE CODE

### Context for Future Development:

**This document should be used as:**
1. **Feature reference** when implementing new features
2. **Scope control** to avoid feature creep
3. **Prioritization guide** when deciding what to build next
4. **Timeline reference** for realistic planning

**Key Principles:**
1. **Ship fast, iterate faster** - Don't aim for perfection in MVP
2. **User feedback is king** - Build what users need, not what we think is cool
3. **Offline-first always** - This is our differentiator, never compromise
4. **Profit tracking** - This is our killer feature, prioritize this
5. **Debt tracking** - This is culture-specific, make it great

**Technical Decisions Made:**
- **State Management:** Riverpod (cleaner than Bloc)
- **Database:** SQLite for offline, PostgreSQL (Supabase) for cloud
- **Backend:** Supabase (faster than custom Node.js for solo dev)
- **Payment:** Xendit (Indonesia-focused)
- **Subscription:** RevenueCat (free up to 10k subscribers)

**When in Doubt:**
- Ask: "Does this feature help Pak Adi (warung owner) make more money or save time?"
- If NO: Don't build it (yet)
- If YES: Prioritize based on impact vs effort

---

## 📞 CONTACT & FEEDBACK

For questions about this roadmap or feature prioritization:
- Email: [your-email]
- WhatsApp: [your-number]
- GitHub Issues: [if open source]

---

**Document Version:** 1.0  
**Last Updated:** November 2024  
**Author:** [Your Name]  
**Project:** KASBON - Kasir Digital UMKM Indonesia

---

**Next Steps:**
1. ✅ Validate MVP features with 3-5 target users (warung owners)
2. ✅ Start Week 1: Project setup & database schema
3. ✅ Create detailed technical specification for each P0 feature
4. ✅ Setup development environment & tools
5. ✅ Start building! 🚀
