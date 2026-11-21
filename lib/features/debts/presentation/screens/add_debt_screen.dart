import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/debt_item.dart';
import '../../../../core/widgets/action_feedback_dialog.dart';
import '../providers/debt_providers.dart';
import '../widgets/debt_direction_switch.dart';

class AddDebtScreen extends ConsumerStatefulWidget {
  const AddDebtScreen({
    super.key,
    this.debtToEdit,
    this.initialDirection,
  });

  final DebtItem? debtToEdit;
  final String? initialDirection;

  @override
  ConsumerState<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends ConsumerState<AddDebtScreen> {
  late String _direction;
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  DateTime? _dueDate;
  int _leadDays = 2;

  String? _nameError;
  String? _amountError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final debt = widget.debtToEdit;
    _direction = debt?.direction ?? widget.initialDirection ?? 'owe';
    _nameController = TextEditingController(text: debt?.personName ?? '');
    _amountController = TextEditingController(
      text: debt != null
          ? NumberFormatter.formatWithCommas(debt.totalAmount ~/ 100)
          : '',
    );
    _dueDate = debt?.dueDate;
    _leadDays = debt?.leadDays ?? 2;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final today = DateTime.now();
    final initial = _dueDate ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: DateTime(today.year - 2),
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
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _nameError = null;
      _amountError = null;
    });

    final rawName = _nameController.text;
    final sanitizedName = rawName.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (sanitizedName.isEmpty) {
      setState(() => _nameError = 'الاسم مطلوب');
      return;
    }

    final parsedAmount = NumberFormatter.parsePositiveInteger(_amountController.text);
    if (parsedAmount == null || parsedAmount <= 0) {
      setState(() => _amountError = 'برجاء إدخال مبلغ صحيح أكبر من الصفر');
      return;
    }

    if (parsedAmount > 100000000) {
      setState(() => _amountError = 'المبلغ يتجاوز الحد الأقصى 100,000,000 جنيه');
      return;
    }

    final totalAmountPiastres = parsedAmount * 100;

    // Edit validation: total cannot be set below what was already paid
    if (widget.debtToEdit != null) {
      if (totalAmountPiastres < widget.debtToEdit!.paidAmount) {
        setState(() => _amountError = 'المبلغ أقل من المدفوع');
        return;
      }
    }

    setState(() => _isSaving = true);

    final repo = ref.read(debtRepositoryProvider);

    try {
      if (widget.debtToEdit != null) {
        await repo.updateDebt(
          id: widget.debtToEdit!.id,
          personName: sanitizedName,
          direction: _direction,
          totalAmount: totalAmountPiastres,
          dueDate: _dueDate,
          leadDays: _leadDays,
        );
      } else {
        await repo.addDebt(
          personName: sanitizedName,
          direction: _direction,
          totalAmount: totalAmountPiastres,
          dueDate: _dueDate,
          leadDays: _leadDays,
        );
      }

      if (mounted) {
        final isEdit = widget.debtToEdit != null;
        final isOwe = _direction == 'owe';
        final formatted = '${NumberFormatter.formatCurrency(parsedAmount)} جنيه';

        await ActionFeedbackDialog.show(
          context: context,
          type: isEdit ? ActionFeedbackType.updated : ActionFeedbackType.added,
          title: isEdit ? 'تم تعديل الدين بنجاح' : 'تم حفظ الدين بنجاح',
          subtitle: isEdit
              ? 'تم تحديث بيانات الدين الخاص بـ $sanitizedName'
              : (isOwe
                  ? 'تم تسجيل دين عليك لـ $sanitizedName بمبلغ $formatted'
                  : 'تم تسجيل دين لك عند $sanitizedName بمبلغ $formatted'),
        );
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _amountError = e is ArgumentError ? e.message.toString() : 'حدث خطأ أثناء الحفظ';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'دين جديد',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 32.0,
            color: AppColors.text,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24.0,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Switch "عليا" / "ليا"
                        DebtDirectionSwitch(
                          selectedDirection: _direction,
                          onChanged: (dir) {
                            setState(() => _direction = dir);
                          },
                        ),
                        const SizedBox(height: 24.0),

                        // Field 1: "الاسم"
                        Text(
                          'الاسم',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: _nameError != null
                                  ? Colors.red
                                  : AppColors.inputBorder,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _nameController,
                            maxLength: 40,
                            buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14.0),
                            ),
                            onChanged: (_) {
                              if (_nameError != null) {
                                setState(() => _nameError = null);
                              }
                            },
                          ),
                        ),
                        if (_nameError != null) ...[
                          const SizedBox(height: 6.0),
                          Text(
                            _nameError!,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.0,
                              color: Colors.red,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20.0),

                        // Field 2: "المبلغ"
                        Text(
                          'المبلغ',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(14.0),
                            border: Border.all(
                              color: _amountError != null
                                  ? Colors.red
                                  : AppColors.inputBorder,
                              width: 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: TextField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9٠-٩,،]'),
                              ),
                              ThousandsSeparatorInputFormatter(),
                            ],
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.text,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14.0),
                            ),
                            onChanged: (_) {
                              if (_amountError != null) {
                                setState(() => _amountError = null);
                              }
                            },
                          ),
                        ),
                        if (_amountError != null) ...[
                          const SizedBox(height: 6.0),
                          Text(
                            _amountError!,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.0,
                              color: Colors.red,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20.0),

                        // Field 3: "تاريخ السداد (اختياري)"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تاريخ السداد (اختياري)',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            if (_dueDate != null)
                              GestureDetector(
                                onTap: () => setState(() => _dueDate = null),
                                child: Text(
                                  'بدون تاريخ سداد',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.0,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8.0),
                        GestureDetector(
                          onTap: _pickDueDate,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14.0),
                              border: Border.all(
                                color: AppColors.inputBorder,
                                width: 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 16.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _dueDate != null
                                          ? Icons.calendar_month_rounded
                                          : Icons.event_busy_outlined,
                                      size: 22.0,
                                      color: _dueDate != null
                                          ? AppColors.mainGreen
                                          : AppColors.secondaryText,
                                    ),
                                    const SizedBox(width: 10.0),
                                    Text(
                                      _dueDate != null
                                          ? '${_dueDate!.day.toArabicDigits()} ${ArabicDateHelper.getMonthName(_dueDate!.month)}'
                                          : 'بدون تاريخ سداد (غير محدد)',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 16.0,
                                        fontWeight: _dueDate != null
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: _dueDate != null
                                            ? AppColors.text
                                            : AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_dueDate != null)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      setState(() => _dueDate = null);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0,
                                        vertical: 6.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.close_rounded,
                                            size: 16.0,
                                            color: Colors.red.shade700,
                                          ),
                                          const SizedBox(width: 4.0),
                                          Text(
                                            'إلغاء',
                                            style: TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    'تحديد موعد',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.mainGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8.0),

                        // Note under due date exactly as in the screenshot:
                        // "لو حددت تاريخ هنبعتلك إشعار قبله، ولو سبته فاضي مفيش إشعار."
                        Text(
                          'لو حددت تاريخ هنبعتلك إشعار قبله، ولو سبته فاضي مفيش إشعار.',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                        ),

                        if (_dueDate != null) ...[
                          const SizedBox(height: 16.0),
                          Text(
                            'تذكير قبل الميعاد بـ',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              Expanded(
                                child: _LeadDaysChip(
                                  label: '٣ أيام',
                                  isSelected: _leadDays == 3,
                                  onTap: () => setState(() => _leadDays = 3),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: _LeadDaysChip(
                                  label: 'يومين',
                                  isSelected: _leadDays == 2,
                                  onTap: () => setState(() => _leadDays = 2),
                                ),
                              ),
                              const SizedBox(width: 10.0),
                              Expanded(
                                child: _LeadDaysChip(
                                  label: 'يوم',
                                  isSelected: _leadDays == 1,
                                  onTap: () => setState(() => _leadDays = 1),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const Spacer(),
                        const SizedBox(height: 24.0),

                        // Button "حفظ"
                        SizedBox(
                          height: 52.0,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4A7C59),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.0),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20.0,
                                    height: 20.0,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.0,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
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
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LeadDaysChip extends StatelessWidget {
  const _LeadDaysChip({
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 44.0,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE2EFEA) : AppColors.card,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isSelected ? const Color(0xFF4A7C59) : AppColors.inputBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2A5949) : AppColors.text,
          ),
        ),
      ),
    );
  }
}
