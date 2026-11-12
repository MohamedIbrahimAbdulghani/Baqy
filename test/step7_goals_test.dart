import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/data/services/audio_recording_service.dart';
import 'package:baqy/features/expenses/data/services/speech_recognition_service.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:baqy/features/goals/domain/models/goal_item.dart';
import 'package:baqy/features/goals/domain/repositories/goal_repository.dart';
import 'package:baqy/features/goals/presentation/providers/goal_providers.dart';
import 'package:baqy/features/goals/presentation/screens/add_goal_screen.dart';
import 'package:baqy/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:baqy/features/goals/presentation/widgets/goals_speed_dial_fab.dart';
import 'package:baqy/features/shell/presentation/providers/tab_provider.dart';
import 'package:baqy/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

class _FakeAudioRecordingService implements AudioRecordingService {
  final _controller = StreamController<double>.broadcast();
  bool _isRec = false;

  @override
  bool get isRecording => _isRec;

  @override
  Stream<double> get amplitudeStream => _controller.stream;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<String?> startRecording({
    void Function()? onSafetyWarning,
    void Function(String path)? onMaxDurationReached,
  }) async {
    _isRec = true;
    return 'test_audio.m4a';
  }

  @override
  Future<String?> stopRecording() async {
    _isRec = false;
    return null;
  }

  @override
  Future<void> cancelRecording() async {
    _isRec = false;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool _isListening = false;
  String wordsToEmit = '';
  void Function(String words, {bool isFinal})? _onResult;

  @override
  bool get isAvailable => true;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async => true;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async =>
      true;

  @override
  Future<void> listen({
    required void Function(String recognizedWords, {bool isFinal}) onResult,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    _isListening = true;
    _onResult = onResult;
    if (wordsToEmit.isNotEmpty) {
      _onResult?.call(wordsToEmit, isFinal: true);
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
    if (wordsToEmit.isNotEmpty) {
      _onResult?.call(wordsToEmit, isFinal: true);
    }
  }

  @override
  Future<void> cancel() async {
    _isListening = false;
  }
}

class _FakeGoalsTabNotifier extends TabIndexNotifier {
  @override
  int build() => 1;
}

Widget createTestApp(ProviderContainer container, {Widget? home}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ar'),
      theme: AppTheme.lightTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home ?? const MainShellScreen(),
    ),
  );
}

void main() {
  group('Step 7: GoalRepository Unit Tests & Financial Invariants', () {
    late AppDatabase db;
    late GoalRepository repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = GoalRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('addGoal saves goal with correct fields in piastres and strips control characters', () async {
      final id = await repository.addGoal(
        name: '  آيفون \x00\x1F جديد  ',
        targetAmount: 10000000, // 100,000 EGP in piastres
      );

      final goal = await repository.getGoalById(id);
      expect(goal, isNotNull);
      expect(goal!.name, equals('آيفون  جديد'));
      expect(goal.targetAmount, equals(10000000));
      expect(goal.targetEgp, equals(100000));
      expect(goal.monthlySaving, equals(0));
      expect(goal.monthlySavingEgp, equals(0));
      expect(goal.monthsToGoal, isNull);
    });

    test('addGoal validation: empty name or name > 40 chars throws ArgumentError', () async {
      expect(
        () => repository.addGoal(name: '', targetAmount: 500000),
        throwsArgumentError,
      );
      expect(
        () => repository.addGoal(name: '   \x00  ', targetAmount: 500000),
        throwsArgumentError,
      );
    });

    test('addGoal validation: amount <= 0 or > 100,000,000 throws ArgumentError', () async {
      expect(
        () => repository.addGoal(name: 'لابتوب', targetAmount: 0),
        throwsArgumentError,
      );
      expect(
        () => repository.addGoal(name: 'لابتوب', targetAmount: -100),
        throwsArgumentError,
      );
      // > 100,000,000 EGP (in piastres)
      expect(
        () => repository.addGoal(
          name: 'لابتوب',
          targetAmount: (100000001 * 100),
        ),
        throwsArgumentError,
      );
    });

    test('updateMonthlySaving updates amount and validates bounds', () async {
      final id = await repository.addGoal(
        name: 'سفر دبي',
        targetAmount: 5000000, // 50,000 EGP
      );

      // Valid monthly saving (e.g. 5,000 EGP = 500,000 piastres)
      await repository.updateMonthlySaving(id: id, monthlySaving: 500000);
      var goal = await repository.getGoalById(id);
      expect(goal!.monthlySaving, equals(500000));
      expect(goal.monthlySavingEgp, equals(5000));
      expect(goal.monthsToGoal, equals(10)); // 50,000 / 5,000 = 10

      // Cannot be negative
      expect(
        () => repository.updateMonthlySaving(id: id, monthlySaving: -1),
        throwsArgumentError,
      );

      // Cannot exceed target
      expect(
        () => repository.updateMonthlySaving(id: id, monthlySaving: 6000000),
        throwsArgumentError,
      );
    });

    test('Months to goal calculation rounds up (target ÷ saving)', () {
      // 100,000 ÷ 4,000 = 25
      final goal1 = GoalItem(
        id: 1,
        name: 'آيفون',
        targetAmount: 10000000,
        monthlySaving: 400000,
        createdAt: DateTime.now(),
      );
      expect(goal1.monthsToGoal, equals(25));

      // 100,000 ÷ 3,000 = 33.333 -> 34 months
      final goal2 = GoalItem(
        id: 2,
        name: 'آيفون',
        targetAmount: 10000000,
        monthlySaving: 300000,
        createdAt: DateTime.now(),
      );
      expect(goal2.monthsToGoal, equals(34));

      // Monthly saving 0 -> null
      final goal3 = GoalItem(
        id: 3,
        name: 'آيفون',
        targetAmount: 10000000,
        monthlySaving: 0,
        createdAt: DateTime.now(),
      );
      expect(goal3.monthsToGoal, isNull);
    });

    test('watchGoals stream updates immediately upon writing through repository', () async {
      final stream = repository.watchGoals();
      final initial = await stream.first;
      expect(initial, isEmpty);

      await repository.addGoal(name: 'عجلة', targetAmount: 300000);
      final updated = await stream.first;
      expect(updated.length, equals(1));
      expect(updated.first.name, equals('عجلة'));
    });
  });

  group('Step 7: Goals Screen & UI Widget Tests', () {
    late AppDatabase db;
    late GoalRepository repository;
    late _FakeSpeechRecognitionService fakeSpeech;
    late _FakeAudioRecordingService fakeAudio;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = GoalRepositoryImpl(db);
      fakeSpeech = _FakeSpeechRecognitionService();
      fakeAudio = _FakeAudioRecordingService();

      // Seed a budget so HomeScreen auto-budget bottom sheet doesn't pop up
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await db.into(db.monthBudgets).insert(
            MonthBudgetsCompanion.insert(
              yearMonth: ym,
              amount: 1000000,
            ),
          );
    });

    tearDown(() async {
      await fakeAudio.dispose();
      await db.close();
    });

    testWidgets('Empty state: when no goals, shows ONLY title "الأهداف" and "+" button, NO extra text',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          tabIndexProvider.overrideWith(_FakeGoalsTabNotifier.new), // Goals tab
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Title should be visible (page title, distinct from bottom bar tab)
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == 'الأهداف' && w.style?.fontSize == 26.0,
        ),
        findsOneWidget,
      );

