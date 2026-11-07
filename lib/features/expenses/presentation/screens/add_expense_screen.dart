import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_item.dart';
import '../providers/expense_providers.dart';
import '../widgets/category_chip.dart';
import '../widgets/dashed_chip.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  int? _selectedCategoryId;
  bool _isEditMode = false;
  String? _amountError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _sanitizeName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (sanitized.length > 60) {
      return sanitized.substring(0, 60);
    }
    return sanitized;
  }

  Future<void> _handleSave(List<CategoryItem> categories) async {
    final amountParsed = NumberFormatter.parsePositiveInteger(_amountController.text);
    if (amountParsed == null || amountParsed <= 0 || amountParsed > 100000000) {
      setState(() {
        _amountError = 'برجاء إدخال مبلغ صحيح أكبر من الصفر وحتى 100,000,000';
      });
      return;
    }

    if (categories.isEmpty) return;

    final selectedCategory = categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => categories.first,
    );

    final rawName = _nameController.text;
    final sanitizedName = _sanitizeName(rawName);

    // If name is empty, description is the category name
    final finalDescription = sanitizedName.isEmpty ? selectedCategory.name : sanitizedName;

    setState(() {
      _amountError = null;
      _isSaving = true;
    });

    try {
      final amountInPiastres = amountParsed * 100;

      await ref.read(addExpenseUseCaseProvider)(
        amountInPiastres: amountInPiastres,
        description: finalDescription,
        categoryId: selectedCategory.id,
        createdAt: DateTime.now().toUtc(),
      );

      // Invalidate Home queries so ring and last expenses update immediately
      ref.invalidate(currentMonthRemainingProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(yearsWithDataProvider);
      final currentYm = ref.read(selectedYearMonthProvider);
      final (year, _) = ArabicDateHelper.parseYearMonthKey(currentYm);
      ref.invalidate(monthsWithDataProvider(year));

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _amountError = 'حدث خطأ أثناء الحفظ';
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _openCreateCategory() async {
    final newCategoryId = await context.push<int?>('/category-form');
    if (newCategoryId != null && mounted) {
      setState(() {
        _selectedCategoryId = newCategoryId;
        _isEditMode = false;
      });
    }
  }

  Future<void> _openEditCategory(CategoryItem category) async {
    final editedId = await context.push<int?>(
      '/category-form',
      extra: category,
    );
    if (editedId != null && mounted) {
      setState(() {
        _selectedCategoryId = editedId;
        _isEditMode = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with back arrow and title "مصروف جديد"
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(8.0),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 22.0,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    const Text(
                      'مصروف جديد',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12.0),

              // Form fields
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.mainGreen),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'تعذر تحميل التصنيفات',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(categoriesProvider),
                          icon: const Icon(Icons.refresh, color: AppColors.mainGreen),
                          label: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppColors.mainGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (categories) {
                    // Default to first category if not selected or invalid
                    if (_selectedCategoryId == null ||
                        !categories.any((c) => c.id == _selectedCategoryId)) {
                      if (categories.isNotEmpty) {
                        _selectedCategoryId = categories.first.id;
                      }
                    }

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Field 1: Label "الاسم"
                          const Text(
                            'الاسم',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8.0),

                          // Text input for name
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: AppColors.dividers,
                                width: 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: _nameController,
                              maxLength: 60,
                              buildCounter: (
                                _, {
                                required currentLength,
                                required isFocused,
                                maxLength,
                              }) =>
                                  null,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24.0),

                          // Field 2: Label "المبلغ"
                          const Text(
                            'المبلغ',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 8.0),

                          // Text input for amount
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16.0),
                              border: Border.all(
                                color: _amountError != null
                                    ? Colors.red
                                    : AppColors.dividers,
                                width: 1.0,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: TextField(
                              controller: _amountController,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
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

                          const SizedBox(height: 28.0),

                          // Section Header: "النوع" on right, "تعديل" link on left
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'النوع',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isEditMode = !_isEditMode;
                                  });
                                },
                                child: Text(
                                  _isEditMode ? 'إلغاء' : 'تعديل',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    color: _isEditMode
                                        ? Colors.red
                                        : AppColors.mainGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12.0),

                          // Category Chips & "+ نوع جديد"
                          Wrap(
                            spacing: 8.0,
                            runSpacing: 10.0,
                            children: [
                              ...categories.map((cat) {
                                final isSelected = _selectedCategoryId == cat.id;

                                return CategoryChip(
                                  category: cat,
                                  isSelected: isSelected,
                                  isEditMode: _isEditMode,
                                  onTap: () {
                                    if (_isEditMode) {
                                      if (!cat.isDefault) {
                                        _openEditCategory(cat);
                                      }
                                    } else {
                                      setState(() {
                                        _selectedCategoryId = cat.id;
                                      });
                                    }
                                  },
                                );
                              }),

                              // "+ نوع جديد" chip
                              DashedChip(
                                onTap: _openCreateCategory,
                              ),
                            ],
                          ),

                          const SizedBox(height: 32.0),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Button "حفظ"
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
                child: SizedBox(
                  height: 54.0,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            categoriesAsync.whenData((categories) {
                              _handleSave(categories);
                            });
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mainGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.0),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24.0,
                            height: 24.0,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'حفظ',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 18.0,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

