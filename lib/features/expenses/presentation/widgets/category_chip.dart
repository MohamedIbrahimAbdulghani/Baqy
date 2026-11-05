import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../domain/models/category_item.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.isEditMode,
    required this.onTap,
  });

  final CategoryItem category;
  final bool isSelected;
  final bool isEditMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isCustom = !category.isDefault;
    final bool canTap = !isEditMode || isCustom;

    // In edit mode, default categories are not editable
    final double opacity = (isEditMode && !isCustom) ? 0.45 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canTap ? onTap : null,
          borderRadius: BorderRadius.circular(22.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F1EE) : AppColors.card,
              borderRadius: BorderRadius.circular(22.0),
              border: Border.all(
                color: isSelected ? AppColors.mainGreen : AppColors.dividers,
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // If custom category, show its icon
                if (isCustom) ...[
                  Icon(
                    CategoryIconHelper.getIcon(category.icon),
                    size: 18.0,
                    color: isSelected ? AppColors.darkGreen : AppColors.secondaryText,
                  ),
                  const SizedBox(width: 6.0),
                ],

                // Category name
                Text(
                  category.name,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.darkGreen : AppColors.text,
                  ),
                ),

                // In edit mode for custom category, show small edit icon
                if (isEditMode && isCustom) ...[
                  const SizedBox(width: 6.0),
                  const Icon(
                    Icons.edit,
                    size: 14.0,
                    color: AppColors.mainGreen,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

