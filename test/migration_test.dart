// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:baqy/core/database/app_database.dart';

void main() {
  group('Requirement 5: Schema Migration, Transaction Preservation & Idempotency Tests', () {
    test('Migration preserves all existing transactions and updates legacy categories', () async {
      final tempDir = await Directory.systemTemp.createTemp('baqy_mig_preserve_');
      final dbFile = File('${tempDir.path}/test_v2.sqlite');

      // 1. Build a real v2 SQLite database
      final raw = sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 2;');
      raw.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          amount INTEGER NOT NULL,
          description TEXT NOT NULL,
          category_id INTEGER NOT NULL REFERENCES categories (id),
          kind TEXT NOT NULL,
          source TEXT NOT NULL,
          note TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE month_budgets (
          year_month TEXT NOT NULL PRIMARY KEY,
          amount INTEGER NOT NULL
        );
      ''');

      // Insert legacy v2 categories: id=1 أكل, id=2 قهوة وكافيهات, id=3 ديون
      raw.execute('''
        INSERT INTO categories (id, name, icon, color, is_default) VALUES
        (1, 'أكل', 'food', '#4E8B7A', 1),
        (2, 'قهوة وكافيهات', 'coffee', '#5C9A86', 1),
        (3, 'ديون', 'debts', '#C0644B', 1);
      ''');

      // Insert transactions linked to each category
      raw.execute('''
        INSERT INTO transactions (id, amount, description, category_id, kind, source, note, created_at) VALUES
        (1, 15000, 'غداء عمل', 1, 'expense', 'voice', NULL, 1730900000),
        (2, 4500, 'لاتيه موكا', 2, 'expense', 'voice', 'كافيه البن', 1730903600),
        (3, 120000, 'قسط القرض', 3, 'expense', 'text', NULL, 1730907200);
      ''');

      // Set month budget
      raw.execute('''
        INSERT INTO month_budgets (year_month, amount) VALUES ('2026-11', 500000);
      ''');

      raw.close();

      // 2. Open with AppDatabase (v3) - runs onUpgrade from 2 to 3
      final v3Db = AppDatabase(NativeDatabase(dbFile));

      // Check categories: 'قهوة وكافيهات' -> 'مشروبات وكافيهات' with same id=2
      final cats = await v3Db.select(v3Db.categories).get();
      expect(cats.length, equals(24), reason: 'All 24 default categories should exist');

      final coffeeCat = cats.firstWhere((c) => c.id == 2);
      expect(coffeeCat.name, equals('مشروبات وكافيهات'));
      expect(coffeeCat.icon, equals('coffee'));

      final debtCat = cats.firstWhere((c) => c.id == 3);
      expect(debtCat.name, equals('ديون وأقساط'));
      expect(debtCat.icon, equals('debts'));

      // Check transactions: all 3 preserved exactly
      final txs = await v3Db.select(v3Db.transactions).get();
      expect(txs.length, equals(3), reason: 'All 3 transactions must be preserved');

      final tx1 = txs.firstWhere((t) => t.id == 1);
      expect(tx1.amount, equals(15000));
      expect(tx1.description, equals('غداء عمل'));
      expect(tx1.categoryId, equals(1));

      final tx2 = txs.firstWhere((t) => t.id == 2);
      expect(tx2.amount, equals(4500));
      expect(tx2.description, equals('لاتيه موكا'));
      expect(tx2.categoryId, equals(2), reason: 'Linked to updated مشروبات category');
      expect(tx2.note, equals('كافيه البن'));

      final tx3 = txs.firstWhere((t) => t.id == 3);
      expect(tx3.amount, equals(120000));
      expect(tx3.description, equals('قسط القرض'));
      expect(tx3.categoryId, equals(3), reason: 'Linked to updated ديون وأقساط category');

      await v3Db.close();

      // 3. Test Idempotency: Open the same database again
      final v3DbAgain = AppDatabase(NativeDatabase(dbFile));
      final catsAgain = await v3DbAgain.select(v3DbAgain.categories).get();
      expect(catsAgain.length, equals(24), reason: 'Re-opening must not duplicate categories');

      final txsAgain = await v3DbAgain.select(v3DbAgain.transactions).get();
      expect(txsAgain.length, equals(3), reason: 'Re-opening must not duplicate or lose transactions');

      await v3DbAgain.close();
      await tempDir.delete(recursive: true);
    });

    test('Migration v5 to v6 adds nullable icon column to goals and preserves all data', () async {
      final tempDir = await Directory.systemTemp.createTemp('baqy_mig_v6_');
      final dbFile = File('${tempDir.path}/test_v5.sqlite');

      // 1. Build a real v5 SQLite database
      final raw = sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 5;');
      raw.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_by_ai INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('''
        CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL,
          target_amount INTEGER NOT NULL,
          monthly_saving INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE goal_savings (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          goal_id INTEGER NOT NULL REFERENCES goals (id),
          amount INTEGER NOT NULL,
          saved_at INTEGER NOT NULL
        );
      ''');

      // Insert existing goals (v5 without icon)
      raw.execute('''
        INSERT INTO goals (id, name, target_amount, monthly_saving, created_at) VALUES
        (1, 'ماك برو', 10000000, 500000, 1730900000),
        (2, 'عمرة', 5000000, 1000000, 1730900100);
      ''');

      // Insert savings
      raw.execute('''
        INSERT INTO goal_savings (id, goal_id, amount, saved_at) VALUES
        (1, 1, 1000000, 1730900200),
        (2, 2, 500000, 1730900300);
      ''');

      raw.close();

      // 2. Open with AppDatabase (v6) - triggers onUpgrade from 5 to 6
      final v6Db = AppDatabase(NativeDatabase(dbFile));

      // Verify schemaVersion is 6
      expect(v6Db.schemaVersion, equals(6));

      // Verify goals: both preserved, icon is nullable/null for old rows
      final goals = await v6Db.select(v6Db.goals).get();
      expect(goals.length, equals(2));
      expect(goals[0].name, equals('ماك برو'));
      expect(goals[0].targetAmount, equals(10000000));
      expect(goals[0].icon, isNull);
      expect(goals[1].name, equals('عمرة'));
      expect(goals[1].targetAmount, equals(5000000));
      expect(goals[1].icon, isNull);

      // Verify savings preserved
      final savings = await v6Db.select(v6Db.goalSavings).get();
      expect(savings.length, equals(2));
      expect(savings[0].amount, equals(1000000));
      expect(savings[1].amount, equals(500000));

      // Verify PRAGMA table_info confirms icon column exists
      final cols = await v6Db.customSelect("PRAGMA table_info('goals');").get();
      final colNames = cols.map((r) => r.read<String>('name')).toSet();
      expect(colNames.contains('icon'), isTrue);

      await v6Db.close();

      // 3. Idempotency test: Re-open v6 database
      final v6DbAgain = AppDatabase(NativeDatabase(dbFile));
      final goalsAgain = await v6DbAgain.select(v6DbAgain.goals).get();
      expect(goalsAgain.length, equals(2));
      await v6DbAgain.close();

      await tempDir.delete(recursive: true);
    });
  });
}

