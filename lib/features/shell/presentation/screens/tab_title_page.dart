import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

class TabTitlePage extends StatelessWidget {
  const TabTitlePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 24.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

