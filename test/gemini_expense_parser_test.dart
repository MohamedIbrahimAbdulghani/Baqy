import 'dart:convert';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/utils/category_matcher.dart';
import 'package:baqy/core/utils/number_formatter.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/domain/models/parsed_expense.dart';
import 'package:baqy/features/expenses/domain/models/transaction_item.dart';
import 'package:baqy/features/expenses/domain/parser/egyptian_expense_parser.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/widgets/transaction_actions_sheet.dart';
import 'package:baqy/features/expenses/presentation/widgets/voice_expense_review_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response utf8Response(String body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('15 Required Sentences: Dynamic Categories, Currencies & Rules', () {
    // 1. Long 7-operations sentence
    test('1. Complex long Egyptian sentence with 7 expenses and ignored narrative', () async {
      const input =
          'خرجت النهارده ركبت المواصلات ب70 جنيه رحت المحكمة خلصت وانا مروح ركبت توك توك ب30 جنيه وجبت فطار ب100 جنيه ونمت صحيت نزلت اشتريت لبس ب3000 جنيه واخدت فرابيه وايت موكا ب70 جنيه وبعد كده رحت لصحابي شربت قهوة معاهم ب70 جنيه وجبت اكل ومروح ب300 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 70,
                      'description': 'مواصلات',
                      'category_name': 'مواصلات',
                      'is_new_category': false,
                      'source_text': 'ركبت المواصلات ب70 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 30,
                      'description': 'توك توك',
                      'category_name': 'مواصلات',
                      'is_new_category': false,
                      'source_text': 'ركبت توك توك ب30 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 100,
                      'description': 'فطار',
                      'category_name': 'أكل',
                      'is_new_category': false,
                      'source_text': 'وجبت فطار ب100 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 3000,
                      'description': 'لبس',
                      'category_name': 'ملابس',
                      'is_new_category': false,
                      'source_text': 'اشتريت لبس ب3000 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 70,
                      'description': 'فرابيه وايت موكا',
                      'category_name': 'مشروبات',
                      'is_new_category': false,
                      'source_text': 'واخدت فرابيه وايت موكا ب70 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 70,
                      'description': 'قهوة مع الأصحاب',
                      'category_name': 'مشروبات',
                      'is_new_category': false,
                      'source_text': 'شربت قهوة معاهم ب70 جنيه',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 300,
                      'description': 'أكل',
                      'category_name': 'أكل',
                      'is_new_category': false,
                      'source_text': 'وجبت اكل ومروح ب300 جنيه',
                      'confidence': 0.98
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.length, equals(7));
      expect(result[0].amount, equals(70));
      expect(result[0].category, equals('مواصلات'));
      expect(result[3].amount, equals(3000));
      expect(result[3].category, equals('ملابس'));
      expect(result[4].category, equals('مشروبات وكافيهات'));
    });

    // 2. برفيوم ← عناية شخصية
    test('2. برفيوم ← عناية شخصية', () async {
      const input = 'اشتريت برفيوم ب 1200 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 1200,
                      'description': 'برفيوم',
                      'category_name': 'عناية شخصية',
                      'is_new_category': false,
                      'source_text': 'اشتريت برفيوم ب 1200 جنيه',
                      'confidence': 0.97
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(1200));
      expect(result.first.category, equals('عناية شخصية'));

      // Also verify local fallback
      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.first.amount, equals(1200));
      expect(fallback.first.category, equals('عناية شخصية'));
    });

    // 3. فرابيه ← مشروبات
    test('3. فرابيه ← مشروبات', () async {
      const input = 'شربت فرابيه كراميل ب 85 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 85,
                      'description': 'فرابيه كراميل',
                      'category_name': 'مشروبات',
                      'is_new_category': false,
                      'source_text': 'شربت فرابيه كراميل ب 85 جنيه',
                      'confidence': 0.96
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(85));
      expect(result.first.category, equals('مشروبات وكافيهات'));

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.first.amount, equals(85));
      expect(fallback.first.category, equals('مشروبات وكافيهات'));
    });

    // 4. شاحن ← إلكترونيات
    test('4. شاحن ← إلكترونيات', () async {
      const input = 'اشتريت شاحن سريع ب 250 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 250,
                      'description': 'شاحن سريع',
                      'category_name': 'إلكترونيات',
                      'is_new_category': false,
                      'source_text': 'اشتريت شاحن سريع ب 250 جنيه',
                      'confidence': 0.96
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(250));
      expect(result.first.category, equals('إلكترونيات'));

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.first.amount, equals(250));
      expect(fallback.first.category, equals('إلكترونيات'));
    });

    // 5. قسط ← ديون وأقساط
    test('5. قسط ← ديون وأقساط', () async {
      const input = 'دفعت قسط الشقة 3500 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 3500,
                      'description': 'قسط الشقة',
                      'category_name': 'ديون وأقساط',
                      'is_new_category': false,
                      'source_text': 'دفعت قسط الشقة 3500 جنيه',
                      'confidence': 0.98
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(3500));
      expect(result.first.category, equals('ديون وأقساط'));

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.first.amount, equals(3500));
      expect(fallback.first.category, equals('ديون وأقساط'));
    });

    // 6. ذهب وملوش تصنيف ← يتنشئ تصنيف جديد
    test('6. ذهب وملوش تصنيف ← يتنشئ تصنيف جديد', () async {
      const input = 'اشتريت سبيكة ذهب ب 15000 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 15000,
                      'description': 'سبيكة ذهب',
                      'category_name': 'ذهب ومجوهرات',
                      'is_new_category': true,
                      'new_category': {
                        'name': 'ذهب ومجوهرات',
                        'icon': 'trending_up',
                        'color': '#4E8B7A'
                      },
                      'source_text': 'اشتريت سبيكة ذهب ب 15000 جنيه',
                      'confidence': 0.95
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input, categories: ['أكل', 'مواصلات']);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(15000));
      expect(result.first.isNewCategory, isTrue);
      expect(result.first.newCategoryProposal?.name, equals('ذهب ومجوهرات'));
    });

    // 7. تصنيف موجود يستخدم مباشرة دون تكرار
    test('7. تصنيف تم إنشاؤه يستخدم بعدها دون تكرار', () async {
      const input = 'اشتريت اسهم ب 4000 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 4000,
                      'description': 'اسهم',
                      'category_name': 'استثمار وادخار',
                      'is_new_category': false,
                      'source_text': 'اشتريت اسهم ب 4000 جنيه',
                      'confidence': 0.97
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input, categories: ['استثمار وادخار']);

      expect(result, isNotNull);
      expect(result!.first.amount, equals(4000));
      expect(result.first.isNewCategory, isFalse);
      expect(result.first.category, equals('استثمار وادخار'));
    });

    // 8. جملة بمبلغ واحد
    test('8. جملة بمبلغ واحد', () async {
      const input = 'صرفت 150 جنيه في السوبرماركت';

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(150));
    });

    // 9. كلمة تبدأ بـ و أصلية (ورق)
    test('9. كلمة تبدأ بـ و أصلية: "اشتريت ورق طباعة بمية وخمسين جنيه"', () async {
      const input = 'اشتريت ورق طباعة بمية وخمسين جنيه';

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(150));
      expect(fallback.first.description, contains('ورق'));
    });

    // 10. وقود للعربية
    test('10. وقود للعربية: "حطيت وقود للعربية بربعمية جنيه"', () async {
      const input = 'حطيت وقود للعربية بربعمية جنيه';

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(400));
    });

    // 11. أرقام بالكلمات
    test('11. أرقام بالكلمات: "طلبت وجبة كفتة بخمسة وستين جنيه"', () async {
      const input = 'طلبت وجبة كفتة بخمسة وستين جنيه';

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(65));
      expect(fallback.first.category, equals('أكل'));
    });

    // 12. عملة أجنبية بمعادلة: "اشتريت $150 ب 8400 جنيه" ← عملية واحدة 8400
    test('12. "اشتريت \$150 ب 8400 جنيه" ← عملية واحدة 8400', () async {
      const input = 'اشتريت \$150 ب 8400 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 8400,
                      'description': 'دولار',
                      'category_name': 'استثمار وادخار',
                      'is_new_category': false,
                      'foreign_amount': 150,
                      'foreign_currency': 'USD',
                      'source_text': 'اشتريت \$150 ب 8400 جنيه',
                      'confidence': 0.98
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first.amount, equals(8400));
      expect(result.first.foreignAmount, equals(150.0));
      expect(result.first.foreignCurrency, equals('USD'));

      // Also test fallback equivalence
      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(8400));
      expect(fallback.first.foreignAmount, equals(150.0));
      expect(fallback.first.foreignCurrency, equals('USD'));
    });

    // 13. عملة أجنبية بمعادلة: "اشتريت سماعة ب 50 دولار يعني 2500 جنيه" ← واحدة 2500
    test('13. "اشتريت سماعة ب 50 دولار يعني 2500 جنيه" ← واحدة 2500', () async {
      const input = 'اشتريت سماعة ب 50 دولار يعني 2500 جنيه';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 2500,
                      'description': 'سماعة',
                      'category_name': 'إلكترونيات',
                      'is_new_category': false,
                      'foreign_amount': 50,
                      'foreign_currency': 'USD',
                      'source_text': 'اشتريت سماعة ب 50 دولار يعني 2500 جنيه',
                      'confidence': 0.98
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first.amount, equals(2500));
      expect(result.first.foreignAmount, equals(50.0));
      expect(result.first.foreignCurrency, equals('USD'));
      expect(result.first.category, equals('إلكترونيات'));

      // Also fallback
      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, equals(2500));
      expect(fallback.first.foreignAmount, equals(50.0));
      expect(fallback.first.foreignCurrency, equals('USD'));
    });

    // 14. "دفعت 50 يورو" ← بدون مبلغ جنيه، محتاج مراجعة
    test('14. "دفعت 50 يورو" ← بدون مبلغ جنيه، محتاج مراجعة', () async {
      const input = 'دفعت 50 يورو';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': null,
                      'description': 'يورو',
                      'category_name': 'أخرى',
                      'is_new_category': false,
                      'foreign_amount': 50,
                      'foreign_currency': 'EUR',
                      'source_text': 'دفعت 50 يورو',
                      'confidence': 0.4
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first.amount, isNull);
      expect(result.first.foreignAmount, equals(50.0));
      expect(result.first.foreignCurrency, equals('EUR'));
      expect(result.first.needsReview, isTrue);

      // Local fallback
      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(1));
      expect(fallback.first.amount, isNull);
      expect(fallback.first.foreignAmount, equals(50.0));
      expect(fallback.first.foreignCurrency, equals('EUR'));
      expect(fallback.first.needsReview, isTrue);
    });

    // 15. "اشتريت تيشيرت ب 400 وبنطلون ب 600" ← اتنين
    test('15. "اشتريت تيشيرت ب 400 وبنطلون ب 600" ← اتنين', () async {
      const input = 'اشتريت تيشيرت ب 400 وبنطلون ب 600';

      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 400,
                      'description': 'تيشيرت',
                      'category_name': 'ملابس',
                      'is_new_category': false,
                      'source_text': 'اشتريت تيشيرت ب 400',
                      'confidence': 0.98
                    },
                    {
                      'amount_egp': 600,
                      'description': 'بنطلون',
                      'category_name': 'ملابس',
                      'is_new_category': false,
                      'source_text': 'وبنطلون ب 600',
                      'confidence': 0.98
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);

      expect(result, isNotNull);
      expect(result!.length, equals(2));
      expect(result[0].amount, equals(400));
      expect(result[0].category, equals('ملابس'));
      expect(result[1].amount, equals(600));
      expect(result[1].category, equals('ملابس'));

      final fallback = EgyptianExpenseParser.parse(input);
      expect(fallback.length, equals(2));
      expect(fallback[0].amount, equals(400));
      expect(fallback[1].amount, equals(600));
    });
  });

  group('Database CRUD & Financial Invariant Tests', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Budget and remaining: Deleting an expense restores remaining balance', () async {
      const yearMonth = '2026-11';
      await repo.setMonthBudget(yearMonth: yearMonth, amount: 1000000); // 10,000 EGP

      final categories = await repo.getCategories();
      final cat = categories.first;

      final txId = await repo.addTransaction(
        amount: 200000, // 2,000 EGP
        description: 'شراء ملابس',
        categoryId: cat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5),
      );

      var remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(800000)); // 8,000 EGP

      // Delete transaction
      await repo.deleteTransaction(txId);

      remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(1000000)); // Restored back to 10,000 EGP!
    });

    test('Updating amount 2000 -> 200 restores the difference', () async {
      const yearMonth = '2026-11';
      await repo.setMonthBudget(yearMonth: yearMonth, amount: 500000); // 5,000 EGP

      final categories = await repo.getCategories();
      final cat = categories.first;

      final txId = await repo.addTransaction(
        amount: 200000, // 2,000 EGP
        description: 'فاتورة',
        categoryId: cat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5),
      );

      var remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(300000)); // 3,000 EGP

      // Update 2000 -> 200
      await repo.updateTransaction(
        id: txId,
        amount: 20000, // 200 EGP
        description: 'فاتورة معدلة',
        categoryId: cat.id,
      );

      remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(480000)); // 4,800 EGP (1,800 returned!)
    });

    test('Undo (restoreTransaction) restores deleted transaction and balance', () async {
      const yearMonth = '2026-11';
      await repo.setMonthBudget(yearMonth: yearMonth, amount: 500000);

      final categories = await repo.getCategories();
      final cat = categories.first;

      final txId = await repo.addTransaction(
        amount: 150000, // 1,500 EGP
        description: 'غدا',
        categoryId: cat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5),
      );

      final txList = await repo.getLast3Transactions();
      final tx = txList.firstWhere((t) => t.id == txId);

      // Delete
      await repo.deleteTransaction(txId);
      var remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(500000));

      // Restore
      await repo.restoreTransaction(tx);
      remaining = await repo.getRemainingOfMonth(yearMonth);
      expect(remaining.remaining, equals(350000)); // Re-applied!
    });

    test('Changing category moves transaction totals immediately in category breakdown', () async {
      const yearMonth = '2026-11';
      final categories = await repo.getCategories();
      final foodCat = categories.firstWhere((c) => c.name == 'أكل');
      final clothesCat = categories.firstWhere((c) => c.name == 'ملابس');

      final txId = await repo.addTransaction(
        amount: 50000, // 500 EGP
        description: 'شراء',
        categoryId: foodCat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5),
      );

      var totals = await repo.getTotalsPerCategoryPerMonth(yearMonth);
      var foodTotal = totals.firstWhere((t) => t.category.id == foodCat.id);
      expect(foodTotal.totalAmount, equals(50000));

      // Move from Food to Clothes
      await repo.updateTransaction(
        id: txId,
        amount: 50000,
        description: 'شراء ملابس',
        categoryId: clothesCat.id,
      );

      totals = await repo.getTotalsPerCategoryPerMonth(yearMonth);
      final clothesTotal = totals.firstWhere((t) => t.category.id == clothesCat.id);
      expect(clothesTotal.totalAmount, equals(50000));
      expect(totals.any((t) => t.category.id == foodCat.id), isFalse);
    });

    test('Duplicate category name is prevented', () async {
      final categories = await repo.getCategories();
      final existingName = categories.first.name;

      expect(
        () => repo.addCategory(
          name: existingName,
          icon: 'other',
          color: '#4E8B7A',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Foreign currency amounts do NOT enter any EGP totals', () async {
      const yearMonth = '2026-11';
      await repo.setMonthBudget(yearMonth: yearMonth, amount: 1000000);

      final categories = await repo.getCategories();
      final cat = categories.first;

      await repo.addTransaction(
        amount: 840000, // 8,400 EGP
        description: 'شراء دولار',
        categoryId: cat.id,
        kind: 'expense',
        source: 'voice',
        createdAt: DateTime.utc(2026, 11, 5),
        foreignAmount: 150.0,
        foreignCurrency: 'USD',
      );

      final remaining = await repo.getRemainingOfMonth(yearMonth);
      // Expenses must be strictly 8400 EGP (840000 piastres), 150 USD is untouched
      expect(remaining.expenses, equals(840000));
      expect(remaining.remaining, equals(160000));
    });
  });

  group('VoiceExpenseReviewSheet Widget Tests', () {
    testWidgets('VoiceExpenseReviewSheet displays items, live total, and saves', (tester) async {
      final initialExpenses = [
        const ParsedExpense(
          amount: 70,
          description: 'مواصلات',
          category: 'مواصلات',
        ),
        const ParsedExpense(
          amount: 100,
          description: 'فطار',
          category: 'أكل',
        ),
      ];

      final categories = [
        const CategoryItem(id: 1, name: 'أكل', icon: 'food', color: '#4E8B7A'),
        const CategoryItem(id: 2, name: 'مواصلات', icon: 'transport', color: '#E8A83A'),
      ];

      List<ParsedExpense>? saved;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VoiceExpenseReviewSheet(
                initialExpenses: initialExpenses,
                categories: categories,
                onSave: (list) async {
                  saved = list;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('مراجعة وتأكيد المصاريف'), findsOneWidget);
      expect(find.text('مواصلات'), findsWidgets);
      expect(find.text('فطار'), findsWidgets);

      // Verify Live Total is 170 جنيه (in Arabic digits)
      expect(find.textContaining(170.toArabicDigits()), findsOneWidget);

      // Tap save
      final saveBtn = find.text('حفظ الكل');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.length, equals(2));
      expect(saved![0].amount, equals(70));
      expect(saved![1].amount, equals(100));
    });
  });

  group('Issue 3: Quantities, Gold Pounds, Weights & Specification Parsing', () {
    test('1. "اشتريت ربع جنيه دهب ب 13000" gives single 13000 item, description="ربع جنيه دهب", category="استثمار وادخار"', () async {
      const input = 'اشتريت ربع جنيه دهب ب 13000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(13000));
      expect(res[0].description, equals('ربع جنيه دهب'));
      expect(res[0].category, equals('استثمار وادخار'));
      expect(res[0].quantityText, equals('ربع جنيه'));
    });

    test('2. "اشتريت جنيه دهب ب 50000" gives single 50000 item, description="جنيه دهب", category="استثمار وادخار"', () async {
      const input = 'اشتريت جنيه دهب ب 50000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(50000));
      expect(res[0].description, equals('جنيه دهب'));
      expect(res[0].category, equals('استثمار وادخار'));
    });

    test('3. "اشتريت سبيكة دهب 2 جرام ب 13000" gives single 13000 item, description="سبيكة دهب 2 جرام", quantity="2 جرام"', () async {
      const input = 'اشتريت سبيكة دهب 2 جرام ب 13000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(13000));
      expect(res[0].description, equals('سبيكة دهب 2 جرام'));
      expect(res[0].category, equals('استثمار وادخار'));
      expect(res[0].quantityText, equals('2 جرام'));
    });

    test('4. "اشتريت 3 كيلو فراخ ب 300" gives single 300 item, description="3 كيلو فراخ", quantity="3 كيلو"', () async {
      const input = 'اشتريت 3 كيلو فراخ ب 300';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(300));
      expect(res[0].description, equals('3 كيلو فراخ'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].quantityText, equals('3 كيلو'));
    });

    test('5. "اشتريت تيشيرت ب 400 وبنطلون ب 600" gives 2 items (400 and 600)', () async {
      const input = 'اشتريت تيشيرت ب 400 وبنطلون ب 600';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(2));
      expect(res[0].amount, equals(400));
      expect(res[0].description, equals('تيشيرت'));
      expect(res[1].amount, equals(600));
      expect(res[1].description, equals('بنطلون'));
    });

    test('6. "اشتريت لبس ب 3000" gives single 3000 item', () async {
      const input = 'اشتريت لبس ب 3000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(3000));
      expect(res[0].description, equals('لبس'));
    });

    test('7. "اشتريت سبيكة دهب 5 جرام ب 32000" gives single 32000 item, quantity="5 جرام"', () async {
      const input = 'اشتريت سبيكة دهب 5 جرام ب 32000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(32000));
      expect(res[0].description, equals('سبيكة دهب 5 جرام'));
      expect(res[0].category, equals('استثمار وادخار'));
      expect(res[0].quantityText, equals('5 جرام'));
    });

    test('8. "اشتريت 2 كيلو لحمة ب 800" gives single 800 item, quantity="2 كيلو"', () async {
      const input = 'اشتريت 2 كيلو لحمة ب 800';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(800));
      expect(res[0].description, equals('2 كيلو لحمة'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].quantityText, equals('2 كيلو'));
    });

    test('9. "فلاشة 128 جيجا ب 350" gives single 350 item, quantity="128 جيجا"', () async {
      const input = 'فلاشة 128 جيجا ب 350';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(350));
      expect(res[0].description, equals('فلاشة 128 جيجا'));
      expect(res[0].quantityText, equals('128 جيجا'));
    });

    test('10. "اشتريت 100 دولار ب 5000 جنيه" gives single item 5000 EGP, foreign 100 USD', () async {
      const input = 'اشتريت 100 دولار ب 5000 جنيه';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, equals(5000));
      expect(res[0].foreignAmount, equals(100.0));
      expect(res[0].foreignCurrency, equals('USD'));
    });

    test('11. "اشتريت 2 جرام دهب" (no price) gives amount=null and needsReview=true', () async {
      const input = 'اشتريت 2 جرام دهب';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res[0].amount, isNull);
      expect(res[0].needsReview, isTrue);
      expect(res[0].category, equals('استثمار وادخار'));
      expect(res[0].quantityText, equals('2 جرام'));
    });

    test('12. Gemini postProcessItems merges suspicious quantity item into price item', () {
      final items = [
        const ParsedExpense(
          amount: 2,
          description: '2 جرام دهب',
          category: 'أخرى',
          sourceText: 'اشتريت 2 جرام دهب',
        ),
        const ParsedExpense(
          amount: 13000,
          description: 'دهب',
          category: 'استثمار وادخار',
          sourceText: 'ب 13000',
        ),
      ];
      final merged = GeminiExpenseParser.postProcessItems(
        items,
        'اشتريت 2 جرام دهب ب 13000',
      );
      expect(merged.length, equals(1));
      expect(merged.first.amount, equals(13000));
      expect(merged.first.description, contains('2 جرام دهب'));
      expect(merged.first.category, equals('استثمار وادخار'));
    });
  });

  group('Issue 1: SnackBar Deletion & Undo Invariant', () {
    testWidgets('Delete SnackBar has duration=5s, persist=false, and hides on undo', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = ExpenseRepositoryImpl(db);

      final categories = await repo.getCategories();
      final cat = categories.first;

      final txId = await repo.addTransaction(
        amount: 500000,
        description: 'وجبة غدا',
        categoryId: cat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.now(),
      );

      final item = TransactionItem(
        id: txId,
        amount: 500000,
        description: 'وجبة غدا',
        categoryId: cat.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () {
                      TransactionActionsHelper.confirmAndDelete(
                        context: context,
                        ref: ref,
                        transaction: item,
                      );
                    },
                    child: const Text('افتح الحذف'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('افتح الحذف'));
      await tester.pumpAndSettle();

      // Dialog is shown, confirm delete
      expect(find.text('حذف العملية'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'حذف'));
      await tester.pumpAndSettle();

      // Verify transaction deleted from db
      final afterDelete = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
      expect(afterDelete, isNull);

      // Verify SnackBar attributes
      final snackBarFinder = find.byType(SnackBar);
      expect(snackBarFinder, findsOneWidget);
      final snackBarWidget = tester.widget<SnackBar>(snackBarFinder);
      expect(snackBarWidget.duration, equals(const Duration(seconds: 5)));
      expect(snackBarWidget.persist, isFalse);

      // Verify Undo button tap closes SnackBar and restores transaction
      await tester.tap(find.text('تراجع'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final restored = await (db.select(db.transactions)..where((t) => t.id.equals(txId))).getSingleOrNull();
      expect(restored, isNotNull);
      expect(restored!.description, equals('وجبة غدا'));
    });
  });

  group('Permanent Regression & Verification: 6 Required Invariant Tests', () {
    test('1. "اديت عمتي 2000 جنيه صدقه" → صدقات، 2000', () {
      const input = 'اديت عمتي 2000 جنيه صدقه';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(2000));
      expect(res.first.category, equals('صدقات'));
    });

    test('2. "اتغديت ب 150" → أكل، 150', () {
      const input = 'اتغديت ب 150';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(150));
      expect(res.first.category, equals('أكل'));
    });

    test('3. "شربت فرابيه ب 70" → مشروبات وكافيهات، 70', () {
      const input = 'شربت فرابيه ب 70';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(70));
      expect(res.first.category, equals('مشروبات وكافيهات'));
    });

    test('4. "اشتريت ربع جنيه دهب ب 13000" → استثمار وادخار، 13000، عملية واحدة', () {
      const input = 'اشتريت ربع جنيه دهب ب 13000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(13000));
      expect(res.first.category, equals('استثمار وادخار'));
    });

    test('5. "ركبت توك توك ب 30" → مواصلات، 30', () {
      const input = 'ركبت توك توك ب 30';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(30));
      expect(res.first.category, equals('مواصلات'));
    });

    test('6. "اشتريت تيشيرت ب 400 وبنطلون ب 600" → عمليتين (ملابس 400، ملابس 600)', () {
      const input = 'اشتريت تيشيرت ب 400 وبنطلون ب 600';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(2));
      expect(res[0].amount, equals(400));
      expect(res[0].category, equals('ملابس'));
      expect(res[1].amount, equals(600));
      expect(res[1].category, equals('ملابس'));
    });

    test('CategoryMatcher binds charity variants to "صدقات"', () {
      final defaultCats = GeminiExpenseParser.defaultCategoryNames;
      for (final variant in ['صدقة', 'صدقه', 'صدقات', 'زكاة', 'زكاه', 'تبرع', 'كفالة']) {
        final matched = CategoryMatcher.matchName(
          categoryName: variant,
          availableNames: defaultCats,
        );
        expect(matched, equals('صدقات'));
      }
    });

    test('GeminiExpenseParser parses "اديت عمتي 2000 جنيه صدقه" without falling to أخرى', () async {
      const input = 'اديت عمتي 2000 جنيه صدقه';
      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 2000,
                      'description': 'صدقة',
                      'category_name': 'صدقة',
                      'is_new_category': false,
                      'source_text': 'اديت عمتي 2000 جنيه صدقه',
                      'confidence': 0.98,
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);
      expect(result, isNotNull);
      expect(result!.length, equals(1));
      expect(result.first.amount, equals(2000));
      expect(result.first.category, equals('صدقات'));
    });
  });

  group('11 Mandatory Test Cases & Continuous Recording Persistence', () {
    test('1. "اديت عمتي 2000 جنيه صدقة" → صدقات، 2000', () {
      const input = 'اديت عمتي 2000 جنيه صدقة';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(2000));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('صدقات'));
    });

    test('2. "طلعت 200 جنيه لله" → صدقات، 200', () {
      const input = 'طلعت 200 جنيه لله';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(200));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('صدقات'));
    });

    test('3. "اشتريت دولار ب 5000" → استثمار وادخار، 5000', () {
      const input = 'اشتريت دولار ب 5000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(5000));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('استثمار وادخار'));
    });

    test('4. "اشتريت ذهب ب 13000" → استثمار وادخار، 13000', () {
      const input = 'اشتريت ذهب ب 13000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(13000));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('استثمار وادخار'));
    });

    test('5. "شربت عصير ب 40" → مشروبات وكافيهات، 40', () {
      const input = 'شربت عصير ب 40';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(40));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('مشروبات وكافيهات'));
    });

    test('6. "جبت أكل ب 120" → أكل، 120', () {
      const input = 'جبت أكل ب 120';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(120));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('أكل'));
    });

    test('7. "نزلت سوبر ماركت جبت شيبسي وجبنة وساقعة ب 450" → سوبر ماركت، 450، عملية واحدة', () {
      const input = 'نزلت سوبر ماركت جبت شيبسي وجبنة وساقعة ب 450';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(450));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('سوبر ماركت'));
    });

    test('8. "اشتريت برفيوم وبادز ب 800" → عناية شخصية، 800', () {
      const input = 'اشتريت برفيوم وبادز ب 800';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(800));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('عناية شخصية'));
    });

    test('9. "دفعت باقة نت ب 250" → فواتير واتصالات، 250', () {
      const input = 'دفعت باقة نت ب 250';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(250));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('فواتير واتصالات'));
    });

    test('10. "اشتريت لبس ب 3000" → ملابس، 3000', () {
      const input = 'اشتريت لبس ب 3000';
      final res = EgyptianExpenseParser.parse(input);
      expect(res.length, equals(1));
      expect(res.first.amount, equals(3000));
      expect(CategoryMatcher.matchName(categoryName: res.first.category, availableNames: GeminiExpenseParser.defaultCategoryNames), equals('ملابس'));
    });

    test('11. Dynamic new category proposed by Gemini when no existing category matches', () async {
      const input = 'اشتريت اشتراك نادي ب 600';
      final mockResponse = jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode([
                    {
                      'amount_egp': 600,
                      'description': 'اشتراك نادي',
                      'category_name': 'نوادي ورياضة',
                      'is_new_category': true,
                      'new_category': {
                        'name': 'نوادي ورياضة',
                        'icon': 'fitness_center',
                        'color': '#2ECC71'
                      },
                      'source_text': 'اشتريت اشتراك نادي ب 600',
                      'confidence': 0.95
                    }
                  ])
                }
              ]
            }
          }
        ]
      });

      final parser = GeminiExpenseParser(
        client: MockClient((req) async => utf8Response(mockResponse)),
        apiKey: 'test_key',
      );
      final result = await parser.parse(input);
      expect(result, isNotNull);
      expect(result!.first.amount, equals(600));
      expect(result.first.isNewCategory, isTrue);
      expect(result.first.newCategoryProposal?.name, equals('نوادي ورياضة'));
      expect(result.first.newCategoryProposal?.icon, equals('fitness_center'));
    });

    test('12. Voice Session Accumulator: does not lose text across 20s simulated silence pause and session restarts', () {
      // Chunk 1 before pause
      const chunk1 = 'ركبت تاكسي ب 50 جنيه';
      // Silence pause occurs, speech session triggers done/timeout, partial committed
      final sessions = <String>[chunk1];
      
      // Chunk 2 after 20s pause with slight recognizer overlap "ب 50 جنيه وجبت فطار ب 40"
      const chunk2 = 'ب 50 جنيه وجبت فطار ب 40';
      sessions.add(chunk2);

      // Final speech segment
      const chunk3 = 'وشربت قهوة ب 30';
      sessions.add(chunk3);

      final merged = VoiceRecordingNotifier.mergeVoiceSessions(sessions);
      expect(merged, equals('ركبت تاكسي ب 50 جنيه وجبت فطار ب 40 وشربت قهوة ب 30'));
    });
  });
}
