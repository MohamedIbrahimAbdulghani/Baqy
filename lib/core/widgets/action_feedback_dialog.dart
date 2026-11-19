import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

enum ActionFeedbackType {
  added,
  updated,
  deleted,
  paymentRecorded,
  settled,
}

/// A unified, sleek modal feedback popup shown across all screens
/// for add, edit, delete, and payment actions with standardized layout,
/// icons, smooth scale+fade transition, and auto-dismiss.
class ActionFeedbackDialog extends StatefulWidget {
  const ActionFeedbackDialog({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    this.onUndo,
    this.undoLabel = 'تراجع',
  });

  final ActionFeedbackType type;
  final String title;
  final String subtitle;
  final VoidCallback? onUndo;
  final String undoLabel;

  /// Shows the unified modal popup
  static Future<void> show({
    required BuildContext context,
    required ActionFeedbackType type,
    required String title,
    required String subtitle,
    VoidCallback? onUndo,
    String undoLabel = 'تراجع',
    Duration duration = const Duration(milliseconds: 2600),
  }) async {
    HapticFeedback.lightImpact();

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق',
      barrierColor: Colors.black.withValues(alpha: 0.38),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Dialog(
          backgroundColor: AppColors.card,
          elevation: 16.0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28.0),
          child: ActionFeedbackDialog(
            type: type,
            title: title,
            subtitle: subtitle,
            onUndo: onUndo,
            undoLabel: undoLabel,
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<ActionFeedbackDialog> createState() => _ActionFeedbackDialogState();
}

class _ActionFeedbackDialogState extends State<ActionFeedbackDialog> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    final duration = widget.onUndo != null
        ? const Duration(milliseconds: 5000)
        : const Duration(milliseconds: 2600);
    _autoDismissTimer = Timer(duration, () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color iconColor;
    Color iconBgColor;

    switch (widget.type) {
      case ActionFeedbackType.deleted:
        icon = Icons.delete_outline_rounded;
        iconColor = Colors.redAccent;
        iconBgColor = Colors.redAccent.withValues(alpha: 0.12);
        break;

      case ActionFeedbackType.updated:
        icon = Icons.edit_note_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        break;

      case ActionFeedbackType.added:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        break;

      case ActionFeedbackType.paymentRecorded:
        icon = Icons.task_alt_rounded;
        iconColor = AppColors.mainGreen;
        iconBgColor = AppColors.mainGreen.withValues(alpha: 0.12);
        break;

      case ActionFeedbackType.settled:
        icon = Icons.celebration_rounded;
        iconColor = const Color(0xFF2E7D32);
        iconBgColor = const Color(0xFF2E7D32).withValues(alpha: 0.14);
        break;
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 26.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Standardized Icon Badge
            Container(
              width: 64.0,
              height: 64.0,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 34.0,
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Standardized Title
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 19.0,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8.0),

            // Standardized Subtitle
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: AppColors.secondaryText,
                height: 1.45,
              ),
            ),

            if (widget.onUndo != null) ...[
              const SizedBox(height: 20.0),
              Row(
                children: [
                  // Primary "تم" button to close immediately
                  Expanded(
                    child: SizedBox(
                      height: 42.0,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                        child: const Text(
                          'تم',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10.0),
                  // Secondary "تراجع" button
                  Expanded(
                    child: SizedBox(
                      height: 42.0,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          widget.onUndo?.call();
                        },
                        icon: const Icon(Icons.undo_rounded, size: 16.0),
                        label: Text(
                          widget.undoLabel,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.secondaryText,
                          side: BorderSide(
                            color: AppColors.inputBorder,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

