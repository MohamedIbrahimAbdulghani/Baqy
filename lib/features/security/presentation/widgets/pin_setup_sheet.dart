import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/security_providers.dart';
import 'pin_keypad.dart';

enum PinSetupMode {
  create,
  change,
  disable,
}

class PinSetupSheet extends ConsumerStatefulWidget {
  const PinSetupSheet({
    super.key,
    required this.mode,
  });

  final PinSetupMode mode;

  static Future<bool?> show(
    BuildContext context, {
    required PinSetupMode mode,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PinSetupSheet(mode: mode),
    );
  }

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  // Step 0: verify current (for change / disable)
  // Step 1: enter new PIN
  // Step 2: confirm new PIN
  int _step = 1;
  String _newPin = '';
  String _confirmPin = '';
  String _enteredDigits = '';
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    if (widget.mode == PinSetupMode.change ||
        widget.mode == PinSetupMode.disable) {
      _step = 0;
    } else {
      _step = 1;
    }
  }

  String get _title {
    if (_step == 0) {
      return widget.mode == PinSetupMode.disable
          ? 'أدخل رمز المرور لإلغاء القفل'
          : 'أدخل رمز المرور الحالي';
    } else if (_step == 1) {
      return widget.mode == PinSetupMode.change
          ? 'أدخل رمز المرور الجديد'
          : 'أنشئ رمز مرور للتطبيق';
    } else {
      return 'تأكيد رمز المرور الجديد';
    }
  }

  String get _subtitle {
    if (_step == 0) {
      return 'لتأكيد هويتك وحماية خصوصية بياناتك';
    } else if (_step == 1) {
      return 'رمز مكوّن من 4 أرقام سيُطلب عند فتح التطبيق';
    } else {
      return 'أعد كتابة الرمز نفسه للتأكيد';
    }
  }

  void _onDigitTap(int digit) {
    if (_enteredDigits.length >= 4) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _enteredDigits += digit.toString();
    });

    if (_enteredDigits.length == 4) {
      _handleCompletedPin(_enteredDigits);
    }
  }

  void _onDeleteTap() {
    if (_enteredDigits.isEmpty) return;
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _enteredDigits = _enteredDigits.substring(0, _enteredDigits.length - 1);
    });
  }

  Future<void> _handleCompletedPin(String pin) async {
    final notifier = ref.read(securitySettingsProvider.notifier);

    if (_step == 0) {
      // Verify current PIN
      final valid = await notifier.verifyPin(pin);
      if (!mounted) return;
      if (valid) {
        if (widget.mode == PinSetupMode.disable) {
          await notifier.removePin();
          if (mounted) Navigator.of(context).pop(true);
        } else {
          // Mode is change: proceed to new PIN
          setState(() {
            _enteredDigits = '';
            _step = 1;
          });
        }
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'رمز المرور غير صحيح';
          _enteredDigits = '';
        });
      }
    } else if (_step == 1) {
      // Set new PIN, move to confirm
      setState(() {
        _newPin = pin;
        _enteredDigits = '';
        _step = 2;
      });
    } else if (_step == 2) {
      // Confirm new PIN
      _confirmPin = pin;
      if (_newPin == _confirmPin) {
        await notifier.savePin(_newPin);
        if (mounted) Navigator.of(context).pop(true);
      } else {
        setState(() {
          _hasError = true;
          _errorMessage = 'الرمز غير متطابق، حاول مرة أخرى';
          _enteredDigits = '';
          _step = 1;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.dividers,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Icon badge
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.mainGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: AppColors.mainGreen,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 6),

            // Subtitle
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: _hasError ? AppColors.errorRed : AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 28),

            // Dots
            PinDots(
              length: _enteredDigits.length,
              totalLength: 4,
              hasError: _hasError,
            ),
            const SizedBox(height: 32),

            // Keypad
            PinKeypad(
              onDigitTap: _onDigitTap,
              onDeleteTap: _onDeleteTap,
              showBiometrics: false,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
