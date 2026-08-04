# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

KASBON POS Flutter frontend - cloud-based POS app for Indonesian UMKM powered by Supabase. Requires authentication (email/password). All data stored in Supabase with Row Level Security. See `../CLAUDE.md` for full project context including database schema and RPC functions.

## Development Commands

```bash
flutter pub get              # Install dependencies

# One-time setup: copy env.example.json to env.json (and env.android.json for
# the Android emulator, using SUPABASE_URL=http://10.0.2.2:54321). Gitignored.
flutter run --dart-define-from-file=env.json
flutter run -d chrome --dart-define-from-file=env.json   # Web (must-ship target)
flutter run -d macos --dart-define-from-file=env.json    # Drag through breakpoints
flutter analyze              # Analyze code for issues
flutter test                 # Run all tests
flutter test test/path/      # Run specific test
flutter test --update-goldens test/widget/shared/modern/layout/  # Re-record shell goldens
dart run build_runner build  # Generate code (freezed, riverpod, json)
dart format lib/             # Format code

# Production build (env.prod.json with production URL + publishable key)
# Release: --obfuscate needs --split-debug-info, and build/symbols must be kept
# per release or crash reports cannot be symbolised. R8 is on for the Java side
# (android/app/build.gradle.kts) - a minified APK that builds is not a minified
# APK that runs, so install it before shipping it.
flutter build appbundle --dart-define-from-file=env.prod.json \
  --obfuscate --split-debug-info=build/symbols
```

## Architecture

**Clean Architecture** with feature-based modules:

