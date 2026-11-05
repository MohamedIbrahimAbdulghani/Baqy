import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../domain/models/category_item.dart';
import '../providers/expense_providers.dart';

class CategoryFormScreen extends ConsumerStatefulWidget {
  const CategoryFormScreen({
    super.key,
    this.categoryToEdit,
  });

  final CategoryItem? categoryToEdit;

  @override
  ConsumerState<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends ConsumerState<CategoryFormScreen> {
  late final TextEditingController _nameController;
  late String _selectedIcon;
  late String _selectedColor;
  String? _errorMessage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final edit = widget.categoryToEdit;
    _nameController = TextEditingController(text: edit?.name ?? '');
    _selectedIcon = edit?.icon ?? CategoryIconHelper.customIconKeys.first;
    _selectedColor = edit?.color ?? CategoryIconHelper.customColorHexes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _sanitizeName(String input) {
    final sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (sanitized.length > 30) {
      return sanitized.substring(0, 30);
    }
    return sanitized;
  }

  Future<void> _handleSave() async {
    final rawName = _nameController.text;
    final sanitizedName = _sanitizeName(rawName);

    if (sanitizedName.isEmpty) {
      setState(() {
        _errorMessage = 'برجاء إدخال اسم النوع';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final categories = await ref.read(getCategoriesUseCaseProvider)();

      // Check duplicates (excluding the currently edited category)
      final duplicate = categories.any((c) =>
          c.id != widget.categoryToEdit?.id &&
          c.name.trim().toLowerCase() == sanitizedName.toLowerCase());

      if (duplicate) {
        if (mounted) {
          setState(() {
            _errorMessage = 'اسم النوع موجود بالفعل';
            _isSaving = false;
          });
        }
        return;
      }

      int resultCategoryId;
      if (widget.categoryToEdit != null) {
        final id = widget.categoryToEdit!.id;
        await ref.read(updateCategoryUseCaseProvider)(
          id: id,
          name: sanitizedName,
          icon: _selectedIcon,
          color: _selectedColor,
        );
        resultCategoryId = id;
      } else {
        resultCategoryId = await ref.read(addCategoryUseCaseProvider)(
          name: sanitizedName,
          icon: _selectedIcon,
          color: _selectedColor,
        );
      }

      // Refresh categories list
      ref.invalidate(categoriesProvider);

      if (mounted) {
        context.pop(resultCategoryId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء الحفظ';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar with back arrow and title "نوع جديد"
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
                      'نوع جديد',
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

              // Form content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Field 1: Label "اسم النوع"
                      const Text(
                        'اسم النوع',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 8.0),

                      // Text input for category name
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: _errorMessage != null ? Colors.red : AppColors.dividers,
                            width: 1.0,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _nameController,
                          maxLength: 30,
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
                          onChanged: (_) {
                            if (_errorMessage != null) {
                              setState(() => _errorMessage = null);
                            }
                          },
                        ),
                      ),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 6.0),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.0,
                            color: Colors.red,
                          ),
                        ),
                      ],

                      const SizedBox(height: 28.0),

                      // Field 2: Label "الأيقونة"
                      const Text(
                        'الأيقونة',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // 8 Icons in 2 rows of 4 columns
                      _buildIconsGrid(),

                      const SizedBox(height: 28.0),

                      // Field 3: Label "اللون"
                      const Text(
                        'اللون',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.0,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 12.0),

                      // 6 color dots
                      _buildColorsRow(),

                      const SizedBox(height: 32.0),
                    ],
                  ),
                ),
              ),

              // Button "حفظ"
              Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 8.0, 20.0, 20.0),
                child: SizedBox(
                  height: 54.0,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
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

  Widget _buildIconsGrid() {
    final icons = CategoryIconHelper.customIconKeys;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: icons.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 1.15,
      ),
      itemBuilder: (context, index) {
        final iconKey = icons[index];
        final isSelected = _selectedIcon == iconKey;
        final iconData = CategoryIconHelper.getIcon(iconKey);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _selectedIcon = iconKey);
            },
            borderRadius: BorderRadius.circular(16.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE8F1EE) : AppColors.card,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(
                  color: isSelected ? AppColors.mainGreen : AppColors.dividers,
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: Center(
                child: Icon(
                  iconData,
                  size: 26.0,
                  color: isSelected ? AppColors.mainGreen : const Color(0xFF4A554D),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildColorsRow() {
    final colors = CategoryIconHelper.customColorHexes;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: colors.map((hex) {
        final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
        final color = CategoryIconHelper.parseColor(hex);

        return GestureDetector(
          onTap: () {
            setState(() => _selectedColor = hex);
          },
          child: Container(
            width: 44.0,
            height: 44.0,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: const Color(0xFF1F2420), width: 2.2)
                  : null,
            ),
            child: Center(
              child: Container(
                width: isSelected ? 34.0 : 40.0,
                height: isSelected ? 34.0 : 40.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

