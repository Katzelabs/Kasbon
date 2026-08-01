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
├── app/                # Flutter mobile app (has its own CLAUDE.md)
├── supabase/           # Supabase config, migrations, seed data
├── brand/              # The logo, and the generator for every app icon
│                       # (icons under app/ are OUTPUTS - see brand/README.md)
├── docs/               # HISTORICAL planning docs (see warning below)
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

The project migrated from offline-first SQLite to **Supabase-only** (Feb–Mar 2026). The planning docs in `docs/` predate that migration — treat them as historical context only.

| Topic | Authoritative source |
|-------|---------------------|
| Database schema | `supabase/migrations/` (NOT `docs/TECHNICAL_REQUIREMENTS.md`) |
| RPC functions | `supabase/migrations/20260316000001_create_rpc_functions.sql` |
| Seed / test data | `supabase/seed.sql` (test user: `test@kasbon.id` / `password123`) |
| Development progress | ClickUp Kasbon space (link above) |
| Frontend conventions | `app/CLAUDE.md` |
| Logo, app icons, brand rules | `docs/BRAND.md` + `brand/` (`docs/BRAND.md` is current, not historical) |
| Business vision | `docs/PROJECT_BRIEF.md` (business sections still valid) |

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

### Flutter (run from app/)
```bash
flutter pub get              # Install dependencies

# One-time setup: copy env.example.json to env.json (and env.android.json for
# the Android emulator, using SUPABASE_URL=http://10.0.2.2:54321). Gitignored.
flutter run --dart-define-from-file=env.json
flutter analyze              # Analyze code
flutter test                 # Run all tests
flutter test test/path/      # Run specific test directory
dart run build_runner build  # Generate code (freezed, riverpod, json)
dart format lib/             # Format code

# Production build (env.prod.json with production URL + publishable key)
# --obfuscate renames Dart symbols; --split-debug-info writes the mapping that
# turns a production stack trace back into names. Archive build/symbols with
# each release or crash reports are unreadable. R8 handles the Java/Kotlin side
# and is configured in android/app/build.gradle.kts.
flutter build appbundle --dart-define-from-file=env.prod.json \
  --obfuscate --split-debug-info=build/symbols
```

### Supabase Local Development (run from project root)
```bash
supabase start               # Start local Supabase (API: 54321, DB: 54322)
supabase stop                # Stop local Supabase
supabase migration new <name>  # Create new migration
supabase db push             # Apply migrations to local
supabase db reset            # Reset local database (applies migrations + seed)

# Security invariants: RLS scoping, search_path pinning, tenant isolation in
# create_pos_transaction, janitor grants, required indexes. Runs in one
# transaction that rolls back, so it is safe to repeat. CI runs this after a
# reset; run it yourself after touching a policy, an RPC or a GRANT.
psql "postgresql://postgres:postgres@127.0.0.1:54322/postgres" \
  -v ON_ERROR_STOP=1 -f supabase/tests/security_invariants.sql
```

## Continuous Integration

`.github/workflows/ci.yml` — three parallel jobs on every push to `main` and
every PR:

| Job | What it protects |
|-----|------------------|
| `flutter` | `flutter analyze --fatal-infos`, then the suite minus goldens, with coverage uploaded as an artifact |
| `database` | Every migration applies to an **empty** database in order, the security invariants hold, and the Edge Function type-checks |
| `build` | Web and a **release** Android build compile, and the merged release manifest still has `INTERNET`, still has `allowBackup="false"`, and still has no external-storage permission |

Two things worth knowing before you change it:

- **Goldens are excluded on CI.** The baselines are macOS-recorded and font
  rasterisation differs on a Linux runner. They are tagged `golden` (see
  `app/dart_test.yaml`) and still run by default locally, which is where they
  are recorded. `flutter test` locally runs 1166 tests; CI runs 1161.
- **There is no `dart format` gate**, because 70 of 473 files do not currently
  match `dart format` and turning it on means a mechanical reformat across
  everyone's in-flight branches first. The workflow header says how to enable
  it once that is done.