```
lib/
├── main.dart                     # Supabase.initialize(), DI init, ProviderScope
├── core/                         # Shared infrastructure
│   ├── constants/                # App constants
│   ├── errors/                   # Failure classes (AuthFailure, NetworkFailure, etc.)
│   ├── platform/                 # AppPlatform capabilities, scroll behaviour
│   ├── responsive/               # Breakpoint, scope, content column, master-detail
│   ├── services/                 # SupabaseClientProvider, BackupService, ImageStorage
│   ├── usecase/                  # Base UseCase<T, Params> class
│   └── utils/                    # Formatters, validators, ResponsiveContext extension
├── config/
│   ├── app_config.dart           # Supabase URL & publishable key (from dart-define)
│   ├── di/injection.dart         # GetIt service locator setup
│   ├── routes/app_router.dart    # GoRouter with auth redirect
│   ├── routes/url_strategy*.dart # Path URLs on web, no-op elsewhere
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
    └── providers/                # Shared Riverpod providers
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

Mandatory email/password auth via Supabase Auth, with email verification and
password recovery by **6-digit OTP code** — never a magic link. The app
registers no deep-link handlers on any platform (no `intent-filter` beyond
LAUNCHER, no `CFBundleURLTypes`, no `redirectTo` anywhere), and a link opened
from a mobile mail client lands in an in-app browser with no session. A code is
one path that works identically on Android, iOS, macOS and Chrome. Do not
reintroduce `{{ .ConfirmationURL }}` into the templates.

**The flow:** register → `/verify-email?email=` → onboarding → POS.
`signUp()` returns a user but **no session** while `enable_confirmations = true`
in `supabase/config.toml`; `verifyOTP` is what mints the first session. Signing
in with an unverified account is routed to the same screen, matched on
`AuthErrorCodes.emailNotConfirmed` rather than on the Bahasa Indonesia copy.

Recovery is `/forgot-password` → `/reset-password?email=`, which verifies the
code and sets the password in one step — the code establishes the session the
change is made against. The forgot-password screen advances whether or not the
address has an account, deliberately: Supabase answers an unknown email with a
plain success, and a screen that said "email tidak terdaftar" would turn the
form into a way to enumerate accounts.

A wrong code and an expired one are the **same error** to Supabase
(`otp_expired` / "Token has expired or is invalid"). One message names both.

**Route guarding** in `app_router.dart` via `redirect`, three rules in order:
- not signed in, not a public auth route → `/login`
- signed in, on a public auth route → `/dashboard`
- signed in, not onboarded, not already there → `/onboarding`

`AppRouter._publicAuthRoutes` is the set for the first two. Adding a screen to
the auth flow without adding it there bounces the user to `/login` on arrival.
`/onboarding` is **not** in it — that route needs a session.

**The onboarding marker lives in auth metadata**
(`raw_user_meta_data.onboarding_completed_at`, see
`SupabaseClientProvider.onboardingCompletedAtKey`), not in a `user_profiles`
column, because `redirect` is synchronous: metadata is already in memory at
first frame, while a table read would paint the dashboard and then yank a
half-onboarded user away from it on every cold start. It is deliberately not
mirrored anywhere. `MarkOnboardingComplete` must land **before** the wizard
navigates, or the gate sends the user straight back.

**Deleting the account** is the one auth action the client cannot perform:
removing an `auth.users` row needs the service role, which this app must never
hold. `DeleteAccount` re-authenticates with `signInWithPassword` (the only way
to check a password with a publishable key), invokes the `delete-account` Edge
Function, then signs out locally — the sign-out failure is swallowed on purpose,
because reporting it would say "deletion failed" about a deletion that
succeeded. `DeleteAccountDialog` owns the confirmation; a wrong password comes
back as `AuthErrorCodes.wrongPassword` so it lands on the field rather than in a
banner. See the root `CLAUDE.md` for the server half.

## Onboarding

`lib/features/onboarding/` — three steps, one of which blocks.

The signup trigger creates a `user_profiles` row and nothing else: no
`shop_settings` (whose `name` is NOT NULL), no categories, no products. Step 1
(nama toko + jenis usaha) is the only thing in the app that creates that row, so
it blocks. Steps 2 and 3 fill the app with something to sell and are skippable.
Finishing lands on **POS**, not the dashboard — on day one the dashboard is a
wall of zeros.

The feature is presentation-heavy and thin on domain: it orchestrates use cases
that already exist. `UpdateShopSettings` upserts on `user_id` so it creates the
row; `CreateCategory` is find-or-create so stepping back and forth cannot
duplicate; `CreateProduct` mints its own id and SKU. Each step persists as it
completes, so abandoning on step 2 still leaves a named shop.

`BusinessType` ids (`warung_makan`, `kedai_kopi`, …) are **storage** — they
reach `shop_settings.business_type`. Labels and starter category lists are free
to change; ids are not.

Everything that does *not* block lives on the dashboard's `SetupChecklistCard`,
dismissible per device via `shared_preferences`.

## Modern Widget Library (REQUIRED)

**CRITICAL:** All UI development MUST use the Modern Widget Library. DO NOT use raw Flutter widgets when a Modern equivalent exists.

**Import:**
```dart
import 'package:kasbon_pos/shared/modern/modern.dart';
```

**Widget Mapping (raw Flutter → Modern equivalent):**
| Raw Flutter | Modern Equivalent |
|-------------|-------------------|
| `ElevatedButton` | `ModernButton.primary()` |
| `OutlinedButton` | `ModernButton.outline()` |
| `TextButton` | `ModernButton.text()` |
| `TextField` | `ModernTextField` |
| `Card` | `ModernCard.elevated()` |
| `CircularProgressIndicator` | `ModernLoading()` |
| `AlertDialog` | `ModernDialog` |
| `SnackBar` | `ModernToast` |
| `showModalBottomSheet` | `ModernBottomSheet.showAdaptive()` |
| `DataTable` | `ModernDataTable` |
| `showDateRangePicker` | `ModernDateRangePicker` |

**Full component list** — the table above covers only the raw-Flutter swaps. These have no Flutter equivalent to replace:

| Category | Components |
|----------|------------|
| Buttons | `ModernButton`, `ModernIconButton` |
| Cards | `ModernCard`, `ModernGradientCard` |
| Inputs | `ModernTextField`, `ModernCurrencyField`, `ModernSearchField`, `ModernDropdown`, `ModernQuantityStepper`, `ModernCalendar`, `ModernDateRangePicker` |
| Layout | `ModernScaffold`, `ModernAppShell`, `ModernAppBar`, `ModernContentHeader`, `ModernSectionHeader`, `ModernDivider` |
| Feedback | `ModernDialog`, `ModernToast`, `ModernLoading`, `ModernSkeleton`, `ModernBottomSheet`, `ModernEmptyState`, `ModernErrorState` |
| Data display | `ModernBadge`, `ModernChip`, `ModernAvatar`, `ModernListTile`, `ModernSummaryRow`, `ModernDataTable` + `ModernTableColumn`, `ModernPaginationControls` |
| Hover (`utils/`) | `ModernHoverBuilder` — for components that paint their own background instead of using `InkWell` |

`ModernContentColumn`, `SliverContentColumn` and `MasterDetailScaffold` live in `core/responsive/`, not here — see **Responsive Layout** below.

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
ModernAppBar.withActions(title: 'Produk')
ModernAppBar.back(title: 'Detail')
ModernAppBar.backWithActions(title: 'Detail')
ModernAppBar.search(title: 'Produk', onSearch: onSearch)
ModernSectionHeader(title: 'Terlaris', actionLabel: 'Lihat Semua', onActionTap: onViewAll)
ModernSectionHeader.withSeeAll(title: 'Terlaris', onSeeAll: onViewAll)
```

