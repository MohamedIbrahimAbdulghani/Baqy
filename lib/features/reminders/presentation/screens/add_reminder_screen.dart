import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/reminder_icon_helper.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../../domain/models/reminder_item.dart';
import '../providers/reminder_providers.dart';
import '../widgets/reminder_success_dialog.dart';

/// Form screen for adding a new reminder or editing an existing one ("موعد جديد").
class AddReminderScreen extends ConsumerStatefulWidget {
  const AddReminderScreen({super.key, this.reminderToEdit});

  final ReminderItem? reminderToEdit;

  @override
  ConsumerState<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends ConsumerState<AddReminderScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  late DateTime _selectedDate;
  String _repeat = 'once'; // 'once' or 'monthly'
  int _leadDays = 2; // 1, 2, or 3 (default 2 = يومين)

  String? _nameError;
  String? _amountError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      if (mounted) setState(() {});
    });
    final edit = widget.reminderToEdit;
    if (edit != null) {
      _nameController.text = edit.name;
      _amountController.text =
          NumberFormatter.formatWithCommas(edit.amountEgp);
      _selectedDate = edit.dueDate;
      _repeat = edit.repeat;
      _leadDays = edit.leadDays;
    } else {
      final now = DateTime.now();
      _selectedDate = DateTime(now.year, now.month, now.day);
      _repeat = 'once';
      _leadDays = 2;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _selectedDate.isBefore(today) ? today : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 10, 12, 31),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.mainGreen,
              onPrimary: Colors.white,
              surface: AppColors.card,
              onSurface: AppColors.text,
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          title: Text(
            'حذف الموعد؟',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          content: Text(
            'هيتحذف الموعد والإشعار بتاعه.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: AppColors.secondaryText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'حذف',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.bold,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final reminderName = widget.reminderToEdit!.name;
      final repo = ref.read(reminderRepositoryProvider);
      await repo.deleteReminder(widget.reminderToEdit!.id);
      if (mounted) {
        context.pop();
        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await ActionFeedbackDialog.show(
            context: targetContext,
            type: ActionFeedbackType.deleted,
            title: 'تم حذف الموعد',
            subtitle: 'تم حذف موعد "$reminderName" وإلغاء الإشعار الخاص به.',
          );
        }
      }
    }
  }

  Future<void> _saveReminder() async {
    final rawName = _nameController.text;
    final sanitizedName =
        rawName.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();

    String? nameErr;
    String? amountErr;

    if (sanitizedName.isEmpty) {
      nameErr = 'من فضلك اكتب اسم الموعد';
    } else if (sanitizedName.length > 40) {
      nameErr = 'اسم الموعد يجب ألا يتجاوز ٤٠ حرفاً';
    }

    final rawAmount = _amountController.text;
    final amountEgp = NumberFormatter.parsePositiveInteger(rawAmount);

    if (amountEgp == null || amountEgp <= 0) {
      amountErr = 'من فضلك اكتب المبلغ';
    } else if (amountEgp > 100000000) {
      amountErr = 'الحد الأقصى للمبلغ ١٠٠,٠٠٠,٠٠٠ جنيه';
    }

    if (nameErr != null || amountErr != null) {
      setState(() {
        _nameError = nameErr;
        _amountError = amountErr;
      });
      return;
    }

    setState(() {
      _nameError = null;
      _amountError = null;
      _isSaving = true;
    });

    try {
      // Ask for notification permission (Android 13+) when saving the FIRST reminder
      final prefs = await SharedPreferences.getInstance();
      final hasAsked =
          prefs.getBool('has_prompted_first_reminder_permission') ?? false;
      if (!hasAsked) {
        await prefs.setBool('has_prompted_first_reminder_permission', true);
        await NotificationService.instance.requestPermissions();
      }

      final repo = ref.read(reminderRepositoryProvider);
      final amountPiastres = amountEgp! * 100;

      late final ReminderItem savedItem;
      if (widget.reminderToEdit == null) {
        final id = await repo.addReminder(
          name: sanitizedName,
          amount: amountPiastres,
          dueDate: _selectedDate,
          repeat: _repeat,
          leadDays: _leadDays,
        );
        savedItem = ReminderItem(
          id: id,
          name: sanitizedName,
          amount: amountPiastres,
          dueDate: _selectedDate,
          repeat: _repeat,
          leadDays: _leadDays,
        );
      } else {
        await repo.updateReminder(
          id: widget.reminderToEdit!.id,
          name: sanitizedName,
          amount: amountPiastres,
          dueDate: _selectedDate,
          repeat: _repeat,
          leadDays: _leadDays,
        );
        savedItem = widget.reminderToEdit!.copyWith(
          name: sanitizedName,
          amount: amountPiastres,
          dueDate: _selectedDate,
          repeat: _repeat,
          leadDays: _leadDays,
        );
      }

      if (mounted) {
        final isEdit = widget.reminderToEdit != null;
        if (isEdit) {
          context.pop();
          final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
          if (targetContext != null && targetContext.mounted) {
            final formatted = '${NumberFormatter.formatCurrency(amountEgp)} جنيه';
            await ActionFeedbackDialog.show(
              context: targetContext,
              type: ActionFeedbackType.updated,
              title: 'تم تعديل الموعد بنجاح',
              subtitle: 'تم تحديث موعد "$sanitizedName" بمبلغ $formatted.',
            );
          }
        } else {
          await ReminderSuccessDialog.show(
            context: context,
            reminder: savedItem,
            isEdit: false,
          );
          if (mounted) {
            context.pop();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _amountError = e is ArgumentError && e.message != null
              ? e.message.toString()
              : 'حدث خطأ أثناء الحفظ، يرجى المحاولة مرة أخرى';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 20.0,
                      color: AppColors.text,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 12.0),
                  if (widget.reminderToEdit != null) ...[
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        color: AppColors.mainGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: Icon(
                        ReminderIconHelper.resolveIcon(widget.reminderToEdit!.name),
                        color: AppColors.mainGreen,
                        size: 20.0,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                  ],
                  Expanded(
                    child: Text(
                      widget.reminderToEdit != null
                          ? widget.reminderToEdit!.name
                          : 'موعد جديد',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  if (widget.reminderToEdit != null)
                    IconButton(
                      onPressed: _confirmDelete,
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 22.0,
                        color: Colors.redAccent,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),

            // Form Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Field 1: الاسم
                    Text(
                      'الاسم',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _nameController,
                      maxLength: 40,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16.0,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        errorText: _nameError,
                        prefixIcon: Icon(
                          ReminderIconHelper.resolveIcon(_nameController.text),
                          color: AppColors.mainGreen,
                          size: 22.0,
                        ),
                        filled: true,
                        fillColor: AppColors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 14.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                            width: 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: const BorderSide(
                            color: AppColors.mainGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Field 2: المبلغ
                    Text(
                      'المبلغ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandsSeparatorInputFormatter(),
                      ],
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16.0,
                        color: AppColors.text,
                      ),
                      decoration: InputDecoration(
                        errorText: _amountError,
                        filled: true,
                        fillColor: AppColors.inputFill,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 14.0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                            width: 1.0,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: BorderSide(
                            color: AppColors.inputBorder,
                            width: 1.0,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14.0),
                          borderSide: const BorderSide(
                            color: AppColors.mainGreen,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Field 3: تاريخ الاستحقاق
                    Text(
                      'تاريخ الاستحقاق',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 14.0),
                        decoration: BoxDecoration(
                          color: AppColors.inputFill,
                          borderRadius: BorderRadius.circular(14.0),
                          border: Border.all(
                            color: AppColors.inputBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '${_selectedDate.day.toArabicDigits()} ${ArabicDateHelper.getMonthName(_selectedDate.month)}',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),

                    // Field 4: التكرار
                    Text(
                      'التكرار',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: 'شهري',
                            isSelected: _repeat == 'monthly',
                            onTap: () => setState(() => _repeat = 'monthly'),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: _SegmentButton(
                            label: 'مرة واحدة',
                            isSelected: _repeat == 'once',
                            onTap: () => setState(() => _repeat = 'once'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),

                    // Field 5: فكّرني قبلها بـ
                    Text(
                      'فكّرني قبلها بـ',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: '٣ أيام',
                            isSelected: _leadDays == 3,
                            onTap: () => setState(() => _leadDays = 3),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: _SegmentButton(
                            label: 'يومين',
                            isSelected: _leadDays == 2,
                            onTap: () => setState(() => _leadDays = 2),
                          ),
                        ),
                        const SizedBox(width: 10.0),
                        Expanded(
                          child: _SegmentButton(
                            label: 'يوم',
                            isSelected: _leadDays == 1,
                            onTap: () => setState(() => _leadDays = 1),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36.0),

                    // Button: حفظ
                    SizedBox(
                      height: 52.0,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveReminder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mainGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.0),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                'حفظ',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 17.0,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
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
      child: Container(
        height: 48.0,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.mainGreen.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? AppColors.mainGreen : AppColors.inputBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 15.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppColors.mainGreen : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
