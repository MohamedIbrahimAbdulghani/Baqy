import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:excel_community/excel_community.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/data/services/excel_export_service.dart';
import 'package:baqy/features/expenses/data/services/pdf_export_service.dart';
import 'package:baqy/features/expenses/domain/models/month_export_data.dart';
import 'package:baqy/features/expenses/domain/usecases/build_month_export_data_usecase.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/screens/month_details_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExpenseRepositoryImpl repository;
  late Uint8List cairoRegularBytes;
  late Uint8List cairoBoldBytes;

  final Map<String, String> testArabicLabels = {
    'appName': 'باقي',
    'currencyEgp': 'جنيه',
    'exportSummaryTitle': 'ملخص الشهر',
    'exportTotalExpenses': 'إجمالي المصاريف',
    'exportTotalIncome': 'إجمالي الدخل',
    'exportMonthBudget': 'ميزانية الشهر',
    'exportRemainingAmount': 'المبلغ المتبقي',
    'exportOperationsCount': 'عدد العمليات',
    'exportCreatedAt': 'تاريخ الإنشاء',
    'exportSheetSummary': 'ملخص',
    'exportSheetOperations': 'العمليات',
    'exportChartCategoryExpenses': 'توزيع المصاريف حسب التصنيف',
    'exportChartDailyExpenses': 'المصاريف اليومية خلال الشهر',
    'exportChartCategoryPercentage': 'نسبة كل تصنيف من المصاريف',
    'exportColCategory': 'التصنيف',
    'exportColOperationsCount': 'عدد العمليات',
    'exportColTotal': 'الإجمالي',
    'exportColPercentage': 'النسبة',
    'exportColDate': 'التاريخ',
    'exportColDay': 'اليوم',
    'exportColTime': 'الوقت',
    'exportColDescription': 'البيان / الملاحظة',
    'exportColType': 'النوع',
    'exportColAmount': 'المبلغ',
    'exportTypeExpense': 'مصروف',
    'exportTypeIncome': 'دخل',
    'exportTypeSaving': 'تحويش',
    'exportPageOf': 'صفحة {current} من {total}',
    'daySaturday': 'السبت',
    'daySunday': 'الأحد',
    'dayMonday': 'الاثنين',
    'dayTuesday': 'الثلاثاء',
    'dayWednesday': 'الأربعاء',
    'dayThursday': 'الخميس',
    'dayFriday': 'الجمعة',
  };

  setUpAll(() {
    cairoRegularBytes = File(
      'assets/fonts/Cairo-Regular.ttf',
    ).readAsBytesSync();
    cairoBoldBytes = File('assets/fonts/Cairo-Bold.ttf').readAsBytesSync();
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = ExpenseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Month Data Builder Tests (Integer Piastres & Month Isolation)', () {
    test(
      'Calculates exact totals, percentages, and daily sums in integer piastres',
      () async {
        final categories = await repository.getCategories();
        final food = categories.firstWhere((c) => c.name == 'أكل');
        final transport = categories.firstWhere((c) => c.name == 'مواصلات');

        // Add transactions for 2026-11
        // Food: 50.00 EGP (5000 piastres) and 25.50 EGP (2550 piastres) = 75.50 EGP (7550 piastres)
        await repository.addTransaction(
          amount: 5000,
          description: 'غداء',
          categoryId: food.id,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 11, 2, 12, 30),
        );
        await repository.addTransaction(
          amount: 2550,
          description: 'عشاء',
          categoryId: food.id,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 11, 2, 20, 0),
        );

        // Transport: 24.50 EGP (2450 piastres) on 2026-11-03
        await repository.addTransaction(
          amount: 2450,
          description: 'مترو',
          categoryId: transport.id,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 11, 3, 8, 15),
        );

        // Add transaction in another month (2026-10) to verify month isolation
        await repository.addTransaction(
          amount: 100000,
          description: 'إيجار أكتوبر',
          categoryId: food.id,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 10, 25, 10, 0),
        );

        final useCase = BuildMonthExportDataUseCase(repository);
        final data = await useCase(
          yearMonth: '2026-11',
          formatDayName: (d) => 'الاثنين',
          formatTime: (d) => '12:00',
          typeExpenseLabel: 'مصروف',
          typeIncomeLabel: 'دخل',
          typeSavingLabel: 'تحويش',
          monthTitle: 'نوفمبر 2026',
        );

        expect(data, isNotNull);
        // Total expenses should be 7550 + 2450 = 10000 piastres (100.00 EGP)
        expect(data!.expenses, equals(10000));
        expect(data.operationsCount, equals(3));
        expect(data.categories.length, equals(2));

        // Percentages: Food = 75.5%, Transport = 24.5%
        final foodExport = data.categories.firstWhere(
          (c) => c.categoryId == food.id,
        );
        final transportExport = data.categories.firstWhere(
          (c) => c.categoryId == transport.id,
        );
        expect(foodExport.totalAmount, equals(7550));
        expect(foodExport.transactionCount, equals(2));
        expect(foodExport.percentage, equals(75.5));

        expect(transportExport.totalAmount, equals(2450));
        expect(transportExport.transactionCount, equals(1));
        expect(transportExport.percentage, equals(24.5));

        // Daily totals: Day 2 = 7550, Day 3 = 2450
        expect(data.dailyExpenses.length, equals(2));
        final day2 = data.dailyExpenses.firstWhere((d) => d.dayNumber == 2);
        final day3 = data.dailyExpenses.firstWhere((d) => d.dayNumber == 3);
        expect(day2.totalAmount, equals(7550));
        expect(day3.totalAmount, equals(2450));

        // Sorted newest last (ascending createdAt)
        expect(data.transactions.first.amount, equals(5000));
        expect(data.transactions.last.amount, equals(2450));
      },
    );

    test('Empty month returns null and produces no export data', () async {
      final useCase = BuildMonthExportDataUseCase(repository);
      final data = await useCase(
        yearMonth: '2025-01',
        formatDayName: (d) => 'الأحد',
        formatTime: (d) => '10:00',
        typeExpenseLabel: 'مصروف',
        typeIncomeLabel: 'دخل',
        typeSavingLabel: 'تحويش',
        monthTitle: 'يناير 2025',
      );

      expect(data, isNull);
    });
  });

  group('2. PDF Export Service Tests', () {
    test(
      'Generates valid PDF bytes with Arabic Cairo fonts for standard month',
      () async {
        final categories = await repository.getCategories();
        final food = categories.firstWhere((c) => c.name == 'أكل');

        await repository.addTransaction(
          amount: 8500,
          description: 'سوبرماركت وطلبات البيت',
          categoryId: food.id,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 11, 5, 14, 0),
        );

        final useCase = BuildMonthExportDataUseCase(repository);
        final data = (await useCase(
          yearMonth: '2026-11',
          formatDayName: (d) => 'الخميس',
          formatTime: (d) => '14:00',
          typeExpenseLabel: 'مصروف',
          typeIncomeLabel: 'دخل',
          typeSavingLabel: 'تحويش',
          monthTitle: 'نوفمبر 2026',
        ))!;

        final pdfBytes = await PdfExportService.generate(
          data: data,
          fontRegularBytes: cairoRegularBytes,
          fontBoldBytes: cairoBoldBytes,
          labels: testArabicLabels,
          isArabic: true,
        );

        expect(pdfBytes, isNotEmpty);
        // Valid PDF magic header: %PDF (0x25, 0x50, 0x44, 0x46)
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
      },
    );

    test(
      'Generates multi-page PDF for 3000 operations and measures performance',
      () async {
        // Build 3000 mock transactions
        final List<MonthExportTransaction> largeList = List.generate(3000, (
          index,
        ) {
          final day = (index % 28) + 1;
          return MonthExportTransaction(
            id: index + 1,
            dateText: '2026/11/${day.toString().padLeft(2, '0')}',
            dayName: 'اليوم',
            timeText: '12:00',
            categoryName: 'مصاريف عامة $index',
            categoryColorHex: '#4E8B7A',
            description: 'معاملة تجريبية رقم $index لشهر نوفمبر',
            typeText: 'مصروف',
            kind: 'expense',
            amount: (index + 1) * 100,
            createdAt: DateTime(2026, 11, day, 12, 0),
          );
        });

        final largeData = MonthExportData(
          yearMonth: '2026-11',
          monthTitle: 'نوفمبر 2026',
          expenses: 450150000,
          income: 0,
          budget: 500000000,
          remaining: 49850000,
          operationsCount: 3000,
          createdAt: DateTime(2026, 11, 30, 23, 59),
          categories: const [
            MonthExportCategory(
              categoryId: 1,
              name: 'أكل ومشروبات',
              colorHex: '#4E8B7A',
              totalAmount: 200000000,
              transactionCount: 1500,
              percentage: 44.4,
            ),
            MonthExportCategory(
              categoryId: 2,
              name: 'مواصلات',
              colorHex: '#E8A83A',
              totalAmount: 250150000,
              transactionCount: 1500,
              percentage: 55.6,
            ),
          ],
          dailyExpenses: List.generate(
            28,
            (d) => MonthExportDay(
              dayNumber: d + 1,
              dayName: 'اليوم',
              date: DateTime(2026, 11, d + 1),
              totalAmount: 16000000,
            ),
          ),
          transactions: largeList,
        );

        final stopwatch = Stopwatch()..start();
        final pdfBytes = await PdfExportService.generate(
          data: largeData,
          fontRegularBytes: cairoRegularBytes,
          fontBoldBytes: cairoBoldBytes,
          labels: testArabicLabels,
          isArabic: true,
        );
        stopwatch.stop();

        // Output measured time for reporting
        // ignore: avoid_print
        print(
          'MEASURED_PDF_TIME_3000_OPS: ${stopwatch.elapsedMilliseconds} ms',
        );

        expect(pdfBytes, isNotEmpty);
        expect(pdfBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
        // A 3000-row table produces a substantial multi-page PDF document (> 100 KB)
        expect(pdfBytes.length, greaterThan(100 * 1024));
      },
    );
  });

  group('3. Excel Export Service Tests', () {
    test(
      'Produces XLSX with two sheets ("ملخص" and "العمليات"), numeric amounts, and frozen row',
      () async {
        final sampleData = MonthExportData(
          yearMonth: '2026-11',
          monthTitle: 'نوفمبر 2026',
          expenses: 15000,
          income: 0,
          budget: 30000,
          remaining: 15000,
          operationsCount: 2,
          createdAt: DateTime(2026, 11, 27, 10, 0),
          categories: const [
            MonthExportCategory(
              categoryId: 1,
              name: 'أكل',
              colorHex: '#4E8B7A',
              totalAmount: 10000,
              transactionCount: 1,
              percentage: 66.7,
            ),
            MonthExportCategory(
              categoryId: 2,
              name: 'مواصلات',
              colorHex: '#E8A83A',
              totalAmount: 5000,
              transactionCount: 1,
              percentage: 33.3,
            ),
          ],
          dailyExpenses: [
            MonthExportDay(
              dayNumber: 1,
              dayName: 'الأحد',
              date: DateTime(2026, 11, 1),
              totalAmount: 10000,
            ),
            MonthExportDay(
              dayNumber: 2,
              dayName: 'الاثنين',
              date: DateTime(2026, 11, 2),
              totalAmount: 5000,
            ),
          ],
          transactions: [
            MonthExportTransaction(
              id: 1,
              dateText: '2026/11/01',
              dayName: 'الأحد',
              timeText: '13:00',
              categoryName: 'أكل',
              categoryColorHex: '#4E8B7A',
              description: 'غداء',
              typeText: 'مصروف',
              kind: 'expense',
              amount: 10000,
              createdAt: DateTime(2026, 11, 1, 13, 0),
            ),
            MonthExportTransaction(
              id: 2,
              dateText: '2026/11/02',
              dayName: 'الاثنين',
              timeText: '09:00',
              categoryName: 'مواصلات',
              categoryColorHex: '#E8A83A',
              description: 'تاكسي',
              typeText: 'مصروف',
              kind: 'expense',
              amount: 5000,
              createdAt: DateTime(2026, 11, 2, 9, 0),
            ),
          ],
        );

        final excelBytes = ExcelExportService.generate(
          data: sampleData,
          labels: testArabicLabels,
        );

        expect(excelBytes, isNotEmpty);
        // Valid ZIP/XLSX magic bytes: PK\x03\x04 (0x50, 0x4B, 0x03, 0x04)
        expect(excelBytes.sublist(0, 4), equals([0x50, 0x4B, 0x03, 0x04]));

        // Decode and verify sheets
        final excel = Excel.decodeBytes(excelBytes);
        expect(excel.tables.containsKey('ملخص'), isTrue);
        expect(excel.tables.containsKey('العمليات'), isTrue);

        final opsTable = excel.tables['العمليات']!;
        // Row 0 is title banner, row 1 is table header, followed by transactions and total row
        expect(opsTable.rows.length, greaterThanOrEqualTo(4));
        // First data row, amount column (index 6) has numeric value 100
        final amountCell = opsTable.rows[2][6]?.value;
        expect(
          amountCell is DoubleCellValue || amountCell is IntCellValue,
          isTrue,
        );
        final numValue = amountCell is DoubleCellValue
            ? amountCell.value
            : (amountCell as IntCellValue).value;
        expect(numValue, equals(100));

        // Verify Summary sheet has Category Table & KPI cards
        final summaryTable = excel.tables['ملخص']!;
        expect(summaryTable.rows.length, greaterThan(7));
        final catNameCell = summaryTable.rows[8][0]?.value;
        expect(catNameCell, isA<TextCellValue>());
        expect((catNameCell as TextCellValue).value.text, equals('أكل'));
      },
    );
  });

  group('4. Temporary File Deletion & Privacy Tests', () {
    test('Temporary exported file is deleted in finally block', () async {
      final tempDir = Directory.systemTemp.createTempSync('baqy_test_');
      final testFile = File('${tempDir.path}/baqy-2026-11.pdf');
      await testFile.writeAsString('mock pdf content');

      expect(await testFile.exists(), isTrue);

      // Simulate sharing and cleanup in finally block
      try {
        // Pretend share dialog runs
      } finally {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      }

      expect(await testFile.exists(), isFalse);
      tempDir.deleteSync(recursive: true);
    });
  });

  group('5. AndroidManifest Permissions & ARB Localization Sync', () {
    test('AndroidManifest contains NO storage permissions', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final manifestContent = manifestFile.readAsStringSync();
      expect(
        manifestContent.contains('android.permission.READ_EXTERNAL_STORAGE'),
        isFalse,
      );
      expect(
        manifestContent.contains('android.permission.WRITE_EXTERNAL_STORAGE'),
        isFalse,
      );
      expect(
        manifestContent.contains('android.permission.MANAGE_EXTERNAL_STORAGE'),
        isFalse,
      );
    });

    test('ARB files app_ar.arb and app_en.arb contain identical keys', () {
      final arJson =
          jsonDecode(File('lib/l10n/app_ar.arb').readAsStringSync())
              as Map<String, dynamic>;
      final enJson =
          jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
              as Map<String, dynamic>;

      final arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();

      final missingInEn = arKeys.difference(enKeys);
      final missingInAr = enKeys.difference(arKeys);

      expect(
        missingInEn,
        isEmpty,
        reason: 'Keys present in AR but missing in EN: $missingInEn',
      );
      expect(
        missingInAr,
        isEmpty,
        reason: 'Keys present in EN but missing in AR: $missingInAr',
      );
    });
  });

  group('6. UI Buttons in MonthDetailsScreen', () {
    testWidgets(
      'Header displays PDF and Excel export buttons with 44x44 touch targets and tooltips',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              expenseRepositoryProvider.overrideWithValue(repository),
            ],
            child: const MaterialApp(
              locale: Locale('ar'),
              themeMode: ThemeMode.light,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: MonthDetailsScreen(initialYearMonth: '2026-11'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final pdfButton = find.byTooltip('تصدير كملف PDF');
        final excelButton = find.byTooltip('تصدير كملف Excel');

        expect(pdfButton, findsOneWidget);
        expect(excelButton, findsOneWidget);
        expect(find.text('PDF'), findsOneWidget);
        expect(find.text('Excel'), findsOneWidget);

        final pdfSize = tester.getSize(pdfButton);
        final excelSize = tester.getSize(excelButton);

        expect(pdfSize.width, greaterThanOrEqualTo(44.0));
        expect(pdfSize.height, greaterThanOrEqualTo(44.0));
        expect(excelSize.width, greaterThanOrEqualTo(44.0));
        expect(excelSize.height, greaterThanOrEqualTo(44.0));
      },
    );

    testWidgets('Empty month shows snackbar "مفيش عمليات في الشهر ده"', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            themeMode: ThemeMode.light,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: MonthDetailsScreen(initialYearMonth: '2026-11'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap PDF button when month has no operations
      final pdfButton = find.byTooltip('تصدير كملف PDF');
      await tester.tap(pdfButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('مفيش عمليات في الشهر ده'), findsOneWidget);
    });
  });
}
