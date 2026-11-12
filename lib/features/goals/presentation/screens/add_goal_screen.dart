import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/goal_item.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../providers/goal_providers.dart';

class AddGoalScreen extends ConsumerStatefulWidget {
  const AddGoalScreen({super.key, this.goalToEdit});

  final GoalItem? goalToEdit;

  @override
  ConsumerState<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends ConsumerState<AddGoalScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String? _nameError;
  String? _amountError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.goalToEdit != null) {
      _nameController.text = widget.goalToEdit!.name;
      _amountController.text =
          NumberFormatter.formatCurrency(widget.goalToEdit!.targetEgp);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onAmountChanged(String val) {
    if (_amountError != null) {
      setState(() => _amountError = null);
    }
  }

  void _onNameChanged(String val) {
    if (_nameError != null) {
      setState(() => _nameError = null);
    }
  }

  Future<void> _saveGoal() async {
    final rawName = _nameController.text;
    final sanitizedName = GoalRepositoryImpl.sanitizeName(rawName);

    final rawAmount = _amountController.text;
    final parsedAmount = NumberFormatter.parsePositiveInteger(rawAmount);

    bool hasError = false;

    if (sanitizedName.isEmpty) {
      setState(() {
        _nameError = 'يرجى إدخال اسم الهدف';
      });
      hasError = true;
    } else if (sanitizedName.length > 40) {
      setState(() {
        _nameError = 'اسم الهدف لا يزيد عن 40 حرفًا';
      });
      hasError = true;
    }

    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() {
        _amountError = 'يرجى إدخال مبلغ صحيح';
      });
      hasError = true;
    } else if (parsedAmount > 100000000) {
      setState(() {
        _amountError = 'الحد الأقصى للمبلغ 100,000,000 جنيه';
      });
      hasError = true;
    } else if (widget.goalToEdit != null &&
        parsedAmount * 100 < widget.goalToEdit!.totalSaved) {
      setState(() {
        _amountError = 'المبلغ لا يمكن أن يقل عن المحوّش';
      });
      hasError = true;
    }

    if (hasError) return;

    setState(() => _isSaving = true);

    try {
      final targetAmountPiastres = parsedAmount! * 100;
      if (widget.goalToEdit != null) {
        final currentSaving = widget.goalToEdit!.monthlySaving;
        final adjustedSaving = currentSaving > targetAmountPiastres
            ? targetAmountPiastres
            : currentSaving;
        await ref.read(goalRepositoryProvider).updateGoal(
              id: widget.goalToEdit!.id,
              name: sanitizedName,
              targetAmount: targetAmountPiastres,
              monthlySaving: adjustedSaving,
            );
      } else {
        // Save new goal with target amount in piastres (EGP * 100)
        await ref.read(goalRepositoryProvider).addGoal(
              name: sanitizedName,
              targetAmount: targetAmountPiastres,
              monthlySaving: 0,
            );
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _amountError = e is ArgumentError && e.message != null
              ? e.message.toString()
              : 'حدث خطأ أثناء الحفظ، يرجى المحاولة مرة أخرى';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12.0),
              // Top Bar: Back Chevron & Title "هدف جديد"
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 20.0,
                      color: AppColors.text,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12.0),
                  const Text(
                    'هدف جديد',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28.0),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field 1: اسم الهدف
                      const Text(
                        'اسم الهدف',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.5,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: _nameError != null
                                ? Colors.redAccent
                                : const Color(0xFFE2DDD5),
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _nameController,
                          maxLength: 40,
                          onChanged: _onNameChanged,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            counterText: '',
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16.0,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (_nameError != null) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          _nameError!,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.0,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20.0),

                      // Field 2: المبلغ المطلوب
                      const Text(
                        'المبلغ المطلوب',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.5,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: _amountError != null
                                ? Colors.redAccent
                                : const Color(0xFFE2DDD5),
                            width: 1.0,
                          ),
                        ),
                        child: TextField(
                          controller: _amountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9٠-٩,،]'),
                            ),
                          ],
                          onChanged: _onAmountChanged,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveGoal(),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                          ),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16.0,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (_amountError != null) ...[
                        const SizedBox(height: 4.0),
                        Text(
                          _amountError!,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.0,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Button: "حفظ"
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
                child: SizedBox(
                  height: 52.0,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGoal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22.0,
                            height: 22.0,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

