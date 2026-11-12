import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/goal_item.dart';

class GoalSaveBottomSheet extends StatefulWidget {
  const GoalSaveBottomSheet({
    super.key,
    required this.goal,
    required this.remainingEgp,
    required this.onSave,
    this.isWithdrawal = false,
  });

  final GoalItem goal;
  final int remainingEgp;
  final Future<void> Function(int amountPiastres) onSave;
  final bool isWithdrawal;

  /// Displays the saving or withdrawal bottom sheet modally
  static Future<void> show({
    required BuildContext context,
    required GoalItem goal,
    required int remainingEgp,
    bool isWithdrawal = false,
    required Future<void> Function(int amountPiastres) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GoalSaveBottomSheet(
        goal: goal,
        remainingEgp: remainingEgp,
        isWithdrawal: isWithdrawal,
        onSave: onSave,
      ),
    );
  }

  @override
  State<GoalSaveBottomSheet> createState() => _GoalSaveBottomSheetState();
}

class _GoalSaveBottomSheetState extends State<GoalSaveBottomSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isWithdrawal && widget.goal.monthlySavingEgp > 0) {
      _controller.text =
          NumberFormatter.formatCurrency(widget.goal.monthlySavingEgp);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final parsed = NumberFormatter.parsePositiveInteger(_controller.text);
    if (parsed == null || parsed <= 0) {
      setState(() {
        _errorMessage = 'يرجى إدخال مبلغ صحيح';
      });
      return;
    }

    if (widget.isWithdrawal) {
      if (parsed > widget.goal.totalSavedEgp) {
        setState(() {
          _errorMessage = 'المبلغ أكبر من المحوّش في الهدف';
        });
        return;
      }
    } else {
      if (parsed > widget.remainingEgp) {
        setState(() {
          _errorMessage = 'المبلغ أكبر من الباقي';
        });
        return;
      }

      if (parsed > widget.goal.remainingToTargetEgp) {
        setState(() {
          _errorMessage = 'المبلغ أكبر من المتبقي للهدف';
        });
        return;
      }
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      await widget.onSave(parsed * 100);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'حدث خطأ أثناء الحفظ';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 24.0,
        bottom: bottomInset + 24.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title: "حوّشت في <اسم الهدف>" or "سحبت من <اسم الهدف>"
          Text(
            widget.isWithdrawal
                ? 'سحبت من ${widget.goal.name}'
                : 'حوّشت في ${widget.goal.name}',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22.0,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 20.0),

          // Label: "المبلغ بالجنيه"
          const Text(
            'المبلغ بالجنيه',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8.0),

          // Input field styled identically to Budget sheet
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFBF9F5),
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(
                color: _errorMessage != null ? Colors.red : AppColors.dividers,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              autofocus: true,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: false,
                contentPadding: EdgeInsets.symmetric(vertical: 14.0),
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 8.0),
            Text(
              _errorMessage!,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.0,
                color: Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 20.0),

          // Save button: "حفظ"
          SizedBox(
            height: 50.0,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mainGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'حفظ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

