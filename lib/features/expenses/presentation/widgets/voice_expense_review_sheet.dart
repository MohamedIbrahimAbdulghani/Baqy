import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/category_matcher.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/parsed_expense.dart';
import '../providers/expense_providers.dart';

/// Modal sheet to review, edit, merge, and confirm extracted voice expenses before saving.
class VoiceExpenseReviewSheet extends ConsumerStatefulWidget {
  final List<ParsedExpense> initialExpenses;
  final List<CategoryItem> categories;
  final String? transcript;
  final Future<void> Function(List<ParsedExpense> expenses) onSave;

  const VoiceExpenseReviewSheet({
    super.key,
    required this.initialExpenses,
    required this.categories,
    this.transcript,
    required this.onSave,
  });

  static Future<void> show({
    required BuildContext context,
    required List<ParsedExpense> initialExpenses,
    required List<CategoryItem> categories,
    String? transcript,
    required Future<void> Function(List<ParsedExpense> expenses) onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => VoiceExpenseReviewSheet(
        initialExpenses: initialExpenses,
        categories: categories,
        transcript: transcript,
        onSave: onSave,
      ),
    );
  }

  @override
  ConsumerState<VoiceExpenseReviewSheet> createState() =>
      _VoiceExpenseReviewSheetState();
}

class _EditableItem {
  final TextEditingController descriptionController;
  final TextEditingController amountController;
  String category;
  bool isNewCategory;
  ParsedExpenseCategoryProposal? newCategoryProposal;
  double? foreignAmount;
  String? foreignCurrency;
  String? quantityText;
  double confidence;
  String? errorMessage;
  final String originalCategory;

  _EditableItem({
    required String description,
    required int? amount,
    required this.category,
    this.isNewCategory = false,
    this.newCategoryProposal,
    this.foreignAmount,
    this.foreignCurrency,
    this.quantityText,
    this.confidence = 1.0,
  })  : originalCategory = category,
        descriptionController = TextEditingController(text: description),
        amountController =
            TextEditingController(text: (amount != null && amount > 0) ? '$amount' : '');

  bool get needsReview =>
      confidence < 0.6 ||
      amountController.text.trim().isEmpty ||
      (NumberFormatter.parsePositiveInteger(amountController.text) ?? 0) <= 0;

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }
}

