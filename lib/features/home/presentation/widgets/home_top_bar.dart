import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.selectedMonthText,
    required this.onTapMonthSelector,
  });

  final String selectedMonthText;
  final VoidCallback onTapMonthSelector;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Settings / Sun icon (does nothing yet)
          Container(
            width: 42.0,
            height: 42.0,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12.0),
              boxShadow: AppDimensions.cardShadow,
            ),
            child: const Icon(
              Icons.wb_sunny_outlined,
              color: AppColors.darkGreen,
              size: 22.0,
            ),
          ),

          // Right: "صباح الخير" & Month Selector
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'صباح الخير',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainGreen,
                  ),
                ),
                const SizedBox(height: 2.0),
                InkWell(
                  onTap: onTapMonthSelector,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              selectedMonthText,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 22.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.text,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
