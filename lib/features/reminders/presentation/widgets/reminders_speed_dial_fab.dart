import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Floating Action Button for the Reminders ("المواعيد") tab.
/// Tapping it directly opens the manual "موعد جديد" screen (writing only).
class RemindersSpeedDialFab extends StatelessWidget {
  const RemindersSpeedDialFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58.0,
      height: 58.0,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.mainGreen,
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () {
            context.push('/add-reminder');
          },
          customBorder: const CircleBorder(),
          child: const Center(
            child: Icon(
              Icons.add,
              color: Colors.white,
              size: 30.0,
            ),
          ),
        ),
      ),
    );
  }
}
