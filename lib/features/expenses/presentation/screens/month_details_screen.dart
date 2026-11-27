import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/baqy_refresh.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/services/excel_export_service.dart';
import '../../data/services/pdf_export_service.dart';
import '../../domain/models/category_details_args.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/month_export_data.dart';
import '../providers/expense_providers.dart';
import '../widgets/month_expenses_chart.dart';

class _PdfIsolateArgs {
  final MonthExportData data;
  final Uint8List fontRegularBytes;
  final Uint8List fontBoldBytes;
  final Map<String, String> labels;
  final bool isArabic;

  const _PdfIsolateArgs({
    required this.data,
    required this.fontRegularBytes,
    required this.fontBoldBytes,
    required this.labels,
    required this.isArabic,
  });
}

Future<Uint8List> _generatePdfIsolate(_PdfIsolateArgs args) async {
  return await PdfExportService.generate(
    data: args.data,
    fontRegularBytes: args.fontRegularBytes,
    fontBoldBytes: args.fontBoldBytes,
    labels: args.labels,
    isArabic: args.isArabic,
  );
}

class _ExcelIsolateArgs {
  final MonthExportData data;
  final Map<String, String> labels;

  const _ExcelIsolateArgs({
    required this.data,
    required this.labels,
  });
}

Uint8List _generateExcelIsolate(_ExcelIsolateArgs args) {
  return ExcelExportService.generate(
    data: args.data,
    labels: args.labels,
  );
}

class MonthDetailsScreen extends ConsumerStatefulWidget {
  const MonthDetailsScreen({
    super.key,
    this.initialYearMonth,
  });

  final String? initialYearMonth;

  @override
  ConsumerState<MonthDetailsScreen> createState() => _MonthDetailsScreenState();
}

class _MonthDetailsScreenState extends ConsumerState<MonthDetailsScreen> {
  late String _currentYearMonth;
  late DateTime _selectedDay;
  bool _initializedLatestDay = false;
  bool _isExportingPdf = false;
  bool _isExportingExcel = false;

  Map<String, String> _extractExportLabels(AppLocalizations l10n) {
    return {
      'appName': l10n.appTitle,
      'currencyEgp': l10n.currencyEgp,
      'exportSummaryTitle': l10n.exportSummaryTitle,
      'exportTotalExpenses': l10n.exportTotalExpenses,
      'exportTotalIncome': l10n.exportTotalIncome,
      'exportMonthBudget': l10n.exportMonthBudget,
      'exportRemainingAmount': l10n.exportRemainingAmount,
      'exportOperationsCount': l10n.exportOperationsCount,
      'exportCreatedAt': l10n.exportCreatedAt,
      'exportSheetSummary': l10n.exportSheetSummary,
      'exportSheetOperations': l10n.exportSheetOperations,
      'exportChartCategoryExpenses': l10n.exportChartCategoryExpenses,
      'exportChartDailyExpenses': l10n.exportChartDailyExpenses,
      'exportChartCategoryPercentage': l10n.exportChartCategoryPercentage,
      'exportColCategory': l10n.exportColCategory,
      'exportColOperationsCount': l10n.exportColOperationsCount,
      'exportColTotal': l10n.exportColTotal,
      'exportColPercentage': l10n.exportColPercentage,
      'exportColDate': l10n.exportColDate,
      'exportColDay': l10n.exportColDay,
      'exportColTime': l10n.exportColTime,
      'exportColDescription': l10n.exportColDescription,
      'exportColType': l10n.exportColType,
      'exportColAmount': l10n.exportColAmount,
      'exportTypeExpense': l10n.exportTypeExpense,
      'exportTypeIncome': l10n.exportTypeIncome,
      'exportTypeSaving': l10n.exportTypeSaving,
      'exportPageOf': l10n.exportPageOf('{current}', '{total}'),
      'daySaturday': l10n.daySaturday,
      'daySunday': l10n.daySunday,
      'dayMonday': l10n.dayMonday,
      'dayTuesday': l10n.dayTuesday,
      'dayWednesday': l10n.dayWednesday,
      'dayThursday': l10n.dayThursday,
      'dayFriday': l10n.dayFriday,
    };
  }

