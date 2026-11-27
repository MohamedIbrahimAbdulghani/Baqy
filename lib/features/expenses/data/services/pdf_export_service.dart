import 'dart:math';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../domain/models/month_export_data.dart';

class PdfExportService {
  static const PdfColor colorBg = PdfColor.fromInt(0xFFF8F6F1);
  static const PdfColor colorGreen = PdfColor.fromInt(0xFF4E8B7A);
  static const PdfColor colorDarkGreen = PdfColor.fromInt(0xFF2F6B5A);
  static const PdfColor colorLightGreen = PdfColor.fromInt(0xFFE3EEE9);
  static const PdfColor colorText = PdfColor.fromInt(0xFF1F2420);
  static const PdfColor colorSecondaryText = PdfColor.fromInt(0xFF5F675F);
  static const PdfColor colorDividers = PdfColor.fromInt(0xFFE8E3D8);
  static const PdfColor colorCard = PdfColors.white;

  /// Generates the complete A4 PDF document bytes
  static Future<Uint8List> generate({
    required MonthExportData data,
    required Uint8List fontRegularBytes,
    required Uint8List fontBoldBytes,
    required Map<String, String> labels,
    required bool isArabic,
  }) async {
    final ttfRegular = pw.Font.ttf(fontRegularBytes.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontBoldBytes.buffer.asByteData());

    final theme = pw.ThemeData.withFont(
      base: ttfRegular,
      bold: ttfBold,
    );

    final pdf = pw.Document(theme: theme);

    // Helpers
    String formatMoney(int piastres) {
      final pounds = piastres ~/ 100;
      final currency = labels['currencyEgp'] ?? 'جنيه';
      if (isArabic) {
        return '${_toArabicDigits(pounds.toString())} $currency';
      }
      return '$pounds $currency';
    }

    String formatNumber(int n) {
      if (isArabic) {
        return _toArabicDigits(n.toString());
      }
      return n.toString();
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 500,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        textDirection:
            isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 8.0),
            margin: const pw.EdgeInsets.only(bottom: 12.0),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: colorDividers, width: 1.0),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: pw.BoxDecoration(
                        color: colorDarkGreen,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(6.0),
                        ),
                      ),
                      child: pw.Text(
                        labels['appTitle'] ?? 'باقي',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 14.0,
                          color: PdfColors.white,
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 8.0),
                    pw.Text(
                      data.monthTitle,
                      style: pw.TextStyle(
                        font: ttfBold,
                        fontSize: 16.0,
                        color: colorText,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  '${labels['exportCreatedAt'] ?? 'تاريخ الإنشاء'}: ${_formatDate(data.createdAt, isArabic)}',
                  style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 9.0,
                    color: colorSecondaryText,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          final pageStr = (labels['exportPageOf'] ?? 'صفحة {current} من {total}')
              .replaceAll('{current}', formatNumber(context.pageNumber))
              .replaceAll('{total}', formatNumber(context.pagesCount));

          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 10.0),
            alignment: pw.Alignment.center,
            child: pw.Text(
              pageStr,
              style: pw.TextStyle(
                font: ttfRegular,
                fontSize: 9.0,
                color: colorSecondaryText,
              ),
            ),
          );
        },
        build: (context) {
          return [
            // 1. Summary Cards
            pw.Container(
              padding: const pw.EdgeInsets.all(12.0),
              decoration: pw.BoxDecoration(
                color: colorLightGreen.flatten(),
                borderRadius: const pw.BorderRadius.all(
                  pw.Radius.circular(8.0),
                ),
                border: pw.Border.all(color: colorDividers, width: 1.0),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    labels['exportSummaryTitle'] ?? 'ملخص الشهر',
                    style: pw.TextStyle(
                      font: ttfBold,
                      fontSize: 13.0,
                      color: colorDarkGreen,
                    ),
                  ),
                  pw.SizedBox(height: 8.0),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem(
                        ttfBold,
                        ttfRegular,
                        labels['exportTotalExpenses'] ?? 'إجمالي المصاريف',
                        formatMoney(data.expenses),
                        colorText,
                      ),
                      if (data.income > 0)
                        _buildSummaryItem(
                          ttfBold,
                          ttfRegular,
                          labels['exportTotalIncome'] ?? 'إجمالي الدخل',
                          formatMoney(data.income),
                          colorGreen,
                        ),
                      if (data.budget > 0)
                        _buildSummaryItem(
                          ttfBold,
                          ttfRegular,
                          labels['exportMonthBudget'] ?? 'ميزانية الشهر',
                          formatMoney(data.budget),
                          colorText,
                        ),
                      _buildSummaryItem(
                        ttfBold,
                        ttfRegular,
                        labels['exportRemainingAmount'] ?? 'المبلغ المتبقي',
                        formatMoney(data.remaining),
                        data.remaining >= 0 ? colorDarkGreen : PdfColors.red800,
                      ),
                      _buildSummaryItem(
                        ttfBold,
                        ttfRegular,
                        labels['exportOperationsCount'] ?? 'عدد العمليات',
                        formatNumber(data.operationsCount),
                        colorText,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16.0),

            // 2. Charts Section
            if (data.categories.isNotEmpty) ...[
              // Chart 1: Bar Chart per category
              _buildSectionTitle(
                ttfBold,
                labels['exportChartCategoryExpenses'] ??
                    'توزيع المصاريف حسب التصنيف',
              ),
              pw.SizedBox(height: 8.0),
              _buildCategoryBarChart(
                data: data,
                ttfBold: ttfBold,
                ttfRegular: ttfRegular,
                formatMoney: formatMoney,
                formatNumber: formatNumber,
              ),

              pw.SizedBox(height: 16.0),

              // Chart 2 & 3 side by side: Daily Spending & Donut Share
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Daily bar chart
                  pw.Expanded(
                    flex: 6,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          ttfBold,
                          labels['exportChartDailyExpenses'] ??
                              'المصاريف اليومية خلال الشهر',
                        ),
                        pw.SizedBox(height: 8.0),
                        _buildDailyExpensesChart(
                          dailyExpenses: data.dailyExpenses,
                          ttfBold: ttfBold,
                          ttfRegular: ttfRegular,
                          formatNumber: formatNumber,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 14.0),
                  // Donut chart
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(
                          ttfBold,
                          labels['exportChartCategoryPercentage'] ??
                              'نسبة كل تصنيف من المصاريف',
                        ),
                        pw.SizedBox(height: 8.0),
                        _buildDonutChartWithLegend(
                          categories: data.categories,
                          ttfBold: ttfBold,
                          ttfRegular: ttfRegular,
                          formatNumber: formatNumber,
                          formatMoney: formatMoney,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 16.0),

              // 3. Category Table
              _buildSectionTitle(
                ttfBold,
                labels['exportColCategory'] ?? 'التصنيفات',
              ),
              pw.SizedBox(height: 6.0),
              _buildCategoryTable(
                data: data,
                ttfBold: ttfBold,
                ttfRegular: ttfRegular,
                labels: labels,
                formatMoney: formatMoney,
                formatNumber: formatNumber,
              ),

              pw.SizedBox(height: 16.0),
            ],

            // 4. Operations Table
            _buildSectionTitle(
              ttfBold,
              labels['exportSheetOperations'] ?? 'العمليات',
            ),
            pw.SizedBox(height: 6.0),
            _buildOperationsTable(
              transactions: data.transactions,
              ttfBold: ttfBold,
              ttfRegular: ttfRegular,
              labels: labels,
              formatMoney: formatMoney,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildSummaryItem(
    pw.Font ttfBold,
    pw.Font ttfRegular,
    String label,
    String value,
    PdfColor valueColor,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: ttfRegular,
            fontSize: 8.5,
            color: colorSecondaryText,
          ),
        ),
        pw.SizedBox(height: 2.0),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: 11.0,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(pw.Font ttfBold, String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: ttfBold,
        fontSize: 11.5,
        color: colorText,
      ),
    );
  }

  static pw.Widget _buildCategoryBarChart({
    required MonthExportData data,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required String Function(int) formatMoney,
    required String Function(int) formatNumber,
  }) {
    final maxAmount = data.categories.isEmpty
        ? 1
        : data.categories.map((c) => c.totalAmount).reduce(max);

    const double chartHeight = 75.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10.0),
      decoration: pw.BoxDecoration(
        color: colorCard,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8.0)),
        border: pw.Border.all(color: colorDividers, width: 1.0),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: chartHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: data.categories.map((cat) {
                final ratio = maxAmount > 0 ? (cat.totalAmount / maxAmount) : 0.0;
                final barHeight = max(ratio * (chartHeight - 20.0), 4.0);
                final color = _parsePdfColor(cat.colorHex);
                final pounds = cat.totalAmount ~/ 100;

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        formatNumber(pounds),
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 7.0,
                          color: color,
                        ),
                      ),
                      pw.SizedBox(height: 2.0),
                      pw.Container(
                        width: 18.0,
                        height: barHeight,
                        decoration: pw.BoxDecoration(
                          color: color,
                          borderRadius: const pw.BorderRadius.vertical(
                            top: pw.Radius.circular(3.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          pw.Container(height: 1.0, color: colorDividers),
          pw.SizedBox(height: 4.0),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: data.categories.map((cat) {
              return pw.Expanded(
                child: pw.Text(
                  cat.name,
                  textAlign: pw.TextAlign.center,
                  maxLines: 2,
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 7.5,
                    color: colorText,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDailyExpensesChart({
    required List<MonthExportDay> dailyExpenses,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required String Function(int) formatNumber,
  }) {
    if (dailyExpenses.isEmpty) {
      return pw.Container();
    }

    final maxAmount = dailyExpenses.map((d) => d.totalAmount).reduce(max);
    const double chartHeight = 70.0;

    return pw.Container(
      padding: const pw.EdgeInsets.all(10.0),
      decoration: pw.BoxDecoration(
        color: colorCard,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8.0)),
        border: pw.Border.all(color: colorDividers, width: 1.0),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            height: chartHeight,
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: dailyExpenses.map((day) {
                final ratio = maxAmount > 0 ? (day.totalAmount / maxAmount) : 0.0;
                final barHeight = max(ratio * (chartHeight - 18.0), 3.0);
                final pounds = day.totalAmount ~/ 100;

                return pw.Expanded(
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.FittedBox(
                        child: pw.Text(
                          formatNumber(pounds),
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 6.0,
                            color: colorSecondaryText,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 1.0),
                      pw.Container(
                        width: 10.0,
                        height: barHeight,
                        decoration: const pw.BoxDecoration(
                          color: colorGreen,
                          borderRadius: pw.BorderRadius.vertical(
                            top: pw.Radius.circular(2.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          pw.Container(height: 1.0, color: colorDividers),
          pw.SizedBox(height: 3.0),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: dailyExpenses.map((day) {
              return pw.Expanded(
                child: pw.Text(
                  formatNumber(day.dayNumber),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    font: ttfRegular,
                    fontSize: 6.5,
                    color: colorText,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildDonutChartWithLegend({
    required List<MonthExportCategory> categories,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required String Function(int) formatNumber,
    required String Function(int) formatMoney,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10.0),
      decoration: pw.BoxDecoration(
        color: colorCard,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8.0)),
        border: pw.Border.all(color: colorDividers, width: 1.0),
      ),
      child: pw.Row(
        children: [
          // Donut pie chart
          pw.SizedBox(
            width: 80.0,
            height: 80.0,
            child: pw.Chart(
              grid: pw.PieGrid(),
              datasets: categories.map((cat) {
                return pw.PieDataSet(
                  value: cat.totalAmount.toDouble(),
                  color: _parsePdfColor(cat.colorHex),
                  innerRadius: 22.0,
                  borderColor: PdfColors.white,
                  borderWidth: 1.0,
                );
              }).toList(),
            ),
          ),
          pw.SizedBox(width: 10.0),
          // Legend list
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisSize: pw.MainAxisSize.min,
              children: categories.take(6).map((cat) {
                final color = _parsePdfColor(cat.colorHex);
                return pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 7.0,
                        height: 7.0,
                        decoration: pw.BoxDecoration(
                          color: color,
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(2.0),
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 4.0),
                      pw.Expanded(
                        child: pw.Text(
                          cat.name,
                          overflow: pw.TextOverflow.clip,
                          maxLines: 1,
                          style: pw.TextStyle(
                            font: ttfRegular,
                            fontSize: 7.5,
                            color: colorText,
                          ),
                        ),
                      ),
                      pw.Text(
                        '${cat.percentage.toStringAsFixed(1)}%',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 7.5,
                          color: colorSecondaryText,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCategoryTable({
    required MonthExportData data,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required Map<String, String> labels,
    required String Function(int) formatMoney,
    required String Function(int) formatNumber,
  }) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: [
        labels['exportColCategory'] ?? 'التصنيف',
        labels['exportColOperationsCount'] ?? 'عدد العمليات',
        labels['exportColTotal'] ?? 'الإجمالي',
        labels['exportColPercentage'] ?? 'النسبة',
      ],
      data: data.categories.map((c) {
        return [
          c.name,
          formatNumber(c.transactionCount),
          formatMoney(c.totalAmount),
          '${c.percentage.toStringAsFixed(1)}%',
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        font: ttfBold,
        fontSize: 8.5,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: colorDarkGreen),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.5),
      cellStyle: pw.TextStyle(
        font: ttfRegular,
        fontSize: 8.0,
        color: colorText,
      ),
      border: pw.TableBorder.all(color: colorDividers, width: 0.5),
      cellAlignments: {
        0: pw.Alignment.centerRight,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
      },
    );
  }

  static pw.Widget _buildOperationsTable({
    required List<MonthExportTransaction> transactions,
    required pw.Font ttfBold,
    required pw.Font ttfRegular,
    required Map<String, String> labels,
    required String Function(int) formatMoney,
  }) {
    return pw.TableHelper.fromTextArray(
      headerCount: 1,
      headers: [
        labels['exportColDate'] ?? 'التاريخ',
        labels['exportColDay'] ?? 'اليوم',
        labels['exportColTime'] ?? 'الوقت',
        labels['exportColCategory'] ?? 'التصنيف',
        labels['exportColDescription'] ?? 'البيان / الملاحظة',
        labels['exportColType'] ?? 'النوع',
        labels['exportColAmount'] ?? 'المبلغ',
      ],
      data: transactions.map((tx) {
        final desc = tx.note != null && tx.note!.isNotEmpty
            ? '${tx.description} (${tx.note})'
            : tx.description;

        return [
          tx.dateText,
          tx.dayName,
          tx.timeText,
          tx.categoryName,
          desc,
          tx.typeText,
          formatMoney(tx.amount),
        ];
      }).toList(),
      headerStyle: pw.TextStyle(
        font: ttfBold,
        fontSize: 8.0,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: colorDarkGreen),
      headerPadding: const pw.EdgeInsets.symmetric(horizontal: 5.0, vertical: 4.0),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5.0, vertical: 3.0),
      cellStyle: pw.TextStyle(
        font: ttfRegular,
        fontSize: 7.5,
        color: colorText,
      ),
      border: pw.TableBorder.all(color: colorDividers, width: 0.5),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.center,
        6: pw.Alignment.center,
      },
    );
  }

  static String _formatDate(DateTime dt, bool isArabic) {
    final local = dt.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final text = '$y-$m-$d $hh:$mm';
    if (isArabic) {
      return _toArabicDigits(text);
    }
    return text;
  }

  static String _toArabicDigits(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = input;
    for (int i = 0; i < 10; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  static PdfColor _parsePdfColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      if (clean.length == 6) {
        return PdfColor.fromInt(int.parse('0xFF$clean'));
      } else if (clean.length == 8) {
        return PdfColor.fromInt(int.parse('0x$clean'));
      }
    } catch (_) {}
    return colorGreen;
  }
}
