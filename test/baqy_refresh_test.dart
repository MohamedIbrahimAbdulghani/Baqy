import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baqy/core/network/network_checker.dart';
import 'package:baqy/core/widgets/baqy_logo.dart';
import 'package:baqy/core/widgets/baqy_refresh.dart';
import 'package:baqy/features/auth/presentation/providers/auth_providers.dart';
import 'package:baqy/features/backup/presentation/controllers/backup_sync_controller.dart';
import 'package:baqy/features/backup/presentation/providers/backup_providers.dart';
import 'package:baqy/l10n/app_localizations.dart';

class FakeBackupSyncController extends Fake implements BackupSyncController {
  FakeBackupSyncController({required this.simulatedResult});

  final SyncRefreshResult simulatedResult;

  @override
  Future<SyncRefreshResult> syncOnManualRefresh({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return simulatedResult;
  }
}

Widget createTestApp({
  required Widget child,
  List<dynamic> overrides = const [],
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWithValue(null),
      ...overrides,
    ].cast(),
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    NetworkChecker.customChecker = null;
  });

  tearDown(() {
    NetworkChecker.customChecker = null;
  });

  group('BaqyRefresh & Localization Tests', () {
    test(
      'ARB files have the same keys including refreshOffline and refreshFailed',
      () {
        final arFile = File('lib/l10n/app_ar.arb');
        final enFile = File('lib/l10n/app_en.arb');

        expect(arFile.existsSync(), isTrue);
        expect(enFile.existsSync(), isTrue);

        final arMap =
            json.decode(arFile.readAsStringSync()) as Map<String, dynamic>;
        final enMap =
            json.decode(enFile.readAsStringSync()) as Map<String, dynamic>;

        expect(arMap.containsKey('refreshOffline'), isTrue);
        expect(arMap.containsKey('refreshFailed'), isTrue);
        expect(enMap.containsKey('refreshOffline'), isTrue);
        expect(enMap.containsKey('refreshFailed'), isTrue);

        expect(
          arMap['refreshOffline'],
          'مفيش اتصال، اتعرضت البيانات اللي على الموبايل',
        );
        expect(arMap['refreshFailed'], 'مقدرتش أحدّث، جرّب تاني');

        // Check key parity (excluding @ metadata keys)
        final arKeys = arMap.keys.where((k) => !k.startsWith('@')).toSet();
        final enKeys = enMap.keys.where((k) => !k.startsWith('@')).toSet();

        expect(arKeys, equals(enKeys));
      },
    );

    testWidgets(
      'Widget builds on a scrollable screen with custom logo inside RepaintBoundary',
      (tester) async {
        await tester.pumpWidget(
          createTestApp(
            child: BaqyRefresh(
              child: ListView(children: const [Text('عنصر 1'), Text('عنصر 2')]),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('عنصر 1'), findsOneWidget);
        expect(find.text('عنصر 2'), findsOneWidget);
        expect(find.byType(BaqyRefresh), findsOneWidget);
      },
    );

    testWidgets('Pulling past the trigger distance calls refresh callback once', (
      tester,
    ) async {
      int refreshCount = 0;
      final key = GlobalKey<BaqyRefreshState>();

      await tester.pumpWidget(
        createTestApp(
          child: BaqyRefresh(
            key: key,
            onRefresh: () async {
              refreshCount++;
            },
            child: ListView.builder(
              itemCount: 20,
              itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Trigger pull by drag past trigger distance (default 80px, dragging 250px)
      await tester.drag(find.byType(ListView), const Offset(0, 250));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(refreshCount, 1);
    });

    testWidgets('A second pull during a refresh is ignored', (tester) async {
      NetworkChecker.customChecker = () async => true;
      int refreshCount = 0;
      final completer = Completer<void>();
      final key = GlobalKey<BaqyRefreshState>();

      await tester.pumpWidget(
        createTestApp(
          child: BaqyRefresh(
            key: key,
            onRefresh: () async {
              refreshCount++;
              await completer.future;
            },
            child: ListView(children: const [Text('محتوى')]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Start first refresh
      key.currentState!.triggerRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(key.currentState!.isRefreshing, isTrue);
      expect(refreshCount, 1);

      // Attempt second trigger via programmatic or drag while first is running
      key.currentState!.triggerRefresh();
      await tester.drag(
        find.byType(ListView),
        const Offset(0, 200),
        warnIfMissed: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(refreshCount, 1);

      // Complete refresh
      completer.complete();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(key.currentState!.isRefreshing, isFalse);
      expect(refreshCount, 1);
    });

    testWidgets(
      'The animation lasts at least 600ms even if refresh is instant',
      (tester) async {
        final key = GlobalKey<BaqyRefreshState>();

        await tester.pumpWidget(
          createTestApp(
            child: BaqyRefresh(
              key: key,
              minDuration: const Duration(milliseconds: 600),
              onRefresh: () async {
                // Instant refresh
              },
              child: ListView(children: const [Text('تجربة')]),
            ),
          ),
        );

        await tester.pumpAndSettle();

        key.currentState!.triggerRefresh();
        await tester.pump();
        expect(key.currentState!.isRefreshing, isTrue);

        // Advance by 300ms: still refreshing because minDuration is 600ms
        await tester.pump(const Duration(milliseconds: 300));
        expect(key.currentState!.isRefreshing, isTrue);
        expect(find.byType(BaqyLogo), findsOneWidget);

        // Advance past 600ms + 300ms dismiss animation
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(key.currentState!.isRefreshing, isFalse);
      },
    );

    testWidgets('The 10-second timeout ends the refresh if it hangs', (
      tester,
    ) async {
      final key = GlobalKey<BaqyRefreshState>();
      final hangingCompleter = Completer<void>();

      await tester.pumpWidget(
        createTestApp(
          child: BaqyRefresh(
            key: key,
            timeout: const Duration(seconds: 10),
            onRefresh: () => hangingCompleter.future,
            child: ListView(children: const [Text('معلق')]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      key.currentState!.triggerRefresh();
      await tester.pump();
      expect(key.currentState!.isRefreshing, isTrue);

      // Advance 9 seconds: still refreshing
      await tester.pump(const Duration(seconds: 9));
      expect(key.currentState!.isRefreshing, isTrue);

      // Advance past 10 seconds: times out and dismisses
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(key.currentState!.isRefreshing, isFalse);
    });

    testWidgets('Offline shows the offline snackbar', (tester) async {
      final key = GlobalKey<BaqyRefreshState>();
      final fakeController = FakeBackupSyncController(
        simulatedResult: SyncRefreshResult.offline,
      );

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            backupSyncControllerProvider.overrideWith((ref) => fakeController),
          ],
          child: BaqyRefresh(
            key: key,
            child: ListView(children: const [Text('محتوى بدون نت')]),
          ),
        ),
      );

      await tester.pumpAndSettle();

      key.currentState!.triggerRefresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify offline snackbar message is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('مفيش اتصال، اتعرضت البيانات اللي على الموبايل'),
        findsOneWidget,
      );
    });
  });
}
