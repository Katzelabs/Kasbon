# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KASBON (Kasir Bisnis Online) is a cloud-based POS application for Indonesian small businesses (UMKM) built with Flutter and Supabase. It requires authentication and stores all data in Supabase (PostgreSQL). It prioritizes simplicity, profit tracking, and multi-device access.

**Key Differentiators:**
- Cloud-first with Supabase (PostgreSQL + Auth + RLS)
- Mandatory authentication (email/password)
- Profit tracking built-in (not just revenue)
- Debt tracking (hutang) - culture-specific for Indonesia
- Multi-tenant with Row Level Security (user_id scoped)

## Project Structure

```
Kasbon/
├── kasbon-frontend/    # Flutter mobile app (has its own CLAUDE.md)
├── supabase/           # Supabase config, migrations, seed data
├── DOCS/               # HISTORICAL planning docs (see warning below)
│   ├── CURRENT_STATE.md           # Snapshot of project state
│   ├── PROJECT_BRIEF.md           # Business vision (tech sections outdated)
│   ├── TECHNICAL_REQUIREMENTS.md  # OUTDATED - describes old SQLite design
│   └── FEATURE_PRIORITY_AND_PHASES.md  # Feature priorities (sync refs outdated)
```

Development tasks and progress are tracked in ClickUp (Katzelabs workspace, Kasbon space):
https://app.clickup.com/90182053080/v/b/s/901812129010 — the former `TASKS/` folder
(TASK_001-021 + PROGRESS.md) was migrated there in July 2026; original task specs
remain available in git history.

## Sources of Truth

The project migrated from offline-first SQLite to **Supabase-only** (Feb–Mar 2026). The planning docs in `DOCS/` predate that migration — treat them as historical context only.

| Topic | Authoritative source |
|-------|---------------------|
| Database schema | `supabase/migrations/` (NOT `DOCS/TECHNICAL_REQUIREMENTS.md`) |
| RPC functions | `supabase/migrations/20260316000001_create_rpc_functions.sql` |
| Seed / test data | `supabase/seed.sql` (test user: `test@kasbon.id` / `password123`) |
| Development progress | ClickUp Kasbon space (link above) |
| Frontend conventions | `kasbon-frontend/CLAUDE.md` |
| Business vision | `DOCS/PROJECT_BRIEF.md` (business sections still valid) |

## Claude Code Setup (Required Plugins)

This project relies on user-scope Claude Code plugins rather than bundling generic
skills in the repo. If they are not installed, run in Claude Code:

```
/plugin marketplace add flutter/agent-plugins
/plugin install dart-flutter@dart-flutter          # Dart/Flutter MCP tools + skills
/plugin install supabase@claude-plugins-official   # Supabase skills & best practices
```

Recommended (optional): `feature-dev@claude-plugins-official` (planning/review agents),
`frontend-design@claude-plugins-official` (UI design guidance).

Prefer the dart-flutter MCP tools (analyze, run_tests, hot_reload, etc.) over raw
shell commands when available.

The repo ships one project-specific skill: `.claude/skills/pos-uiux-designer`
(KASBON POS UI/UX patterns) — this stays in the repo because it is not covered by
any plugin.

## Development Commands

