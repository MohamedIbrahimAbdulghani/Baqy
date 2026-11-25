import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_refresh.dart';
import '../../../../core/widgets/empty_state_welcome_card.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_card.dart';
import '../widgets/debt_direction_switch.dart';
import '../widgets/debt_summary_card.dart';
import '../widgets/settled_debts_section.dart';

class DebtsTabScreen extends ConsumerWidget {
  const DebtsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = ref.watch(debtDirectionProvider);
    final activeDebtsAsync = ref.watch(activeDebtsStreamProvider(direction));
    final settledDebtsAsync = ref.watch(settledDebtsStreamProvider(direction));
    final totalRemaining = ref.watch(selectedDirectionTotalRemainingProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Title "الديون" matching Screenshot 1
              Padding(
                padding: const EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 16.0,
                ),
                child: Text(
                  'الديون',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 26.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ),

              // Switch "عليا" / "ليا"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: DebtDirectionSwitch(
                  selectedDirection: direction,
                  onChanged: (newDir) {
                    ref.read(debtDirectionProvider.notifier).setDirection(newDir);
                  },
                ),
              ),
              const SizedBox(height: 16.0),

              // Debts Content or empty
              Expanded(
                child: BaqyRefresh(
                  onRefresh: () async {
                    ref.invalidate(databaseChangesProvider);
                    ref.invalidate(activeDebtsStreamProvider(direction));
                    ref.invalidate(settledDebtsStreamProvider(direction));
                  },
                  child: activeDebtsAsync.when(
                    data: (activeDebts) {
                      return settledDebtsAsync.when(
                        data: (settledDebts) {
                          final hasNoDebts = activeDebts.isEmpty && settledDebts.isEmpty;
                          if (hasNoDebts) {
                            final isOwe = direction == 'owe';
                            return LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                      child: EmptyStateWelcomeCard(
                                        icon: isOwe
                                            ? Icons.handshake_outlined
                                            : Icons.payments_outlined,
                                        title: isOwe
                                            ? 'سجّل اللي عليك ونظم ديونك'
                                            : 'تابع فلوسك واللي ليك برّه',
                                        subtitle: isOwe
                                            ? 'تقدر تسجل أي دين أو سلفة عليك بالضغط على (+) وتتابع سدادها أول بأول.'
                                            : 'سجّل المبالغ اللي ليك عند الناس بالضغط على (+) والتطبيق هيفكرك بيها دايماً.',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(
                              left: 20.0,
                              right: 20.0,
                              top: 4.0,
                              bottom: 110.0, // Space above bottom FAB and nav bar
                            ),
                            children: [
                            // Summary Card
                            DebtSummaryCard(
                              direction: direction,
                              totalRemainingPiastres: totalRemaining,
                            ),
                            const SizedBox(height: 16.0),

                            // Active Debts Cards
                            ...activeDebts.map((debt) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: DebtCard(
                                  debt: debt,
                                  onTap: () {
                                    context.push('/debt-details', extra: debt.id);
                                  },
                                ),
                              );
                            }),

                            // Settled Debts Row & Accordion
                            if (settledDebts.isNotEmpty) ...[
                              const SizedBox(height: 4.0),
                              SettledDebtsSection(
                                settledDebts: settledDebts,
                                onDebtTap: (debt) {
                                  context.push('/debt-details', extra: debt.id);
                                },
                              ),
                            ],
                          ],
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (e, s) => const SizedBox.shrink(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                ),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}
