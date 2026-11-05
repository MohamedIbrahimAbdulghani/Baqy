import 'package:flutter/material.dart';
import '../../../../l10n/app_localizations.dart';
import 'tab_title_page.dart';

class AppointmentsTab extends StatelessWidget {
  const AppointmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context)?.tabAppointments ?? 'المواعيد';
    return TabTitlePage(title: title);
  }
}

