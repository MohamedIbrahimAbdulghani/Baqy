import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_refresh.dart';
import '../../../../core/widgets/empty_state_welcome_card.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../reminders/presentation/widgets/reminder_card.dart';

/// The "المواعيد" (Appointments / Reminders) tab screen.
class AppointmentsTab extends ConsumerWidget {
  const AppointmentsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Title "المواعيد" matching Screenshot 1
            Padding(
              padding: const EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 20.0,
                bottom: 16.0,
              ),
              child: Text(
                'المواعيد',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
            ),

            // Reminders List or Empty State
            Expanded(
              child: BaqyRefresh(
                onRefresh: () async {
                  ref.invalidate(databaseChangesProvider);
                  ref.invalidate(remindersStreamProvider);
                },
                child: remindersAsync.when(
                  data: (reminders) {
                    if (reminders.isEmpty) {
                      return LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 20.0),
                                child: EmptyStateWelcomeCard(
                                  icon: Icons.event_available_rounded,
                                  title: 'نظم التزاماتك وفواتيرك',
                                  subtitle:
                                      'سجل مواعيد أقساطك وفواتيرك الدورية بالضغط على (+) والتطبيق هيفكرك بيها دايماً في ميعادها.',
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(
                        left: 20.0,
                        right: 20.0,
                        top: 4.0,
                        bottom: 110.0, // Space above FAB and bottom navigation bar
                      ),
                      itemCount: reminders.length,
                      separatorBuilder: (context, _) => const SizedBox(height: 12.0),
                      itemBuilder: (context, index) {
                        final reminder = reminders[index];
                        return ReminderCard(
                          reminder: reminder,
                          onTap: () {
                            context.push('/add-reminder', extra: reminder);
                          },
                        );
                      },
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (error, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
