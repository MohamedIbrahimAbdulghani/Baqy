import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class DebtDirectionSwitch extends StatelessWidget {
  const DebtDirectionSwitch({
    super.key,
    required this.selectedDirection,
    required this.onChanged,
  });

  final String selectedDirection; // "owe" or "owed"
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isOwe = selectedDirection == 'owe';

    return Row(
      children: [
        // "عليا" (I owe) on the right in RTL
        Expanded(
          child: _SwitchItem(
            label: 'عليا',
            isSelected: isOwe,
            onTap: () => onChanged('owe'),
          ),
        ),
        const SizedBox(width: 12.0),
        // "ليا" (They owe me) on the left in RTL
        Expanded(
          child: _SwitchItem(
            label: 'ليا',
            isSelected: !isOwe,
            onTap: () => onChanged('owed'),
          ),
        ),
      ],
    );
  }
}

class _SwitchItem extends StatelessWidget {
  const _SwitchItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48.0,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE2EFEA)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4A7C59)
                : AppColors.inputBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? const Color(0xFF2A5949)
                : AppColors.text,
          ),
        ),
      ),
    );
  }
}

