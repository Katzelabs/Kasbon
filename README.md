# KASBON - Kasir Bisnis Online

A cloud-based POS (Point of Sale) application for Indonesian small businesses (UMKM), built with Flutter and Supabase.

## Key Features

- **Cloud-First** - All data stored in Supabase (PostgreSQL) with Row Level Security
- **Multi-Device** - Sign in from any device, data follows your account
- **Profit Tracking** - Track profits, not just revenue
- **Debt Management** - Built-in debt (hutang) tracking for local business needs

## Tech Stack

- **Frontend:** Flutter
- **State Management:** Riverpod
- **Backend:** Supabase (PostgreSQL + Auth + RLS)
- **Authentication:** Supabase Auth (mandatory email/password)
- **Architecture:** Clean Architecture (feature-based modules)

## Project Structure

```
Kasbon/
├── kasbon-frontend/    # Flutter mobile app
├── supabase/           # Supabase config, migrations, seed data
└── DOCS/               # Project documentation
```

Development tasks and progress are tracked in [ClickUp (Kasbon space)](https://app.clickup.com/90182053080/v/b/s/901812129010).

## Development

### Prerequisites

- Flutter SDK 3.x
- Dart SDK
- Supabase CLI (for local development)
- Docker (required by Supabase CLI)

### Setup

```bash
# Clone repository
git clone <repository-url>
cd Kasbon

# Start local Supabase (from project root)
supabase start
# Note the API URL and anon key printed by this command

# Install Flutter dependencies
cd kasbon-frontend
flutter pub get

# Run the app against local Supabase
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon-key-from-supabase-start>
```

Local test user (from seed data): `test@kasbon.id` / `password123`

### Supabase Local Development

```bash
supabase start                 # Start local Supabase (API: 54321, DB: 54322)
supabase stop                  # Stop local Supabase
supabase migration new <name>  # Create a new migration
supabase db reset              # Reset local DB (applies migrations + seed)
```

## Documentation

- `CLAUDE.md` — Current architecture, commands, and conventions (kept up to date)
- [ClickUp Kasbon space](https://app.clickup.com/90182053080/v/b/s/901812129010) — Development tasks & progress tracker
- `supabase/migrations/` — Database schema source of truth
- `DOCS/` — Original planning documents (historical; early sections describe a
  since-abandoned SQLite offline-first design)

## License

[License information here]
