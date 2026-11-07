import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'connection/db_connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Transactions,
  UserRules,
  MonthBudgets,
  Goals,
  Reminders,
  Debts,
  DebtPayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openEncryptedConnection());

  @override
  int get schemaVersion => 4;

  static const List<({String name, String icon, String color, int sortOrder})>
      defaultCategoryDefinitions = [
    (name: 'أكل', icon: 'food', color: '#4E8B7A', sortOrder: 1),
    (name: 'مشروبات وكافيهات', icon: 'coffee', color: '#5C9A86', sortOrder: 2),
    (name: 'سوبر ماركت', icon: 'local_grocery_store', color: '#3A9D78', sortOrder: 3),
    (name: 'مواصلات', icon: 'transport', color: '#E8A83A', sortOrder: 4),
    (name: 'سيارة', icon: 'car', color: '#D9982E', sortOrder: 5),
    (name: 'ملابس', icon: 'clothes', color: '#7C6FA8', sortOrder: 6),
    (name: 'إلكترونيات', icon: 'phone', color: '#4A789C', sortOrder: 7),
    (name: 'بيت وأثاث', icon: 'home', color: '#8FA3BD', sortOrder: 8),
    (name: 'إيجار', icon: 'rent', color: '#6888A8', sortOrder: 9),
    (name: 'فواتير واتصالات', icon: 'bills', color: '#7E98A8', sortOrder: 10),
    (name: 'اشتراكات', icon: 'subscriptions', color: '#8B7DB8', sortOrder: 11),
    (name: 'صحة', icon: 'medical', color: '#3B8B88', sortOrder: 12),
    (name: 'عناية شخصية', icon: 'personal_care', color: '#D6A19A', sortOrder: 13),
    (name: 'تعليم', icon: 'education', color: '#5B9382', sortOrder: 14),
    (name: 'ترفيه', icon: 'entertainment', color: '#5BA3B8', sortOrder: 15),
    (name: 'سفر', icon: 'travel', color: '#4599A0', sortOrder: 16),
    (name: 'أطفال', icon: 'kids', color: '#E2976C', sortOrder: 17),
    (name: 'حيوانات أليفة', icon: 'pets', color: '#9E8268', sortOrder: 18),
    (name: 'هدايا ومناسبات', icon: 'gift', color: '#D47E8A', sortOrder: 19),
    (name: 'صدقات', icon: 'charity', color: '#C88B82', sortOrder: 20),
    (name: 'استثمار وادخار', icon: 'investment', color: '#3D7A68', sortOrder: 21),
    (name: 'ديون وأقساط', icon: 'debts', color: '#C0644B', sortOrder: 22),
    (name: 'أخرى', icon: 'other', color: '#9A9488', sortOrder: 23),
  ];

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        final sw = Stopwatch()..start();
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] onCreate: creating all tables...');
        }
        await m.createAll();
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] onCreate: tables created in ${sw.elapsedMilliseconds}ms. Seeding 22 default categories...');
        }

        // Seed 22 default categories once (idempotent)
        final now = DateTime.now();
        await batch((b) {
          b.insertAll(
            categories,
            defaultCategoryDefinitions.map((def) {
              return CategoriesCompanion.insert(
                name: def.name,
                icon: def.icon,
                colorHex: def.color,
                isDefault: const Value(true),
                sortOrder: Value(def.sortOrder),
                createdAt: Value(now),
              );
            }).toList(),
          );
        });
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] onCreate: seeded 22 default categories in ${sw.elapsedMilliseconds}ms total');
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        final sw = Stopwatch()..start();
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] onUpgrade: starting migration from version $from to $to...');
        }

        Future<Set<String>> getColumns(String tableName) async {
          final rows = await customSelect("PRAGMA table_info('$tableName');").get();
          return rows.map((r) => r.read<String>('name')).toSet();
        }

        if (from < 2) {
          if (kDebugMode) {
            debugPrint('[DB_DEBUG] onUpgrade (v1->v2): checking note column in transactions');
          }
          final txCols = await getColumns('transactions');
          if (!txCols.contains('note')) {
            await m.addColumn(transactions, transactions.note);
            if (kDebugMode) {
              debugPrint('[DB_DEBUG] onUpgrade (v1->v2): added note column');
            }
          }
        }

        if (from < 3) {
          if (kDebugMode) {
            debugPrint('[DB_DEBUG] onUpgrade (v2->v3): checking new columns in categories');
          }
          // 1. Add new columns to categories if not already present
          final catCols = await getColumns('categories');
          if (!catCols.contains('is_archived')) {
            await m.addColumn(categories, categories.isArchived);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added is_archived column');
          }
          if (!catCols.contains('sort_order')) {
            await m.addColumn(categories, categories.sortOrder);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added sort_order column');
          }
          if (!catCols.contains('created_by_ai')) {
            await m.addColumn(categories, categories.createdByAi);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added created_by_ai column');
          }
          if (!catCols.contains('created_at')) {
            // SQLite accepts constant defaults like 0 in ALTER TABLE ADD COLUMN.
            await customStatement(
              'ALTER TABLE categories ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0;',
            );
            final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
            await customStatement(
              'UPDATE categories SET created_at = $nowSec WHERE created_at = 0 OR created_at IS NULL;',
            );
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added and backfilled created_at column');
          }

          // Ensure any row with created_at = 0 or NULL is updated
          final nowSec = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          await customStatement(
            'UPDATE categories SET created_at = $nowSec WHERE created_at = 0 OR created_at IS NULL;',
          );

          // 2. Add foreign amount and currency to transactions if not already present
          final txCols = await getColumns('transactions');
          if (!txCols.contains('foreign_amount')) {
            await m.addColumn(transactions, transactions.foreignAmount);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added foreign_amount column');
          }
          if (!txCols.contains('foreign_currency')) {
            await m.addColumn(transactions, transactions.foreignCurrency);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: added foreign_currency column');
          }

          // 3. Create user_rules table if not exists
          final userRulesTable = await customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='user_rules';",
          ).get();
          if (userRulesTable.isEmpty) {
            await m.createTable(userRules);
            if (kDebugMode) debugPrint('[DB_DEBUG] onUpgrade: created user_rules table');
          }

          // 4. Migration of old categories:
          // Update 'قهوة وكافيهات' -> 'مشروبات'
          await customStatement(
            "UPDATE categories SET name = 'مشروبات', icon = 'coffee' WHERE name = 'قهوة وكافيهات';",
          );

          // Update 'ديون' -> 'ديون وأقساط'
          await customStatement(
            "UPDATE categories SET name = 'ديون وأقساط', icon = 'debts' WHERE name = 'ديون';",
          );

          // Seed any missing default categories from the 22 defaults (idempotent)
          final existingRows = await customSelect('SELECT name FROM categories;').get();
          final existingNames = existingRows.map((c) => c.read<String>('name').trim()).toSet();
          final now = DateTime.now();

          int newlySeededCount = 0;
          for (final def in defaultCategoryDefinitions) {
            if (!existingNames.contains(def.name)) {
              await into(categories).insert(
                CategoriesCompanion.insert(
                  name: def.name,
                  icon: def.icon,
                  colorHex: def.color,
                  isDefault: const Value(true),
                  sortOrder: Value(def.sortOrder),
                  createdAt: Value(now),
                ),
              );
              newlySeededCount++;
            }
          }
          if (kDebugMode) {
            debugPrint('[DB_DEBUG] onUpgrade: seeded $newlySeededCount missing default categories');
          }
        }

        if (from < 4) {
          if (kDebugMode) {
            debugPrint('[DB_DEBUG] onUpgrade (v3->v4): updating category names to standard and seeding سوبر ماركت');
          }
          await customStatement(
            "UPDATE categories SET name = 'مشروبات وكافيهات', icon = 'coffee' WHERE name = 'مشروبات' OR name = 'قهوة وكافيهات';",
          );
          await customStatement(
            "UPDATE categories SET name = 'فواتير واتصالات', icon = 'bills' WHERE name = 'فواتير';",
          );
          await customStatement(
            "UPDATE categories SET name = 'سفر', icon = 'travel' WHERE name = 'سفر وسياحة';",
          );

          final existingRows = await customSelect('SELECT name FROM categories;').get();
          final existingNames = existingRows.map((c) => c.read<String>('name').trim()).toSet();
          final now = DateTime.now();

          for (final def in defaultCategoryDefinitions) {
            if (!existingNames.contains(def.name)) {
              await into(categories).insert(
                CategoriesCompanion.insert(
                  name: def.name,
                  icon: def.icon,
                  colorHex: def.color,
                  isDefault: const Value(true),
                  sortOrder: Value(def.sortOrder),
                  createdAt: Value(now),
                ),
              );
            }
          }
        }

        if (kDebugMode) {
          debugPrint('[DB_DEBUG] onUpgrade: finished migration successfully in ${sw.elapsedMilliseconds}ms');
        }
      },
      beforeOpen: (details) async {
        final sw = Stopwatch()..start();
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] beforeOpen: wasCreated=${details.wasCreated}, hadUpgrade=${details.hadUpgrade}, versionBefore=${details.versionBefore}, versionNow=${details.versionNow}');
        }
        await customStatement('PRAGMA foreign_keys = ON;');
        // Ensure standard names and missing default categories (e.g. سوبر ماركت) are seeded idempotently
        try {
          await customStatement(
            "UPDATE categories SET name = 'مشروبات وكافيهات', icon = 'coffee' WHERE name = 'مشروبات' OR name = 'قهوة وكافيهات';",
          );
          await customStatement(
            "UPDATE categories SET name = 'فواتير واتصالات', icon = 'bills' WHERE name = 'فواتير';",
          );
          await customStatement(
            "UPDATE categories SET name = 'سفر', icon = 'travel' WHERE name = 'سفر وسياحة';",
          );

          final existingRows = await customSelect('SELECT name FROM categories;').get();
          final existingNames = existingRows.map((c) => c.read<String>('name').trim()).toSet();
          final now = DateTime.now();

          for (final def in defaultCategoryDefinitions) {
            if (!existingNames.contains(def.name)) {
              await into(categories).insert(
                CategoriesCompanion.insert(
                  name: def.name,
                  icon: def.icon,
                  colorHex: def.color,
                  isDefault: const Value(true),
                  sortOrder: Value(def.sortOrder),
                  createdAt: Value(now),
                ),
              );
            }
          }
        } catch (_) {}
        if (kDebugMode) {
          debugPrint('[DB_DEBUG] beforeOpen: completed in ${sw.elapsedMilliseconds}ms');
        }
      },
    );
  }

  /// Clears all user transactions, budgets, debts, goals and custom categories,
  /// preserving only the default seeded categories.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(transactions).go();
      await delete(monthBudgets).go();
      await delete(debtPayments).go();
      await delete(debts).go();
      await delete(goals).go();
      await delete(reminders).go();
      await delete(userRules).go();
      await (delete(categories)..where((c) => c.isDefault.equals(false))).go();
    });
  }
}