### Feedback
```dart
ModernLoading()
// ModernEmptyState requires `message`; `title` and `icon` are optional
ModernEmptyState(icon: Icons.inventory_2_outlined, title: 'Belum Ada Produk', message: 'Tambah produk pertama Anda', actionLabel: 'Tambah', onAction: onAdd)
ModernErrorState(message: 'Gagal memuat', onRetry: onRetry)
ModernDialog.confirm(context, title: 'Hapus?', message: 'Permanen', confirmLabel: 'Hapus', onConfirm: onDel)
// context and message are POSITIONAL, not named
ModernToast.success(context, 'Berhasil')
```

### Data Display
```dart
ModernBadge.success(label: 'Lunas')
ModernBadge.warning(label: 'Hutang')
ModernListTile(title: 'Produk', subtitle: 'Rp 50.000', leading: avatar, trailing: badge, onTap: onTap)
ModernSummaryRow(label: 'Subtotal', value: 'Rp 150.000')
ModernSummaryRow.total(label: 'TOTAL', value: 'Rp 150.000')
```

## Responsive Layout

The app runs from a 320dp phone to a 2560dp monitor and in Chrome, from one
codebase. Four rules carry that; the rest of this section is detail.

1. **Four tiers, named after the space — not the hardware.**
2. **Measure the container, never the window.**
3. **Clamp content width.** No screen may span 2560dp edge to edge.
4. **Never hand-roll the shell's insets.**

### The four tiers

`Breakpoint` in `core/responsive/breakpoint.dart`:

| Tier | Width | Typical | Shell chrome |
|------|-------|---------|--------------|
| `compact` | < 600dp | phone portrait | bottom bar (4 items) + notched FAB |
| `medium` | 600–899dp | phone landscape, iPad portrait, half-screen window | 80dp rail, 7 items, no toggle |
| `expanded` | 900–1299dp | landscape tablet | 80dp rail, toggles to 280dp |
| `large` | ≥ 1300dp | desktop window | 280dp rail, labelled |

The thresholds (`AppBreakpoints.compactMax/mediumMax/expandedMax`) live beside
the enum, not in `AppDimensions`. 900 and 1300 are inherited from the app's
original three-tier split so the extra tiers landed without moving any existing
layout — `medium` is the only band where behaviour changed.

`medium` is why the system exists: an iPad portrait at 834dp used to get the
phone build, with POS, Hutang and Laporan simply absent from the nav.

### Container, not window

```dart
context.breakpoint        // tier of the space THIS widget has  ← use this
context.availableWidth    // that space, in logical pixels
context.isCompact / isMedium / isExpanded / isLarge
context.isAtLeast(Breakpoint.expanded) / isBelow(...)
context.isInPane          // true inside a split-view pane
context.windowBreakpoint  // tier of the whole window          ← shell chrome only
```

A 400dp master pane in a 1600dp window is `compact`. Reading the window there
lays a desktop layout into a phone-width column — the single bug the whole
subsystem exists to prevent. `MediaQuery.sizeOf(context).width` in
`lib/features/` fails `architecture_test.dart` for this reason.

`windowBreakpoint` has two legitimate callers: `ModernAppShell`, which picks the
nav for the window, and `shellBottomInset`. Anything else reading it is a bug.

**Pick per-tier values with `responsive<T>()`**, which cascades upward — supply
only the tiers you care about:

```dart
// 2 columns at compact AND medium, 3 at expanded AND large
final columns = context.responsive<int>(compact: 2, expanded: 3);

final padding = context.contentPadding;   // 16 / 20 / 24 / 32 per tier
```

