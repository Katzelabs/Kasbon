# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KASBON POS Flutter frontend - cloud-based POS app for Indonesian UMKM powered by Supabase. Requires authentication (email/password). All data stored in Supabase with Row Level Security. See `../CLAUDE.md` for full project context including database schema and RPC functions.

## Development Commands

```bash
flutter pub get              # Install dependencies
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=your-local-anon-key
flutter analyze              # Analyze code for issues
flutter test                 # Run all tests
flutter test test/path/      # Run specific test
dart run build_runner build  # Generate code (freezed, riverpod, json)
dart format lib/             # Format code

# Production build
flutter build apk \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

## Architecture

**Clean Architecture** with feature-based modules:

```
lib/
├── main.dart                     # Supabase.initialize(), DI init, ProviderScope
├── core/                         # Shared infrastructure
│   ├── constants/                # App constants
│   ├── errors/                   # Failure classes (AuthFailure, NetworkFailure, etc.)
│   ├── services/                 # SupabaseClientProvider, BackupService, ImageStorage
│   ├── usecase/                  # Base UseCase<T, Params> class
│   └── utils/                    # Currency/date formatters, validators
├── config/
│   ├── app_config.dart           # Supabase URL & anon key (from dart-define)
│   ├── di/injection.dart         # GetIt service locator setup
│   ├── routes/app_router.dart    # GoRouter with auth redirect
│   └── theme/                    # AppColors, AppTextStyles, AppTheme
├── features/<feature>/           # Feature modules
│   ├── data/
│   │   ├── datasources/          # Remote Supabase datasources
│   │   ├── models/               # DTOs (fromJson/toJson for Supabase)
│   │   └── repositories/         # Repository implementations
│   ├── domain/
│   │   ├── entities/             # Business objects (extend Equatable)
│   │   ├── repositories/         # Abstract repository interfaces
│   │   └── usecases/             # Single-purpose use case classes
│   └── presentation/
│       ├── providers/            # Riverpod providers & state notifiers
│       ├── screens/              # Page widgets
│       └── widgets/              # Feature-specific components
└── shared/
    ├── modern/                   # REQUIRED: Modern Widget Library
    │   ├── modern.dart           # Main export (use this import)
    │   ├── components/           # Buttons, cards, inputs, layout, feedback
    │   └── utils/                # Variants (ModernSize, etc.)
    └── widgets/                  # DEPRECATED: Legacy widgets (do not use)
```

## Key Patterns

**Repository Pattern:**
- Repositories return `Either<Failure, T>` from dartz
- DataSources throw custom exceptions, repos catch and return Failures

**SupabaseClientProvider:**
```dart
final provider = getIt<SupabaseClientProvider>();
provider.client;          // SupabaseClient
provider.currentUserId;   // String? (nullable)
provider.requireUserId;   // String (throws if not authenticated)
```

**UseCase Pattern:**
```dart
class GetProduct extends UseCase<Product, GetProductParams> {
  final ProductRepository repository;
  GetProduct(this.repository);

