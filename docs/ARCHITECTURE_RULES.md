# Baqy Architecture Rules

## 1. Clean Architecture & Layer Separation
- **Presentation**: UI only, dumb widgets, reacts to state via Riverpod providers. No business logic in UI widgets.
- **Domain**: Pure Dart business logic, UseCases, Entities, Parser. Testable and independent with no UI or Flutter dependencies.
- **Data**: Repositories, Database (Drift), external services. Handles mapping and data persistence.

## 2. Single Repository & Reactive Data Flow
- All writes (insert/update/delete) must go through `ExpenseRepository` so that `appDatabase.tableUpdates()` fires.
- Every screen and widget watching providers (like `databaseChangesProvider`, `recentTransactionsProvider`, `currentMonthRemainingProvider`) updates instantly without manual state synchronization.

## 3. Privacy & Security
- Financial data remains strictly on-device in the encrypted local database.
- No network transmission, no analytics/tracking, no external API calls for expense parsing or recording.

## 4. Voice Parsing & Speech Invariants
- Parser is pure Dart, deterministic, running under 5ms.
- No invention: Every amount spoken becomes exactly one item.
- Sum of items equals sum of spoken amounts.
- Leftover words/names never become item names.
- Notes are disabled (null) until explicitly enabled.
- Digits (Western or Arabic-Indic) are never merged across "و". Words merged only if forming valid Arabic numbers.

## 5. Pre-release Auditing (Step 11)
During Step 11 (Security audit, performance, and release preparation), verify and audit:
- [ ] **DEBUG TRANSCRIPT AUDIT**: Search for `REMOVE BEFORE RELEASE` in the codebase.
  - Specifically verify that in `expense_providers.dart`, the debug print statements guarded by `kDebugMode` that output recognized speech words and parsed items are either removed or ensured to be completely compiled out in release builds so no spoken text or debug output exists in release.

