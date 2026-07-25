# KASBON - Current Project State

**Last Updated:** July 2026
**Status:** MVP complete, Supabase migration complete — preparing for deployment

> This document is a snapshot. For live progress see the [ClickUp Kasbon space](https://app.clickup.com/90182053080/v/b/s/901812129010).
> For current architecture and conventions see the root [CLAUDE.md](../CLAUDE.md).

---

## Project Overview

KASBON (Kasir Bisnis Online) is a cloud-based POS application for Indonesian UMKM (small businesses) built with Flutter and Supabase. All data is stored in Supabase (PostgreSQL) with Row Level Security; authentication (email/password) is mandatory.

**Important:** The project originally launched as an offline-first SQLite app. In Feb–Mar 2026 it was fully migrated to a Supabase-only architecture — SQLite was removed entirely. The other documents in this folder (`PROJECT_BRIEF.md`, `TECHNICAL_REQUIREMENTS.md`, `FEATURE_PRIORITY_AND_PHASES.md`) predate that migration and describe the old architecture in places.

---

## What Is Built (as of July 2026)

All MVP features (TASK_001–015) plus authentication (TASK_017) are complete:

- **Products & Categories** — Full CRUD, search, filtering, bulk actions, create-category-from-product-form
- **POS** — Cart, payment flow (cash/debt), atomic transaction creation via `create_pos_transaction` RPC, stock validation
- **Transactions** — History with date filtering, detail view, grouped by date
- **Dashboard** — Today's sales/profit/transaction count with comparisons (via `get_dashboard_summary` RPC), low stock alerts
- **Receipts** — Text-based digital receipt, copy/share/WhatsApp
- **Stock Tracking** — Automatic deduction, low stock alerts
- **Profit & Reports** — Profit reports, sales reports, top products (via reporting RPCs)
- **Debt (Hutang)** — Debt payment option, debt list, mark as paid, summary
- **Settings** — Shop profile, receipt customization, low stock threshold
- **Backup** — JSON export/import
- **Auth** — Login/register screens, route guarding, logout
- **Testing** — 358 tests, 95–100% coverage on business logic

## Remaining Work

| Task | Status |
|------|--------|
| TASK_016 Beta Preparation | Not started |
| TASK_019 Advanced Reports | Not started |
| TASK_020 QRIS Payment | Not started |
| TASK_021 Deployment | Not started |
| TASK_018 Cloud Sync | Obsolete (Supabase-only architecture makes it unnecessary) |

---

## Architecture Summary

- **Frontend:** Flutter, Clean Architecture, feature modules under `kasbon-frontend/lib/features/` (auth, products, categories, pos, transactions, dashboard, reports, debt, receipt, backup, settings, dev_tools)
- **State:** Riverpod; **DI:** GetIt; **Navigation:** GoRouter with auth redirect
- **Backend:** Supabase — schema in `supabase/migrations/`, seed in `supabase/seed.sql`
- **UI:** Modern Widget Library (`lib/shared/modern/`) is REQUIRED; `lib/shared/widgets/` is deprecated
- **Config:** Supabase URL and anon key injected via `--dart-define` (see `lib/config/app_config.dart`)

## Sources of Truth

| Topic | Where to look |
|-------|---------------|
| Database schema | `supabase/migrations/` (NOT the docs in this folder) |
| RPC functions | `supabase/migrations/20260316000001_create_rpc_functions.sql` |
| Progress | [ClickUp Kasbon space](https://app.clickup.com/90182053080/v/b/s/901812129010) |
| Architecture & conventions | Root `CLAUDE.md` and `kasbon-frontend/CLAUDE.md` |
| Business vision & roadmap | `DOCS/PROJECT_BRIEF.md`, `DOCS/FEATURE_PRIORITY_AND_PHASES.md` (still valid for business context) |
