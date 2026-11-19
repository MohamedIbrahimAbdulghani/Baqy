# Baqy Architecture Rules

## 1. Clean Architecture & Layer Separation
- **Presentation**: UI only, dumb widgets, reacts to state via Riverpod providers. No business logic in UI widgets.
- **Domain**: Pure Dart business logic, UseCases, Entities, Parser. Testable and independent with no UI or Flutter dependencies.
- **Data**: Repositories, Database (Drift), external services. Handles mapping and data persistence.

## 2. Single Repository & Reactive Data Flow
- All writes (insert/update/delete) must go through `ExpenseRepository`, `GoalRepository` or `DebtRepository` so that `appDatabase.tableUpdates()` fires.
- Every screen and widget watching providers (like `databaseChangesProvider`, `recentTransactionsProvider`, `currentMonthRemainingProvider`, `goalsStreamProvider`, `debtsStreamProvider`) updates instantly without manual state synchronization.
- **Money Rule**: `remaining = month money - month expenses - net goal savings of that month`.
  - Month money = budget + month income.
  - Goal savings are treated as a virtual category named "تحويش" (color `#B5883E`, icon `Icons.savings_outlined`). Withdrawals are shown as "سحب من الهدف" with a minus sign.
  - Savings and withdrawals appear in "آخر المصاريف", Month details chart (if net saved in month > 0), Day list, and Category details for "تحويش".
  - Home screen line: when the month has net savings Z > 0, show "صرفت X وحوّشت Z من Y" (X = expenses only). When Z is zero keep "صرفت X من Y".
  - Consistency rule: chart column = month total = category-details total.
  - Deleting a goal with savings removes its savings and returns the money to the remaining immediately.
- **Debt Money Rules**:
  - Every payment is saved in ONE database transaction together with its linked row.
  - When paying someone ("عليا"), the linked row is an EXPENSE in the default category "ديون" with source "debt", person name as description, created_at = payment time. It is deducted from the month's money and shows in "آخر المصاريف", month chart, and day list like any expense.
  - When someone pays back ("ليا"), the linked row is INCOME with source "debt" in that month; it is added to the month's money and is NOT shown as an expense anywhere.
  - Store the id of the linked row in `debt_payments.transaction_id`.
  - Remaining of a debt = total - sum of its payments.
  - When remaining reaches zero, the debt is automatically archived (`archived = true`) in the same database transaction and shows the mark "تم السداد".
  - If a payment is undone or total is edited so remaining > 0, the debt returns to the active list.
  - Deleting a debt removes the debt, its payments, and the linked transactions, restoring the month remaining.
- **Module Transaction Protection Rule**:
  - Transactions originating from dedicated modules (such as `source == 'debt'` or `source == 'goal'` / virtual savings) CANNOT be edited or deleted from the general expense lists (Home screen "آخر المصاريف" or "تفاصيل الشهر / تفاصيل التصنيف").
  - They can only be managed (edited or deleted) from their dedicated screens (the "الديون" or "الأهداف" screens).
  - Attempting to edit or delete them from the expenses repository throws an error, and clicking on them in expense views displays an explanatory sheet directing the user to the dedicated module without exposing edit or delete actions.

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