When a count should follow an exact width rather than a tier, measure it —
`large` covers everything from 1300dp to 2560dp, so a tier is not a width. See
the `SliverLayoutBuilder` in `product_list_screen.dart`.

**Re-scope when you constrain.** Anything that narrows its child must publish a
fresh `ModernBreakpointScope` at the new width, or children keep hearing the old
tier. `ModernContentColumn` and `MasterDetailScaffold` already do.

### Content width

`ModernContentColumn` centres, clamps and pads. It aligns to the **top**, not
the centre — only the auth forms pass `alignment` to override that.

```dart
ModernContentColumn.form(child: ...)      //  560dp — single-column forms
ModernContentColumn.reading(child: ...)   //  720dp — prose, settings lists
ModernContentColumn(child: ...)           // 1080dp — default: lists, details
ModernContentColumn.wide(child: ...)      // 1440dp — dashboards, reports
// ContentWidth.full — screens managing their own width (POS, split views)
SliverContentColumn(sliver: ...)          // the sliver form
```

### Shell insets

The shell sets `extendBody: true` on compact, so the bottom bar floats *over*
the content. Scrollables must pad for it:

```dart
final bottomPadding = AppDimensions.spacing16 + context.shellBottomInset;
```

Never write `AppDimensions.bottomNavHeight + ...` by hand. Twenty-five sites did;
two forgot the tier guard and reserved 112px of dead space on tablet, one
invented its own `80.0`, and the count grew from 19 to 25 unnoticed.
`architecture_test.dart` now fails the build on a twenty-sixth.

`shellBottomInset` reads the **window** deliberately — a screen in a narrow pane
still has no bottom bar under it if the window chose a rail.

### Master–detail split views

Products, Transactions and Debt become two-pane at `expanded` and up, URL-driven
so the URLs stay shareable. The route table is untouched: the list route wraps in
`MasterDetailScaffold`, the detail route wraps in `SplitDetailRoute`.

Two rules if you add a third:
- **Read the tier in `build`, never in a `pageBuilder`.** A resize does not
  rebuild the route table, so a split decided there leaves a permanently blank
  pane after dragging 1400 → 700.
- Each pane installs its own `isPane: true` scope. Panes size from their own
  width, with no column ladder that has to know the pane exists.

### Testing responsive code

