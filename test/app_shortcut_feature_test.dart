// ignore_for_file: depend_on_referenced_packages
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/services/app_shortcut_service.dart';
import 'package:baqy/features/auth/domain/models/account_status.dart';
import 'package:baqy/features/auth/domain/models/auth_user.dart';
import 'package:baqy/features/auth/domain/repositories/auth_repository.dart';
import 'package:baqy/features/auth/presentation/providers/auth_providers.dart';
import 'package:baqy/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:baqy/features/backup/domain/models/backup_meta.dart';
import 'package:baqy/features/backup/presentation/providers/backup_providers.dart';
import 'package:baqy/features/expenses/data/services/audio_recording_service.dart';
import 'package:baqy/features/expenses/data/services/gemini_expense_parser.dart';
import 'package:baqy/features/expenses/data/services/speech_recognition_service.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/domain/models/parsed_expense.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/widgets/voice_expense_review_sheet.dart';
import 'package:baqy/features/security/domain/models/security_settings.dart';
import 'package:baqy/features/security/domain/repositories/security_repository.dart';
import 'package:baqy/features/security/presentation/providers/security_providers.dart';
import 'package:baqy/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Test Doubles (Fakes)
// ---------------------------------------------------------------------------

class FakeAuthRepository extends Fake implements AuthRepository {
  AuthUser? user;

  FakeAuthRepository({this.user});

  @override
  AuthUser? get currentUser => user;

  @override
  Stream<AuthUser?> get authStateChanges => Stream.value(user);

  @override
  Future<AuthUser?> signInWithGoogle() async => user;

  @override
  Future<AccountStatus> checkAccountStatus() async => AccountStatus.active;

  @override
  Future<void> signOut() async {
    user = null;
  }
}

class FakeBackupRemoteDataSource implements BackupRemoteDataSource {
  BackupMeta? storedMeta;
  final Map<int, Uint8List> storedChunks = {};

  @override
  Future<BackupMeta?> getMeta(String uid) async => storedMeta;

  @override
  Future<List<Uint8List>> getChunks(String uid, int chunkCount) async => [];

  @override
  Future<void> uploadBackup({
    required String uid,
    required BackupMeta meta,
    required List<Uint8List> chunks,
    Map<String, dynamic>? readableSummary,
  }) async {}

  @override
  Future<void> deleteBackup(String uid) async {}

  @override
  Stream<BackupMeta?> watchMeta(String uid) => Stream.value(storedMeta);
}

class FakeSpeechRecognitionService implements SpeechRecognitionService {
  bool _isListening = false;
  @override
  bool get isListening => _isListening;
  @override
  Future<bool> get hasPermission async => true;
  @override
  bool get isAvailable => true;
  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(SpeechRecognitionError error)? onError,
  }) async => true;
  @override
  Future<void> listen({
    required void Function(String recognizedWords, {bool isFinal}) onResult,
    Duration? listenFor,
    Duration? pauseFor,
  }) async {
    _isListening = true;
  }
  @override
  Future<void> stop() async {
    _isListening = false;
  }
  @override
  Future<void> cancel() async {
    _isListening = false;
  }
}

class FakeSecurityRepository extends Fake implements SecurityRepository {
  FakeSecurityRepository({
    this.initialSettings = const SecuritySettings(
      isAppLockEnabled: false,
      hasPinSet: false,
    ),
  }) : settings = initialSettings;

  final SecuritySettings initialSettings;
  SecuritySettings settings;

  @override
  bool get isAppLockEnabledSync => settings.isAppLockEnabled;

  @override
  bool get isBiometricPromptActive => false;

  @override
  Future<SecuritySettings> getSettings() async => settings;

  @override
  Future<bool> isBiometricsAvailable() async => false;

  @override
  Future<bool> hasPin() async => false;
}

class FakeAudioRecordingService implements AudioRecordingService {
  final _amplitudeController = StreamController<double>.broadcast();
  bool fakeHasPermission = true;
  bool isRec = false;
  String? recordPath;

