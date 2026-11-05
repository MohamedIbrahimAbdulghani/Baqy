import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';

class MonthSelectorPopup extends StatefulWidget {
  const MonthSelectorPopup({
    super.key,
    required this.selectedYear,
    required this.selectedMonth,
    required this.availableYears,
    required this.monthsWithData,
    required this.onSelectMonth,
    required this.onClose,
  });

  final int selectedYear;
  final int selectedMonth;
  final List<int> availableYears;
  final Set<int> monthsWithData;
  final void Function(int year, int month) onSelectMonth;
  final VoidCallback onClose;

  @override
  State<MonthSelectorPopup> createState() => _MonthSelectorPopupState();
}

class _MonthSelectorPopupState extends State<MonthSelectorPopup> {
  late int _activeYear;
  bool _showingMonths = false;

  @override
  void initState() {
    super.initState();
    _activeYear = widget.selectedYear;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250.0,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18.0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      child: _showingMonths ? _buildMonthsView() : _buildYearsView(),
    );
  }

  /// View 1: Years Popup (Screenshot 2)
  Widget _buildYearsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.availableYears.map((year) {
        final bool isSelected = year == widget.selectedYear;

        return InkWell(
          onTap: () {
            setState(() {
              _activeYear = year;
              _showingMonths = true;
            });
          },
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.lightGreen : Colors.transparent,
              borderRadius: BorderRadius.circular(10.0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (isSelected)
                  const Icon(
                    Icons.check,
                    color: AppColors.darkGreen,
                    size: 20.0,
                  )
                else
                  const SizedBox(width: 20.0),
                Text(
                  year.toArabicDigits(),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18.0,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? AppColors.darkGreen : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// View 2: Months Popup (Screenshot 3)
  Widget _buildMonthsView() {
    final now = DateTime.now();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Year header row (tapping switches back to years list)
        InkWell(
          onTap: () {
            setState(() {
              _showingMonths = false;
            });
          },
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.text,
                  size: 22.0,
                ),
                Text(
                  _activeYear.toArabicDigits(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6.0),
        const Divider(
          color: AppColors.dividers,
          height: 1.0,
          thickness: 1.0,
        ),
        const SizedBox(height: 8.0),

        // 3x4 Grid of 12 months
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 12,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.7,
            crossAxisSpacing: 6.0,
            mainAxisSpacing: 6.0,
          ),
          itemBuilder: (context, index) {
            final int monthNumber = index + 1;
            final String monthName = ArabicDateHelper.getMonthName(monthNumber);

            final bool isSelected =
                _activeYear == widget.selectedYear && monthNumber == widget.selectedMonth;

            final bool isFuture = _activeYear > now.year ||
                (_activeYear == now.year && monthNumber > now.month);

            final bool hasData = widget.monthsWithData.contains(monthNumber);

            // A month is tappable if it is the current/selected month OR it has data and is not in the future
            final bool isTappable = !isFuture && hasData;

            if (isSelected) {
              return InkWell(
                onTap: () => widget.onSelectMonth(_activeYear, monthNumber),
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.lightGreen,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check,
                          color: AppColors.darkGreen,
                          size: 14.0,
                        ),
                        const SizedBox(width: 3.0),
                        Text(
                          monthName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            if (isTappable) {
              return InkWell(
                onTap: () => widget.onSelectMonth(_activeYear, monthNumber),
                borderRadius: BorderRadius.circular(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      monthName,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ),
              );
            }

            // Faded and not tappable (no data or future)
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  monthName,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w400,
                    color: AppColors.secondaryText.withValues(alpha: 0.35),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
