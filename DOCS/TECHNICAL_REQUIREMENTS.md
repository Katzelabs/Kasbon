# KASBON - Technical Requirements Document

> ⚠️ **HISTORICAL DOCUMENT (planning-phase, Nov 2024).** The project has since
> migrated to a **Supabase-only** architecture (Feb–Mar 2026) — SQLite/sqflite was
> removed entirely and the offline-first/sync design described below was abandoned.
> Do **not** use this document as the source of truth for the database schema or
> architecture. Current sources of truth:
> - Database schema & RPC functions: `supabase/migrations/`
> - Architecture & conventions: root `CLAUDE.md` and `kasbon-frontend/CLAUDE.md`
> - Current state: `DOCS/CURRENT_STATE.md`, progress: the ClickUp Kasbon space (see root `CLAUDE.md`)

**Version:** 1.0  
**Last Updated:** November 2024  
**Budget:** Rp 3,000,000  
**Timeline:** 6 months (MVP + Launch)  
**Tech Stack:** Flutter + Supabase Only

---

## TABLE OF CONTENTS

1. [Project Overview](#1-project-overview)
2. [Tech Stack & Dependencies](#2-tech-stack--dependencies)
3. [System Architecture](#3-system-architecture)
4. [Database Schema](#4-database-schema)
5. [Features Specifications](#5-features-specifications)
6. [API Specifications](#6-api-specifications)
7. [Authentication & Authorization](#7-authentication--authorization)
8. [UI/UX Requirements](#8-uiux-requirements)
9. [Testing Strategy](#9-testing-strategy)
10. [Performance Requirements](#10-performance-requirements)
11. [Security Requirements](#11-security-requirements)
12. [Deployment Strategy](#12-deployment-strategy)
13. [Development Phases](#13-development-phases)

---

## 1. PROJECT OVERVIEW

### 1.1 Product Summary

**Name:** KASBON (Kasir Bisnis Online)  
**Tagline:** "Kasir Digital untuk Semua"  
**Target Market:** UMKM Indonesia (Warung, Toko, Cafe, Retail Kecil)  
**Platform:** Android (Phase 1) → iOS (Phase 2)

### 1.2 Core Value Proposition

- **Offline-First:** Works 100% without internet
- **Simple:** Easiest POS app for non-tech-savvy users
- **Affordable:** FREE tier + Pro Rp 39k/month (cheapest in market)
- **Complete:** Product management + POS + Reports + Profit tracking + Debt tracking

### 1.3 Target Users

**Primary Persona: Pak Adi (45) - Warung Owner**
- Tech literacy: LOW (bisa WhatsApp, belum pernah pakai POS)
- Pain points: Catat manual, sering salah hitung, stok tidak terkontrol
- Budget: <Rp 50k/month
- Location: Kampung/Pinggir kota dengan internet tidak stabil

### 1.4 Success Metrics

**MVP (Month 3):**
- 100 free users
- 2-5 paying users
- 4.0+ star rating
- 70%+ Day-7 retention

**Launch (Month 6):**
- 500 free users
- 20-25 paying users
- MRR: Rp 780k-975k (break even)
- 4.5+ star rating

---

## 2. TECH STACK & DEPENDENCIES

### 2.1 Frontend (Mobile App)

```yaml
Flutter SDK: 3.16+ (stable channel)
Dart: 3.2+

Target Platforms:
- Android: API 21+ (Android 5.0 Lollipop)
- iOS: iOS 12+ (Phase 2)

Minimum Device Specs:
- RAM: 2GB minimum (target low-end devices)
- Storage: 50MB app size (after installation)
- Screen: 4.5" to 7" (phone + small tablets)
```

### 2.2 Core Dependencies

```yaml
# pubspec.yaml

name: kasbon_pos
description: Kasir Digital untuk UMKM Indonesia
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

  # ═══════════════════════════════════════════════════════════
  # STATE MANAGEMENT
  # ═══════════════════════════════════════════════════════════
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # ═══════════════════════════════════════════════════════════
  # LOCAL DATABASE (Offline-First)
  # ═══════════════════════════════════════════════════════════
  sqflite: ^2.3.0                    # SQLite database
  path_provider: ^2.1.1              # Get local storage paths
  path: ^1.8.3                       # Path manipulation
  
  # ═══════════════════════════════════════════════════════════
  # LOCAL STORAGE (Settings, Cache)
  # ═══════════════════════════════════════════════════════════
  hive_flutter: ^1.1.0               # Key-value store
  flutter_secure_storage: ^9.0.0    # Secure token storage
  shared_preferences: ^2.2.2         # Simple preferences

  # ═══════════════════════════════════════════════════════════
  # BACKEND & CLOUD SYNC (Phase 2)
  # ═══════════════════════════════════════════════════════════
  supabase_flutter: ^2.0.0           # Supabase SDK

  # ═══════════════════════════════════════════════════════════
  # DEPENDENCY INJECTION
  # ═══════════════════════════════════════════════════════════
  get_it: ^7.6.4                     # Service locator

  # ═══════════════════════════════════════════════════════════
  # NAVIGATION
  # ═══════════════════════════════════════════════════════════
  go_router: ^12.1.1                 # Declarative routing

  # ═══════════════════════════════════════════════════════════
  # UI COMPONENTS
  # ═══════════════════════════════════════════════════════════
  fl_chart: ^0.65.0                  # Charts for reports
  shimmer: ^3.0.0                    # Loading skeleton
  flutter_slidable: ^3.0.1          # Swipe actions
  
  # ═══════════════════════════════════════════════════════════
  # UTILITIES
  # ═══════════════════════════════════════════════════════════
  intl: ^0.18.1                      # Date/number formatting (Indonesian locale)
  uuid: ^4.2.1                       # UUID generation
  equatable: ^2.0.5                  # Value equality
  dartz: ^0.10.1                     # Functional programming (Either, Option)
  logger: ^2.0.2                     # Logging

  # ═══════════════════════════════════════════════════════════
  # PHASE 1.1 DEPENDENCIES (Add after MVP)
  # ═══════════════════════════════════════════════════════════
  # image_picker: ^1.0.5             # Product photos
  # flutter_image_compress: ^2.1.0   # Image compression
  # mobile_scanner: ^3.5.5           # Barcode scanner
  # qr_flutter: ^4.1.0               # QR code generation
  # pdf: ^3.10.7                     # PDF receipts
  # printing: ^5.11.1                # Print/share PDF

  # ═══════════════════════════════════════════════════════════
  # PHASE 2 DEPENDENCIES (Monetization)
  # ═══════════════════════════════════════════════════════════
  # dio: ^5.4.0                      # HTTP client (for Xendit)
  # purchases_flutter: ^6.9.0        # RevenueCat subscription

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

  # Code Generation
  build_runner: ^2.4.6
  riverpod_generator: ^2.3.9
  freezed: ^2.4.5
  json_serializable: ^6.7.1

  # Testing
  mocktail: ^1.0.1                   # Mocking

flutter:
  uses-material-design: true
  
  assets:
    - assets/images/
    - assets/icons/
    - assets/sample_data/
```

### 2.3 Backend (Supabase)

```yaml
Supabase Services Used:
├─ PostgreSQL Database (Main data store)
├─ Supabase Auth (Email/Password, Google OAuth)
├─ Supabase Storage (Product images - Phase 1.1)
├─ Supabase Edge Functions (Custom business logic - Phase 2)
├─ Supabase Realtime (Live sync - Phase 2)
└─ Row Level Security (Multi-tenant security)

Supabase Configuration:
- Region: Southeast Asia (Singapore) - closest to Indonesia
- Database: PostgreSQL 15+
- Connection pooling: PgBouncer (Transaction mode)
- SSL: Required
```

### 2.4 Third-Party Services

```yaml
# Payment Gateway (Phase 2)
Xendit:
  - QRIS payment
  - Virtual Account
  - Pricing: 0.7% per transaction
  - Webhook for payment verification

# Subscription Management (Phase 2)
RevenueCat:
  - Manage Pro/Business tier subscriptions
  - Free tier: up to 10k MTU
  - Handles: Play Store billing, webhook, analytics

# Analytics (Phase 2 - Optional)
Firebase Analytics:
  - User behavior tracking
  - Free tier (unlimited events)
  - Optional, can use Supabase dashboard instead

# Error Tracking (Phase 2 - Optional)
Sentry:
  - Crash reporting
  - Free tier: 5k errors/month
  - Optional, can use basic logging instead
```

---

## 3. SYSTEM ARCHITECTURE

### 3.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     KASBON ARCHITECTURE                      │
│                  (Offline-First, Cloud-Optional)             │
└─────────────────────────────────────────────────────────────┘

                      MOBILE APP LAYER
┌─────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                          │
│  ├─ Screens (Dashboard, Products, POS, Reports, Settings)   │
│  ├─ Widgets (Reusable UI components)                        │
│  └─ Providers (Riverpod state management)                   │
├─────────────────────────────────────────────────────────────┤
│  DOMAIN LAYER                                                │
│  ├─ Entities (Business models)                              │
│  ├─ Repositories (Abstract interfaces)                      │
│  └─ Use Cases (Business logic)                              │
├─────────────────────────────────────────────────────────────┤
│  DATA LAYER                                                  │
│  ├─ Data Sources (Local SQLite, Remote Supabase)            │
│  ├─ Repository Implementations                              │
│  └─ Models (DTOs with JSON serialization)                   │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  STORAGE LAYER                                               │
│  ├─ SQLite (Main local database)                            │
│  ├─ Hive (Settings, cache)                                  │
│  └─ Secure Storage (Tokens)                                 │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ (Phase 2 only)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  CLOUD LAYER (Supabase)                                      │
│  ├─ PostgreSQL Database                                     │
│  ├─ Authentication                                           │
│  ├─ Storage (Images)                                         │
│  ├─ Edge Functions                                           │
│  └─ Realtime (Sync)                                          │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Folder Structure

```
kasbon_pos/
├─ android/
├─ ios/
├─ assets/
│  ├─ images/
│  ├─ icons/
│  └─ sample_data/
│
├─ lib/
│  ├─ main.dart
│  │
│  ├─ core/
│  │  ├─ constants/
│  │  │  ├─ app_constants.dart
│  │  │  ├─ database_constants.dart
│  │  │  └─ route_constants.dart
│  │  │
│  │  ├─ errors/
│  │  │  ├─ failures.dart
│  │  │  └─ exceptions.dart
│  │  │
│  │  ├─ utils/
│  │  │  ├─ currency_formatter.dart
│  │  │  ├─ date_formatter.dart
│  │  │  └─ validators.dart
│  │  │
│  │  └─ usecase/
│  │     └─ usecase.dart
│  │
│  ├─ config/
│  │  ├─ routes/
│  │  │  └─ app_router.dart
│  │  │
│  │  ├─ theme/
│  │  │  ├─ app_theme.dart
│  │  │  ├─ app_colors.dart
│  │  │  └─ app_text_styles.dart
│  │  │
│  │  ├─ database/
│  │  │  ├─ database_helper.dart
│  │  │  └─ migrations.dart
│  │  │
│  │  └─ di/
│  │     └─ injection.dart
│  │
│  ├─ features/
│  │  ├─ products/
│  │  │  ├─ data/
│  │  │  │  ├─ datasources/
│  │  │  │  ├─ models/
│  │  │  │  └─ repositories/
│  │  │  ├─ domain/
│  │  │  │  ├─ entities/
│  │  │  │  ├─ repositories/
│  │  │  │  └─ usecases/
│  │  │  └─ presentation/
│  │  │     ├─ providers/
│  │  │     ├─ screens/
│  │  │     └─ widgets/
│  │  │
│  │  ├─ pos/
│  │  ├─ transactions/
│  │  ├─ reports/
│  │  ├─ dashboard/
│  │  ├─ settings/
│  │  └─ auth/ (Phase 2)
│  │
│  └─ shared/
│     ├─ widgets/
│     └─ providers/
│
├─ test/
├─ integration_test/
├─ pubspec.yaml
└─ README.md
```

---

## 4. DATABASE SCHEMA

### 4.1 Local Database (SQLite) - Phase 1

```sql
-- Database: kasbon.db
-- Version: 1.0.0
-- Encoding: UTF-8

-- ═══════════════════════════════════════════════════════════
-- TABLE: shop_settings (Single row table)
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS shop_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  name TEXT NOT NULL,
  address TEXT,
  phone TEXT,
  logo_url TEXT,
  receipt_header TEXT,
  receipt_footer TEXT,
  currency TEXT DEFAULT 'IDR',
  low_stock_threshold INTEGER DEFAULT 5,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

INSERT OR IGNORE INTO shop_settings (id, name, created_at, updated_at)
VALUES (1, 'Toko Saya', strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000);

-- ═══════════════════════════════════════════════════════════
-- TABLE: categories
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#FF6B35',
  icon TEXT DEFAULT 'category',
  sort_order INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

INSERT OR IGNORE INTO categories (id, name, color, created_at, updated_at) VALUES
  ('cat-1', 'Makanan', '#FF6B35', strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000),
  ('cat-2', 'Minuman', '#1E88E5', strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000),
  ('cat-3', 'Kebutuhan Rumah', '#43A047', strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000),
  ('cat-4', 'Lainnya', '#757575', strftime('%s', 'now') * 1000, strftime('%s', 'now') * 1000);

-- ═══════════════════════════════════════════════════════════
-- TABLE: products
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  category_id TEXT,
  sku TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  barcode TEXT UNIQUE,
  cost_price REAL NOT NULL DEFAULT 0,
  selling_price REAL NOT NULL,
  stock INTEGER NOT NULL DEFAULT 0,
  min_stock INTEGER DEFAULT 5,
  unit TEXT DEFAULT 'pcs',
  image_url TEXT,
  is_active INTEGER DEFAULT 1,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  
  FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX idx_products_name ON products(name);
CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_active ON products(is_active);

-- ═══════════════════════════════════════════════════════════
-- TABLE: transactions
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  transaction_number TEXT NOT NULL UNIQUE,
  customer_name TEXT,
  subtotal REAL NOT NULL,
  discount_amount REAL DEFAULT 0,
  discount_percentage REAL DEFAULT 0,
  tax_amount REAL DEFAULT 0,
  total REAL NOT NULL,
  payment_method TEXT DEFAULT 'cash',
  payment_status TEXT DEFAULT 'paid',
  cash_received REAL,
  cash_change REAL,
  notes TEXT,
  cashier_name TEXT,
  transaction_date INTEGER NOT NULL,
  debt_paid_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_number ON transactions(transaction_number);
CREATE INDEX idx_transactions_status ON transactions(payment_status);
CREATE INDEX idx_transactions_customer ON transactions(customer_name);

-- ═══════════════════════════════════════════════════════════
-- TABLE: transaction_items
-- ═══════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS transaction_items (
  id TEXT PRIMARY KEY,
  transaction_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  product_sku TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  cost_price REAL NOT NULL,
  selling_price REAL NOT NULL,
  discount_amount REAL DEFAULT 0,
  subtotal REAL NOT NULL,
  created_at INTEGER NOT NULL,
  
  FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES products(id)
);

CREATE INDEX idx_transaction_items_txn ON transaction_items(transaction_id);
CREATE INDEX idx_transaction_items_product ON transaction_items(product_id);
```

### 4.2 Database Constants

```dart
// lib/core/constants/database_constants.dart

class DatabaseConstants {
  // Database
  static const String databaseName = 'kasbon.db';
  static const int databaseVersion = 1;
  
  // Table names
  static const String tableShopSettings = 'shop_settings';
  static const String tableCategories = 'categories';
  static const String tableProducts = 'products';
  static const String tableTransactions = 'transactions';
  static const String tableTransactionItems = 'transaction_items';
  
  // Common columns
  static const String colId = 'id';
  static const String colName = 'name';
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  
  // Product columns
  static const String colCategoryId = 'category_id';
  static const String colSku = 'sku';
  static const String colDescription = 'description';
  static const String colBarcode = 'barcode';
  static const String colCostPrice = 'cost_price';
  static const String colSellingPrice = 'selling_price';
  static const String colStock = 'stock';
  static const String colMinStock = 'min_stock';
  static const String colUnit = 'unit';
  static const String colImageUrl = 'image_url';
  static const String colIsActive = 'is_active';
  
  // Transaction columns
  static const String colTransactionNumber = 'transaction_number';
  static const String colCustomerName = 'customer_name';
  static const String colSubtotal = 'subtotal';
  static const String colDiscountAmount = 'discount_amount';
  static const String colTotal = 'total';
  static const String colPaymentMethod = 'payment_method';
  static const String colPaymentStatus = 'payment_status';
  static const String colCashReceived = 'cash_received';
  static const String colCashChange = 'cash_change';
  static const String colTransactionDate = 'transaction_date';
  
  // Transaction item columns
  static const String colTransactionId = 'transaction_id';
  static const String colProductId = 'product_id';
  static const String colProductName = 'product_name';
  static const String colQuantity = 'quantity';
  
  // Enums
  static const String paymentMethodCash = 'cash';
  static const String paymentMethodTransfer = 'transfer';
  static const String paymentMethodQris = 'qris';
  static const String paymentMethodDebt = 'debt';
  
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusDebt = 'debt';
}
```

---

## 5. FEATURES SPECIFICATIONS

### 5.1 MVP Features (Phase 1) - Priority P0

#### Feature 1: Product Management

**Priority:** P0 (Critical)  
**Complexity:** LOW  
**Timeline:** Week 3-4

**User Stories:**
- As a warung owner, I want to add products with name, prices, and stock
- As a warung owner, I want to edit product information
- As a warung owner, I want to search products quickly

**Acceptance Criteria:**
- [ ] Can add product (name, cost price, selling price, stock)
- [ ] Can edit product
- [ ] Can soft-delete product
- [ ] Real-time search by name
- [ ] Auto-generate SKU
- [ ] Show low stock indicator
- [ ] Form validation

**API Endpoints:**
```dart
// Local SQLite operations
- createProduct(Product) -> Product
- getProducts({String? search}) -> List<Product>
- getProduct(String id) -> Product
- updateProduct(Product) -> Product
- deleteProduct(String id) -> void
- searchProducts(String query) -> List<Product>
```

---

#### Feature 2: Point of Sale (POS)

**Priority:** P0 (Critical)  
**Complexity:** MEDIUM  
**Timeline:** Week 5-6

**User Stories:**
- As a kasir, I want to quickly add products to cart
- As a kasir, I want to calculate change automatically
- As a kasir, I want to complete transactions fast

**Acceptance Criteria:**
- [ ] Search products (autocomplete)
- [ ] Add to cart
- [ ] Adjust quantity (+/-)
- [ ] Remove from cart (swipe)
- [ ] Show cart summary
- [ ] Cash payment only
- [ ] Calculate change
- [ ] Create transaction (atomic)
- [ ] Auto-reduce stock
- [ ] Generate text receipt
- [ ] Share via WhatsApp

**State Management:**
```dart
@riverpod
class Cart extends _$Cart {
  @override
  List<CartItem> build() => [];
  
  void addProduct(Product product);
  void updateQuantity(String productId, int quantity);
  void removeProduct(String productId);
  void clear();
  
  double get subtotal;
  double get total;
  int get itemCount;
}
```

---

#### Feature 3: Transaction History

**Priority:** P0  
**Complexity:** LOW  
**Timeline:** Week 6

**Acceptance Criteria:**
- [ ] List all transactions (newest first)
- [ ] Filter by date range
- [ ] View transaction detail
- [ ] Show transaction items
- [ ] Display receipt

---

#### Feature 4: Dashboard

**Priority:** P0  
**Complexity:** LOW  
**Timeline:** Week 7

**Acceptance Criteria:**
- [ ] Show sales today
- [ ] Show transaction count
- [ ] Show comparison with yesterday
- [ ] Quick action buttons
- [ ] Low stock alerts

---

#### Feature 5: Profit Calculation

**Priority:** P1  
**Complexity:** MEDIUM  
**Timeline:** Week 7

**Acceptance Criteria:**
- [ ] Track cost price per product
- [ ] Calculate profit per transaction
- [ ] Show profit in dashboard
- [ ] Show profit margin %
- [ ] Report: Most profitable products

**Formula:**
```
Profit = Σ (selling_price - cost_price) × quantity
Margin% = (Profit / Revenue) × 100
```

---

#### Feature 6: Debt Tracking

**Priority:** P1  
**Complexity:** MEDIUM  
**Timeline:** Week 8

**Acceptance Criteria:**
- [ ] Mark transaction as "Hutang"
- [ ] Add customer name
- [ ] Add notes (e.g., "Bayar tanggal 30")
- [ ] List unpaid debts
- [ ] Mark debt as paid
- [ ] Total debt per customer

---

#### Feature 7: Basic Reports

**Priority:** P1  
**Complexity:** MEDIUM  
**Timeline:** Week 7

**Acceptance Criteria:**
- [ ] Daily sales summary
- [ ] Weekly sales chart
- [ ] Monthly sales chart
- [ ] Top 5 products (by revenue)
- [ ] Top 5 products (by profit)

---

#### Feature 8: Settings & Shop Profile

**Priority:** P1  
**Complexity:** LOW  
**Timeline:** Week 7

**Acceptance Criteria:**
- [ ] Edit shop name, address, phone
- [ ] Customize receipt header/footer
- [ ] Set low stock threshold
- [ ] Backup data (JSON export)
- [ ] Restore data (JSON import)

---

### 5.2 Phase 2 Features (Cloud Sync & Monetization)

#### Feature 9: Authentication

**Timeline:** Month 4 (Week 13-14)

**Acceptance Criteria:**
- [ ] Email/password registration
- [ ] Email/password login
- [ ] Google Sign-In (optional)
- [ ] Password reset
- [ ] Auto-login (session persistence)

---

#### Feature 10: Cloud Sync

**Timeline:** Month 4-5 (Week 15-19)

**Acceptance Criteria:**
- [ ] Upload local data to cloud
- [ ] Download cloud data
- [ ] Real-time sync (background)
- [ ] Conflict resolution
- [ ] Multi-device support (max 2 for Pro)
- [ ] Sync status indicator

---

#### Feature 11: Payment Integration

**Timeline:** Month 5 (Week 20)

**Acceptance Criteria:**
- [ ] QRIS payment (via Xendit)
- [ ] Display QR code
- [ ] Payment verification (webhook)
- [ ] Update transaction status

---

#### Feature 12: Subscription Management

**Timeline:** Month 5 (Week 20)

**Acceptance Criteria:**
- [ ] In-app purchase (RevenueCat)
- [ ] Upgrade to Pro flow
- [ ] Subscription status check
- [ ] Feature gating (Free vs Pro)
- [ ] Restore purchases

---

## 6. API SPECIFICATIONS

### 6.1 Supabase REST API (Phase 2)

#### Authentication

```dart
// Sign Up
final response = await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'password123',
);

// Sign In
final response = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'password123',
);

// Get Current User
final user = supabase.auth.currentUser;

// Sign Out
await supabase.auth.signOut();
```

#### Products CRUD

```dart
// Get all products
final products = await supabase
  .from('products')
  .select()
  .eq('shop_id', shopId)
  .eq('is_active', true);

// Create product
await supabase.from('products').insert({
  'id': uuid,
  'shop_id': shopId,
  'name': 'Product Name',
  'cost_price': 5000,
  'selling_price': 7000,
});

// Update product
await supabase.from('products')
  .update({'selling_price': 8000})
  .eq('id', productId);
```

---

## 7. AUTHENTICATION & AUTHORIZATION

### 7.1 Auth Flow (Phase 2)

```
User Registration → Supabase Auth
   ↓
Create user_profiles entry
   ↓
Create default shop
   ↓
Return JWT token
   ↓
Save to SecureStorage
   ↓
Navigate to Dashboard
```

### 7.2 Row Level Security (RLS)

```sql
-- Users can only access their own shop's data
CREATE POLICY "Users can view own products"
  ON products FOR SELECT
  USING (shop_id IN (
    SELECT id FROM shops WHERE user_id = auth.uid()
  ));
```

---

## 8. UI/UX REQUIREMENTS

### 8.1 Design Principles

- **Simplicity:** Minimal UI, large touch targets
- **Speed:** All actions < 3 taps
- **Clarity:** Clear labels in Bahasa Indonesia
- **Feedback:** Loading states, success messages
- **Accessibility:** Works on small screens (4.5"+)

### 8.2 Color Palette

```dart
class AppColors {
  // Primary
  static const primary = Color(0xFFFF6B35);      // Orange
  static const primaryDark = Color(0xFFE55A2B);
  
  // Secondary
  static const secondary = Color(0xFF1E3A8A);    // Navy Blue
  
  // Status
  static const success = Color(0xFF10B981);      // Green
  static const warning = Color(0xFFF59E0B);      // Yellow
  static const error = Color(0xFFEF4444);        // Red
  
  // Neutral
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF1F2937);
  static const textLight = Color(0xFF6B7280);
}
```

### 8.3 Typography

```dart
class AppTextStyles {
  // Headings
  static const h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    fontFamily: 'Inter',
  );
  
  static const h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    fontFamily: 'Inter',
  );
  
  // Body
  static const body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    fontFamily: 'Inter',
  );
  
  // Numbers (for prices, totals)
  static const number = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    fontFamily: 'JetBrains Mono',
  );
}
```

### 8.4 Key Screens

1. **Dashboard**
   - Sales summary card (large, prominent)
   - Quick action buttons (Kasir, Tambah Produk)
   - Low stock alerts
   - Recent transactions

2. **POS Screen**
   - Search bar (sticky top)
   - Product search results
   - Cart (bottom sheet)
   - Large [BAYAR] button

3. **Product List**
   - Search bar
   - Product cards (grid/list view toggle)
   - FAB "+" button
   - Low stock indicators

4. **Transaction History**
   - Date filter
   - Transaction cards
   - Pull-to-refresh
   - Infinite scroll

---

## 9. TESTING STRATEGY

### 9.1 Unit Tests

```dart
// Target: 70% code coverage

test/
├─ features/
│  ├─ products/
│  │  ├─ domain/
│  │  │  └─ usecases/
│  │  │     └─ create_product_test.dart
│  │  └─ data/
│  │     └─ repositories/
│  │        └─ product_repository_impl_test.dart
│  └─ ...
└─ core/
   └─ utils/
      └─ currency_formatter_test.dart
```

### 9.2 Widget Tests

```dart
// Test critical UI components

testWidgets('Product card displays correctly', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ProductCard(product: mockProduct),
    ),
  );
  
  expect(find.text('Product Name'), findsOneWidget);
  expect(find.text('Rp 10.000'), findsOneWidget);
});
```

### 9.3 Integration Tests

```dart
// Test complete user flows

testWidgets('Complete transaction flow', (tester) async {
  // 1. Open POS screen
  // 2. Search product
  // 3. Add to cart
  // 4. Complete payment
  // 5. Verify transaction created
  // 6. Verify stock reduced
});
```

---

## 10. PERFORMANCE REQUIREMENTS

### 10.1 App Performance

- **Cold start:** < 3 seconds
- **Screen navigation:** < 300ms
- **Search results:** < 500ms
- **Transaction creation:** < 1 second
- **App size:** < 50MB

### 10.2 Database Performance

- **Product list load (100 items):** < 500ms
- **Transaction history (100 items):** < 500ms
- **Search products:** < 300ms
- **Create transaction:** < 1 second

### 10.3 Memory

- **Idle memory:** < 150MB
- **Active memory:** < 250MB
- **No memory leaks**

---

## 11. SECURITY REQUIREMENTS

### 11.1 Local Security

- **Database:** No encryption needed (local device only)
- **Tokens:** Encrypted with FlutterSecureStorage
- **Input validation:** All user inputs validated
- **SQL injection:** Prevented (parameterized queries)

### 11.2 Cloud Security (Phase 2)

- **HTTPS only:** All API calls
- **JWT tokens:** Secure, short-lived (1 hour)
- **Row Level Security:** Enforced at database level
- **Password:** Hashed with bcrypt
- **Rate limiting:** API calls limited

---

## 12. DEPLOYMENT STRATEGY

### 12.1 Development Environment

```yaml
Environment: Development
- Debug mode enabled
- Verbose logging
- Test data included
- API: Supabase Dev project
```

### 12.2 Staging Environment

```yaml
Environment: Staging
- Release mode
- Minimal logging
- Real-like data
- API: Supabase Staging project
```

### 12.3 Production Environment

```yaml
Environment: Production
- Release mode
- Error logging only (Sentry)
- Real data
- API: Supabase Production project
```

### 12.4 Play Store Deployment

```yaml
Release Process:
1. Bump version (pubspec.yaml)
2. Run tests (unit + integration)
3. Build release APK/AAB
4. Upload to Play Console
5. Internal testing (1 week)
6. Beta release (2 weeks)
7. Production release

Versioning:
- Format: MAJOR.MINOR.PATCH+BUILD
- Example: 1.0.0+1
```

---

## 13. DEVELOPMENT PHASES

### 13.1 Month 1-2: MVP Development

**Week 1-2: Setup**
- [ ] Initialize Flutter project
- [ ] Setup architecture (Clean Architecture)
- [ ] Setup state management (Riverpod)
- [ ] Setup SQLite database
- [ ] Create database schema
- [ ] Setup navigation (GoRouter)
- [ ] Create base UI components

**Week 3-4: Products**
- [ ] Product list screen
- [ ] Add product form
- [ ] Edit product
- [ ] Delete product
- [ ] Search products

**Week 5-6: POS**
- [ ] POS screen UI
- [ ] Product search in POS
- [ ] Cart functionality
- [ ] Payment flow
- [ ] Transaction creation
- [ ] Receipt generation

**Week 7: Dashboard & Reports**
- [ ] Dashboard
- [ ] Profit calculation
- [ ] Basic reports
- [ ] Transaction history

**Week 8: Polish & Testing**
- [ ] Debt tracking
- [ ] Settings
- [ ] Backup/Restore
- [ ] Bug fixes
- [ ] Internal testing

---

### 13.2 Month 3: Beta Testing

**Week 9-10: Private Beta**
- [ ] Deploy to Internal Testing (Play Console)
- [ ] 5-10 beta testers
- [ ] Collect feedback
- [ ] Fix critical bugs

**Week 11-12: Public Beta**
- [ ] Deploy to Open Beta (Play Console)
- [ ] Marketing push (organic)
- [ ] Monitor analytics
- [ ] Iterate based on feedback

---

### 13.3 Month 4-5: Cloud Sync & Monetization

**Week 13-14: Backend Setup**
- [ ] Setup Supabase project
- [ ] Configure auth
- [ ] Setup PostgreSQL schema
- [ ] Configure RLS

**Week 15-19: Cloud Sync**
- [ ] Authentication screens
- [ ] Sync engine
- [ ] Conflict resolution
- [ ] Multi-device testing

**Week 20: Monetization**
- [ ] RevenueCat integration
- [ ] Xendit integration
- [ ] In-app purchase flow
- [ ] Subscription management

---

### 13.4 Month 6: Launch

**Week 21-24: Launch Preparation**
- [ ] Performance optimization
- [ ] Play Store listing (ASO)
- [ ] Marketing materials
- [ ] Landing page
- [ ] Support documentation

**Week 25-26: Public Launch**
- [ ] Soft launch
- [ ] Monitor metrics
- [ ] Marketing campaign
- [ ] Quick iterations

---

## APPENDIX A: Budget Breakdown

```
Total Budget: Rp 3,000,000

One-Time Costs:
├─ Domain (1 year): Rp 100,000
├─ Play Console: Rp 390,000
└─ Logo/Branding: Rp 200,000
Subtotal: Rp 690,000

Infrastructure (6 months):
├─ Month 1-4 (Free tier): Rp 40,000
├─ Month 5 (Supabase Pro): Rp 400,000
└─ Month 6 (Supabase + Firebase): Rp 410,000
Subtotal: Rp 850,000

Marketing (4 months):
├─ Facebook Ads: Rp 600,000
├─ Content creation: Rp 200,000
└─ Print materials: Rp 200,000
Subtotal: Rp 1,000,000

Buffer: Rp 460,000

TOTAL: Rp 3,000,000
```

---

## APPENDIX B: Success Metrics

### KPIs to Track

**Acquisition:**
- Downloads/installs
- Source of installs (organic vs paid)
- Cost per install (CPI)

**Activation:**
- % users who complete first transaction
- Time to first transaction
- % users who add 10+ products

**Retention:**
- Day 1, 7, 30 retention
- Monthly Active Users (MAU)
- Daily Active Users (DAU)

**Revenue:**
- Free to Paid conversion rate
- Monthly Recurring Revenue (MRR)
- Average Revenue Per User (ARPU)
- Churn rate

**Referral:**
- Referral rate
- Viral coefficient

---

## APPENDIX C: Risk Mitigation

### Technical Risks

**Risk:** Development takes longer than expected  
**Mitigation:** Strict MVP scope, no feature creep, time-box features

**Risk:** Database performance issues with large datasets  
**Mitigation:** Proper indexing, pagination, query optimization

**Risk:** Sync conflicts in multi-device scenario  
**Mitigation:** Last-write-wins strategy, clear conflict UI

### Business Risks

**Risk:** Low user acquisition  
**Mitigation:** Focus on organic growth, referral program, community building

**Risk:** Low Free to Paid conversion  
**Mitigation:** Clear value proposition for Pro tier, free trial, social proof

**Risk:** High churn rate  
**Mitigation:** Excellent onboarding, responsive support, continuous improvements

---

**END OF DOCUMENT**

For questions or clarifications, refer to:
- PROJECT_BRIEF.md (High-level overview)
- FEATURE_PRIORITY_AND_PHASES.md (Detailed features)
- This document (Technical implementation)