  @override
  bool get isRecording => isRec;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Future<bool> hasPermission() async => fakeHasPermission;

  @override
  Future<String?> startRecording({
    void Function()? onSafetyWarning,
    void Function(String path)? onMaxDurationReached,
  }) async {
    if (!fakeHasPermission) return null;
    isRec = true;
    return recordPath;
  }

  @override
  Future<String?> stopRecording() async {
    isRec = false;
    return recordPath;
  }

  @override
  Future<void> cancelRecording() async {
    isRec = false;
  }

  @override
  Future<void> dispose() async {
    await _amplitudeController.close();
  }
}

class FakeGeminiExpenseParser extends Fake implements GeminiExpenseParser {
  AudioParseResult? resultToReturn;
  String errorMessage = 'fake error';
  GeminiAudioErrorType errorType = GeminiAudioErrorType.none;

  @override
  String? get apiKey => 'fake_api_key';

  @override
  String get lastErrorMessage => errorMessage;

  @override
  GeminiAudioErrorType get lastAudioError => errorType;

  @override
  Future<AudioParseResult?> parseAudio(
    File audioFile, {
    List<CategoryItem> categories = const [],
    List<({int id, String keyword, String categoryName, int categoryId})>
        userRules = const [],
  }) async {
    return resultToReturn;
  }

  @override
  Future<void> warmUp() async {}
}

class FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  FakePathProviderPlatform(this.tempPath);
  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => tempPath;

  @override
  Future<String?> getApplicationSupportPath() async => tempPath;
}

class FakeActiveUserIdNotifier extends ActiveUserIdNotifier {
  FakeActiveUserIdNotifier(this._initial);
  final String? _initial;

  @override
  String? build() => _initial;
}

class FakeAppLockStateNotifier extends AppLockStateNotifier {
  FakeAppLockStateNotifier([this._initial = false]);
  final bool _initial;

  @override
  bool build() => _initial;
}