`test/helpers/responsive_helpers.dart` — resize the **view**, not a `MediaQuery`
wrapper (an override there is invisible to anything reading the view directly and
does not survive `MaterialApp`'s own `MediaQuery`):

```dart
for (final width in ResponsiveWidths.all) {   // 375 / 700 / 1100 / 1600
  testWidgets('renders at ${ResponsiveWidths.label(width)}', (tester) async {
    await pumpAtWidth(tester, width, const MyWidget());       // wraps in Scaffold
    // pumpScreenAtWidth — for screens providing their own Scaffold/ModernAppBar
  });
}

setViewWidth(tester, 700);   // mid-test resize, then await tester.pump()
await tester.pumpAndSettle();
```

Shell chrome also has pixel baselines in
`test/widget/shared/modern/layout/goldens/`. Re-record intentional changes with
`flutter test --update-goldens test/widget/shared/modern/layout/` and commit the
PNGs alongside. They were recorded on macOS and are not portable to other hosts.

Hover tests must set `debugDefaultTargetPlatformOverride` to a desktop platform
first — `ModernHoverBuilder` short-circuits on touch platforms, and `flutter
test` reports `TargetPlatform.android`.

## Platform Capabilities & Web

The app ships to Android, iOS, macOS and **Chrome**. Web is a must-ship target,
not a nice-to-have.

**Ask what the app can do, never what OS it is on.** `AppPlatform`
(`core/platform/app_platform.dart`):

```dart
AppPlatform.isWeb                    AppPlatform.supportsHaptics
AppPlatform.isMobileOs               AppPlatform.usesSystemOverlayStyle
AppPlatform.isDesktopOs              AppPlatform.needsRuntimePermissions
AppPlatform.isPointerFirst           AppPlatform.supportsCameraCapture
AppPlatform.hasFileSystem
```

`supportsHaptics` says why the branch exists; `Platform.isIOS ||
Platform.isAndroid` makes the next reader work it out, and gets copied wrongly.
`kIsWeb` and `Platform.isX` outside this file fail `architecture_test.dart`.

**`dart:io` never appears in a file the web build can reach.** Put it behind a
conditional import — `foo.dart` (facade) → `foo_io.dart` / `foo_web.dart`. Only
`_io.dart` files may import `dart:io`, and only a facade may import an
`_io.dart`. Naming an `_io` implementation directly from `injection.dart` is how
`dart:io` first reached the web build: every import looked innocent and the
failure only surfaced at build time.

Web specifics worth knowing:
- **Path URLs, not hash URLs** (`config/routes/url_strategy_web.dart`), so detail
  URLs are shareable. The host must rewrite unknown paths to `index.html` or a
  hard refresh on `/products/abc` 404s.
- **The Content-Security-Policy is a host header, never a `<meta>` tag.** The
  full policy to set is written out in the comment at the top of
  `web/index.html`. It lived in a meta tag until it was found to break every
  `flutter run -d chrome`: a release build bootstraps from an external
  `flutter_bootstrap.js` and was fine, but a debug build calls `main()` from an
  *inline* script, which `script-src 'self'` refuses. Nothing then paints, and
  `splash.js` only clears the spinner on `flutter-first-frame` — so the app
  hangs on the splash with no Dart error and a clean `flutter run` log. If a
  bundled default is ever wanted, inject it into `build/web/index.html` after
  the build, never into `web/index.html`.
- Product images go to **Supabase Storage** on every platform. A device
  filesystem path in `products.image_url` never synced across devices.
- `products.image_url` holds the **object path** inside the bucket, not a URL.
  The host belongs to the environment (`127.0.0.1` in a browser, `10.0.2.2` in
  the emulator, a LAN IP on a device, production), so render sites resolve it
  through `productImageUrl()` in `product_image.dart` - never
  `Image.network(product.imageUrl!)`. Rows written by an older client can still
  hold a full URL and are re-pointed at the current host on read;
  `referenced_object_paths` in `20260804010009_storage_retention.sql` normalises
  the same shape so the janitor does not collect a live photo.
- Storage is written when a photo is **picked**, the row when the form is
  **saved**. `ProductImagePicker` therefore only ever uploads; deleting what is
  no longer referenced is `ProductFormScreen._releaseUnusedImages`, on the way
  out. Deleting at pick time destroyed live photos whenever an edit was
  abandoned or an upload failed.
- Exports are in-memory `ExportResult` values; only delivery splits io/web.
- `flutter build web` targets JS. Wasm is blocked by third-party `dart:ffi`
  imports (`win32`, `image`), not by our code.

```bash
flutter run -d chrome --dart-define-from-file=env.json
flutter build web --dart-define-from-file=env.json
```

## Architecture Rules (enforced by test)

`test/architecture_test.dart` encodes eleven rules the analyzer cannot express.
Each one already went wrong at least once. They run in milliseconds and fail with
the offending file and line, so treat a failure as the rule talking, not as a
flaky test.

| Rule | Use instead |
|------|-------------|
| No `MediaQuery...width` in `lib/features/` | `context.breakpoint` / `responsive()` |
| Nothing adds `bottomNavHeight` by hand | `context.shellBottomInset` |
| The deprecated window-based API stays deleted | `Breakpoint`, `contentPadding` |
| `dart:io` only in `_io.dart` files | a conditional-import facade |
| `_io.dart` imported only by its facade | the facade |
| No raw `Platform.isX` | `AppPlatform` capabilities |
| No raw `kIsWeb` | a named `AppPlatform` capability |
| No raw `showModalBottomSheet` | `ModernBottomSheet.showAdaptive` |
| `HapticFeedback` guarded | `AppPlatform.supportsHaptics` |
| No raw `CircularProgressIndicator` | `ModernLoading` |
| No raw `fontSize:` in the Modern library | an `AppTextStyles` entry |

The third rule is a tombstone. `ResponsiveUtils`, `DeviceType`,
`AppDimensions.breakpointMobile`/`breakpointDesktop` and the window-based
`context.isMobile` family were deleted in RESP_10 after a
deprecate-and-forward migration. The analyzer catches a reference to a symbol
that no longer exists; it cannot catch someone reintroducing one, which is the
real risk — reading the window is the obvious way to write a layout and silently
wrong inside a pane.

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
