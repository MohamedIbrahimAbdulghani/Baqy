import 'package:baqy/core/constants/app_colors.dart';
import 'package:baqy/core/theme/theme_provider.dart';
import 'package:baqy/features/home/presentation/widgets/home_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.isDark = false;
  });

  test('ThemeModeNotifier toggles between light and dark and syncs AppColors.isDark', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Initial state
    expect(container.read(themeModeProvider), equals(ThemeMode.light));
    expect(AppColors.isDark, isFalse);
    expect(AppColors.background, equals(AppColors.lightBackground));

    // Toggle to Dark
    container.read(themeModeProvider.notifier).toggleTheme();
    expect(container.read(themeModeProvider), equals(ThemeMode.dark));
    expect(AppColors.isDark, isTrue);
    expect(AppColors.background, equals(AppColors.darkBackground));
    expect(AppColors.card, equals(AppColors.darkCard));
    expect(AppColors.text, equals(AppColors.darkText));
    expect(AppColors.inputFill, equals(const Color(0xFF202428)));
    expect(AppColors.inputBorder, equals(const Color(0xFF323840)));
    expect(AppColors.subtleBox, equals(const Color(0xFF202428)));
    expect(AppColors.subtleButton, equals(const Color(0xFF262B30)));

    // Toggle back to Light
    container.read(themeModeProvider.notifier).toggleTheme();
    expect(container.read(themeModeProvider), equals(ThemeMode.light));
    expect(AppColors.isDark, isFalse);
    expect(AppColors.background, equals(AppColors.lightBackground));
    expect(AppColors.card, equals(AppColors.lightCard));
    expect(AppColors.text, equals(AppColors.lightText));
    expect(AppColors.inputFill, equals(const Color(0xFFFFFFFF)));
    expect(AppColors.inputBorder, equals(const Color(0xFFE2DDD5)));
    expect(AppColors.subtleBox, equals(const Color(0xFFF9F7F2)));
    expect(AppColors.subtleButton, equals(const Color(0xFFF4F0E8)));
  });

  testWidgets('HomeTopBar sun icon toggles theme mode on tap', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: HomeTopBar(
              selectedMonthText: 'نوفمبر ٢٠٢٦',
              onTapMonthSelector: () {},
            ),
          ),
        ),
      ),
    );

    // Initial state: Light mode
    expect(container.read(themeModeProvider), equals(ThemeMode.light));
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

    // Tap theme toggle button
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Now in Dark mode
    expect(container.read(themeModeProvider), equals(ThemeMode.dark));
    expect(find.byIcon(Icons.wb_sunny_rounded), findsOneWidget);

    // Tap again to return to Light mode
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(container.read(themeModeProvider), equals(ThemeMode.light));
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
  });

  test('HomeTopBar.resolveGreeting returns صباح الخير or مساء الخير based on hour of day', () {
    // Morning (4:00 AM to 11:59 AM)
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 4, 0)), equals('صباح الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 8, 30)), equals('صباح الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 11, 59)), equals('صباح الخير'));

    // Afternoon, Evening & Night (12:00 PM to 3:59 AM)
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 12, 0)), equals('مساء الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 15, 0)), equals('مساء الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 20, 0)), equals('مساء الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 23, 59)), equals('مساء الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 0, 0)), equals('مساء الخير'));
    expect(HomeTopBar.resolveGreeting(DateTime(2026, 11, 17, 3, 59)), equals('مساء الخير'));
  });
}
