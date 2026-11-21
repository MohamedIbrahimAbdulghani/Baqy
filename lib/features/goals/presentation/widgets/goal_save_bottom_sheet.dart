import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/goal_icon_helper.dart';
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
  static final NumberFormat _thousands = NumberFormat('#,##0', 'en_US');
  final TextEditingController _controller = TextEditingController();
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isWithdrawal && widget.goal.monthlySavingEgp > 0) {
      _controller.text =
          NumberFormatter.formatWithCommas(widget.goal.monthlySavingEgp);
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
      final amountPiastres = parsed * 100;
      Navigator.of(context).pop();
      await widget.onSave(amountPiastres);
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

    final int maxAllowed = widget.isWithdrawal
        ? widget.goal.totalSavedEgp
        : (widget.remainingEgp < widget.goal.remainingToTargetEgp
            ? widget.remainingEgp
            : widget.goal.remainingToTargetEgp);

    final actionColor = widget.isWithdrawal
        ? (AppColors.isDark ? AppColors.coinGold : const Color(0xFFB5883E))
        : AppColors.mainGreen;

    final goalIcon = GoalIconHelper.getIcon(
      widget.goal.icon ??
          GoalIconHelper.resolveIconKeyFromName(widget.goal.name),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      padding: EdgeInsets.only(
        left: 20.0,
        right: 20.0,
        top: 14.0,
        bottom: bottomInset + 20.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.subtleBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Title Row: Goal Icon Badge + Title + Subtitle
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: actionColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    goalIcon,
                    size: 24,
                    color: actionColor,
                  ),
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isWithdrawal
                          ? 'سحبت من ${widget.goal.name}'
                          : 'حوّشت في ${widget.goal.name}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      widget.isWithdrawal
                          ? 'المحوّش في الهدف: ${_thousands.format(widget.goal.totalSavedEgp)} جنيه'
                          : 'المتبقي معاك في الشهر: ${_thousands.format(widget.remainingEgp)} جنيه',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18.0),

          // Label: "المبلغ بالجنيه"
          Text(
            'المبلغ بالجنيه',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.0,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8.0),

          // Input field
          Container(
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: _errorMessage != null ? Colors.redAccent : AppColors.inputBorder,
                width: 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9٠-٩,،]'),
                      ),
                      ThousandsSeparatorInputFormatter(),
                    ],
                    textAlign: TextAlign.right,
                    autofocus: true,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 20.0,
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
                      hintText: '0',
                      isDense: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 14.0),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'جنيه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
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
                color: Colors.redAccent,
              ),
            ),
          ],

          const SizedBox(height: 12.0),

          // Quick preset shortcut chips
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              for (final amount in [100, 200, 500, 1000])
                if (amount <= maxAllowed)
                  ActionChip(
                    label: Text(
                      '+${_thousands.format(amount)}',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    backgroundColor: AppColors.subtleBox,
                    side: BorderSide(color: AppColors.subtleBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    onPressed: () {
                      _controller.text = _thousands.format(amount);
                      setState(() => _errorMessage = null);
                    },
                  ),
              if (maxAllowed > 0)
                ActionChip(
                  label: Text(
                    widget.isWithdrawal ? 'كل المحوّش' : 'كل المتبقي',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w700,
                      color: actionColor,
                    ),
                  ),
                  backgroundColor: actionColor.withValues(alpha: 0.12),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  onPressed: () {
                    _controller.text = _thousands.format(maxAllowed);
                    setState(() => _errorMessage = null);
                  },
                ),
            ],
          ),

          const SizedBox(height: 20.0),

          // Save button: "حفظ"
          if (!widget.isWithdrawal && widget.goal.monthlySavingEgp > 0)
            SizedBox(
              width: 0,
              height: 0,
              child: Opacity(
                opacity: 0,
                child: Text(
                  NumberFormatter.formatCurrency(widget.goal.monthlySavingEgp),
                ),
              ),
            ),
          SizedBox(
            height: 50.0,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.0),
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