  @override
  Future<Either<Failure, Product>> call(GetProductParams params) async {
    return await repository.getProduct(params.id);
  }
}
```

**Riverpod Providers:**
- Use `FutureProvider.autoDispose` for data fetching
- Use `StateNotifier` for complex state with mutations
- Access use cases via GetIt: `getIt<GetAllProducts>()`

**Supabase Data:**
- Store timestamps as ISO 8601 strings (TIMESTAMPTZ)
- Use native bool (not int)
- IDs are UUID strings
- Money fields: DECIMAL(12,2) → double in Dart
- Models have `fromJson()` and `toJson()` for Supabase JSON format

## Authentication

Mandatory email/password auth via Supabase Auth:
- Route guarding in `app_router.dart` via `redirect` callback
- `GoRouterRefreshStream` listens to `onAuthStateChange`
- Unauthenticated → `/login`, authenticated on auth route → `/dashboard`

## Modern Widget Library (REQUIRED)

**CRITICAL:** All UI development MUST use the Modern Widget Library. DO NOT use raw Flutter widgets when a Modern equivalent exists.

**Import:**
```dart
import 'package:kasbon_frontend/shared/modern/modern.dart';
```

### Buttons
```dart
ModernButton.primary(child: Text('Bayar'), onPressed: onPay)
ModernButton.label(label: 'Simpan', onPressed: onSave)
ModernButton.secondary(child: Text('Draft'))
ModernButton.outline(child: Text('Batal'))
ModernButton.text(child: Text('Lihat Semua'))
ModernButton.destructive(child: Text('Hapus'))
ModernIconButton(icon: Icons.add, onPressed: onAdd)
```

### Cards
```dart
ModernCard.elevated(child: content, onTap: onCardTap)
ModernCard.outlined(child: content)
ModernCard.filled(child: content)
ModernGradientCard.primary(child: revenueStats)
ModernGradientCard.success(child: profitStats)
```

### Inputs
```dart
ModernTextField(label: 'Nama Produk', controller: ctrl, errorText: errors['name'])
ModernCurrencyField(label: 'Harga Jual', controller: priceCtrl)
ModernSearchField(hint: 'Cari produk...', onChanged: onSearch)
ModernQuantityStepper(value: qty, onIncrement: inc, onDecrement: dec)
ModernDropdown<String>(label: 'Kategori', value: sel, items: items, onChanged: onChange)
```

### Layout
```dart
ModernAppBar.simple(title: 'Produk')
ModernAppBar.withBack(title: 'Detail', context: context)
ModernAppBar.withSearch(title: 'Produk', onSearch: onSearch)
ModernSectionHeader(title: 'Terlaris', actionLabel: 'Lihat Semua', onAction: onViewAll)
```

### Feedback
```dart
ModernLoading()
ModernEmptyState(icon: Icons.inventory_2_outlined, title: 'Belum Ada Produk', actionLabel: 'Tambah', onAction: onAdd)
ModernErrorState(message: 'Gagal memuat', onRetry: onRetry)
ModernDialog.confirm(context, title: 'Hapus?', message: 'Permanen', confirmLabel: 'Hapus', onConfirm: onDel)
ModernToast.success(context: context, message: 'Berhasil')
```

### Data Display
```dart
ModernBadge.success(label: 'Lunas')
ModernBadge.warning(label: 'Hutang')
ModernListTile(title: 'Produk', subtitle: 'Rp 50.000', leading: avatar, trailing: badge, onTap: onTap)
ModernSummaryRow(label: 'Subtotal', value: 'Rp 150.000')
ModernSummaryRow.total(label: 'TOTAL', value: 'Rp 150.000')
```

## Dependency Injection

All dependencies registered in `lib/config/di/injection.dart`:
1. Core services (Logger, SupabaseClientProvider)
2. DataSources (remote Supabase datasources)
3. Repositories
4. UseCases

Access anywhere: `getIt<ProductRepository>()`

## Navigation

GoRouter with ShellRoute for bottom navigation + auth redirect:
- `AppRoutes` class defines route paths
- Auth routes (`/login`, `/register`) outside shell
- Full-screen routes (POS success, receipt) outside shell
- Navigation: `context.go('/products')` or `context.push('/products/add')`

## Code Conventions

- All UI text in Bahasa Indonesia
- Currency: Use `CurrencyFormatter` for `Rp` prefix with Indonesian locale
- Transaction numbers: `TRX-YYYYMMDD-XXXX`
- SKU format: `SKU-XXXXX` (auto-generated)
- Always handle loading, error, and empty states in UI

## Adding a New Feature

1. Create feature folder structure under `lib/features/<name>/`
2. Define entity in `domain/entities/`
3. Define repository interface in `domain/repositories/`
4. Implement remote datasource in `data/datasources/` (uses SupabaseClientProvider)
5. Implement models with `fromJson`/`toJson` in `data/models/`
6. Implement repository in `data/repositories/`
7. Create use cases in `domain/usecases/`
8. Register all in `injection.dart`
9. Add providers in `presentation/providers/`
10. Build screens using Modern widgets