// ---------------------------------------------------------------------------
// Helper to pump UI in test environment
// ---------------------------------------------------------------------------
Widget createTestApp({
  required ProviderContainer container,
  required Widget child,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. ARB Translation Keys Consistency', () {
    test('app_ar.arb and app_en.arb must have identical keys', () {
      final arFile = File('lib/l10n/app_ar.arb');
      final enFile = File('lib/l10n/app_en.arb');

      expect(arFile.existsSync(), isTrue);
      expect(enFile.existsSync(), isTrue);

      final arMap = json.decode(arFile.readAsStringSync()) as Map<String, dynamic>;
      final enMap = json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;

      final arKeys = arMap.keys.toSet();
      final enKeys = enMap.keys.toSet();

      final missingInEn = arKeys.difference(enKeys);
      final missingInAr = enKeys.difference(arKeys);

      expect(missingInEn, isEmpty, reason: 'Keys in ar but missing in en: $missingInEn');
      expect(missingInAr, isEmpty, reason: 'Keys in en but missing in ar: $missingInAr');

      expect(arKeys.contains('shortcutExpenseRecordedSingle'), isTrue);
      expect(arKeys.contains('shortcutExpenseRecordedMultiple'), isTrue);
      expect(arKeys.contains('undo'), isTrue);
      expect(arKeys.contains('shortcutVoiceRecord'), isTrue);
    });
  });

  group('2. Android Manifest Permissions Verification', () {
    test('merged manifest contains no new permissions beyond existing baseline', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      final regex = RegExp(r'<uses-permission\s+android:name="([^"]+)"(?:\s+tools:node="remove")?');
      final matches = regex.allMatches(content);

      final permissions = <String>[];
      for (final m in matches) {
        final line = m.group(0)!;
        if (!line.contains('tools:node="remove"')) {
          permissions.add(m.group(1)!);
        }
      }

      const expectedAllowedPermissions = [
        'android.permission.RECORD_AUDIO',
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        'android.permission.USE_BIOMETRIC',
        'android.permission.USE_FINGERPRINT',
        'android.permission.FOREGROUND_SERVICE',
        'android.permission.FOREGROUND_SERVICE_MICROPHONE',
      ];

      for (final p in permissions) {
        expect(
          expectedAllowedPermissions.contains(p),
          isTrue,
          reason: 'Unexpected permission found in manifest: $p',
        );
      }
      expect(permissions.length, expectedAllowedPermissions.length);
    });
  });

  group('3. AppShortcutService Unit Tests', () {
    test('unknown or missing shortcut action is ignored', () async {
      final service = AppShortcutService.test();
      final receivedActions = <String>[];
      final sub = service.actionStream.listen(receivedActions.add);

      const channel = MethodChannel(AppShortcutService.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialShortcut') {
          return 'malicious_payload_action';
        }
        return null;
      });

      service.initialize();
      final initial = await service.checkInitialShortcut();
      expect(initial, isNull);

      // Send unknown action via channel mock
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', 'unknown_action_name'),
        ),
        (data) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedActions, isEmpty);

      // Null argument
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', null),
        ),
        (data) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedActions, isEmpty);

      await sub.cancel();
      service.dispose();
    });

    test('valid action "record_voice" is emitted and initial action is consumed', () async {
      final service = AppShortcutService.test();
      final receivedActions = <String>[];
      final sub = service.actionStream.listen(receivedActions.add);

      const channel = MethodChannel(AppShortcutService.channelName);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'getInitialShortcut') {
          return AppShortcutService.actionRecordVoice;
        }
        return null;
      });

      service.initialize();
      final initial = await service.checkInitialShortcut();
      expect(initial, equals(AppShortcutService.actionRecordVoice));

      // Trigger warm start action
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', AppShortcutService.actionRecordVoice),
        ),
        (data) {},
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(receivedActions, equals([AppShortcutService.actionRecordVoice]));

      await sub.cancel();
      service.dispose();
    });
  });

  group('4. Shortcut Voice Flow & Behavior Integration Tests', () {
    late AppDatabase db;
    late FakeAuthRepository fakeAuth;
    late FakeAudioRecordingService fakeAudio;
    late FakeSpeechRecognitionService fakeSpeech;
    late FakeGeminiExpenseParser fakeParser;
    late FakeBackupRemoteDataSource fakeBackupSource;
    late FakeSecurityRepository fakeSecurity;
    late Directory tempDir;

    setUp(() async {
      MainShellScreen.enableSecurityTimer = false;
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('shortcut_test_');
      PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
      db = AppDatabase(NativeDatabase.memory());
      fakeAuth = FakeAuthRepository(
        user: const AuthUser(
          uid: 'test_user_123',
          email: 'test@example.com',
          displayName: 'Test User',
        ),
      );
      fakeAudio = FakeAudioRecordingService();
      final defaultAudioFile = File('${tempDir.path}${Platform.pathSeparator}audio.m4a');
      defaultAudioFile.writeAsBytesSync(List.filled(100, 0));
      fakeAudio.recordPath = defaultAudioFile.path;
      fakeSpeech = FakeSpeechRecognitionService();
      fakeParser = FakeGeminiExpenseParser();
      fakeBackupSource = FakeBackupRemoteDataSource();
      fakeSecurity = FakeSecurityRepository();

      // Reset AppShortcutService test instance for clean isolation
      AppShortcutService.testInstance = AppShortcutService.test();
      AppShortcutService.instance.initialize();

      // Default mock handler for channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(AppShortcutService.channelName),
        (call) async {
          if (call.method == 'getInitialShortcut') return null;
          return null;
        },
      );

      // Seed current month budget and default category
      final now = DateTime.now();
      final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await db.into(db.monthBudgets).insert(
            MonthBudgetsCompanion.insert(
              yearMonth: ym,
              amount: 500000,
            ),
          );
      await db.into(db.categories).insert(
            CategoriesCompanion.insert(
              name: 'أكل ومشروبات',
              icon: 'restaurant',
              colorHex: '#2F6B5A',
            ),
          );
    });

    tearDown(() async {
      MainShellScreen.enableSecurityTimer = true;
      AppShortcutService.instance.dispose();
      await db.close();
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    dynamic createOverrides({String? userId = 'test_user_123'}) {
      return [
        appDatabaseProvider.overrideWithValue(db),
        authRepositoryProvider.overrideWithValue(fakeAuth),
        audioRecordingServiceProvider.overrideWithValue(fakeAudio),
        speechRecognitionServiceProvider.overrideWithValue(fakeSpeech),
        geminiExpenseParserProvider.overrideWithValue(fakeParser),
        backupRemoteDataSourceProvider.overrideWithValue(fakeBackupSource),
        backupSyncControllerProvider.overrideWithValue(null),
        activeUserIdProvider.overrideWith(() => FakeActiveUserIdNotifier(userId)),
        securityRepositoryProvider.overrideWithValue(fakeSecurity),
        isAppLockedProvider.overrideWith(() => FakeAppLockStateNotifier(false)),
      ];
    }

    testWidgets('not signed in starts no recording when shortcut triggers', (tester) async {
      fakeAuth.user = null; // Unauthenticated

      final container = ProviderContainer(
        overrides: createOverrides(userId: null),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger shortcut
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', AppShortcutService.actionRecordVoice),
        ),
        (data) {},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(voiceRecordingProvider), isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('permission refused starts no recording and shows feedback', (tester) async {
      fakeAudio.fakeHasPermission = false; // Denied permission

      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger shortcut
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', AppShortcutService.actionRecordVoice),
        ),
        (data) {},
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(container.read(voiceRecordingProvider), isFalse);
      expect(find.text('يرجى تفعيل إذن الميكروفون من الإعدادات لتسجيل المصاريف'), findsOneWidget);
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cold start shortcut starts recording once on app launch', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel(AppShortcutService.channelName),
        (call) async {
          if (call.method == 'getInitialShortcut') {
            return AppShortcutService.actionRecordVoice;
          }
          return null;
        },
      );

      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 150));
      expect(container.read(voiceRecordingProvider), isTrue);

      await container.read(voiceRecordingProvider.notifier).cancelRecording();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('valid shortcut starts recording once on warm start; second trigger does nothing', (tester) async {
      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Trigger warm start shortcut
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', AppShortcutService.actionRecordVoice),
        ),
        (data) {},
      );
      await tester.pump(const Duration(milliseconds: 150));

      expect(container.read(voiceRecordingProvider), isTrue);

      // Trigger second time while recording
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        AppShortcutService.channelName,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('onShortcutTriggered', AppShortcutService.actionRecordVoice),
        ),
        (data) {},
      );
      await tester.pump(const Duration(milliseconds: 150));

      // Still recording normally, not restarted or duplicated
      expect(container.read(voiceRecordingProvider), isTrue);

      // Cancel to clean up
      await container.read(voiceRecordingProvider.notifier).cancelRecording();
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await tester.pumpWidget(const SizedBox());
      expect(container.read(voiceRecordingProvider), isFalse);
    });

    testWidgets('clear parse result from shortcut is auto-saved and "تراجع" removes it', (tester) async {
      final audioFile = File('${tempDir.path}/test_clear.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));
      fakeAudio.recordPath = audioFile.path;

      // Provide clear result with amount, description, and high confidence
      fakeParser.resultToReturn = const AudioParseResult(
        transcript: 'اشتريت قهوة بخمسين',
        operations: [
          ParsedExpense(
            amount: 50,
            description: 'قهوة',
            category: 'أكل ومشروبات',
            confidence: 0.95,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Start recording via shortcut
      final notifier = container.read(voiceRecordingProvider.notifier);
      await notifier.startRecording(
        context: tester.element(find.byType(MainShellScreen)),
        isFromShortcut: true,
      );
      expect(container.read(voiceRecordingProvider), isTrue);
      expect(notifier.isFromShortcut, isTrue);

      // 2. Stop recording and let it process
      await notifier.stopRecording(context: tester.element(find.byType(MainShellScreen)));
      // Pump enough time for SnackBar animation to settle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      // 3. Verify auto-save: Expense is saved in database directly!
      final txs = await (db.select(db.transactions)).get();
      expect(txs.length, 1);
      expect(txs.first.description, 'قهوة');
      expect(txs.first.amount, 5000); // 50 EGP in piastres

      // 4. Verify Undo snackbar with "تراجع" button is showing
      expect(find.text('تم تسجيل 50 جنيه في أكل ومشروبات'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);

      // 5. Tap "تراجع"
      final undoAction = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      undoAction.onPressed();
      await tester.pump(const Duration(milliseconds: 100));

      // 6. Verify expense is removed from database
      final txsAfterUndo = await (db.select(db.transactions)).get();
      expect(txsAfterUndo, isEmpty);

      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).clearSnackBars();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('unclear parse result saves nothing and opens review sheet', (tester) async {
      final audioFile = File('${tempDir.path}${Platform.pathSeparator}test_unclear.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));
      fakeAudio.recordPath = audioFile.path;

      // Provide unclear result (needsReview = true due to low confidence or missing amount)
      fakeParser.resultToReturn = const AudioParseResult(
        transcript: 'حاجة مش مفهومة',
        operations: [
          ParsedExpense(
            amount: null, // No amount
            description: 'حاجة',
            category: 'أخرى',
            confidence: 0.3, // Low confidence
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Start recording via shortcut
      final notifier = container.read(voiceRecordingProvider.notifier);
      await notifier.startRecording(
        context: tester.element(find.byType(MainShellScreen)),
        isFromShortcut: true,
      );

      // 2. Stop recording and let it process (review sheet is shown modally, so do not block waiting for it to close)
      unawaited(notifier.stopRecording(context: tester.element(find.byType(MainShellScreen))));
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Verify NOTHING was saved
      final txs = await (db.select(db.transactions)).get();
      expect(txs, isEmpty);

      // 4. Verify VoiceExpenseReviewSheet was shown instead so user can fix it
      expect(find.byType(VoiceExpenseReviewSheet), findsOneWidget);

      Navigator.of(tester.element(find.byType(VoiceExpenseReviewSheet))).pop();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('normal microphone button keeps existing behavior (review sheet, not auto-save)', (tester) async {
      final audioFile = File('${tempDir.path}${Platform.pathSeparator}test_normal.m4a');
      audioFile.writeAsBytesSync(List.filled(200, 1));
      fakeAudio.recordPath = audioFile.path;

      fakeParser.resultToReturn = const AudioParseResult(
        transcript: 'قهوة بخمسين',
        operations: [
          ParsedExpense(
            amount: 50,
            description: 'قهوة',
            category: 'أكل ومشروبات',
            confidence: 0.95,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: createOverrides(),
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(
        container: container,
        child: const MainShellScreen(),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Start recording from normal button (isFromShortcut = false)
      final notifier = container.read(voiceRecordingProvider.notifier);
      await notifier.startRecording(
        context: tester.element(find.byType(MainShellScreen)),
        isFromShortcut: false,
      );
      expect(notifier.isFromShortcut, isFalse);

      // 2. Stop recording (review sheet is shown modally, so do not block waiting for it to close)
      unawaited(notifier.stopRecording(context: tester.element(find.byType(MainShellScreen))));
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Normal flow: Review sheet is opened, NOT auto-saved directly
      expect(find.byType(VoiceExpenseReviewSheet), findsOneWidget);

      // Database is still empty until user explicitly clicks save on review sheet
      final txs = await (db.select(db.transactions)).get();
      expect(txs, isEmpty);

      Navigator.of(tester.element(find.byType(VoiceExpenseReviewSheet))).pop();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