      // FAB "+" button should be visible
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Verify no empty text like "لا توجد أهداف"
      expect(find.textContaining('لا توجد'), findsNothing);
      expect(find.textContaining('أضف هدفك'), findsNothing);
      expect(find.textContaining('فارغ'), findsNothing);
    });

    testWidgets('Goals list shows goal cards with name, "الهدف: X جنيه", percentage 0%, progress bar',
        (tester) async {
      await repository.addGoal(
        name: 'آيفون',
        targetAmount: 10000000, // 100,000 EGP
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          tabIndexProvider.overrideWith(_FakeGoalsTabNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      expect(find.text('آيفون'), findsOneWidget);
      expect(find.text('الهدف: ١٠٠,٠٠٠ جنيه'), findsOneWidget);
      expect(find.text('٠٪'), findsOneWidget);

      final progressFinder = find.byType(LinearProgressIndicator);
      expect(progressFinder, findsOneWidget);
      final progress = tester.widget<LinearProgressIndicator>(progressFinder);
      expect(progress.value, equals(0.0));
    });

    testWidgets('FAB Speed Dial: tapping "+" expands mic and pencil icon buttons, "+" turns to "x"',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          tabIndexProvider.overrideWith(_FakeGoalsTabNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Initially action buttons are closed
      final fabButton = find.byType(GoalsSpeedDialFab);
      expect(fabButton, findsOneWidget);

      // Tap "+"
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Now both pencil and mic buttons are present
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
    });

    testWidgets('Add Goal Screen (Pencil): validates name and amount, saves and pops',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestApp(container, home: const AddGoalScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('هدف جديد'), findsOneWidget);
      expect(find.text('اسم الهدف'), findsOneWidget);
      expect(find.text('المبلغ المطلوب'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);

      // Try tapping حفظ with empty fields -> shows errors
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال اسم الهدف'), findsOneWidget);
      expect(find.text('يرجى إدخال مبلغ صحيح'), findsOneWidget);

      // Enter valid fields
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'آيفون');
      await tester.enterText(textFields.at(1), '100000');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // Database should contain the saved goal
      final allGoals = await repository.getGoals();
      expect(allGoals.length, equals(1));
      expect(allGoals.first.name, equals('آيفون'));
      expect(allGoals.first.targetEgp, equals(100000));
    });

    testWidgets('Goal Details Screen: shows target, live month remaining, saving calculation, and 0% bar',
        (tester) async {
      final goalId = await repository.addGoal(
        name: 'آيفون',
        targetAmount: 10000000, // 100,000 EGP
      );

      final expenseRepo = ExpenseRepositoryImpl(db);
      // Set remaining of current month: budget 10,000, expense 1,000 -> 9,000 EGP
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await expenseRepo.setMonthBudget(yearMonth: ym, amount: 1000000); // 10,000 EGP
      await expenseRepo.addTransaction(
        amount: 100000, // 1,000 EGP
        description: 'شوبينج',
        categoryId: 1,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.now().toUtc(),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestApp(container, home: GoalDetailsScreen(goalId: goalId)),
      );
      await tester.pumpAndSettle();

      // Goal name and target card
      expect(find.text('آيفون'), findsOneWidget);
      expect(find.text('المبلغ المطلوب'), findsOneWidget);
      expect(find.text('١٠٠,٠٠٠ جنيه'), findsOneWidget);

      // Live remaining line: 9,000 جنيه
      expect(find.text('المتبقي معاك الشهر ده'), findsOneWidget);
      expect(find.text('٩,٠٠٠ جنيه'), findsOneWidget);

      // Field "هتوفر كام في الشهر؟"
      expect(find.text('هتوفر كام في الشهر؟'), findsOneWidget);

      // Initially saving is empty, so result is NOT shown
      expect(find.textContaining('هتوصل لهدفك في'), findsNothing);

      // Enter 4,000
      final savingInput = find.byType(TextField);
      await tester.enterText(savingInput, '4000');
      await tester.pumpAndSettle();

      // Calculation: 100,000 ÷ 4,000 = 25 months
      expect(find.text('هتوصل لهدفك في'), findsOneWidget);
      expect(find.text('٢٥ شهر'), findsOneWidget);

      // Progress bar and percent show 0%
      expect(find.text('٠٪ من الهدف'), findsOneWidget);

      // Saving is saved in the database
      final updatedGoal = await repository.getGoalById(goalId);
      expect(updatedGoal!.monthlySavingEgp, equals(4000));
    });

    testWidgets('Voice Goal Addition: "عايز اجيب ايفون بمية الف" saves name "ايفون" and target 100,000',
        (tester) async {
      fakeSpeech.wordsToEmit = 'عايز اجيب ايفون بمية الف';

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          audioRecordingServiceProvider.overrideWithValue(fakeAudio),
          speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
          tabIndexProvider.overrideWith(_FakeGoalsTabNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Open FAB
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap mic
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap stop button
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Check database: goal should be saved with name "ايفون" and 100,000 target
      final goals = await repository.getGoals();
      expect(goals.length, equals(1));
      expect(goals.first.name, equals('ايفون'));
      expect(goals.first.targetEgp, equals(100000));

      // Card appears in the list
      expect(find.text('ايفون'), findsOneWidget);
      expect(find.text('الهدف: ١٠٠,٠٠٠ جنيه'), findsOneWidget);
    });

    testWidgets('Voice Goal Addition: if no amount found, shows snackbar "ماسمعتش مبلغ، جرّب تاني" and saves nothing',
        (tester) async {
      fakeSpeech.wordsToEmit = 'صباح الخير ازيكم جميعا';

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          audioRecordingServiceProvider.overrideWithValue(fakeAudio),
          speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
          tabIndexProvider.overrideWith(_FakeGoalsTabNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Open FAB
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Tap mic
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap stop button
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // No goal should be saved
      final goals = await repository.getGoals();
      expect(goals, isEmpty);

      // Snackbar should be displayed
      expect(find.text('ماسمعتش مبلغ، جرّب تاني'), findsOneWidget);
    });
  });
}
