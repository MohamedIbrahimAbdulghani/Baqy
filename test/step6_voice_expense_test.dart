import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/data/services/speech_recognition_service.dart';
import 'package:baqy/features/expenses/domain/parser/egyptian_expense_parser.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/home/presentation/screens/home_screen.dart';
import 'package:baqy/features/home/presentation/widgets/home_speed_dial_fab.dart';
import 'package:baqy/l10n/app_localizations.dart';
import 'package:baqy/features/expenses/domain/models/category_details_args.dart';
import 'package:baqy/features/expenses/presentation/screens/category_details_screen.dart';
import 'package:baqy/features/expenses/presentation/widgets/voice_expense_review_sheet.dart';
import 'package:drift/native.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

class _FakeSelectedYearMonthNotifier extends SelectedYearMonthNotifier {
  _FakeSelectedYearMonthNotifier(this._initial);
  final String _initial;

  @override
  String build() => _initial;
}

class FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool _isListening = false;
  bool shouldFailInitialize = false;
  String wordsToEmit = '';
  void Function(String words, {bool isFinal})? _onResult;
  void Function(String status)? onStatus;
  void Function(SpeechRecognitionError error)? onError;
  int listenCallCount = 0;

  @override
  bool get isListening => _isListening;

  bool fakeHasPermission = true;
  bool _isAvailable = false;

  @override
  Future<bool> get hasPermission async => fakeHasPermission;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async {
    this.onStatus = onStatus;
    this.onError = onError;
    if (shouldFailInitialize) return false;
    _isAvailable = true;
    return true;
  }

  @override
  Future<void> listen({
    required void Function(String recognizedWords, {bool isFinal}) onResult,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    _isListening = true;
    listenCallCount++;
    _onResult = onResult;
    if (wordsToEmit.isNotEmpty) {
      onResult(wordsToEmit, isFinal: false);
    }
  }

  @override
  Future<void> stop() async {
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    _isListening = false;
  }

  void emitWords(String words, {bool isFinal = false}) {
    wordsToEmit = words;
    _onResult?.call(words, isFinal: isFinal);
  }

  void emitStatus(String status) {
    onStatus?.call(status);
  }

  void emitError(SpeechRecognitionError error) {
    onError?.call(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Step 6: Egyptian Ammiya Expense Parser - Required 15 Tests', () {
    test('1. "صرفت ١٥٠ جنيه غدا" → أكل 150', () {
      final res = EgyptianExpenseParser.parse('صرفت ١٥٠ جنيه غدا');
      expect(res.length, equals(1));
      expect(res.first.category, equals('أكل'));
      expect(res.first.amount, equals(150));
      expect(res.first.description, equals('غدا'));
    });

    test('2. "دفعت ميتين جنيه للميكانيكي" → أخرى 200', () {
      final res = EgyptianExpenseParser.parse('دفعت ميتين جنيه للميكانيكي');
      expect(res.length, equals(1));
      expect(res.first.category, equals('أخرى'));
      expect(res.first.amount, equals(200));
      expect(res.first.description, equals('ميكانيكي'));
    });

    test('3. "اشتريت خضار بخمسين" → أكل 50', () {
      final res = EgyptianExpenseParser.parse('اشتريت خضار بخمسين');
      expect(res.length, equals(1));
      expect(res.first.category, equals('أكل'));
      expect(res.first.amount, equals(50));
      expect(res.first.description, equals('خضار'));
    });

    test(
      '4. "ركبت ميكروباص بعشرة ورجعت بخمستاشر" → مواصلات 10 + مواصلات 15',
      () {
        final res = EgyptianExpenseParser.parse(
          'ركبت ميكروباص بعشرة ورجعت بخمستاشر',
        );
        expect(res.length, equals(2));
        expect(res[0].category, equals('مواصلات'));
        expect(res[0].amount, equals(10));
        expect(res[0].description, equals('ميكروباص'));

        expect(res[1].category, equals('مواصلات'));
        expect(res[1].amount, equals(15));
        expect(res[1].description, equals('مواصلات'));
      },
    );

    test(
      '5. "رحت القاهرة بخمسين ورجعت الشرقية بمية" → مواصلات 50 + مواصلات 100',
      () {
        final res = EgyptianExpenseParser.parse(
          'رحت القاهرة بخمسين ورجعت الشرقية بمية',
        );
        expect(res.length, equals(2));
        expect(res[0].category, equals('مواصلات'));
        expect(res[0].amount, equals(50));
        expect(res[0].description, equals('مواصلات'));

        expect(res[1].category, equals('مواصلات'));
        expect(res[1].amount, equals(100));
        expect(res[1].description, equals('مواصلات'));
      },
    );

    test('6. "عملت صدقة بخمسين جنيه" → صدقات 50', () {
      final res = EgyptianExpenseParser.parse('عملت صدقة بخمسين جنيه');
      expect(res.length, equals(1));
      expect(res.first.category, equals('صدقات'));
      expect(res.first.amount, equals(50));
      expect(res.first.description, equals('صدقة'));
    });

    test('7. "دفعت اشتراك الجيم ستمية" → اشتراكات 600', () {
      final res = EgyptianExpenseParser.parse('دفعت اشتراك الجيم ستمية');
      expect(res.length, equals(1));
      expect(res.first.category, equals('اشتراكات'));
      expect(res.first.amount, equals(600));
      expect(res.first.description, equals('اشتراك'));
    });

    test('8. "فاتورة الكهربا ميت وخمسين" → فواتير 150', () {
      final res = EgyptianExpenseParser.parse('فاتورة الكهربا ميت وخمسين');
      expect(res.length, equals(1));
      expect(res.first.category, matches(RegExp(r'^فواتير')));
      expect(res.first.amount, equals(150));
      expect(res.first.description, equals('فاتورة'));
    });

    test('9. "اتغديت بتمانين واتعشيت بخمسة وسبعين" → أكل 80 + أكل 75', () {
      final res = EgyptianExpenseParser.parse(
        'اتغديت بتمانين واتعشيت بخمسة وسبعين',
      );
      expect(res.length, equals(2));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(80));
      expect(res[0].description, equals('غدا'));

      expect(res[1].category, equals('أكل'));
      expect(res[1].amount, equals(75));
      expect(res[1].description, equals('عشا'));
    });

    test('10. "جبت بنزين بتلتمية جنيه" → سيارة 300', () {
      final res = EgyptianExpenseParser.parse('جبت بنزين بتلتمية جنيه');
      expect(res.length, equals(1));
      expect(res.first.category, equals('سيارة'));
      expect(res.first.amount, equals(300));
      expect(res.first.description, equals('بنزين'));
    });

    test('11. "اشتريت جزمة بالف ومية" → أخرى 1100', () {
      final res = EgyptianExpenseParser.parse('اشتريت جزمة بالف ومية');
      expect(res.length, equals(1));
      expect(res.first.category, equals('أخرى'));
      expect(res.first.amount, equals(1100));
      expect(res.first.description, equals('جزمة'));
    });

    test('12. "دفعت نص الف للكهربا" → فواتير 500', () {
      final res = EgyptianExpenseParser.parse('دفعت نص الف للكهربا');
      expect(res.length, equals(1));
      expect(res.first.category, matches(RegExp(r'^فواتير')));
      expect(res.first.amount, equals(500));
      expect(res.first.description, equals('كهرباء'));
    });

    test('13. "صرفت الف ونص على الايجار" → فواتير 1500', () {
      final res = EgyptianExpenseParser.parse('صرفت الف ونص على الايجار');
      expect(res.length, equals(1));
      expect(res.first.category, matches(RegExp(r'^فواتير')));
      expect(res.first.amount, equals(1500));
      expect(res.first.description, equals('إيجار'));
    });

    test('14. "دفعت ٣٠ ج للتاكسي" → مواصلات 30', () {
      final res = EgyptianExpenseParser.parse('دفعت ٣٠ ج للتاكسي');
      expect(res.length, equals(1));
      expect(res.first.category, equals('مواصلات'));
      expect(res.first.amount, equals(30));
      expect(res.first.description, equals('تاكسي'));
    });

    test('15. "شربت قهوة بخمسة واربعين" → مشروبات 45', () {
      final res = EgyptianExpenseParser.parse('شربت قهوة بخمسة واربعين');
      expect(res.length, equals(1));
      expect(res.first.category, matches(RegExp(r'^مشروبات')));
      expect(res.first.amount, equals(45));
      expect(res.first.description, equals('قهوة'));
    });
  });

  group(
    'Step 6: Egyptian Ammiya Expense Parser - 23 Additional Varied Tests',
    () {
      test('16. "جبت عصير بعشرين" → مشروبات 20', () {
        final res = EgyptianExpenseParser.parse('جبت عصير بعشرين');
        expect(res.length, equals(1));
        expect(res.first.category, matches(RegExp(r'^مشروبات')));
        expect(res.first.amount, equals(20));
        expect(res.first.description, equals('عصير'));
      });

      test('17. "شاورما بتسعين وكشري بخمسة وتلاتين" → أكل 90 + أكل 35', () {
        final res = EgyptianExpenseParser.parse(
          'شاورما بتسعين وكشري بخمسة وتلاتين',
        );
        expect(res.length, equals(2));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(90));
        expect(res[0].description, equals('شاورما'));

        expect(res[1].category, equals('أكل'));
        expect(res[1].amount, equals(35));
        expect(res[1].description, equals('كشري'));
      });

      test('18. "دفعت فاتورة الغاز تمانين جنيه" → فواتير 80', () {
        final res = EgyptianExpenseParser.parse(
          'دفعت فاتورة الغاز تمانين جنيه',
        );
        expect(res.length, equals(1));
        expect(res.first.category, matches(RegExp(r'^فواتير')));
        expect(res.first.amount, equals(80));
      });

      test('19. "ركبت مترو بعشرة" → مواصلات 10', () {
        final res = EgyptianExpenseParser.parse('ركبت مترو بعشرة');
        expect(res.length, equals(1));
        expect(res.first.category, equals('مواصلات'));
        expect(res.first.amount, equals(10));
      });

      test(
        '20. "اشتريت فاكهة بمية وخمسين ولحمة بربعمية" → أكل 150 + أكل 400',
        () {
          final res = EgyptianExpenseParser.parse(
            'اشتريت فاكهة بمية وخمسين ولحمة بربعمية',
          );
          expect(res.length, equals(2));
          expect(res[0].category, equals('أكل'));
          expect(res[0].amount, equals(150));
          expect(res[1].category, equals('أكل'));
          expect(res[1].amount, equals(400));
        },
      );

      test('21. "دفعت كفالة يتيم تلتمية جنيه" → صدقات 300', () {
        final res = EgyptianExpenseParser.parse('دفعت كفالة يتيم تلتمية جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, equals('صدقات'));
        expect(res.first.amount, equals(300));
      });

      test('22. "اشتراك نتفلكس ميتين" → اشتراكات 200', () {
        final res = EgyptianExpenseParser.parse('اشتراك نتفلكس ميتين');
        expect(res.length, equals(1));
        expect(res.first.category, equals('اشتراكات'));
        expect(res.first.amount, equals(200));
      });

      test('23. "شحنت رصيد موبايل بمية" → فواتير 100', () {
        final res = EgyptianExpenseParser.parse('شحنت رصيد موبايل بمية');
        expect(res.length, equals(1));
        expect(res.first.category, matches(RegExp(r'^فواتير')));
        expect(res.first.amount, equals(100));
      });

      test('24. "اوبر للجامعة بخمسة واربعين" → مواصلات 45', () {
        final res = EgyptianExpenseParser.parse('اوبر للجامعة بخمسة واربعين');
        expect(res.length, equals(1));
        expect(res.first.category, equals('مواصلات'));
        expect(res.first.amount, equals(45));
      });

      test('25. "جبت سندوتش باتناشر" → أكل 12', () {
        final res = EgyptianExpenseParser.parse('جبت سندوتش باتناشر');
        expect(res.length, equals(1));
        expect(res.first.category, equals('أكل'));
        expect(res.first.amount, equals(12));
      });

      test('26. "دفعت تلات تلاف ايجار" → فواتير 3000', () {
        final res = EgyptianExpenseParser.parse('دفعت تلات تلاف ايجار');
        expect(res.length, equals(1));
        expect(res.first.category, matches(RegExp(r'^فواتير')));
        expect(res.first.amount, equals(3000));
      });

      test('27. "ربع الف زكاة" → صدقات 250', () {
        final res = EgyptianExpenseParser.parse('ربع الف زكاة');
        expect(res.length, equals(1));
        expect(res.first.category, equals('صدقات'));
        expect(res.first.amount, equals(250));
      });

      test('28. "سواق التاكسي اخد سبعين جنيه" → مواصلات 70', () {
        final res = EgyptianExpenseParser.parse('سواق التاكسي اخد سبعين جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, equals('مواصلات'));
        expect(res.first.amount, equals(70));
      });

      test('29. "فطرت بخمسة وعشرين وشربت شاي بعشرة" → أكل 25 + مشروبات 10', () {
        final res = EgyptianExpenseParser.parse(
          'فطرت بخمسة وعشرين وشربت شاي بعشرة',
        );
        expect(res.length, equals(2));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(25));
        expect(res[1].category, matches(RegExp(r'^مشروبات')));
        expect(res[1].amount, equals(10));
      });

      test('30. "اشتراك سبوتيفاي تسعين" → اشتراكات 90', () {
        final res = EgyptianExpenseParser.parse('اشتراك سبوتيفاي تسعين');
        expect(res.length, equals(1));
        expect(res.first.category, equals('اشتراكات'));
        expect(res.first.amount, equals(90));
      });

      test('31. "فاتورة المياه ستين جنيه" → فواتير 60', () {
        final res = EgyptianExpenseParser.parse('فاتورة المياه ستين جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, matches(RegExp(r'^فواتير')));
        expect(res.first.amount, equals(60));
      });

      test('32. "جبت كتب من المعرض بربعمية وخمسين" → أخرى 450', () {
        final res = EgyptianExpenseParser.parse(
          'جبت كتب من المعرض بربعمية وخمسين',
        );
        expect(res.length, equals(1));
        expect(res.first.category, equals('أخرى'));
        expect(res.first.amount, equals(450));
      });

      test('33. "تبرع للجامع بميتين جنيه" → صدقات 200', () {
        final res = EgyptianExpenseParser.parse('تبرع للجامع بميتين جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, equals('صدقات'));
        expect(res.first.amount, equals(200));
      });

      test('34. "صرفت الفين وخمسمية في كارفور" → أخرى 2500', () {
        final res = EgyptianExpenseParser.parse('صرفت الفين وخمسمية في كارفور');
        expect(res.length, equals(1));
        expect(res.first.category, equals('أخرى'));
        expect(res.first.amount, equals(2500));
      });

      test('35. "اجرة الميكروباص تمانية جنيه" → مواصلات 8', () {
        final res = EgyptianExpenseParser.parse('اجرة الميكروباص تمانية جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, equals('مواصلات'));
        expect(res.first.amount, equals(8));
      });

      test('36. "طلبنا بيتزا بتلتمية وخمسين" → أخرى 350', () {
        final res = EgyptianExpenseParser.parse('طلبنا بيتزا بتلتمية وخمسين');
        expect(res.length, equals(1));
        expect(res.first.category, equals('أخرى'));
        expect(res.first.amount, equals(350));
      });

      test('37. "دفعت كارته الطريق عشرين جنيه" → مواصلات 20', () {
        final res = EgyptianExpenseParser.parse('دفعت كارته الطريق عشرين جنيه');
        expect(res.length, equals(1));
        expect(res.first.category, equals('مواصلات'));
        expect(res.first.amount, equals(20));
      });

      test('38. "شريت علاج بميتين وخمسين" → أخرى 250', () {
        final res = EgyptianExpenseParser.parse('شريت علاج بميتين وخمسين');
        expect(res.length, equals(1));
        expect(res.first.category, equals('أخرى'));
        expect(res.first.amount, equals(250));
      });
    },
  );

  group('Step 6: Custom Category Matching & Performance', () {
    test('Matches custom category when present in sentence', () {
      final res = EgyptianExpenseParser.parse(
        'اشتريت روايات بسبعين',
        customCategories: ['روايات'],
      );
      expect(res.length, equals(1));
      expect(res.first.category, equals('روايات'));
      expect(res.first.amount, equals(70));
    });

    test('Parser runs in less than 5 milliseconds (Prompt Rule 3)', () {
      // Warm up
      EgyptianExpenseParser.parse('ركبت ميكروباص بعشرة ورجعت بخمستاشر');

      final stopwatch = Stopwatch()..start();
      const iterations = 50;
      for (int i = 0; i < iterations; i++) {
        EgyptianExpenseParser.parse('ركبت ميكروباص بعشرة ورجعت بخمستاشر');
      }
      stopwatch.stop();
      final msPerParse = stopwatch.elapsedMilliseconds / iterations;
      expect(msPerParse, lessThan(5.0));
    });

    test('Sentence with no amount returns empty list', () {
      final res = EgyptianExpenseParser.parse('صباح الخير عامل ايه النهاردة');
      expect(res, isEmpty);
    });
  });

  group('Step 6: Voice Recording UI & Home Screen Integration Widget Tests', () {
    late AppDatabase db;
    late FakeSpeechRecognitionService fakeSpeech;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      fakeSpeech = FakeSpeechRecognitionService();

      // Seed a budget for 2026-11 so auto-open budget sheet doesn't pop up during test
      await db
          .into(db.monthBudgets)
          .insert(
            MonthBudgetsCompanion.insert(yearMonth: '2026-11', amount: 1000000),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('ar'),
          theme: AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: HomeScreen(),
            floatingActionButton: HomeSpeedDialFab(),
          ),
        ),
      );
    }

    testWidgets(
      'Tapping mic starts recording, changes FAB to stop button with soft rings',
      (tester) async {
        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        // Find the main '+' button
        final addIcon = find.byIcon(Icons.add);
        expect(addIcon, findsOneWidget);

        // Tap '+' to open speed dial
        await tester.tap(addIcon);
        await tester.pumpAndSettle();

        // Mic button should now be visible
        final micIcon = find.byIcon(Icons.mic_none_rounded);
        expect(micIcon, findsOneWidget);

        // Tap mic button
        await tester.tap(micIcon);
        await tester.pump();

        // Recording should now be active
        expect(container.read(voiceRecordingProvider), isTrue);

        // Main '+' button should be replaced by stop button with stop icon
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        // Recording should be false again
        expect(container.read(voiceRecordingProvider), isFalse);
        expect(find.byIcon(Icons.add), findsOneWidget);
      },
    );

    testWidgets(
      'Voice recognition parses and saves expense with source "voice" and updates Home',
      (tester) async {
        fakeSpeech.wordsToEmit = 'صرفت ١٥٠ جنيه غدا';

        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        // Tap '+'
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Tap mic
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();
        expect(container.read(voiceRecordingProvider), isTrue);

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        // Check database: expense should be saved with source: 'voice'
        final allTransactions = await db.select(db.transactions).get();
        expect(allTransactions.length, equals(1));
        expect(
          allTransactions.first.amount,
          equals(15000),
        ); // 150 EGP in piastres
        expect(allTransactions.first.description, equals('غدا'));
        expect(allTransactions.first.source, equals('voice'));

        // Home screen "آخر المصاريف" should display "غدا"
        expect(find.text('غدا'), findsOneWidget);
        expect(find.text('١٥٠ جنيه'), findsOneWidget);
      },
    );

    testWidgets(
      'If no amount found, shows snackbar "ماسمعتش مبلغ، جرّب تاني" and saves nothing',
      (tester) async {
        fakeSpeech.wordsToEmit = 'صباح الخير ازيكم';

        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        // Open speed dial and tap mic
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        // Verify no transaction was saved
        final allTransactions = await db.select(db.transactions).get();
        expect(allTransactions, isEmpty);

        // Verify snackbar is displayed with exact text
        expect(find.text('ماسمعتش مبلغ، جرّب تاني'), findsOneWidget);

        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.behavior, equals(SnackBarBehavior.floating));
        expect(snackBar.duration, equals(const Duration(seconds: 4)));
        expect((snackBar.margin as EdgeInsets).bottom, equals(84.0));
      },
    );

    testWidgets(
      'error_no_match or error_speech_timeout restarts listening silently without closing recording',
      (tester) async {
        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        expect(container.read(voiceRecordingProvider), isTrue);
        expect(fakeSpeech.listenCallCount, equals(1));

        // Android reports error_no_match (silence or no match)
        fakeSpeech.emitError(SpeechRecognitionError('error_no_match', false));
        // Wait for ~300ms delay in restart
        await tester.pump(const Duration(milliseconds: 350));

        // Still recording! Stop button is still visible, NO error snackbar shown!
        expect(container.read(voiceRecordingProvider), isTrue);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(fakeSpeech.listenCallCount, equals(2));

        // Android reports error_speech_timeout
        fakeSpeech.emitError(
          SpeechRecognitionError('error_speech_timeout', false),
        );
        await tester.pump(const Duration(milliseconds: 350));

        // Still recording!
        expect(container.read(voiceRecordingProvider), isTrue);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(find.byType(SnackBar), findsNothing);
        expect(fakeSpeech.listenCallCount, equals(3));

        // Now tap stop
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        expect(container.read(voiceRecordingProvider), isFalse);
      },
    );

    testWidgets(
      'Multi-chunk recognized parts are kept in memory and joined upon tapping stop',
      (tester) async {
        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        // Chunk 1: recognized words
        fakeSpeech.emitWords('اتغديت بتمانين', isFinal: true);
        // Status notListening fires when Android times out
        fakeSpeech.emitStatus('notListening');
        await tester.pump(const Duration(milliseconds: 350));

        expect(container.read(voiceRecordingProvider), isTrue);

        // Chunk 2: recognized words after silent restart
        fakeSpeech.emitWords('واتعشيت بخمسة وسبعين', isFinal: false);

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        expect(container.read(voiceRecordingProvider), isFalse);

        // Both expenses must be parsed and saved!
        final allTransactions = await db.select(db.transactions).get();
        expect(allTransactions.length, equals(2));

        expect(allTransactions[0].amount, equals(8000)); // 80 EGP
        expect(allTransactions[0].description, equals('غدا'));
        expect(allTransactions[0].source, equals('voice'));

        expect(allTransactions[1].amount, equals(7500)); // 75 EGP
        expect(allTransactions[1].description, equals('عشا'));
        expect(allTransactions[1].source, equals('voice'));
      },
    );

    testWidgets(
      'Session restart test: 4 operations, 15s pause, 5th operation, stop -> review sheet shows all 5 operations',
      (tester) async {
        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(false),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        // 1. First session: 4 operations spoken
        fakeSpeech.emitWords('70 مواصلات 50 مواصلات 60 فطار 10 بتنجان', isFinal: false);
        await tester.pump(const Duration(milliseconds: 100));

        // Session 1 ends (Android times out or sends notListening)
        fakeSpeech.emitStatus('notListening');
        await tester.pump(const Duration(milliseconds: 350));

        // 2. 15-second pause: simulated silence where recognizer times out
        fakeSpeech.emitError(SpeechRecognitionError('error_speech_timeout', false));
        await tester.pump(const Duration(seconds: 15));
        await tester.pump(const Duration(milliseconds: 350));

        // 3. Second session: 5th operation spoken
        fakeSpeech.emitWords('3000 جنيه لبس', isFinal: false);
        await tester.pump(const Duration(milliseconds: 100));

        // 4. Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        // 5. Review sheet is presented and displays all 5 operations!
        expect(find.byType(VoiceExpenseReviewSheet), findsOneWidget);
        expect(find.text('مراجعة وتأكيد المصاريف'), findsOneWidget);

        // Tap 'حفظ الكل' in review sheet
        final saveBtn = find.text('حفظ الكل');
        expect(saveBtn, findsOneWidget);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        // 6. Verify all 5 transactions were persisted into the database!
        final allTransactions = await db.select(db.transactions).get();
        expect(allTransactions.length, equals(5));
        final amounts = allTransactions.map((t) => t.amount).toList();
        expect(amounts, containsAll([7000, 5000, 6000, 1000, 300000]));
      },
    );

    testWidgets(
      'Real error (e.g. error_permission) terminates recording and shows "مقدرتش أسمعك، جرّب تاني"',
      (tester) async {
        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        expect(container.read(voiceRecordingProvider), isTrue);

        // Real error emitted from recognizer
        fakeSpeech.emitError(SpeechRecognitionError('error_permission', true));
        await tester.pumpAndSettle();

        // Recording immediately stopped
        expect(container.read(voiceRecordingProvider), isFalse);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // Exact text shown
        expect(find.text('مقدرتش أسمعك، جرّب تاني'), findsOneWidget);
        expect(find.text('ماسمعتش مبلغ، جرّب تاني'), findsNothing);

        // Verify floating snackbar attributes
        final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(snackBar.behavior, equals(SnackBarBehavior.floating));
        expect(snackBar.duration, equals(const Duration(seconds: 4)));
        expect((snackBar.margin as EdgeInsets).bottom, equals(84.0));
      },
    );

    testWidgets(
      'Speech service initialize failure shows "مقدرتش أسمعك، جرّب تاني"',
      (tester) async {
        fakeSpeech.shouldFailInitialize = true;

        final repository = ExpenseRepositoryImpl(db);
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
            skipVoiceReviewProvider.overrideWithValue(true),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createTestApp(container));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pumpAndSettle();

        expect(container.read(voiceRecordingProvider), isFalse);
        expect(find.text('مقدرتش أسمعك، جرّب تاني'), findsOneWidget);
        expect(find.text('ماسمعتش مبلغ، جرّب تاني'), findsNothing);
      },
    );
  });

  group('Approved Spec Change: Required Permanent Tests', () {
    test('1a. Multi-expense sentence with Western digits', () {
      final res = EgyptianExpenseParser.parse(
        'خرجت مع اصحابي اكلنا في تشيكن فاكتور دفعت 200 جنيه وشربت عصير ب 70 وروحت سينما ب 50 وركبت مواصلات ورجعت ب 30',
      );
      expect(res.length, equals(4));

      // 1: [أكل، أكل، 200، note null]
      expect(res[0].description, equals('أكل'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(200));
      expect(res[0].note, isNull);

      // 2: [عصير، مشروبات، 70]
      expect(res[1].description, equals('عصير'));
      expect(res[1].category, matches(RegExp(r'^مشروبات')));
      expect(res[1].amount, equals(70));
      expect(res[1].note, isNull);

      // 3: [سينما، ترفيه، 50]
      expect(res[2].description, equals('سينما'));
      expect(res[2].category, equals('ترفيه'));
      expect(res[2].amount, equals(50));
      expect(res[2].note, isNull);

      // 4: [مواصلات، مواصلات، 30]
      expect(res[3].description, equals('مواصلات'));
      expect(res[3].category, equals('مواصلات'));
      expect(res[3].amount, equals(30));
      expect(res[3].note, isNull);
    });

    test(
      '1b. The first sentence with Arabic-Indic digits gives identical result',
      () {
        final res = EgyptianExpenseParser.parse(
          'خرجت مع اصحابي اكلنا في تشيكن فاكتور دفعت ٢٠٠ جنيه وشربت عصير ب ٧٠ وروحت سينما ب ٥٠ وركبت مواصلات ورجعت ب ٣٠',
        );
        expect(res.length, equals(4));

        expect(res[0].description, equals('أكل'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(200));
        expect(res[0].note, isNull);

        expect(res[1].description, equals('عصير'));
        expect(res[1].category, equals('مشروبات وكافيهات'));
        expect(res[1].amount, equals(70));
        expect(res[1].note, isNull);

        expect(res[2].description, equals('سينما'));
        expect(res[2].category, equals('ترفيه'));
        expect(res[2].amount, equals(50));
        expect(res[2].note, isNull);

        expect(res[3].description, equals('مواصلات'));
        expect(res[3].category, equals('مواصلات'));
        expect(res[3].amount, equals(30));
        expect(res[3].note, isNull);
      },
    );

    test('1c. The first sentence with number words gives identical result', () {
      final res = EgyptianExpenseParser.parse(
        'خرجت مع اصحابي اكلنا في تشيكن فاكتور دفعت ميتين جنيه وشربت عصير بسبعين وروحت سينما بخمسين وركبت مواصلات ورجعت بتلاتين',
      );
      expect(res.length, equals(4));

      expect(res[0].description, equals('أكل'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(200));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('عصير'));
      expect(res[1].category, matches(RegExp(r'^مشروبات')));
      expect(res[1].amount, equals(70));
      expect(res[1].note, isNull);

      expect(res[2].description, equals('سينما'));
      expect(res[2].category, equals('ترفيه'));
      expect(res[2].amount, equals(50));
      expect(res[2].note, isNull);

      expect(res[3].description, equals('مواصلات'));
      expect(res[3].category, equals('مواصلات'));
      expect(res[3].amount, equals(30));
      expect(res[3].note, isNull);
    });

    test('2. "اكلت في كشري بركات بخمسين وشربت عصير بتلاتين"', () {
      final res = EgyptianExpenseParser.parse(
        'اكلت في كشري بركات بخمسين وشربت عصير بتلاتين',
      );
      expect(res.length, equals(2));

      // [كشري، أكل، 50، note null]
      expect(res[0].description, equals('كشري'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(50));
      expect(res[0].note, isNull);

      // [عصير، مشروبات، 30]
      expect(res[1].description, equals('عصير'));
      expect(res[1].category, matches(RegExp(r'^مشروبات')));
      expect(res[1].amount, equals(30));
      expect(res[1].note, isNull);
    });

    test('3. "جبت غدا ب 20 جنيه" gives [غدا، أكل، 20]', () {
      final res = EgyptianExpenseParser.parse('جبت غدا ب 20 جنيه');
      expect(res.length, equals(1));
      expect(res.first.description, equals('غدا'));
      expect(res.first.category, equals('أكل'));
      expect(res.first.amount, equals(20));
      expect(res.first.note, isNull);
    });

    test('4. "قعدت على الكافيه صرفت 50 جنيه" gives [قهوة، مشروبات، 50]', () {
      final res = EgyptianExpenseParser.parse('قعدت على الكافيه صرفت 50 جنيه');
      expect(res.length, equals(1));
      expect(res.first.description, equals('قهوة'));
      expect(res.first.category, matches(RegExp(r'^مشروبات')));
      expect(res.first.amount, equals(50));
      expect(res.first.note, isNull);
    });

    test(
      '5. "اتغديت بتمانين واتعشيت بخمسة وسبعين" gives [غدا، أكل، 80] + [عشا، أكل، 75]',
      () {
        final res = EgyptianExpenseParser.parse(
          'اتغديت بتمانين واتعشيت بخمسة وسبعين',
        );
        expect(res.length, equals(2));
        expect(res[0].description, equals('غدا'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(80));

        expect(res[1].description, equals('عشا'));
        expect(res[1].category, equals('أكل'));
        expect(res[1].amount, equals(75));
      },
    );

    test('6. "دفعت ميتين جنيه للميكانيكي" gives [ميكانيكي، أخرى، 200]', () {
      final res = EgyptianExpenseParser.parse('دفعت ميتين جنيه للميكانيكي');
      expect(res.length, equals(1));
      expect(res.first.description, equals('ميكانيكي'));
      expect(res.first.category, equals('أخرى'));
      expect(res.first.amount, equals(200));
      expect(res.first.note, isNull);
    });

    test('If amount is found but no name, uses category name', () {
      final res = EgyptianExpenseParser.parse('دفعت خمسين جنيه');
      expect(res.length, equals(1));
      expect(res.first.category, equals('أخرى'));
      expect(res.first.description, equals('أخرى'));
      expect(res.first.amount, equals(50));
    });
  });

  group('Approved Spec Change: 15 Additional Varied Egyptian Sentences', () {
    test('1. "فطرت في فول محروس بخمسة وعشرين وركبت اوبر بخمسين"', () {
      final res = EgyptianExpenseParser.parse(
        'فطرت في فول محروس بخمسة وعشرين وركبت اوبر بخمسين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('فطار'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(25));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('أوبر'));
      expect(res[1].category, equals('مواصلات'));
      expect(res[1].amount, equals(50));
      expect(res[1].note, isNull);
    });

    test('2. "اتغدينا في واحة خطاب بتلتمية جنيه ودفعنا خمسين ملاهي"', () {
      final res = EgyptianExpenseParser.parse(
        'اتغدينا في واحة خطاب بتلتمية جنيه ودفعنا خمسين ملاهي',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('غدا'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(300));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('ملاهي'));
      expect(res[1].category, equals('ترفيه'));
      expect(res[1].amount, equals(50));
      expect(res[1].note, isNull);
    });

    test('3. "شربنا قهوة في بن العميد باربعين ودخلنا فيلم بستين"', () {
      final res = EgyptianExpenseParser.parse(
        'شربنا قهوة في بن العميد باربعين ودخلنا فيلم بستين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('قهوة'));
      expect(res[0].category, matches(RegExp(r'^مشروبات')));
      expect(res[0].amount, equals(40));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('فيلم'));
      expect(res[1].category, equals('ترفيه'));
      expect(res[1].amount, equals(60));
      expect(res[1].note, isNull);
    });

    test('4. "دفعت فاتورة الكهربا ربعمية جنيه وعملت صدقة بخمسين"', () {
      final res = EgyptianExpenseParser.parse(
        'دفعت فاتورة الكهربا ربعمية جنيه وعملت صدقة بخمسين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('فاتورة'));
      expect(res[0].category, matches(RegExp(r'^فواتير')));
      expect(res[0].amount, equals(400));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('صدقة'));
      expect(res[1].category, equals('صدقات'));
      expect(res[1].amount, equals(50));
      expect(res[1].note, isNull);
    });

    test('5. "اشتريت علاج في صيدلية العزبي ب 120 وركبت تاكسي ب 35"', () {
      final res = EgyptianExpenseParser.parse(
        'اشتريت علاج في صيدلية العزبي ب 120 وركبت تاكسي ب 35',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('علاج'));
      expect(res[0].category, equals('أخرى'));
      expect(res[0].amount, equals(120));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('تاكسي'));
      expect(res[1].category, equals('مواصلات'));
      expect(res[1].amount, equals(35));
      expect(res[1].note, isNull);
    });

    test('6. "لعبنا بلايستيشن في جيم اوفر بستين وطلبنا عشا بمية وعشرين"', () {
      final res = EgyptianExpenseParser.parse(
        'لعبنا بلايستيشن في جيم اوفر بستين وطلبنا عشا بمية وعشرين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('بلايستيشن'));
      expect(res[0].category, equals('ترفيه'));
      expect(res[0].amount, equals(60));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('عشا'));
      expect(res[1].category, equals('أكل'));
      expect(res[1].amount, equals(120));
      expect(res[1].note, isNull);
    });

    test('7. "اتعشيت في برجر كينج بمية وخمسين ورجعت بميكروباص بعشرة"', () {
      final res = EgyptianExpenseParser.parse(
        'اتعشيت في برجر كينج بمية وخمسين ورجعت بميكروباص بعشرة',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('عشا'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(150));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('ميكروباص'));
      expect(res[1].category, equals('مواصلات'));
      expect(res[1].amount, equals(10));
      expect(res[1].note, isNull);
    });

    test('8. "دفعت اشتراك الجيم خمسمية وسددت قسط الف وميتين"', () {
      final res = EgyptianExpenseParser.parse(
        'دفعت اشتراك الجيم خمسمية وسددت قسط الف وميتين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('اشتراك'));
      expect(res[0].category, equals('اشتراكات'));
      expect(res[0].amount, equals(500));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('قسط'));
      expect(res[1].category, equals('ديون وأقساط'));
      expect(res[1].amount, equals(1200));
      expect(res[1].note, isNull);
    });

    test('9. "روحت رحلة في وادي دجلة بميتين وشربت عصير بخمسة وعشرين"', () {
      final res = EgyptianExpenseParser.parse(
        'روحت رحلة في وادي دجلة بميتين وشربت عصير بخمسة وعشرين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('رحلة'));
      expect(res[0].category, equals('ترفيه'));
      expect(res[0].amount, equals(200));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('عصير'));
      expect(res[1].category, matches(RegExp(r'^مشروبات')));
      expect(res[1].amount, equals(25));
      expect(res[1].note, isNull);
    });

    test('10. "ركبت مترو بسبعة جنيه واشتريت كتب بستين جنيه"', () {
      final res = EgyptianExpenseParser.parse(
        'ركبت مترو بسبعة جنيه واشتريت كتب بستين جنيه',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('مترو'));
      expect(res[0].category, equals('مواصلات'));
      expect(res[0].amount, equals(7));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('كتب'));
      expect(res[1].category, equals('أخرى'));
      expect(res[1].amount, equals(60));
      expect(res[1].note, isNull);
    });

    test(
      '11. "صرفت عند كشري التحرير خمسة وخمسين وقعدت في كافيه دفعنا تمانين"',
      () {
        final res = EgyptianExpenseParser.parse(
          'صرفت عند كشري التحرير خمسة وخمسين وقعدت في كافيه دفعنا تمانين',
        );
        expect(res.length, equals(2));
        expect(res[0].description, equals('كشري'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(55));
        expect(res[0].note, isNull);

        expect(res[1].description, equals('قهوة'));
        expect(res[1].category, matches(RegExp(r'^مشروبات')));
        expect(res[1].amount, equals(80));
      },
    );

    test('12. "دفعت فاتورة النت تلتمية وخمسين وحولت سلف لصاحبي ميتين"', () {
      final res = EgyptianExpenseParser.parse(
        'دفعت فاتورة النت تلتمية وخمسين وحولت سلف لصاحبي ميتين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('فاتورة'));
      expect(res[0].category, matches(RegExp(r'^فواتير')));
      expect(res[0].amount, equals(350));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('سلف'));
      expect(res[1].category, equals('ديون وأقساط'));
      expect(res[1].amount, equals(200));
      expect(res[1].note, isNull);
    });

    test('13. "حجزنا كورة في الملعب بمية وخمسين وركبنا مواصلات بعشرين"', () {
      final res = EgyptianExpenseParser.parse(
        'حجزنا كورة في الملعب بمية وخمسين وركبنا مواصلات بعشرين',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('كورة'));
      expect(res[0].category, equals('ترفيه'));
      expect(res[0].amount, equals(150));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('مواصلات'));
      expect(res[1].category, equals('مواصلات'));
      expect(res[1].amount, equals(20));
      expect(res[1].note, isNull);
    });

    test('14. "اشتريت لحمة بربعمية وجبت فاكهة بمية"', () {
      final res = EgyptianExpenseParser.parse(
        'اشتريت لحمة بربعمية وجبت فاكهة بمية',
      );
      expect(res.length, equals(2));
      expect(res[0].description, equals('لحمة'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(400));
      expect(res[0].note, isNull);

      expect(res[1].description, equals('فاكهة'));
      expect(res[1].category, equals('أكل'));
      expect(res[1].amount, equals(100));
      expect(res[1].note, isNull);
    });

    test(
      '15. "فطرنا عند ابو طارق باربعين ودخلنا مسرح بميتين وخمسين وركبنا تاكسي باربعين"',
      () {
        final res = EgyptianExpenseParser.parse(
          'فطرنا عند ابو طارق باربعين ودخلنا مسرح بميتين وخمسين وركبنا تاكسي باربعين',
        );
        expect(res.length, equals(3));
        expect(res[0].description, equals('فطار'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(40));
        expect(res[0].note, isNull);

        expect(res[1].description, equals('مسرح'));
        expect(res[1].category, equals('ترفيه'));
        expect(res[1].amount, equals(250));
        expect(res[1].note, isNull);

        expect(res[2].description, equals('تاكسي'));
        expect(res[2].category, equals('مواصلات'));
        expect(res[2].amount, equals(40));
        expect(res[2].note, isNull);
      },
    );
  });

  group('Approved Spec Change: Category Details Stream and Note Display', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createCategoryScreen(
      ProviderContainer container,
      CategoryDetailsArgs args,
    ) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CategoryDetailsScreen(args: args),
        ),
      );
    }

    testWidgets(
      'Voice transaction with note appears on CategoryDetailsScreen day and month streams',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
          ],
        );
        addTearDown(container.dispose);

        final categories = await repository.getCategories();
        final foodCategory = categories.firstWhere((c) => c.name == 'أكل');

        final targetDate = DateTime.utc(2026, 11, 5, 14, 30);
        final dayArgs = CategoryDetailsArgs(
          category: foodCategory,
          yearMonth: '2026-11',
          day: targetDate,
          isMonthMode: false,
        );

        await tester.pumpWidget(createCategoryScreen(container, dayArgs));
        await tester.pumpAndSettle();

        // Initially empty
        expect(find.text('تشيكن فاكتور'), findsNothing);

        // Add a voice transaction with a note through the repository
        await repository.addTransaction(
          amount: 20000, // 200 EGP
          categoryId: foodCategory.id,
          description: 'أكل',
          kind: 'expense',
          note: 'تشيكن فاكتور',
          source: 'voice',
          createdAt: targetDate,
        );

        // Reactive stream updates the UI
        await tester.pumpAndSettle();

        expect(find.text('أكل'), findsAtLeastNWidgets(1));
        expect(find.text('تشيكن فاكتور'), findsOneWidget);

        // Now verify month mode stream also displays the note
        final monthArgs = CategoryDetailsArgs(
          category: foodCategory,
          yearMonth: '2026-11',
          isMonthMode: true,
        );

        await tester.pumpWidget(createCategoryScreen(container, monthArgs));
        await tester.pumpAndSettle();

        expect(find.text('أكل'), findsAtLeastNWidgets(1));
        expect(find.text('تشيكن فاكتور'), findsOneWidget);
      },
    );
  });

  group('Task F: Permanent Diagnostic & Invariant Tests', () {
    test(
      '1. "اديت عمتي 2000 جنيه صدقة" gives exactly [صدقة، صدقات، 2000], no note',
      () {
        final res = EgyptianExpenseParser.parse('اديت عمتي 2000 جنيه صدقة');
        expect(res.length, equals(1));
        expect(res[0].description, equals('صدقة'));
        expect(res[0].category, equals('صدقات'));
        expect(res[0].amount, equals(2000));
        expect(res[0].note, isNull);
      },
    );

    test('1b. "صرفت 200 جنيه غدا" gives exactly [غدا، أكل، 200], no note', () {
      final res = EgyptianExpenseParser.parse('صرفت 200 جنيه غدا');
      expect(res.length, equals(1));
      expect(res[0].description, equals('غدا'));
      expect(res[0].category, equals('أكل'));
      expect(res[0].amount, equals(200));
      expect(res[0].note, isNull);
    });

    test(
      '1c. "دفعت 2000 جنيه في بيت عمتي" gives exactly [أخرى، أخرى، 2000], no note',
      () {
        final res = EgyptianExpenseParser.parse('دفعت 2000 جنيه في بيت عمتي');
        expect(res.length, equals(1));
        expect(res[0].description, equals('أخرى'));
        expect(res[0].category, equals('أخرى'));
        expect(res[0].amount, equals(2000));
        expect(res[0].note, isNull);
      },
    );

    test(
      '1d. "جبت بنزين بميتين" gives exactly [بنزين، سيارة، 200], no note',
      () {
        final res = EgyptianExpenseParser.parse('جبت بنزين بميتين');
        expect(res.length, equals(1));
        expect(res[0].description, equals('بنزين'));
        expect(res[0].category, equals('سيارة'));
        expect(res[0].amount, equals(200));
        expect(res[0].note, isNull);
      },
    );

    test(
      '2. "اديت عمتي رضا 2000 جنيه صدقة" gives exactly [صدقة، صدقات، 2000], no note',
      () {
        final res = EgyptianExpenseParser.parse('اديت عمتي رضا 2000 جنيه صدقة');
        expect(res.length, equals(1));
        expect(res[0].description, equals('صدقة'));
        expect(res[0].category, equals('صدقات'));
        expect(res[0].amount, equals(2000));
        expect(res[0].note, isNull);
      },
    );

    test(
      '3. "صرفت 300 جنيه غدا و70 جنيه عصير و30 و50 جنيه مواصلات" gives [غدا 300, عصير 70, مواصلات 30, مواصلات 50], sum 450',
      () {
        final res = EgyptianExpenseParser.parse(
          'صرفت 300 جنيه غدا و70 جنيه عصير و30 و50 جنيه مواصلات',
        );
        expect(res.length, equals(4));

        expect(res[0].description, equals('غدا'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(300));
        expect(res[0].note, isNull);

        expect(res[1].description, equals('عصير'));
        expect(res[1].category, equals('مشروبات وكافيهات'));
        expect(res[1].amount, equals(70));
        expect(res[1].note, isNull);

        expect(res[2].description, equals('أخرى'));
        expect(res[2].category, equals('أخرى'));
        expect(res[2].amount, equals(30));
        expect(res[2].note, isNull);

        expect(res[3].description, equals('مواصلات'));
        expect(res[3].category, equals('مواصلات'));
        expect(res[3].amount, equals(50));
        expect(res[3].note, isNull);

        final totalSum = res.fold<int>(0, (sum, item) => sum + (item.amount ?? 0));
        expect(totalSum, equals(450));
      },
    );

    test(
      '4. "جبت غدا النهاردة ب 200 جنيه من التشيكن فاكتوري" gives exactly [غدا، أكل، 200], no note',
      () {
        final res = EgyptianExpenseParser.parse(
          'جبت غدا النهاردة ب 200 جنيه من التشيكن فاكتوري',
        );
        expect(res.length, equals(1));
        expect(res[0].description, equals('غدا'));
        expect(res[0].category, equals('أكل'));
        expect(res[0].amount, equals(200));
        expect(res[0].note, isNull);
      },
    );

    test('5. Arabic-Indic digits and number words give identical amounts', () {
      // 5a. Charity with Arabic-Indic digits
      final resCharityIndic = EgyptianExpenseParser.parse(
        'اديت عمتي ٢٠٠٠ جنيه صدقة',
      );
      expect(resCharityIndic.length, equals(1));
      expect(resCharityIndic[0].amount, equals(2000));
      expect(resCharityIndic[0].category, equals('صدقات'));
      expect(resCharityIndic[0].description, equals('صدقة'));
      expect(resCharityIndic[0].note, isNull);

      // 5b. Charity with number words
      final resCharityWords = EgyptianExpenseParser.parse(
        'اديت عمتي الفين جنيه صدقة',
      );
      expect(resCharityWords.length, equals(1));
      expect(resCharityWords[0].amount, equals(2000));
      expect(resCharityWords[0].category, equals('صدقات'));
      expect(resCharityWords[0].description, equals('صدقة'));
      expect(resCharityWords[0].note, isNull);

      // 5c. Multi-expense with Arabic-Indic digits
      final resMultiIndic = EgyptianExpenseParser.parse(
        'صرفت ٣٠٠ جنيه غدا و٧٠ جنيه عصير و٣٠ و٥٠ جنيه مواصلات',
      );
      expect(resMultiIndic.length, equals(4));
      expect(
        resMultiIndic.map((e) => e.amount).toList(),
        equals([300, 70, 30, 50]),
      );
      expect(resMultiIndic.fold<int>(0, (s, e) => s + (e.amount ?? 0)), equals(450));
      expect(resMultiIndic.map((e) => e.note).every((n) => n == null), isTrue);

      // 5d. Multi-expense with number words
      final resMultiWords = EgyptianExpenseParser.parse(
        'صرفت تلتمية جنيه غدا وسبعين جنيه عصير وتلاتين وخمسين جنيه مواصلات',
      );
      expect(resMultiWords.length, equals(4));
      expect(
        resMultiWords.map((e) => e.amount).toList(),
        equals([300, 70, 30, 50]),
      );
      expect(resMultiWords.fold<int>(0, (s, e) => s + (e.amount ?? 0)), equals(450));
      expect(resMultiWords.map((e) => e.note).every((n) => n == null), isTrue);

      // 5e. Food with Arabic-Indic digits
      final resFoodIndic = EgyptianExpenseParser.parse(
        'جبت غدا النهاردة ب ٢٠٠ جنيه من التشيكن فاكتوري',
      );
      expect(resFoodIndic.length, equals(1));
      expect(resFoodIndic[0].amount, equals(200));
      expect(resFoodIndic[0].category, equals('أكل'));
      expect(resFoodIndic[0].description, equals('غدا'));
      expect(resFoodIndic[0].note, isNull);

      // 5f. Food with number words
      final resFoodWords = EgyptianExpenseParser.parse(
        'جبت غدا النهاردة بميتين جنيه من التشيكن فاكتوري',
      );
      expect(resFoodWords.length, equals(1));
      expect(resFoodWords[0].amount, equals(200));
      expect(resFoodWords[0].category, equals('أكل'));
      expect(resFoodWords[0].description, equals('غدا'));
      expect(resFoodWords[0].note, isNull);
    });

    test(
      '6. Invariant test over 42 varied Egyptian sentences: count, sum, keywords, no notes',
      () {
        const testCases = <({String sentence, List<int> expectedAmounts})>[
          (sentence: 'صرفت ١٥٠ جنيه غدا', expectedAmounts: [150]),
          (sentence: 'دفعت ميتين جنيه للميكانيكي', expectedAmounts: [200]),
          (sentence: 'اشتريت خضار بخمسين', expectedAmounts: [50]),
          (
            sentence: 'ركبت ميكروباص بعشرة ورجعت بخمستاشر',
            expectedAmounts: [10, 15],
          ),
          (
            sentence: 'رحت القاهرة بخمسين ورجعت الشرقية بمية',
            expectedAmounts: [50, 100],
          ),
          (sentence: 'عملت صدقة بخمسين جنيه', expectedAmounts: [50]),
          (sentence: 'دفعت اشتراك الجيم ستمية', expectedAmounts: [600]),
          (sentence: 'فاتورة الكهربا ميت وخمسين', expectedAmounts: [150]),
          (
            sentence: 'اتغديت بتمانين واتعشيت بخمسة وسبعين',
            expectedAmounts: [80, 75],
          ),
          (sentence: 'جبت بنزين بتلتمية جنيه', expectedAmounts: [300]),
          (sentence: 'اشتريت جزمة بالف ومية', expectedAmounts: [1100]),
          (sentence: 'دفعت نص الف للكهربا', expectedAmounts: [500]),
          (sentence: 'صرفت الف ونص على الايجار', expectedAmounts: [1500]),
          (sentence: 'دفعت ٣٠ ج للتاكسي', expectedAmounts: [30]),
          (sentence: 'شربت قهوة بخمسة واربعين', expectedAmounts: [45]),
          (sentence: 'جبت عصير بعشرين', expectedAmounts: [20]),
          (
            sentence: 'شاورما بتسعين وكشري بخمسة وتلاتين',
            expectedAmounts: [90, 35],
          ),
          (sentence: 'دفعت فاتورة الغاز تمانين جنيه', expectedAmounts: [80]),
          (sentence: 'ركبت مترو بعشرة', expectedAmounts: [10]),
          (
            sentence: 'اشتريت فاكهة بمية وخمسين ولحمة بربعمية',
            expectedAmounts: [150, 400],
          ),
          (sentence: 'دفعت كفالة يتيم تلتمية جنيه', expectedAmounts: [300]),
          (sentence: 'اشتراك نتفلكس ميتين', expectedAmounts: [200]),
          (sentence: 'شحنت رصيد موبايل بمية', expectedAmounts: [100]),
          (sentence: 'اوبر للجامعة بخمسة واربعين', expectedAmounts: [45]),
          (sentence: 'جبت سندوتش باتناشر', expectedAmounts: [12]),
          (sentence: 'دفعت تلات تلاف ايجار', expectedAmounts: [3000]),
          (sentence: 'ربع الف زكاة', expectedAmounts: [250]),
          (sentence: 'سواق التاكسي اخد سبعين جنيه', expectedAmounts: [70]),
          (
            sentence: 'فطرت بخمسة وعشرين وشربت شاي بعشرة',
            expectedAmounts: [25, 10],
          ),
          (sentence: 'اشتراك سبوتيفاي تسعين', expectedAmounts: [90]),
          (sentence: 'فاتورة المياه ستين جنيه', expectedAmounts: [60]),
          (
            sentence: 'جبت كتب من المعرض بربعمية وخمسين',
            expectedAmounts: [450],
          ),
          (sentence: 'تبرع للجامع بميتين جنيه', expectedAmounts: [200]),
          (sentence: 'صرفت الفين وخمسمية في كارفور', expectedAmounts: [2500]),
          (sentence: 'اجرة الميكروباص تمانية جنيه', expectedAmounts: [8]),
          (sentence: 'طلبنا بيتزا بتلتمية وخمسين', expectedAmounts: [350]),
          (sentence: 'دفعت كارته الطريق عشرين جنيه', expectedAmounts: [20]),
          (sentence: 'شريت علاج بميتين وخمسين', expectedAmounts: [250]),
          (sentence: 'اديت عمتي 2000 جنيه صدقة', expectedAmounts: [2000]),
          (sentence: 'اديت عمتي رضا 2000 جنيه صدقة', expectedAmounts: [2000]),
          (
            sentence: 'صرفت 300 جنيه غدا و70 جنيه عصير و30 و50 جنيه مواصلات',
            expectedAmounts: [300, 70, 30, 50],
          ),
          (
            sentence: 'جبت غدا النهاردة ب 200 جنيه من التشيكن فاكتوري',
            expectedAmounts: [200],
          ),
        ];

        expect(testCases.length, greaterThanOrEqualTo(30));

        for (final tc in testCases) {
          final parsed = EgyptianExpenseParser.parse(tc.sentence);

          // Invariant (i): every spoken amount becomes exactly one item
          expect(
            parsed.length,
            equals(tc.expectedAmounts.length),
            reason: 'Count mismatch for "${tc.sentence}"',
          );

          // Invariant (ii): sum of items equals sum of spoken amounts
          final expectedSum = tc.expectedAmounts.reduce((a, b) => a + b);
          final actualSum = parsed.fold<int>(0, (s, e) => s + (e.amount ?? 0));
          expect(
            actualSum,
            equals(expectedSum),
            reason: 'Sum mismatch for "${tc.sentence}"',
          );

          // Invariant (iii) & (iv): every item name is recognized or category name, no notes
          for (int i = 0; i < parsed.length; i++) {
            final item = parsed[i];
            expect(item.amount, equals(tc.expectedAmounts[i]));
            expect(item.note, isNull, reason: 'Notes must be disabled (null)');
            expect(item.description, isNotEmpty);
            expect(item.category, isNotEmpty);
            expect(item.description, isNot(equals('عمتي')));
            expect(item.description, isNot(equals('عمتي رضا')));
            expect(item.description, isNot(equals('التشيكن فاكتوري')));
            expect(item.description, isNot(equals('النهاردة')));
          }
        }
      },
    );

    testWidgets(
      '7. Instant start: preInitialize prepares speech recognizer in advance without switching FAB prematurely',
      (tester) async {
        final localDb = AppDatabase(NativeDatabase.memory());
        addTearDown(localDb.close);

        // Seed a budget for 2026-11 so auto-open budget sheet does not pop up
        await localDb
            .into(localDb.monthBudgets)
            .insert(
              MonthBudgetsCompanion.insert(
                yearMonth: '2026-11',
                amount: 1000000,
              ),
            );

        final repository = ExpenseRepositoryImpl(localDb);
        final fakeSpeechLocal = FakeSpeechRecognitionService();

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(localDb),
            expenseRepositoryProvider.overrideWithValue(repository),
            speechRecognitionServiceProvider.overrideWithValue(fakeSpeechLocal),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('ar'),
              theme: AppTheme.lightTheme,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: const Scaffold(
                body: HomeScreen(),
                floatingActionButton: HomeSpeedDialFab(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Home screen postFrameCallback should pre-initialize since permission is granted
        expect(fakeSpeechLocal.isAvailable, isTrue);
        // But recording state must NOT be active
        expect(container.read(voiceRecordingProvider), isFalse);
        expect(find.byIcon(Icons.add), findsOneWidget);

        // Open "+" menu
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        // Tap mic button
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pump();

        // Recording switches to true only after recognizer starts listening
        expect(container.read(voiceRecordingProvider), isTrue);
        expect(fakeSpeechLocal.isListening, isTrue);

        // Tap stop button
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pumpAndSettle();

        expect(container.read(voiceRecordingProvider), isFalse);
        expect(fakeSpeechLocal.isListening, isFalse);
      },
    );
  });
}