The release-variant build job is not redundant with a debug build. Every
packaging bug the August 2026 audit found — a release APK with no `INTERNET`
permission, R8 stripping the Flutter embedding into a black screen — existed
only in the release variant, and a debug build was green through all of it.

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
│   ├── app_config.dart           # Supabase URL & publishable key from dart-define
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
    └── providers/                # Shared Riverpod providers
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

## Storage Retention (`storage-janitor`)

Storage is the quota that runs out first: 1 GB on the free tier, against a shop
writing ~15 MB/day of payment proofs. Nothing used to delete anything, so the
`storage-janitor` Edge Function sweeps nightly at 03:00 WIB (`0 20 * * *` UTC).

Two jobs: **retention** (proofs past `shop_settings.payment_proof_retention_days`,
default 90) and **orphans** (objects in either bucket that no row points at and
that are more than 24h old — both app delete paths drop their errors on purpose,
so leaks are by design and this is the other half).

Retention bounds the total but does not make it small. At ~150 KB a proof,
50 QRIS sales/day × 90 days is **~675 MB** — most of a free-tier GB for one
shop. The window is the dial, and a busy shop belongs nearer 30 days than 90.
Product images stopped mattering once they became WebP (~15 KB each); storage
is payment proofs now.

**Image format is per-upload, not a constant.** The native encoders produce
WebP (~50% smaller than JPEG at matched quality, measured); browsers still get
JPEG, because `package:image` only encodes WebP *losslessly* — which would be
larger than the JPEG it replaced. So the format travels with the bytes as
`CompressedImage`, and the object's extension comes from what was actually
encoded. Reading it from a constant is how an object ends up named `.jpg` while
holding WebP. Lossy WebP on web needs `canvas.toBlob` interop and is a
follow-up.

The split is deliberate: **Postgres decides what, the function only does I/O.**
`storage.protect_delete()` blocks direct `DELETE` on `storage.objects` ("Use the
Storage API instead"), so removal has to be an HTTP call — but the policy
queries (`expired_payment_proofs`, `orphaned_object_paths`,
`referenced_object_paths`, `clear_payment_proof_paths`) live in
`20260801000001` and are testable with plain psql.

Those four are **service-role only**, enforced twice: by GRANTs *and* by
`assert_janitor_caller()` inside each body. Both are needed —
`20260725000001_grant_api_role_privileges.sql` sets `ALTER DEFAULT PRIVILEGES`
so every new `public` function is executable by `authenticated`, which would
otherwise hand any signed-in user a cross-tenant read.

**Deployment is not automatic.** The schedule ships in `20260801000002`, but it
no-ops with a `NOTICE` until two Vault secrets exist — they hold a service key
and a per-environment URL, so they cannot live in a migration:

```sql
select vault.create_secret('https://<ref>.supabase.co/functions/v1/storage-janitor', 'storage_janitor_url');
select vault.create_secret('<service-role-key>', 'storage_janitor_service_key');
```

Then `supabase functions deploy storage-janitor`, and verify without deleting:

```sql
select public.run_storage_janitor(dry_run => true);
select status_code, content from net._http_response order by created desc limit 1;
```

## Authentication

Mandatory email/password auth via Supabase Auth, with email verification and
password recovery by **6-digit OTP code** (never a magic link — the app has no
deep-link handlers on any platform). Route guarding in `app_router.dart`:
- Unauthenticated users → redirected to `/login`
- Authenticated users on a public auth route → redirected to `/dashboard`
- Authenticated users who have not finished onboarding → `/onboarding`
- `GoRouterRefreshStream` listens to `onAuthStateChange` for reactive redirects

`enable_confirmations = true` in `supabase/config.toml`, so `signUp()` returns a
user but no session — verifying the emailed code is what mints the first one.
The OTP emails come from `supabase/templates/{confirmation,recovery}.html`,
which carry `{{ .Token }}`. **Production additionally needs real SMTP** in
`[auth.email.smtp]` and the same two templates set on the hosted project;
`config.toml` governs local dev only.

Whether a user has onboarded is recorded in
`auth.users.raw_user_meta_data.onboarding_completed_at`, not in a table, because
the router redirect is synchronous. See `app/CLAUDE.md` for the full flow.

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
import 'package:kasbon_pos/shared/modern/modern.dart';
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
- ALWAYS import Modern widgets: `import 'package:kasbon_pos/shared/modern/modern.dart';`

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
