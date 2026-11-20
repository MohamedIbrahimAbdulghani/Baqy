import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.length,
    this.totalLength = 4,
    this.hasError = false,
  });

  final int length;
  final int totalLength;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalLength, (index) {
        final isFilled = index < length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppColors.errorRed
                : (isFilled ? AppColors.darkGreen : Colors.transparent),
            border: Border.all(
              color: hasError
                  ? AppColors.errorRed
                  : (isFilled ? AppColors.darkGreen : AppColors.secondaryText),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class PinKeypad extends StatelessWidget {
  const PinKeypad({
    super.key,
    required this.onDigitTap,
    required this.onDeleteTap,
    this.onBiometricTap,
    this.showBiometrics = false,
    this.isDisabled = false,
  });

  final void Function(int digit) onDigitTap;
  final VoidCallback onDeleteTap;
  final VoidCallback? onBiometricTap;
  final bool showBiometrics;
  final bool isDisabled;

  Widget _buildKey(BuildContext context, String text, VoidCallback? onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(40),
            splashColor: AppColors.darkGreen.withValues(alpha: 0.15),
            child: Container(
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.subtleButton,
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: isDisabled
                      ? AppColors.secondaryText.withValues(alpha: 0.4)
                      : AppColors.text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required Widget icon,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              height: 72,
              alignment: Alignment.center,
              child: icon,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _buildKey(context, '1', () => onDigitTap(1)),
                _buildKey(context, '2', () => onDigitTap(2)),
                _buildKey(context, '3', () => onDigitTap(3)),
              ],
            ),
            Row(
              children: [
                _buildKey(context, '4', () => onDigitTap(4)),
                _buildKey(context, '5', () => onDigitTap(5)),
                _buildKey(context, '6', () => onDigitTap(6)),
              ],
            ),
            Row(
              children: [
                _buildKey(context, '7', () => onDigitTap(7)),
                _buildKey(context, '8', () => onDigitTap(8)),
                _buildKey(context, '9', () => onDigitTap(9)),
              ],
            ),
            Row(
              children: [
                // Left key: Biometrics (if enabled) or empty
                if (showBiometrics && onBiometricTap != null)
                  _buildActionKey(
                    icon: Icon(
                      Icons.fingerprint_rounded,
                      size: 34,
                      color: isDisabled
                          ? AppColors.secondaryText.withValues(alpha: 0.4)
                          : AppColors.darkGreen,
                    ),
                    onTap: onBiometricTap,
                  )
                else
                  const Expanded(child: SizedBox(height: 72)),

                // Middle key: 0
                _buildKey(context, '0', () => onDigitTap(0)),

                // Right key: Delete
                _buildActionKey(
                  icon: Icon(
                    Icons.backspace_outlined,
                    size: 24,
                    color: isDisabled
                        ? AppColors.secondaryText.withValues(alpha: 0.4)
                        : AppColors.text,
                  ),
                  onTap: onDeleteTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
