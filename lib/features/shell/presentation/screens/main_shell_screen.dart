import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../goals/presentation/widgets/goals_speed_dial_fab.dart';
import '../../../home/presentation/widgets/home_speed_dial_fab.dart';
import '../providers/tab_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../../../../core/theme/theme_provider.dart';
import 'appointments_tab.dart';
import 'debts_tab.dart';
import 'goals_tab.dart';
import 'home_tab.dart';

/// FloatingActionButtonLocation that keeps the bottom of the FAB
/// at a fixed gap directly ABOVE the top edge of the bottom navigation bar.
class AboveBottomBarFabLocation extends FloatingActionButtonLocation {
  const AboveBottomBarFabLocation({this.gap = 14.0});

  final double gap;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2.0;
    final double fabY = scaffoldGeometry.contentBottom -
        gap -
        scaffoldGeometry.floatingActionButtonSize.height;
    return Offset(fabX, fabY);
  }
}

class MainShellScreen extends ConsumerWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final int selectedIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeTab(key: ValueKey('home_${isDark ? 'dark' : 'light'}')),
          GoalsTab(key: ValueKey('goals_${isDark ? 'dark' : 'light'}')),
          AppointmentsTab(key: ValueKey('appts_${isDark ? 'dark' : 'light'}')),
          DebtsTab(key: ValueKey('debts_${isDark ? 'dark' : 'light'}')),
        ],
      ),
      floatingActionButton: selectedIndex == 0
          ? const HomeSpeedDialFab()
          : (selectedIndex == 1 ? const GoalsSpeedDialFab() : null),
      floatingActionButtonLocation: const AboveBottomBarFabLocation(gap: 14.0),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(tabIndexProvider.notifier).selectTab(index);
        },
      ),
    );
  }
}