### Flutter (run from kasbon-frontend/)
```bash
flutter pub get              # Install dependencies
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=your-local-anon-key
flutter analyze              # Analyze code
flutter test                 # Run all tests
flutter test test/path/      # Run specific test directory
dart run build_runner build  # Generate code (freezed, riverpod, json)
dart format lib/             # Format code

# Production build
flutter build apk \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

### Supabase Local Development (run from project root)
```bash
supabase start               # Start local Supabase (API: 54321, DB: 54322)
supabase stop                # Stop local Supabase
supabase migration new <name>  # Create new migration
supabase db push             # Apply migrations to local
supabase db reset            # Reset local database (applies migrations + seed)
```

## Architecture

**Pattern:** Clean Architecture with feature-based modules

```
lib/
├── main.dart                     # Supabase.initialize(), DI init, ProviderScope
├── core/
│   ├── constants/                # App-wide constants
│   ├── errors/                   # Failures & Exceptions (incl. AuthFailure, NetworkFailure)
│   ├── services/                 # SupabaseClientProvider, BackupService, ImageStorage
│   ├── utils/                    # Formatters (currency, date), validators
│   └── usecase/                  # Base UseCase class
├── config/
│   ├── app_config.dart           # Supabase URL & anon key from dart-define
│   ├── di/injection.dart         # GetIt service locator (all dependencies)
│   ├── routes/app_router.dart    # GoRouter with auth redirect
│   └── theme/                    # Colors, typography, dimensions
├── features/
│   ├── auth/                     # Authentication (login, register, auth state)
│   ├── products/                 # Product CRUD
│   ├── categories/               # Category management
│   ├── transactions/             # Transaction history
│   ├── pos/                      # Point of Sale screen
│   ├── dashboard/                # Dashboard summary
│   ├── reports/                  # Sales, product, profit reports
│   ├── debt/                     # Debt (hutang) tracking
│   ├── receipt/                  # Digital receipt & shop settings
│   ├── backup/                   # Data export (JSON)
│   ├── settings/                 # App settings
│   └── dev_tools/                # Dev-only tools (seed data)
│   └── <feature>/
│       ├── data/
│       │   ├── datasources/      # Remote Supabase datasources
│       │   ├── models/           # DTOs with fromJson/toJson
│       │   └── repositories/     # Repository implementations
│       ├── domain/
│       │   ├── entities/         # Business models
│       │   ├── repositories/     # Abstract interfaces
│       │   └── usecases/         # Business logic
│       └── presentation/
│           ├── providers/        # Riverpod state management
│           ├── screens/          # Page widgets
│           └── widgets/          # Feature-specific widgets
└── shared/
    ├── modern/                   # REQUIRED: Modern Widget Library
    │   ├── modern.dart           # Main export
    │   ├── components/           # Buttons, cards, inputs, layout, feedback
    │   └── utils/                # Variants and enums
    └── widgets/                  # DEPRECATED: Legacy widgets (do not use)
