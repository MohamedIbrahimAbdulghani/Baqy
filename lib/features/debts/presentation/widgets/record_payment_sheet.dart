import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';

class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.maxRemainingPiastres,
    required this.onSave,
    this.title = 'تسجيل دفعة',
    this.initialAmountPiastres,
    this.customMaxError,
    this.helperText,
  });

  final int maxRemainingPiastres;
  final Future<void> Function(int amountPiastres) onSave;
  final String title;
  final int? initialAmountPiastres;
  final String? customMaxError;
  final String? helperText;

  static Future<void> show({
    required BuildContext context,
    required int maxRemainingPiastres,
    required Future<void> Function(int amountPiastres) onSave,
    String title = 'تسجيل دفعة',
    int? initialAmountPiastres,
    String? customMaxError,
    String? helperText,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordPaymentSheet(
        maxRemainingPiastres: maxRemainingPiastres,
        onSave: onSave,
        title: title,
        initialAmountPiastres: initialAmountPiastres,
        customMaxError: customMaxError,
        helperText: helperText,
      ),
    );
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialAmountPiastres;
    _controller = TextEditingController(
      text: (initial != null && initial > 0)
          ? NumberFormatter.formatWithCommas(initial ~/ 100)
          : '',
    );
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

    final amountPiastres = parsed * 100;
    if (amountPiastres > widget.maxRemainingPiastres) {
      setState(() {
        _errorMessage = widget.customMaxError ?? 'المبلغ أكبر من المتبقي';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      await widget.onSave(amountPiastres);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ArgumentError ? e.message.toString() : 'حدث خطأ أثناء الحفظ';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
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
            // Title
            Text(
              widget.title,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 22.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 20.0),

            // Field Label: "المبلغ بالجنيه" & Optional helper text
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'المبلغ بالجنيه',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w400,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (widget.helperText != null)
                  Text(
                    widget.helperText!,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8.0),

            // Amount input field matching budget sheet look
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputFill,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: _errorMessage != null ? Colors.red : AppColors.inputBorder,
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9٠-٩,،]'),
                  ),
                  ThousandsSeparatorInputFormatter(),
                ],
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
                decoration: InputDecoration(
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

            // Button: "حفظ"
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
      ),
    );
  }
}

