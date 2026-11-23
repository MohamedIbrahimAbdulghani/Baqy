// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:baqy/core/database/app_database.dart';

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('baqy_migration_v7_test_');
    dbFile = File('${tempDir.path}/migration_v7.db');
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('Migration v6 to v7 keeps all existing debt and payment data and adds nullable transaction_id', () async {
    // 1. Create a schema v6 database using raw SQLite
    final raw = raw_sqlite.sqlite3.open(dbFile.path);
    raw.execute('PRAGMA user_version = 6;');

    raw.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
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
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL,
        category_id INTEGER NOT NULL REFERENCES categories(id),
        kind TEXT NOT NULL,
        source TEXT NOT NULL,
        note TEXT,
        foreign_amount REAL,
        foreign_currency TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    raw.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        person_name TEXT NOT NULL,
        direction TEXT NOT NULL,
        total_amount INTEGER NOT NULL,
        due_date INTEGER,
        reminder_enabled INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    // V6 debt_payments without transaction_id
    raw.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL REFERENCES debts(id),
        amount INTEGER NOT NULL,
        paid_at INTEGER NOT NULL
      );
    ''');

    // Insert legacy data
    raw.execute('''
      INSERT INTO categories (id, name, icon, color, is_default) VALUES
      (1, 'أكل', 'food', '#4E8B7A', 1),
      (2, 'ديون وأقساط', 'debts', '#C0644B', 1);
    ''');

    raw.execute('''
      INSERT INTO debts (id, person_name, direction, total_amount, due_date, reminder_enabled, archived, created_at) VALUES
      (1, 'أحمد', 'owe', 1000000, 1732953600, 1, 0, 1730419200),
      (2, 'سارة', 'owed', 500000, NULL, 0, 1, 1730419200);
    ''');

    raw.execute('''
      INSERT INTO debt_payments (id, debt_id, amount, paid_at) VALUES
      (1, 1, 300000, 1730505600),
      (2, 2, 500000, 1730505600);
    ''');

    raw.close();

    // 2. Open with AppDatabase (v7) -> triggers onUpgrade from 6 to 7
    final v7Db = AppDatabase(NativeDatabase(dbFile));

    // Verify debts are preserved exactly
    final debtsList = await v7Db.select(v7Db.debts).get();
    expect(debtsList.length, equals(2));

    final debt1 = debtsList.firstWhere((d) => d.id == 1);
    expect(debt1.personName, equals('أحمد'));
    expect(debt1.direction, equals('owe'));
    expect(debt1.totalAmount, equals(1000000));
    expect(debt1.archived, isFalse);
    expect(debt1.leadDays, equals(2));
    expect(debt1.updatedAt, isNotNull);

    final debt2 = debtsList.firstWhere((d) => d.id == 2);
    expect(debt2.personName, equals('سارة'));
    expect(debt2.direction, equals('owed'));
    expect(debt2.totalAmount, equals(500000));
    expect(debt2.archived, isTrue);
    expect(debt2.leadDays, equals(2));

    // Verify payments are preserved and transaction_id is null
    final paymentsList = await v7Db.select(v7Db.debtPayments).get();
    expect(paymentsList.length, equals(2));

    final p1 = paymentsList.firstWhere((p) => p.id == 1);
    expect(p1.debtId, equals(1));
    expect(p1.amount, equals(300000));
    expect(p1.transactionId, isNull);

    final p2 = paymentsList.firstWhere((p) => p.id == 2);
    expect(p2.debtId, equals(2));
    expect(p2.amount, equals(500000));
    expect(p2.transactionId, isNull);

    // Verify we can insert new payment with a transaction_id
    final txId = await v7Db.into(v7Db.transactions).insert(
          TransactionsCompanion.insert(
            amount: 200000,
            description: 'أحمد',
            categoryId: 1,
            kind: 'expense',
            source: 'debt',
            createdAt: DateTime.now().toUtc(),
          ),
        );

    final newPaymentId = await v7Db.into(v7Db.debtPayments).insert(
          DebtPaymentsCompanion.insert(
            debtId: 1,
            amount: 200000,
            paidAt: DateTime.now().toUtc(),
            transactionId: Value(txId),
          ),
        );

    final newPayment = await (v7Db.select(v7Db.debtPayments)..where((p) => p.id.equals(newPaymentId))).getSingle();
    expect(newPayment.transactionId, equals(txId));

    await v7Db.close();
  });
}
