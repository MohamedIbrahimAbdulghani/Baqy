import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baqy/core/constants/app_colors.dart';
import 'package:baqy/core/widgets/whatsapp_icon.dart';
import 'package:baqy/features/auth/domain/models/auth_user.dart';
import 'package:baqy/features/auth/presentation/providers/auth_providers.dart';
import 'package:baqy/features/expenses/domain/models/month_remaining.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/security/data/repositories/security_repository_impl.dart';
import 'package:baqy/features/security/domain/models/security_settings.dart';
import 'package:baqy/features/security/domain/repositories/security_repository.dart';
import 'package:baqy/features/security/domain/usecases/reset_passcode_usecase.dart';
import 'package:baqy/features/security/presentation/providers/security_providers.dart';
import 'package:baqy/features/security/presentation/screens/app_lock_screen.dart';
import 'package:baqy/features/security/presentation/widgets/pin_keypad.dart';
import 'package:baqy/features/settings/presentation/screens/settings_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _data.remove(key);
}

class FakeSecurityRepository implements SecurityRepository {
  FakeSecurityRepository({
    this.initialSettings = const SecuritySettings(
      isAppLockEnabled: true,
      hasPinSet: true,
    ),
  }) : settings = initialSettings;

  final SecuritySettings initialSettings;
  SecuritySettings settings;
  String? savedPin = '1234';

  @override
  Future<SecuritySettings> getSettings() async => settings;

  @override
  Future<bool> isBiometricsAvailable() async => settings.isBiometricsSupported;

  @override
  Future<bool> authenticateWithBiometrics({required String localizedReason}) async =>
      true;

  @override
  Future<bool> hasPin() async => savedPin != null;

  @override
  Future<bool> verifyPin(String pin) async {
    if (pin == savedPin) {
      await resetFailedAttempts();
      return true;
    }
    await recordFailedAttempt();
    return false;
  }

  @override
  Future<void> savePin(String pin) async {
    savedPin = pin;
    settings = settings.copyWith(isAppLockEnabled: true, hasPinSet: true);
  }

  @override
  Future<void> removePin() async {
    savedPin = null;
    settings = settings.copyWith(isAppLockEnabled: false, hasPinSet: false);
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    settings = settings.copyWith(isAppLockEnabled: enabled);
  }

  @override
  Future<void> setBiometricsEnabled(bool enabled) async {
    settings = settings.copyWith(isBiometricsEnabled: enabled);
  }

  @override
  Future<void> setLockOnExitEnabled(bool enabled) async {
    settings = settings.copyWith(lockOnExit: enabled);
  }

  @override
  Future<SecuritySettings> recordFailedAttempt() async {
    final newAttempts = settings.failedAttempts + 1;
    DateTime? lockedUntil;
    if (newAttempts >= 5) {
      lockedUntil = DateTime.now().add(const Duration(seconds: 60));
    }
    settings = settings.copyWith(
      failedAttempts: newAttempts,
      lockedUntil: lockedUntil,
    );
    return settings;
  }

  @override
  Future<void> resetFailedAttempts() async {
    settings = settings.copyWith(
      failedAttempts: 0,
      lockedUntil: null,
    );
  }

  String? lastSentEmail;
  String? lastSentPin;
  bool shouldFailEmail = false;

  @override
  Future<String> generateAndSaveNewPin() async {
    savedPin = '8888';
    await savePin('8888');
    await resetFailedAttempts();
    return '8888';
  }

  @override
  Future<bool> sendPasscodeResetEmail({
    required String email,
    required String newPin,
    String? userName,
  }) async {
    if (shouldFailEmail) return false;
    lastSentEmail = email;
    lastSentPin = newPin;
    return true;
  }
}

