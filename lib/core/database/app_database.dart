import 'package:drift/drift.dart';
import 'connection/db_connection.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Categories,
  Transactions,
  MonthBudgets,
  Goals,
  Reminders,
  Debts,
  DebtPayments,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openEncryptedConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();

        // Seed default categories once
        await batch((b) {
          b.insertAll(
            categories,
            [
              CategoriesCompanion.insert(
                name: 'أكل',
                icon: 'food',
                color: '#4E8B7A',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'مواصلات',
                icon: 'transport',
                color: '#E8A83A',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'فواتير',
                icon: 'bills',
                color: '#8FA3BD',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'صدقات',
                icon: 'charity',
                color: '#D6A19A',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'اشتراكات',
                icon: 'subscriptions',
                color: '#7C6FA8',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'ديون',
                icon: 'debts',
                color: '#C0644B',
                isDefault: const Value(true),
              ),
              CategoriesCompanion.insert(
                name: 'أخرى',
                icon: 'other',
                color: '#9A9488',
                isDefault: const Value(true),
              ),
            ],
          );
        });
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Schema migrations will be handled sequentially per version
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }
}

