import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'tab_title_page.dart';

class DebtsTab extends StatelessWidget {
  const DebtsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.tabDebts ?? 'الديون';
    return TabTitlePage(title: title);
  }
}

