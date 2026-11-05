import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'tab_title_page.dart';

class GoalsTab extends StatelessWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.tabGoals ?? 'الأهداف';
    return TabTitlePage(title: title);
  }
}

