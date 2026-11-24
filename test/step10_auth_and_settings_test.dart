import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/database/connection/account_database_manager.dart';
import 'package:baqy/features/auth/domain/exceptions/auth_exceptions.dart';
import 'package:baqy/features/auth/domain/models/account_status.dart';
import 'package:baqy/features/auth/domain/models/auth_user.dart';
import 'package:baqy/features/auth/domain/repositories/auth_repository.dart';
import 'package:baqy/features/auth/presentation/providers/auth_providers.dart';
import 'package:baqy/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:baqy/features/auth/presentation/widgets/account_status_dialog.dart';
import 'package:baqy/features/expenses/domain/models/month_remaining.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/home/presentation/widgets/budget_bottom_sheet.dart';
import 'package:baqy/features/backup/presentation/providers/backup_providers.dart';
import 'package:baqy/features/settings/presentation/screens/settings_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

class FakeAppDatabase extends Fake implements AppDatabase {
  bool clearAllDataCalled = false;

  @override
  Future<void> clearAllData() async {
    clearAllDataCalled = true;
  }

  @override
  Future<void> close() async {}
}

class FakeAccountDatabaseManager extends Fake
    implements AccountDatabaseManager {
  @override
  Future<AppDatabase> openDatabaseForAccount(String accountId) async {
    return FakeAppDatabase();
  }
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.userToReturn,
    this.shouldThrowError = false,
    this.accountStatusToReturn = AccountStatus.active,
    this.errorToThrow,
  });

  AuthUser? userToReturn;
  bool shouldThrowError;
  AccountStatus accountStatusToReturn;
  Object? errorToThrow;
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();

  @override
  Stream<AuthUser?> get authStateChanges => _controller.stream;

  @override
  AuthUser? get currentUser => userToReturn;

  @override
  Future<AuthUser?> signInWithGoogle() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (shouldThrowError) {
      throw Exception('Network or auth error');
    }
    return userToReturn; // null means cancelled silently
  }

  @override
  Future<void> signOut() async {
    userToReturn = null;
    _controller.add(null);
  }

  @override
  Future<AccountStatus> checkAccountStatus() async {
    return accountStatusToReturn;
  }
}