class _VoiceExpenseReviewSheetState
    extends ConsumerState<VoiceExpenseReviewSheet> {
  late final List<_EditableItem> _items;
  bool _isSaving = false;
  late List<CategoryItem> _availableCategories;

  @override
  void initState() {
    super.initState();
    _availableCategories = List.from(widget.categories);

    final availableNames = _availableCategories.map((c) => c.name).toList();
    _items = widget.initialExpenses.map((e) {
      final resolvedCategory = e.isNewCategory
          ? e.category
          : CategoryMatcher.matchName(
              categoryName: e.category,
              availableNames: availableNames,
            );
      return _EditableItem(
        description: e.description,
        amount: e.amount,
        category: resolvedCategory,
        isNewCategory: e.isNewCategory,
        newCategoryProposal: e.newCategoryProposal,
        foreignAmount: e.foreignAmount,
        foreignCurrency: e.foreignCurrency,
        quantityText: e.quantityText,
        confidence: e.confidence,
      );
    }).toList();

    if (_items.isEmpty) {
      _addItem();
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  int get _liveTotalEgp {
    int total = 0;
    for (final item in _items) {
      final parsed = NumberFormatter.parsePositiveInteger(item.amountController.text);
      if (parsed != null && parsed > 0) {
        total += parsed;
      }
    }
    return total;
  }

  void _addItem() {
    final defaultCat = _availableCategories.isNotEmpty
        ? _availableCategories.first.name
        : 'أخرى';
    setState(() {
      _items.add(
        _EditableItem(
          description: '',
          amount: 0,
          category: defaultCat,
        ),
      );
    });
  }

  void _removeItem(int index) {
    if (_items.length <= 1) {
      setState(() {
        _items[0].descriptionController.clear();
        _items[0].amountController.clear();
      });
      return;
    }
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  void _mergeWithPrevious(int index) {
    if (index <= 0 || index >= _items.length) return;
    final prev = _items[index - 1];
    final curr = _items[index];

    setState(() {
      // Merge foreign currency or amounts
      if (curr.foreignAmount != null && prev.foreignAmount == null) {
        prev.foreignAmount = curr.foreignAmount;
        prev.foreignCurrency = curr.foreignCurrency;
      }
      if (curr.quantityText != null && prev.quantityText == null) {
        prev.quantityText = curr.quantityText;
      }
      final prevAmt = NumberFormatter.parsePositiveInteger(prev.amountController.text) ?? 0;
      final currAmt = NumberFormatter.parsePositiveInteger(curr.amountController.text) ?? 0;
      if (prevAmt == 0 && currAmt > 0) {
        prev.amountController.text = '$currAmt';
      }
      if (curr.descriptionController.text.isNotEmpty &&
          !prev.descriptionController.text.contains(curr.descriptionController.text)) {
        prev.descriptionController.text =
            '${prev.descriptionController.text} ${curr.descriptionController.text}'.trim();
      }
      final removed = _items.removeAt(index);
      removed.dispose();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم دمج العمليتين بنجاح'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _quickAddCategory() async {
    final nameCtrl = TextEditingController();
    String selectedIcon = CategoryIconHelper.allowedAiIconKeys.first;
    String selectedColor = CategoryIconHelper.customColorHexes.first;

    final created = await showDialog<CategoryItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppColors.card,
            title: const Text('تصنيف جديد سريع'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم التصنيف'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: CategoryIconHelper.customColorHexes.map((hex) {
                    final isSel = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = hex),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: CategoryIconHelper.parseColor(hex),
                          shape: BoxShape.circle,
                          border: isSel
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    Navigator.of(ctx).pop(
                      CategoryItem(
                        id: -DateTime.now().millisecondsSinceEpoch,
                        name: name,
                        icon: selectedIcon,
                        color: selectedColor,
                        createdByAi: false,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mainGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('إضافة'),
              ),
            ],
          ),
        ),
      ),
    );

    if (created != null) {
      setState(() {
        _availableCategories.add(created);
      });
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: AppColors.card,
          title: const Text(
            'إلغاء التغييرات؟',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('هل أنت متأكد من الخروج دون حفظ العمليات المستخرجة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('البقاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('خروج'),
            ),
          ],
        ),
      ),
    );
    return shouldPop ?? false;
  }

  Future<void> _handleSave() async {
    bool hasErrors = false;
    final List<ParsedExpense> verified = [];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final rawAmount = item.amountController.text.trim();
      final parsed = NumberFormatter.parsePositiveInteger(rawAmount);

      if (parsed == null || parsed <= 0) {
        setState(() {
          item.errorMessage = 'أدخل مبلغاً صحيحاً بالجنيه';
        });
        hasErrors = true;
      } else {
        setState(() {
          item.errorMessage = null;
        });
        final desc = item.descriptionController.text.trim();
        verified.add(
          ParsedExpense(
            amount: parsed,
            description: desc.isNotEmpty ? desc : item.category,
            category: item.category,
            isNewCategory: item.isNewCategory,
            newCategoryProposal: item.newCategoryProposal,
            foreignAmount: item.foreignAmount,
            foreignCurrency: item.foreignCurrency,
            quantityText: item.quantityText,
            confidence: 1.0,
          ),
        );
      }
    }

    if (hasErrors || verified.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 1. Save any new categories to the database
      for (final item in _items) {
        if (item.isNewCategory && item.newCategoryProposal != null) {
          final prop = item.newCategoryProposal!;
          try {
            await ref.read(addCategoryUseCaseProvider)(
              name: prop.name,
              icon: prop.icon,
              color: prop.color,
              createdByAi: true,
            );
          } catch (_) {}
        }
      }

      // 2. Save user correction rules (Section 4)
      for (final item in _items) {
        if (item.category != item.originalCategory) {
          final keyword = item.descriptionController.text.trim();
          if (keyword.isNotEmpty) {
            final catObj = _availableCategories.firstWhere(
              (c) => c.name == item.category,
              orElse: () => _availableCategories.first,
            );
            if (catObj.id > 0) {
              await ref.read(saveUserRuleUseCaseProvider)(
                keyword: keyword,
                categoryId: catObj.id,
              );
            }
          }
        }
      }

      // 3. Save transactions
      await widget.onSave(verified);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final categoryNames =
        _availableCategories.map((c) => c.name).toSet().toList();
    if (!categoryNames.contains('أخرى')) {
      categoryNames.add('أخرى');
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          margin: EdgeInsets.only(bottom: bottomInset),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.dividers,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                // Header with live total
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'مراجعة وتأكيد المصاريف',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 18.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 6.0,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Text(
                          'الإجمالي: ${NumberFormatter.formatCurrency(_liveTotalEgp)} جنيه',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.dividers),

                // Expandable Transcript Section (if available)
                if (widget.transcript != null &&
                    widget.transcript!.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(color: AppColors.dividers),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          initiallyExpanded: false,
                          leading: const Icon(
                            Icons.record_voice_over_outlined,
                            color: AppColors.mainGreen,
                            size: 20,
                          ),
                          title: const Text(
                            'تفريغ التسجيل المسموع',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.text,
                            ),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                                child: SelectableText(
                                  widget.transcript!,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13.0,
                                    color: AppColors.text,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],

                // Operations list
                Flexible(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20.0),
                    shrinkWrap: true,
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final item = _items[index];

                      return Dismissible(
                        key: ValueKey('review_item_${item.hashCode}_$index'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) => _removeItem(index),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: item.needsReview
                                  ? Colors.amber.shade700
                                  : AppColors.dividers,
                              width: item.needsReview ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'العملية ${index + 1}',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Badge "جديد"
                                  if (item.isNewCategory)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.mainGreen,
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: const Text(
                                        'جديد ★',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),

                                  // Badge "محتاج مراجعة"
                                  if (item.needsReview) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0,
                                        vertical: 2.0,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(6.0),
                                      ),
                                      child: Text(
                                        'محتاج مراجعة ⚠️',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 11.0,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],

                                  const Spacer(),

                                  // Merge button with previous item
                                  if (index > 0)
                                    TextButton.icon(
                                      onPressed: () => _mergeWithPrevious(index),
                                      icon: const Icon(
                                        Icons.merge_type_rounded,
                                        size: 16,
                                        color: AppColors.mainGreen,
                                      ),
                                      label: const Text(
                                        'دمج',
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: 12.0,
                                          color: AppColors.mainGreen,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(50, 30),
                                      ),
                                    ),

                                  // Delete icon
                                  if (_items.length > 1)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeItem(index),
                                    ),
                                ],
                              ),

                              // Foreign currency reference line
                              if (item.foreignAmount != null &&
                                  item.foreignCurrency != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'المبلغ الأصلي: ≈ ${item.foreignAmount} ${item.foreignCurrency}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mainGreen,
                                  ),
                                ),
                              ],

                              // Quantity / Specification reference line
                              if (item.quantityText != null &&
                                  item.quantityText!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 4.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(6.0),
                                  ),
                                  child: Text(
                                    'الكمية / المواصفات: ${item.quantityText}',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12.0,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 10),

                              // Amount & Description fields
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Amount in EGP
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: item.amountController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        labelText: 'المبلغ بالجنيه',
                                        suffixText: 'ج.م',
                                        errorText: item.errorMessage,
                                        filled: true,
                                        fillColor: AppColors.background,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.0),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Description
                                  Expanded(
                                    flex: 3,
                                    child: TextFormField(
                                      controller: item.descriptionController,
                                      decoration: InputDecoration(
                                        labelText: 'الوصف',
                                        hintText: 'مثال: فطار',
                                        filled: true,
                                        fillColor: AppColors.background,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10.0),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Category Dropdown
                              DropdownButtonFormField<String>(
                                initialValue: categoryNames.contains(item.category)
                                    ? item.category
                                    : CategoryMatcher.matchName(
                                        categoryName: item.category,
                                        availableNames: categoryNames,
                                      ),
                                decoration: InputDecoration(
                                  labelText: 'التصنيف',
                                  filled: true,
                                  fillColor: AppColors.background,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: categoryNames.map((name) {
                                  final catObj = _availableCategories.firstWhere(
                                    (c) => c.name == name,
                                    orElse: () => CategoryItem(
                                      id: 0,
                                      name: name,
                                      icon: 'other',
                                      color: '#9A9488',
                                    ),
                                  );
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Row(
                                      children: [
                                        Icon(
                                          CategoryIconHelper.getIcon(catObj.icon),
                                          size: 16,
                                          color: CategoryIconHelper.parseColor(
                                              catObj.color),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      item.category = val;
                                      item.isNewCategory = false;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Quick Add Category & Add Operation buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(
                          Icons.add_circle_outline,
                          color: AppColors.mainGreen,
                          size: 18,
                        ),
                        label: const Text(
                          'إضافة عملية يدوي',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppColors.mainGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _quickAddCategory,
                        icon: const Icon(
                          Icons.create_new_folder_outlined,
                          color: AppColors.secondaryText,
                          size: 18,
                        ),
                        label: const Text(
                          'تصنيف جديد',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppColors.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Action Buttons (Save All & Cancel)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  final shouldPop = await _onWillPop();
                                  if (shouldPop && context.mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            side: const BorderSide(color: AppColors.dividers),
                          ),
                          child: const Text(
                            'إلغاء',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 15.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _handleSave,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.mainGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            elevation: 0,
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'حفظ الكل',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
