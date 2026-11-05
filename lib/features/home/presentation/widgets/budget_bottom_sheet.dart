import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';

class BudgetBottomSheet extends StatefulWidget {
  const BudgetBottomSheet({
    super.key,
    required this.monthNumber,
    this.initialBudgetEgp,
    required this.onSave,
  });

  final int monthNumber;
  final int? initialBudgetEgp;
  final Future<void> Function(int budgetPiastres) onSave;

  /// Helper to display this bottom sheet modally
  static Future<void> show({
    required BuildContext context,
    required int monthNumber,
    int? initialBudgetEgp,
    required Future<void> Function(int budgetPiastres) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BudgetBottomSheet(
        monthNumber: monthNumber,
        initialBudgetEgp: initialBudgetEgp,
        onSave: onSave,
      ),
    );
  }

  @override
  State<BudgetBottomSheet> createState() => _BudgetBottomSheetState();
}

class _BudgetBottomSheetState extends State<BudgetBottomSheet> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialText = widget.initialBudgetEgp != null && widget.initialBudgetEgp! > 0
        ? NumberFormatter.formatCurrency(widget.initialBudgetEgp!)
        : '';
    _controller = TextEditingController(text: initialText);
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
        _errorMessage = 'برجاء إدخال مبلغ صحيح أكبر من الصفر';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final budgetPiastres = parsed * 100;
    await widget.onSave(budgetPiastres);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthName = ArabicDateHelper.getMonthName(widget.monthNumber);
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
          // Title: "ميزانية شهر <الشهر>"
          Text(
            'ميزانية شهر $monthName',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22.0,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 8.0),

          // Subtitle
          const Text(
            'اكتب مرتبك أو دخلك المتاح الشهر ده، تقدر تغيّره في أي وقت بالضغط على الحلقة.',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.0,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20.0),

          // Label: "المبلغ المتاح بالجنيه"
          const Text(
            'المبلغ المتاح بالجنيه',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.0,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8.0),

          // Input field
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
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: '٠',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppColors.secondaryText,
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 6.0),
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

          // Save button "حفظ"
          SizedBox(
            height: 52.0,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
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
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