Widget buildTestApp({
  required Widget child,
  required List<dynamic> overrides,
  Locale locale = const Locale('ar'),
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'signed-in user initializes account database and sets active database',
    () async {
      final fakeRepo = FakeAuthRepository(
        userToReturn: const AuthUser(
          uid: 'uid_12345',
          displayName: 'محمد إبراهيم',
          email: 'mohamed@example.com',
        ),
      );
      final fakeDbManager = FakeAccountDatabaseManager();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          accountDatabaseManagerProvider.overrideWithValue(fakeDbManager),
          appDatabaseProvider.overrideWithValue(FakeAppDatabase()),
        ],
      );

      final user = container.read(authRepositoryProvider).currentUser;
      expect(user, isNotNull);
      expect(user?.displayName, equals('محمد إبراهيم'));
      expect(user?.email, equals('mohamed@example.com'));

      final db = await fakeDbManager.openDatabaseForAccount(user!.uid);
      container.read(activeDatabaseProvider.notifier).setDatabase(db);
      container.read(activeUserIdProvider.notifier).setUserId(user.uid);

      expect(container.read(activeUserIdProvider), equals('uid_12345'));
      expect(container.read(activeDatabaseProvider), isNotNull);
    },
  );

  testWidgets('cancelled picker shows no error on sign-in screen', (
    tester,
  ) async {
    final fakeRepo = FakeAuthRepository(
      userToReturn: null,
      shouldThrowError: false,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const SignInScreen(),
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الدخول بحساب جوجل'), findsOneWidget);

    // Tap button (picker opens and is cancelled, returning null)
    await tester.tap(find.text('الدخول بحساب جوجل'));
    await tester.pumpAndSettle();

    // No error snackbar should appear
    expect(find.text('مقدرتش أسجّلك، جرّب تاني'), findsNothing);
  });

  testWidgets('failure shows the exact snackbar "مقدرتش أسجّلك، جرّب تاني"', (
    tester,
  ) async {
    final fakeRepo = FakeAuthRepository(shouldThrowError: true);

    await tester.pumpWidget(
      buildTestApp(
        child: const SignInScreen(),
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('الدخول بحساب جوجل'));
    await tester.pumpAndSettle();

    // Verification: exact snackbar appears
    expect(find.text('مقدرتش أسجّلك، جرّب تاني'), findsOneWidget);
  });

  testWidgets(
    'user profile card displays name, email and avatar in settings screen',
    (tester) async {
      final fakeRepo = FakeAuthRepository(
        userToReturn: const AuthUser(
          uid: 'uid_1',
          displayName: 'محمد إبراهيم',
          email: 'mohamed@test.com',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const SettingsScreen(),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            currentMonthRemainingProvider.overrideWith(
              (ref) async => const MonthRemaining(
                budget: 1000000,
                expenses: 200000,
                income: 0,
                goalSavings: 0,
                monthMoney: 1000000,
                remaining: 800000,
                yearMonth: '2026-11',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محمد إبراهيم'), findsOneWidget);
      expect(find.text('mohamed@test.com'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'signing out clears active database and user id in authController',
    (tester) async {
      final fakeRepo = FakeAuthRepository(
        userToReturn: const AuthUser(
          uid: 'uid_1',
          displayName: 'محمد',
          email: 'mohamed@test.com',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          accountDatabaseManagerProvider.overrideWithValue(
            FakeAccountDatabaseManager(),
          ),
        ],
      );

      container.read(activeUserIdProvider.notifier).setUserId('uid_1');
      expect(container.read(activeUserIdProvider), equals('uid_1'));

      await container.read(authControllerProvider.notifier).signOut();
      expect(container.read(activeUserIdProvider), isNull);
      expect(container.read(activeDatabaseProvider), isNull);
      expect(fakeRepo.currentUser, isNull);
    },
  );

  testWidgets('settings budget row opens budget sheet on tap "تعديل"', (
    tester,
  ) async {
    final fakeRepo = FakeAuthRepository(
      userToReturn: const AuthUser(uid: 'uid_1'),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: const SettingsScreen(),
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          currentMonthRemainingProvider.overrideWith(
            (ref) async => const MonthRemaining(
              budget: 500000, // 5,000 EGP
              expenses: 0,
              income: 0,
              goalSavings: 0,
              monthMoney: 500000,
              remaining: 500000,
              yearMonth: '2026-11',
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('تعديل'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();

    // Verification: Budget sheet opened
    expect(find.byType(BudgetBottomSheet), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
  });

  testWidgets(
    'disabled account on sign-in shows beautiful AccountStatusDialog with reason',
    (tester) async {
      final fakeRepo = FakeAuthRepository(
        errorToThrow: const AccountDisabledException(
          'تم تعطيل هذا الحساب من قِبل إدارة التطبيق لمراجعة النشاط أو لمخالفة شروط الاستخدام.',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const SignInScreen(),
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الدخول بحساب جوجل'));
      await tester.pumpAndSettle();

      // Verification: AccountStatusDialog appears with title and reason
      expect(find.byType(AccountStatusDialog), findsOneWidget);
      expect(find.text('تم تعطيل الحساب'), findsOneWidget);
      expect(find.text('إشعار من إدارة التطبيق'), findsOneWidget);
      expect(
        find.textContaining('تم تعطيل هذا الحساب من قِبل إدارة التطبيق'),
        findsOneWidget,
      );
      expect(find.text('تواصل مع الإدارة لإعادة تفعيل الحساب:'), findsOneWidget);
      expect(find.text('واتساب'), findsOneWidget);
      expect(find.text('جيميل'), findsOneWidget);
      expect(find.text('حسناً'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountStatusDialog), findsNothing);
    },
  );

  testWidgets(
    'deleted account on sign-in shows beautiful AccountStatusDialog with reason',
    (tester) async {
      final fakeRepo = FakeAuthRepository(
        errorToThrow: const AccountDeletedException(
          'تم حذف بيانات هذا الحساب نهائياً من قِبل إدارة التطبيق.',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const SignInScreen(),
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('الدخول بحساب جوجل'));
      await tester.pumpAndSettle();

      // Verification: AccountStatusDialog appears with deleted title and reason
      expect(find.byType(AccountStatusDialog), findsOneWidget);
      expect(find.text('تم حذف الحساب'), findsOneWidget);
      expect(find.text('إشعار من إدارة التطبيق'), findsOneWidget);
      expect(
        find.textContaining('تم حذف بيانات هذا الحساب نهائياً'),
        findsOneWidget,
      );

      expect(find.text('تواصل مع الإدارة لإعادة تفعيل الحساب:'), findsOneWidget);
      expect(find.text('واتساب'), findsOneWidget);
      expect(find.text('جيميل'), findsOneWidget);
      expect(find.text('حسناً'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountStatusDialog), findsNothing);
    },
  );

  testWidgets(
    'SettingsScreen reset data card displays styled card, dialog with warnings, and cancels or confirms',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fakeDb = FakeAppDatabase();
      final fakeRepo = FakeAuthRepository(
        userToReturn: const AuthUser(
          uid: 'uid_1',
          displayName: 'محمد',
          email: 'mohamed@test.com',
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const SettingsScreen(),
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            appDatabaseProvider.overrideWithValue(fakeDb),
            backupSyncControllerProvider.overrideWithValue(null),
            currentMonthRemainingProvider.overrideWith(
              (ref) async => const MonthRemaining(
                budget: 1000000,
                expenses: 200000,
                income: 0,
                goalSavings: 0,
                monthMoney: 1000000,
                remaining: 800000,
                yearMonth: '2026-11',
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to Reset Data card so it comes into view
      await tester.scrollUntilVisible(
        find.text('تصفير جميع البيانات'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Find the Reset Data card
      expect(find.text('تصفير جميع البيانات'), findsOneWidget);
      expect(find.text('حذف كافة المصاريف والديون والميزانيات للبدء من جديد'), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

      // Tap it
      await tester.tap(find.text('تصفير جميع البيانات'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears with detailed warnings
      expect(find.text('تصفير جميع البيانات؟'), findsOneWidget);
      expect(find.textContaining('هل أنت متأكد من رغبتك في حذف كافة البيانات'), findsOneWidget);
      expect(find.textContaining('سيتم مسح جميع المصاريف والمعاملات المسجلة'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تصفير البيانات'), findsOneWidget);

      // Tap "إلغاء" first
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Dialog dismissed and DB was not cleared
      expect(find.text('تصفير جميع البيانات؟'), findsNothing);
      expect(fakeDb.clearAllDataCalled, isFalse);

      // Tap again to confirm
      await tester.tap(find.text('تصفير جميع البيانات'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('تصفير البيانات'));
      await tester.pumpAndSettle();

      // Verified clearAllData was executed
      expect(fakeDb.clearAllDataCalled, isTrue);
    },
  );
}