  static const MethodChannel _fileSaverChannel =
      MethodChannel('com.mohamedibrahim.baqy/file_saver');

  Future<bool> _saveToDownloads({
    required Uint8List bytes,
    required String fileName,
    required bool isPdf,
  }) async {
    // 1. Try native platform channel (Android MediaStore Downloads without storage permissions)
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final success = await _fileSaverChannel.invokeMethod<bool>(
          'saveToDownloads',
          {
            'fileName': fileName,
            'bytes': bytes,
            'mimeType': isPdf
                ? 'application/pdf'
                : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        );
        if (success == true) return true;
      } catch (_) {}
    }

    // 2. Direct filesystem fallback for iOS/Desktop or older devices
    try {
      Directory? targetDir;
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
      targetDir ??= await getExternalStorageDirectory();
      targetDir ??= await getApplicationDocumentsDirectory();

      final targetFile = File('${targetDir.path}/$fileName');
      await targetFile.writeAsBytes(bytes, flush: true);
      return true;
    } catch (_) {}
    return false;
  }

  Future<void> _shareFile({
    required Uint8List fileBytes,
    required String fileName,
    required String pageTitle,
  }) async {
    File? tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(fileBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(tempFile.path)],
          text: pageTitle,
        ),
      );
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.exportFailedSnackbar,
              style: const TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _showExportBottomSheet({
    required BuildContext context,
    required bool isPdf,
    required MonthExportData data,
    required Uint8List fileBytes,
    required String fileName,
    required String pageTitle,
    required AppLocalizations l10n,
  }) async {
    final formatTitle = isPdf ? 'ملف PDF' : 'شيت Excel';
    final formatIcon = isPdf
        ? Icons.picture_as_pdf_rounded
        : Icons.table_chart_rounded;
    final formatColor = isPdf
        ? const Color(0xFFD32F2F)
        : const Color(0xFF2E7D32);

    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 28.0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20.0),
              ),
              boxShadow: AppDimensions.cardShadow,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40.0,
                      height: 4.0,
                      margin: const EdgeInsets.only(bottom: 16.0),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryText.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2.0),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 44.0,
                        height: 44.0,
                        decoration: BoxDecoration(
                          color: formatColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: Icon(formatIcon, color: formatColor, size: 24.0),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$formatTitle - $pageTitle',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 17.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              '${data.operationsCount} عملية • ${NumberFormatter.formatCurrency(data.expenses ~/ 100)} جنيه',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 13.0,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20.0),
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      final saved = await _saveToDownloads(
                        bytes: fileBytes,
                        fileName: fileName,
                        isPdf: isPdf,
                      );
                      if (!mounted) return;
                      if (saved) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20.0),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    l10n.exportSavedSuccess,
                                    style: const TextStyle(fontFamily: AppTheme.fontFamily),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.darkGreen,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      } else {
                        await _shareFile(
                          fileBytes: fileBytes,
                          fileName: fileName,
                          pageTitle: pageTitle,
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded, color: Colors.white),
                    label: Text(
                      l10n.exportDownloadButton,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.darkGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(bottomSheetContext);
                      await _shareFile(
                        fileBytes: fileBytes,
                        fileName: fileName,
                        pageTitle: pageTitle,
                      );
                    },
                    icon: Icon(Icons.share_rounded, color: AppColors.darkGreen),
                    label: Text(
                      l10n.exportShareButton,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkGreen,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14.0),
                      side: BorderSide(
                        color: AppColors.darkGreen.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleExport({required bool isPdf}) async {
    if (_isExportingPdf || _isExportingExcel) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      if (isPdf) {
        _isExportingPdf = true;
      } else {
        _isExportingExcel = true;
      }
    });

    try {
      final (currentYear, currentMonth) =
          ArabicDateHelper.parseYearMonthKey(_currentYearMonth);
      final pageTitle =
          ArabicDateHelper.formatMonthYear(currentYear, currentMonth);

      final buildDataUseCase = ref.read(buildMonthExportDataUseCaseProvider);
      final exportData = await buildDataUseCase(
        yearMonth: _currentYearMonth,
        formatDayName: (date) {
          switch (date.weekday) {
            case DateTime.saturday:
              return l10n.daySaturday;
            case DateTime.sunday:
              return l10n.daySunday;
            case DateTime.monday:
              return l10n.dayMonday;
            case DateTime.tuesday:
              return l10n.dayTuesday;
            case DateTime.wednesday:
              return l10n.dayWednesday;
            case DateTime.thursday:
              return l10n.dayThursday;
            case DateTime.friday:
              return l10n.dayFriday;
            default:
              return '';
          }
        },
        formatTime: (date) =>
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        typeExpenseLabel: l10n.exportTypeExpense,
        typeIncomeLabel: l10n.exportTypeIncome,
        typeSavingLabel: l10n.exportTypeSaving,
        monthTitle: pageTitle,
      );

      if (!mounted) return;

      if (exportData == null || exportData.transactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.exportNoOperationsSnackbar,
              style: const TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            backgroundColor: AppColors.darkGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      final labels = _extractExportLabels(l10n);

      Uint8List fileBytes;
      String fileExtension;

      if (isPdf) {
        fileExtension = 'pdf';
        final regularFontData =
            await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
        final boldFontData =
            await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

        fileBytes = await compute(
          _generatePdfIsolate,
          _PdfIsolateArgs(
            data: exportData,
            fontRegularBytes: regularFontData.buffer.asUint8List(),
            fontBoldBytes: boldFontData.buffer.asUint8List(),
            labels: labels,
            isArabic: isArabic,
          ),
        );
      } else {
        fileExtension = 'xlsx';
        fileBytes = await compute(
          _generateExcelIsolate,
          _ExcelIsolateArgs(
            data: exportData,
            labels: labels,
          ),
        );
      }

      final String monthName = ArabicDateHelper.getMonthName(currentMonth);
      final fileName = isArabic
          ? 'مصاريف شهر $monthName - Baqy.$fileExtension'
          : 'Expenses for $monthName - Baqy.$fileExtension';

      if (!mounted) return;

      await _showExportBottomSheet(
        context: context,
        isPdf: isPdf,
        data: exportData,
        fileBytes: fileBytes,
        fileName: fileName,
        pageTitle: pageTitle,
        l10n: l10n,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.exportFailedSnackbar,
              style: const TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExportingPdf = false;
          _isExportingExcel = false;
        });
      }
    }
  }

  Widget _buildExportButton({
    required String label,
    required Color brandColor,
    required IconData icon,
    required String tooltip,
    required String semanticsLabel,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    final bool isBusy = _isExportingPdf || _isExportingExcel;
    return Semantics(
      label: semanticsLabel,
      button: true,
      enabled: !isBusy,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isBusy ? null : onTap,
            borderRadius: BorderRadius.circular(10.0),
            child: Container(
              height: 44.0,
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10.0),
                boxShadow: AppDimensions.cardShadow,
                border: Border.all(
                  color: brandColor.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: isLoading
                  ? SizedBox(
                      width: 16.0,
                      height: 16.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: brandColor,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 17.0,
                          color: brandColor,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w800,
                            color: brandColor,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.initialYearMonth != null &&
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(widget.initialYearMonth!)) {
      _currentYearMonth = widget.initialYearMonth!;
    } else {
      _currentYearMonth = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    }

    final (y, m) = ArabicDateHelper.parseYearMonthKey(_currentYearMonth);
    if (y == now.year && m == now.month) {
      _selectedDay = today;
      _initializedLatestDay = true;
    } else {
      // For a past month, default to the last day of that month initially
      _selectedDay = DateTime(y, m + 1, 0);
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
  }

  void _goToPreviousDay() {
    final prevDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day - 1,
    );
    setState(() {
      _selectedDay = prevDay;
      final newYm =
          ArabicDateHelper.formatYearMonthKey(prevDay.year, prevDay.month);
      if (newYm != _currentYearMonth) {
        _currentYearMonth = newYm;
      }
    });
  }

  void _goToNextDay() {
    if (_isToday) return;

    final nextDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + 1,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (nextDay.isAfter(today)) return;

    setState(() {
      _selectedDay = nextDay;
      final newYm =
          ArabicDateHelper.formatYearMonthKey(nextDay.year, nextDay.month);
      if (newYm != _currentYearMonth) {
        _currentYearMonth = newYm;
      }
    });
  }

  void _openCategoryDetails({
    required CategoryItem category,
    required bool isMonthMode,
  }) {
    context.push(
      '/category-details',
      extra: CategoryDetailsArgs(
        category: category,
        yearMonth: _currentYearMonth,
        day: isMonthMode ? null : _selectedDay,
        isMonthMode: isMonthMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If opening a past month and haven't checked latest expense day, check it once
    if (!_initializedLatestDay) {
      final latestDayAsync =
          ref.watch(latestExpenseDayForMonthProvider(_currentYearMonth));
      latestDayAsync.whenData((latestDay) {
        if (!_initializedLatestDay) {
          _initializedLatestDay = true;
          if (latestDay != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedDay = latestDay;
                });
              }
            });
          }
        }
      });
    }

    final l10n = AppLocalizations.of(context)!;
    final (currentYear, currentMonth) =
        ArabicDateHelper.parseYearMonthKey(_currentYearMonth);
    final String monthName = ArabicDateHelper.getMonthName(currentMonth);
    final String pageTitle =
        ArabicDateHelper.formatMonthYear(currentYear, currentMonth);

    final monthTotalsAsync =
        ref.watch(monthCategoryTotalsProvider(_currentYearMonth));
    final dayTotalsAsync =
        ref.watch(dayCategoryTotalsProvider(_selectedDay));
    final hasExpensesBeforeAsync =
        ref.watch(hasExpensesBeforeProvider(_selectedDay));

    final bool canGoBack = hasExpensesBeforeAsync.value ?? false;
    final bool canGoForward = !_isToday;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Back arrow on right, title "<month> <year>", PDF and Excel export buttons
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(8.0),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 22.0,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        pageTitle,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    _buildExportButton(
                      label: 'Excel',
                      brandColor: const Color(0xFF2E7D32),
                      icon: Icons.table_chart_rounded,
                      tooltip: l10n.exportExcelTooltip,
                      semanticsLabel: l10n.exportExcelSemantics,
                      isLoading: _isExportingExcel,
                      onTap: () => _handleExport(isPdf: false),
                    ),
                    const SizedBox(width: 8.0),
                    _buildExportButton(
                      label: 'PDF',
                      brandColor: const Color(0xFFD32F2F),
                      icon: Icons.picture_as_pdf_rounded,
                      tooltip: l10n.exportPdfTooltip,
                      semanticsLabel: l10n.exportPdfSemantics,
                      isLoading: _isExportingPdf,
                      onTap: () => _handleExport(isPdf: true),
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                child: BaqyRefresh(
                  onRefresh: () async {
                    ref.invalidate(databaseChangesProvider);
                    ref.invalidate(monthCategoryTotalsProvider(_currentYearMonth));
                    ref.invalidate(dayCategoryTotalsProvider(_selectedDay));
                    ref.invalidate(currentMonthRemainingProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    children: [
                    const SizedBox(height: 8.0),

                    // 1. Month Expenses Card with Vertical Bar Chart
                    monthTotalsAsync.when(
                      loading: () => Container(
                        height: 220.0,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                      error: (_, _) => Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'خطأ في تحميل مصاريف الشهر',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.red,
                                ),
                              ),
                              const SizedBox(height: 8.0),
                              TextButton.icon(
                                onPressed: () => ref.invalidate(monthCategoryTotalsProvider(_currentYearMonth)),
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
                      ),
                      data: (categoryTotals) {
                        return MonthExpensesChartCard(
                          monthName: monthName,
                          categoryTotals: categoryTotals,
                          onTapCategory: (category) {
                            _openCategoryDetails(
                              category: category,
                              isMonthMode: true,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16.0),

                    // 2. Day Selector Card: Previous Arrow (right), Day in Middle, Next Arrow (left)
                    Container(
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.cardRadius),
                        boxShadow: AppDimensions.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Right: Previous Day Arrow
                          InkWell(
                            onTap: canGoBack ? _goToPreviousDay : null,
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: canGoBack
                                    ? AppColors.lightGreen
                                    : AppColors.subtleBox,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18.0,
                                color: canGoBack
                                    ? AppColors.darkGreen
                                    : AppColors.secondaryText.withValues(alpha: 0.5),
                              ),
                            ),
                          ),

                          // Center: "<weekday> <day> <month>"
                          Text(
                            ArabicDateHelper.formatWeekdayDayMonth(_selectedDay),
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),

                          // Left: Next Day Arrow (faded and inactive when today)
                          InkWell(
                            onTap: canGoForward ? _goToNextDay : null,
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: canGoForward
                                    ? AppColors.lightGreen
                                    : AppColors.subtleBox,
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18.0,
                                color: canGoForward
                                    ? AppColors.darkGreen
                                    : AppColors.secondaryText.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // 3. Day's Expenses Grouped by Category
                    dayTotalsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                      error: (_, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'خطأ في تحميل مصاريف اليوم',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 8.0),
                            TextButton.icon(
                              onPressed: () => ref.invalidate(dayCategoryTotalsProvider(_selectedDay)),
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
                      data: (dayTotals) {
                        if (dayTotals.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: dayTotals.map((item) {
                            final int amountEgp = item.totalAmount ~/ 100;
                            final iconData = CategoryIconHelper.getIcon(
                              item.category.icon,
                            );
                            final categoryColor = CategoryIconHelper.parseColor(
                              item.category.color,
                            );
                            final isSavings = item.category.name == 'تحويش' ||
                                item.category.id < 0;
                            final String dayAmountText = amountEgp < 0
                                ? '-${NumberFormatter.formatCurrency(amountEgp.abs())} جنيه'
                                : '${NumberFormatter.formatCurrency(amountEgp)} جنيه';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.cardRadius,
                                ),
                                boxShadow: AppDimensions.cardShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _openCategoryDetails(
                                      category: item.category,
                                      isMonthMode: false,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.cardRadius,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 14.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Right: Icon chip, Category Name, Count
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 44.0,
                                              height: 44.0,
                                              decoration: BoxDecoration(
                                                color: isSavings
                                                    ? categoryColor.withValues(alpha: 0.15)
                                                    : AppColors.lightGreen,
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Icon(
                                                iconData,
                                                color: isSavings
                                                    ? categoryColor
                                                    : AppColors.mainGreen,
                                                size: 22.0,
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.category.name,
                                                  style: TextStyle(
                                                    fontFamily:
                                                        AppTheme.fontFamily,
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2.0),
                                                Text(
                                                  ArabicDateHelper.formatCount(
                                                    item.transactionCount,
                                                  ),
                                                  style: TextStyle(
                                                    fontFamily:
                                                        AppTheme.fontFamily,
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w400,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Left: Total amount and Small Arrow
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              dayAmountText,
                                              style: TextStyle(
                                                fontFamily: AppTheme.fontFamily,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.text,
                                              ),
                                            ),
                                            const SizedBox(width: 6.0),
                                            Icon(
                                              Icons.arrow_back_ios_new_rounded,
                                              size: 13.0,
                                              color: AppColors.text,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24.0),
                  ],
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
