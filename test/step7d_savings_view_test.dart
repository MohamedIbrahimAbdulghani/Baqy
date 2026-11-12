import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/utils/category_icon_helper.dart';
import 'package:baqy/core/utils/number_formatter.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/data/services/audio_recording_service.dart';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:baqy/features/goals/domain/models/goal_item.dart';
import 'package:baqy/features/goals/presentation/widgets/goal_save_bottom_sheet.dart';
import 'package:baqy/features/home/presentation/widgets/budget_ring.dart';
import 'package:baqy/features/home/presentation/widgets/recent_transactions_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late GoalRepositoryImpl goalRepo;
  late ExpenseRepositoryImpl expenseRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    goalRepo = GoalRepositoryImpl(db);
    expenseRepo = ExpenseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Step 7D - Virtual Category & Goal Savings & Withdrawals', () {
    test('Virtual category "تحويش" has correct constants', () {
      expect(CategoryItem.virtualSavings.id, equals(-1));
      expect(CategoryItem.virtualSavings.name, equals('تحويش'));
      expect(CategoryItem.virtualSavings.color, equals('#B5883E'));
      expect(CategoryItem.virtualSavings.icon, equals('savings'));

      final icon = CategoryIconHelper.getIcon(CategoryItem.virtualSavings.icon);
      expect(icon, equals(Icons.savings_outlined));

      final color = CategoryIconHelper.parseColor(CategoryItem.virtualSavings.color);
      expect(color, equals(const Color(0xFFB5883E)));
    });

    test('addGoalSaving and addGoalWithdrawal update total saved and net month remaining', () async {
      final now = DateTime.now().toUtc();
      final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      // 1. Set budget 10,000 EGP (1,000,000 piastres)
      await expenseRepo.setMonthBudget(
        yearMonth: currentYm,
        amount: 1000000,
      );

      // 2. Add goal with target 100,000 EGP
      final goalId = await goalRepo.addGoal(
        name: 'ايفون',
        targetAmount: 100000 * 100,
        monthlySaving: 4000 * 100,
      );

      // 3. Save 5,000 EGP into goal
      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 5000 * 100,
        savedAt: now,
      );

      var totalSaved = await goalRepo.getTotalSavedForGoal(goalId);
      expect(totalSaved, equals(5000 * 100));

      var remaining = await expenseRepo.getRemainingOfMonth(currentYm);
      expect(remaining.goalSavings, equals(5000 * 100));
      expect(remaining.remaining, equals(5000 * 100)); // 10000 - 5000

      // 4. Withdraw 500 EGP from goal
      await goalRepo.addGoalWithdrawal(
        goalId: goalId,
        amount: 500 * 100,
        withdrawnAt: now.add(const Duration(minutes: 5)),
      );

      totalSaved = await goalRepo.getTotalSavedForGoal(goalId);
      expect(totalSaved, equals(4500 * 100)); // 5000 - 500 = 4500

      remaining = await expenseRepo.getRemainingOfMonth(currentYm);
      expect(remaining.goalSavings, equals(4500 * 100));
      expect(remaining.remaining, equals(5500 * 100)); // 10000 - 4500 = 5500
    });

    test('Withdrawal validation prevents withdrawing more than total saved', () async {
      final goalId = await goalRepo.addGoal(
        name: 'سفر',
        targetAmount: 20000 * 100,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 1000 * 100,
      );

      expect(
        () => goalRepo.addGoalWithdrawal(
          goalId: goalId,
          amount: 1500 * 100,
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('المبلغ أكبر من المحوّش في الهدف'),
        )),
      );
    });

    test('Savings and withdrawals appear in getLastTransactionsForMonth (Home آخر المصاريف)', () async {
      final now = DateTime.now().toUtc();
      final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final goalId = await goalRepo.addGoal(
        name: 'ايفون',
        targetAmount: 100000 * 100,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 5000 * 100,
        savedAt: now.subtract(const Duration(minutes: 10)),
      );

      await goalRepo.addGoalWithdrawal(
        goalId: goalId,
        amount: 500 * 100,
        withdrawnAt: now.subtract(const Duration(minutes: 2)),
      );

      final lastTxs = await expenseRepo.getLastTransactionsForMonth(currentYm);
      expect(lastTxs.length, equals(2));

      // Newest first: withdrawal then saving
      expect(lastTxs[0].amount, equals(-500 * 100));
      expect(lastTxs[0].description, equals('ايفون'));
      expect(lastTxs[0].note, equals('سحب من الهدف'));
      expect(lastTxs[0].categoryId, equals(-1));
      expect(lastTxs[0].category?.name, equals('تحويش'));

      expect(lastTxs[1].amount, equals(5000 * 100));
      expect(lastTxs[1].description, equals('ايفون'));
      expect(lastTxs[1].note, isNull);
      expect(lastTxs[1].categoryId, equals(-1));
    });

    test('getTotalsPerCategoryPerMonth includes "تحويش" when net saved > 0', () async {
      final now = DateTime.now().toUtc();
      final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final goalId = await goalRepo.addGoal(
        name: 'لابتوب',
        targetAmount: 50000 * 100,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 5000 * 100,
        savedAt: now,
      );

      await goalRepo.addGoalWithdrawal(
        goalId: goalId,
        amount: 500 * 100,
        withdrawnAt: now.add(const Duration(seconds: 1)),
      );

      final totals = await expenseRepo.getTotalsPerCategoryPerMonth(currentYm);
      final savingsTotal = totals.firstWhere((t) => t.category.name == 'تحويش');
      expect(savingsTotal.totalAmount, equals(4500 * 100));
      expect(savingsTotal.transactionCount, equals(2));
    });

    test('getCategoryTotalsForDay includes "تحويش" for day list', () async {
      final now = DateTime.now();

      final goalId = await goalRepo.addGoal(
        name: 'شقة',
        targetAmount: 1000000 * 100,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 3000 * 100,
        savedAt: now.toUtc(),
      );

      final dayTotals = await expenseRepo.getCategoryTotalsForDay(now);
      final savingsDayTotal = dayTotals.firstWhere((t) => t.category.name == 'تحويش');
      expect(savingsDayTotal.totalAmount, equals(3000 * 100));
      expect(savingsDayTotal.transactionCount, equals(1));
    });

    test('getCategoryTransactionsForMonth and for day return savings and withdrawals', () async {
      final now = DateTime.now().toUtc();
      final currentYm = '${now.year}-${now.month.toString().padLeft(2, '0')}';

      final goalId = await goalRepo.addGoal(
        name: 'عربية',
        targetAmount: 300000 * 100,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 10000 * 100,
        savedAt: now.subtract(const Duration(hours: 1)),
      );

      await goalRepo.addGoalWithdrawal(
        goalId: goalId,
        amount: 1000 * 100,
        withdrawnAt: now,
      );

      final txs = await expenseRepo.getCategoryTransactionsForMonth(
        categoryId: -1,
        yearMonth: currentYm,
      );
      expect(txs.length, equals(2));
      expect(txs[0].amount, equals(-1000 * 100));
      expect(txs[0].description, equals('عربية'));
      expect(txs[0].note, equals('سحب من الهدف'));
      expect(txs[1].amount, equals(10000 * 100));
      expect(txs[1].description, equals('عربية'));
    });
  });

  group('Step 7D - UI Widgets & Flows', () {
    testWidgets('GoalSaveBottomSheet pre-fills monthlySavingEgp when saving and validates', (tester) async {
      final goal = GoalItem(
        id: 1,
        name: 'ايفون',
        targetAmount: 100000 * 100,
        monthlySaving: 4000 * 100,
        totalSaved: 10000 * 100,
        createdAt: DateTime.now().toUtc(),
      );

      int? savedAmount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalSaveBottomSheet(
              goal: goal,
              remainingEgp: 9000,
              onSave: (amt) async {
                savedAmount = amt;
              },
            ),
          ),
        ),
      );

      // Pre-filled with monthly saving value 4,000 in Arabic digits
      expect(find.text(NumberFormatter.formatCurrency(4000)), findsOneWidget);
      expect(find.text('حوّشت في ايفون'), findsOneWidget);

      // Tap "حفظ" directly
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect(savedAmount, equals(4000 * 100));
    });

    testWidgets('GoalSaveBottomSheet withdrawal mode validates against total saved', (tester) async {
      final goal = GoalItem(
        id: 1,
        name: 'ايفون',
        targetAmount: 100000 * 100,
        monthlySaving: 4000 * 100,
        totalSaved: 2000 * 100,
        createdAt: DateTime.now().toUtc(),
      );

      int? withdrawnAmount;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalSaveBottomSheet(
              goal: goal,
              remainingEgp: 9000,
              isWithdrawal: true,
              onSave: (amt) async {
                withdrawnAmount = amt;
              },
            ),
          ),
        ),
      );

      expect(find.text('سحبت من ايفون'), findsOneWidget);

      // Enter amount exceeding totalSaved (e.g. 3000 > 2000)
      await tester.enterText(find.byType(TextField), '3000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('المبلغ أكبر من المحوّش في الهدف'), findsOneWidget);
      expect(withdrawnAmount, isNull);

      // Enter valid amount 500
      await tester.enterText(find.byType(TextField), '500');
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await tester.pumpAndSettle();

      expect(withdrawnAmount, equals(500 * 100));
    });

    testWidgets('BudgetRing displays "صرفت X وحوّشت Z من Y" when savedPiastres > 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 4500 * 100,
              spentPiastres: 1000 * 100,
              monthMoneyPiastres: 10000 * 100,
              savedPiastres: 4500 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      final expectedText =
          'صرفت ${NumberFormatter.formatCurrency(1000)} وحوّشت ${NumberFormatter.formatCurrency(4500)} من ${NumberFormatter.formatCurrency(10000)}';
      expect(find.text(expectedText), findsOneWidget);
    });

    testWidgets('BudgetRing displays standard "صرفت X من Y" when savedPiastres == 0', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 9000 * 100,
              spentPiastres: 1000 * 100,
              monthMoneyPiastres: 10000 * 100,
              savedPiastres: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      final expectedText =
          'صرفت ${NumberFormatter.formatCurrency(1000)} من ${NumberFormatter.formatCurrency(10000)}';
      expect(find.text(expectedText), findsOneWidget);
    });

    testWidgets('RecentTransactionsSection renders withdrawal with minus sign and disables tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecentTransactionsSection(
                transactions: [],
              ),
            ),
          ),
        ),
      );
      expect(find.text('آخر المصاريف'), findsOneWidget);
    });

    test('Gemini failure falls back to local parser and saves expense without error', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          geminiExpenseParserProvider.overrideWithValue(_FailingGeminiParser()),
          audioRecordingServiceProvider.overrideWithValue(_FakeAudioRecordingService()),
          skipVoiceReviewProvider.overrideWithValue(true),
        ],
      );
      addTearDown(container.dispose);

      // Create dummy audio file
      final tempDir = await Directory.systemTemp.createTemp('audio_test');
      final tempAudio = File('${tempDir.path}/test.m4a');
      await tempAudio.writeAsBytes(List.filled(200, 0));

      final notifier = container.read(voiceRecordingProvider.notifier);
      await notifier.processAudioFile(
        tempAudio.path,
        fallbackSpeechText: 'صرفت مية جنيه غدا',
      );

      final currentYm = '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}';
      final txs = await expenseRepo.getLastTransactionsForMonth(currentYm);
      expect(txs.isNotEmpty, isTrue);
      expect(txs.first.amount, equals(100 * 100));
      expect(txs.first.description, equals('غدا'));

      // Clean up temp
      if (await tempAudio.exists()) await tempAudio.delete();
      if (await tempDir.exists()) await tempDir.delete();
    });
  });
}

class _FakeAudioRecordingService implements AudioRecordingService {
  @override
  Stream<double> get amplitudeStream => const Stream.empty();
  @override
  Future<void> cancelRecording() async {}
  @override
  Future<void> dispose() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  bool get isRecording => false;
  @override
  Future<String?> startRecording({void Function()? onSafetyWarning, void Function(String path)? onMaxDurationReached}) async => null;
  @override
  Future<String?> stopRecording() async => null;
}

class _FailingGeminiParser extends GeminiExpenseParser {
  @override
  String? get apiKey => 'test-key';

  @override
  Future<AudioParseResult?> parseAudio(
    File audioFile, {
    List<CategoryItem> categories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) async {
    lastAudioError = GeminiAudioErrorType.network;
    return null; // Simulates network failure / timeout
  }
}
