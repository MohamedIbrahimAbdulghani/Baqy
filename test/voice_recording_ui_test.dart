import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baqy/features/home/presentation/widgets/home_speed_dial_fab.dart';
import 'package:baqy/l10n/app_localizations.dart';

Widget createTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Voice Recording Studio & Cancel UI Tests', () {
    testWidgets('VoiceRecordingStopButton renders studio card with timer, waves and buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VoiceRecordingStopButton(
            onStop: () {},
            onCancel: () {},
          ),
        ),
      );

      // Settle initial animations
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('تسجيل المصاريف بالصوت'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('تم، احسبها'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('Tapping Cancel button invokes onCancel callback', (tester) async {
      bool cancelCalled = false;
      bool stopCalled = false;

      await tester.pumpWidget(
        createTestApp(
          VoiceRecordingStopButton(
            onStop: () => stopCalled = true,
            onCancel: () => cancelCalled = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));

      final cancelFinder = find.text('إلغاء');
      expect(cancelFinder, findsOneWidget);

      await tester.tap(cancelFinder);
      await tester.pump();

      expect(cancelCalled, isTrue);
      expect(stopCalled, isFalse);
    });

    testWidgets('Tapping Send button invokes onStop callback', (tester) async {
      bool cancelCalled = false;
      bool stopCalled = false;

      await tester.pumpWidget(
        createTestApp(
          VoiceRecordingStopButton(
            onStop: () => stopCalled = true,
            onCancel: () => cancelCalled = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));

      final sendFinder = find.byIcon(Icons.check_rounded);
      expect(sendFinder, findsOneWidget);

      await tester.tap(sendFinder);
      await tester.pump();

      expect(stopCalled, isTrue);
      expect(cancelCalled, isFalse);
    });

    testWidgets('Shows analyzing state properly when isAnalyzing is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          VoiceRecordingStopButton(
            onStop: () {},
            onCancel: () {},
            isAnalyzing: true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('بحلل كلامك دلوقتي…'), findsOneWidget);
      expect(find.text('ثواني وهنستخرج كل المصاريف بدقة ونعرضها عليك للتأكيد'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Cancel button is hidden while analyzing
      expect(find.text('إلغاء'), findsNothing);
    });
  });
}