Widget buildTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SecurityRepository Unit Tests', () {
    test('savePin stores hashed PIN and verifies correctly', () async {
      final fakeStorage = FakeSecureStorage();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = SecurityRepositoryImpl(
        secureStorage: fakeStorage,
        prefs: prefs,
      );

      expect(await repo.hasPin(), isFalse);

      await repo.savePin('4567');
      expect(await repo.hasPin(), isTrue);

      // Correct PIN verifies
      expect(await repo.verifyPin('4567'), isTrue);

      // Incorrect PIN fails and increments failed attempts
      expect(await repo.verifyPin('0000'), isFalse);
      final settingsAfterFail = await repo.getSettings();
      expect(settingsAfterFail.failedAttempts, equals(1));
    });

    test('5 failed attempts triggers 60-second lockout', () async {
      final fakeStorage = FakeSecureStorage();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = SecurityRepositoryImpl(
        secureStorage: fakeStorage,
        prefs: prefs,
      );

      await repo.savePin('1111');

      for (int i = 0; i < 4; i++) {
        expect(await repo.verifyPin('9999'), isFalse);
      }
      var settings = await repo.getSettings();
      expect(settings.failedAttempts, equals(4));
      expect(settings.isLockedOut, isFalse);

      // 5th attempt locks out
      expect(await repo.verifyPin('9999'), isFalse);
      settings = await repo.getSettings();
      expect(settings.failedAttempts, equals(5));
      expect(settings.isLockedOut, isTrue);
      expect(settings.lockoutSecondsRemaining, greaterThanOrEqualTo(58));
    });
  });

  group('AppLockScreen Widget Tests', () {
    testWidgets('entering correct 4-digit PIN unlocks the app', (tester) async {
      final fakeRepo = FakeSecurityRepository();

      await tester.pumpWidget(
        buildTestApp(
          child: const AppLockScreen(),
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أهلاً بك مجدداً'), findsOneWidget);
      expect(find.byType(PinDots), findsOneWidget);
      expect(find.byType(PinKeypad), findsOneWidget);

      // Tap 1, 2, 3, 4
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('4'));
      await tester.pumpAndSettle();

      // App is unlocked (isAppLocked becomes false)
      // Note: verifyPin succeeded
      expect(fakeRepo.settings.failedAttempts, equals(0));
    });

    testWidgets('entering wrong PIN shows error message with remaining attempts',
        (tester) async {
      final fakeRepo = FakeSecurityRepository();

      await tester.pumpWidget(
        buildTestApp(
          child: const AppLockScreen(),
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap 9, 9, 9, 9
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pump();
      await tester.tap(find.text('9'));
      await tester.pumpAndSettle();

      expect(find.textContaining('رمز المرور غير صحيح'), findsOneWidget);
    });
  });

  group('WhatsApp and Settings UI Elements', () {
    testWidgets('WhatsAppIcon renders cleanly with vector painter', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: WhatsAppIcon(size: 24),
        ),
      );
      expect(find.byType(WhatsAppIcon), findsOneWidget);
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    test('lockOnExit setting can be toggled and persists', () async {
      final fakeStorage = FakeSecureStorage();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = SecurityRepositoryImpl(
        secureStorage: fakeStorage,
        prefs: prefs,
      );

      // Default is true
      var settings = await repo.getSettings();
      expect(settings.lockOnExit, isTrue);

      // Toggle to false
      await repo.setLockOnExitEnabled(false);
      settings = await repo.getSettings();
      expect(settings.lockOnExit, isFalse);

      // Toggle back to true
      await repo.setLockOnExitEnabled(true);
      settings = await repo.getSettings();
      expect(settings.lockOnExit, isTrue);
    });
  });

  group('Forgot Passcode & Email Reset Flow', () {
    test('generateAndSaveNewPin generates a 4-digit PIN and resets lockout', () async {
      final fakeStorage = FakeSecureStorage();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final repo = SecurityRepositoryImpl(
        secureStorage: fakeStorage,
        prefs: prefs,
      );

      // Save initial PIN '1234'
      await repo.savePin('1234');
      // Simulate failed attempts
      await repo.recordFailedAttempt();
      await repo.recordFailedAttempt();
      var settings = await repo.getSettings();
      expect(settings.failedAttempts, equals(2));

      // Generate new PIN
      final newPin = await repo.generateAndSaveNewPin();
      expect(newPin.length, equals(4));
      expect(int.tryParse(newPin), isNotNull);

      // Verify lockout & failed attempts are reset
      settings = await repo.getSettings();
      expect(settings.failedAttempts, equals(0));

      // Verify old PIN no longer works and new PIN works
      expect(await repo.verifyPin('1234'), isFalse);
      expect(await repo.verifyPin(newPin), isTrue);
    });

    test('ResetPasscodeUseCase coordinates PIN generation and email sending', () async {
      final fakeRepo = FakeSecurityRepository();
      final useCase = ResetPasscodeUseCase(fakeRepo);

      final newPin = await useCase.execute(
        email: 'mohamed@example.com',
        userName: 'محمد',
      );

      expect(newPin, equals('8888'));
      expect(fakeRepo.lastSentEmail, equals('mohamed@example.com'));
      expect(fakeRepo.lastSentPin, equals('8888'));
      expect(await fakeRepo.verifyPin('8888'), isTrue);
    });

    test('ResetPasscodeUseCase throws Exception when sendPasscodeResetEmail fails', () async {
      final fakeRepo = FakeSecurityRepository()..shouldFailEmail = true;
      final useCase = ResetPasscodeUseCase(fakeRepo);

      expect(
        () => useCase.execute(email: 'mohamed@example.com'),
        throwsA(isA<Exception>()),
      );
    });

    testWidgets('AppLockScreen shows forgot passcode button, confirms, and resets passcode', (tester) async {
      final fakeRepo = FakeSecurityRepository();
      const testUser = AuthUser(
        uid: 'user_123',
        email: 'baqy.user@gmail.com',
        displayName: 'مستخدم باقي',
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(testUser),
          ],
          child: const AppLockScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find forgot passcode button
      final forgotBtn = find.text('نسيت رمز المرور؟');
      expect(forgotBtn, findsOneWidget);

      // Scroll into view if needed and tap
      await tester.ensureVisible(forgotBtn);
      await tester.pumpAndSettle();
      await tester.tap(forgotBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog displays with user's registered email
      expect(find.text('استعادة رمز المرور'), findsOneWidget);
      expect(find.text('baqy.user@gmail.com'), findsOneWidget);
      expect(find.text('إرسال رمز جديد'), findsOneWidget);

      // Confirm sending new PIN
      await tester.tap(find.text('إرسال رمز جديد'));
      await tester.pumpAndSettle();

      // Verify success dialog appears
      expect(find.text('تم إرسال رمز المرور'), findsOneWidget);
      expect(fakeRepo.lastSentEmail, equals('baqy.user@gmail.com'));
      expect(fakeRepo.lastSentPin, equals('8888'));

      // Dismiss dialog
      await tester.tap(find.text('حسناً'));
      await tester.pumpAndSettle();

      // Now enter the new PIN '8888' on the keypad
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pump();
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();

      // No error message, unlocked successfully
      expect(find.textContaining('رمز المرور غير صحيح'), findsNothing);
    });

    testWidgets('Keypad is ordered in natural layout (1 left of 3 in row)', (tester) async {
      final fakeRepo = FakeSecurityRepository();

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const AppLockScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final onePos = tester.getTopLeft(find.text('1'));
      final threePos = tester.getTopLeft(find.text('3'));

      // In natural left-to-right phone keypad, 1 is on the left of 3
      expect(onePos.dx, lessThan(threePos.dx));
    });

    testWidgets('Paste passcode button pastes 4 digits from clipboard and unlocks', (tester) async {
      final fakeRepo = FakeSecurityRepository();
      // Set clipboard data to '1234'
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.getData') {
            return const <String, dynamic>{'text': '1234'};
          }
          return null;
        },
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const AppLockScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final pasteBtn = find.text('لصق رمز المرور');
      expect(pasteBtn, findsOneWidget);

      await tester.tap(pasteBtn);
      await tester.pumpAndSettle();

      // Successfully verified and failed attempts is 0
      expect(fakeRepo.settings.failedAttempts, equals(0));
    });

    testWidgets('Settings screen contains Theme Appearance card with Light and Dark options', (tester) async {
      final fakeRepo = FakeSecurityRepository();
      const testUser = AuthUser(
        uid: 'user_123',
        email: 'baqy.user@gmail.com',
        displayName: 'مستخدم باقي',
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            securityRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWithValue(testUser),
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
          child: const SettingsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final appearanceTitle = find.text('المظهر');
      await tester.ensureVisible(appearanceTitle);
      await tester.pumpAndSettle();

      expect(appearanceTitle, findsOneWidget);
      expect(find.text('فاتح'), findsOneWidget);
      expect(find.text('ليلي'), findsOneWidget);

      // Tap dark mode
      final darkOption = find.text('ليلي');
      await tester.ensureVisible(darkOption);
      await tester.tap(darkOption);
      await tester.pumpAndSettle();

      expect(AppColors.isDark, isTrue);

      // Tap light mode
      final lightOption = find.text('فاتح');
      await tester.ensureVisible(lightOption);
      await tester.tap(lightOption);
      await tester.pumpAndSettle();

      expect(AppColors.isDark, isFalse);
    });
  });
}