```

**Key Libraries:**
- **State Management:** Riverpod (flutter_riverpod, riverpod_generator)
- **Navigation:** GoRouter (with auth-based redirect)
- **Database:** Supabase (PostgreSQL via supabase_flutter)
- **Authentication:** Supabase Auth (email/password)
- **Code Generation:** Freezed, JSON Serializable
- **DI:** GetIt

## Database

All data stored in Supabase PostgreSQL with Row Level Security (RLS). Every table has a `user_id` column with RLS policies ensuring users only see their own data.

**Main tables:**
- `user_profiles` - User profile info (auto-created on signup via trigger)
- `shop_settings` - Per-user shop configuration
- `categories` - Product categories (Makanan, Minuman, etc.)
- `products` - Products with cost_price and selling_price for profit tracking
- `transactions` - Transaction headers with payment_status (paid/debt)
- `transaction_items` - Line items with snapshot of prices at transaction time

**RPC functions** (in `supabase/migrations/`):
- `create_pos_transaction` - Atomic: insert transaction + items + update stock
- `get_dashboard_summary` - Today's sales/profit/txn count + comparisons
- `get_sales_summary`, `get_top_products`, `get_daily_sales` - Sales reports
- `get_profit_summary`, `get_top_profitable_products`, `get_product_profitability` - Profit reports

**Data types:**
- IDs: UUID (generated by Supabase)
- Timestamps: TIMESTAMPTZ (ISO 8601 strings in Dart)
- Booleans: native bool
- Money: DECIMAL(12,2) → double in Dart

## Authentication

Mandatory email/password auth via Supabase Auth. Route guarding in `app_router.dart`:
- Unauthenticated users → redirected to `/login`
- Authenticated users on auth routes → redirected to `/dashboard`
- `GoRouterRefreshStream` listens to `onAuthStateChange` for reactive redirects

## Key Patterns

**Repository Pattern:**
- Repositories return `Either<Failure, T>` from dartz
- Remote datasources use `SupabaseClientProvider` for client access
- Datasources throw custom exceptions, repos catch and return Failures

**SupabaseClientProvider:**
```dart
final provider = getIt<SupabaseClientProvider>();
provider.client;          // SupabaseClient
provider.currentUserId;   // String? (nullable)
provider.requireUserId;   // String (throws if not authenticated)
```

**Riverpod Providers:**
- Use `FutureProvider.autoDispose` for data fetching
- Use `StateNotifier` for complex state with mutations
- Access use cases via GetIt: `getIt<GetAllProducts>()`

## Modern Widget Library (REQUIRED)

**CRITICAL:** All UI development MUST use the Modern Widget Library from `lib/shared/modern/`.

**Import:**
```dart
import 'package:kasbon_frontend/shared/modern/modern.dart';
```

**Available Components:**
| Category | Widgets |
|----------|---------|
| **Buttons** | `ModernButton` (primary/secondary/outline/text/destructive), `ModernIconButton` |
| **Cards** | `ModernCard` (elevated/outlined/filled), `ModernGradientCard` (primary/success/warning/error) |
| **Inputs** | `ModernTextField`, `ModernCurrencyField`, `ModernSearchField`, `ModernDropdown`, `ModernQuantityStepper` |
| **Layout** | `ModernAppShell`, `ModernAppBar`, `ModernScaffold`, `ModernDivider`, `ModernSectionHeader` |
| **Feedback** | `ModernDialog`, `ModernToast`, `ModernLoading`, `ModernBottomSheet`, `ModernEmptyState`, `ModernErrorState` |
| **Data Display** | `ModernBadge`, `ModernChip`, `ModernAvatar`, `ModernListTile`, `ModernSummaryRow`, `ModernDataTable` |

**Size Variants:** All components support `ModernSize.small`, `ModernSize.medium`, `ModernSize.large`

## UI/UX Guidelines

### Design System (Use Theme Tokens)
- **Colors:** Use `AppColors.*` from `config/theme/app_colors.dart` (never hardcode hex)
- **Spacing:** Use `AppDimensions.spacing*` (4, 8, 12, 16, 20, 24, 32, 40, 48)
- **Typography:** Use `AppTextStyles.*` (h1-h4, bodyLarge/Medium/Small, priceLarge/Medium/Small, button)
- **Radius:** Use `AppDimensions.radius*` (Small: 4, Medium: 8, Large: 12, XLarge: 16)

### Design Principles
- Touch targets: minimum 48dp (`AppDimensions.minTouchTarget`)
- All text in Bahasa Indonesia
- Loading states with `ModernLoading()`
- Empty states with `ModernEmptyState()`
- Error states with `ModernErrorState()`
- Support 4.5"+ screens with responsive design

## Code Style Notes

- Use `Rp` currency format with `intl` package (Indonesian locale)
- Transaction numbers format: `TRX-YYYYMMDD-XXXX`
- Always handle empty states and loading states
- Prefer `Either<Failure, T>` from dartz for repository returns
- Use freezed for immutable data classes
- ALWAYS import Modern widgets: `import 'package:kasbon_frontend/shared/modern/modern.dart';`
- NEVER use deprecated widgets from `lib/shared/widgets/`

## Performance Targets

- Cold start: < 3 seconds
- Screen navigation: < 300ms
- Search results: < 500ms
- Transaction creation: < 1 second
- App size: < 50MB

## Testing

- Unit tests: 70% coverage target (business logic, use cases)
- Widget tests: Critical UI components
- Integration tests: Complete transaction flow
