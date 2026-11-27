import 'dart:typed_data';
import 'package:excel_community/excel_community.dart';
import '../../domain/models/month_export_data.dart';

class ExcelExportService {
  /// Generates a clean, executive-grade XLSX document with clear formatting and charts
  static Uint8List generate({
    required MonthExportData data,
    required Map<String, String> labels,
  }) {
    final excel = Excel.createExcel();

    // 1. Create Sheets
    final summarySheetName = labels['exportSheetSummary'] ?? 'ملخص';
    final opsSheetName = labels['exportSheetOperations'] ?? 'العمليات';

    final summarySheet = excel[summarySheetName];
    final opsSheet = excel[opsSheetName];

    // Remove the default empty sheet
    excel.delete('Sheet1');

    // Brand Palette Tokens
    final darkGreen = ExcelColor.fromHexString('#2F6B5A');
    final sageGreen = ExcelColor.fromHexString('#4E8B7A');
    final mintLight = ExcelColor.fromHexString('#E3EEE9');
    final zebraRow = ExcelColor.fromHexString('#F8FAF9');
    final textDark = ExcelColor.fromHexString('#1F2420');
    final textMuted = ExcelColor.fromHexString('#5F675F');
    final textWhite = ExcelColor.fromHexString('#FFFFFF');

    // Typography & Cell Styles
    final brandTitleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: darkGreen,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final brandSubtitleStyle = CellStyle(
      fontSize: 11,
      fontColorHex: textMuted,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final sectionHeaderStyle = CellStyle(
      bold: true,
      fontSize: 13,
      fontColorHex: darkGreen,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final kpiHeaderStyle = CellStyle(
      bold: true,
      fontSize: 10,
      backgroundColorHex: darkGreen,
      fontColorHex: textWhite,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final kpiValueStyle = CellStyle(
      bold: true,
      fontSize: 13,
      backgroundColorHex: mintLight,
      fontColorHex: darkGreen,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final tableHeaderPrimary = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: darkGreen,
      fontColorHex: textWhite,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final tableHeaderSecondary = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: sageGreen,
      fontColorHex: textWhite,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final totalRowStyle = CellStyle(
      bold: true,
      fontSize: 11,
      backgroundColorHex: mintLight,
      fontColorHex: darkGreen,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final cellWhiteCenter = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: textDark,
    );

    final cellZebraCenter = CellStyle(
      backgroundColorHex: zebraRow,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: textDark,
    );

    final cellWhiteRight = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: textDark,
    );

    final cellZebraRight = CellStyle(
      backgroundColorHex: zebraRow,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      fontColorHex: textDark,
    );

    // ==========================================
    // 2. BUILD SUMMARY SHEET ("ملخص")
    // ==========================================
    summarySheet.setColumnWidth(0, 22.0); // Category / Date
    summarySheet.setColumnWidth(1, 15.0); // Count / Day
    summarySheet.setColumnWidth(2, 18.0); // Total / Amount
    summarySheet.setColumnWidth(3, 16.0); // Percentage
    summarySheet.setColumnWidth(4, 16.0); // Extra / Spacing

    final appName = labels['appName'] ?? 'باقي';
    final createdAtText =
        '${data.createdAt.year}/${data.createdAt.month.toString().padLeft(2, '0')}/${data.createdAt.day.toString().padLeft(2, '0')} ${data.createdAt.hour.toString().padLeft(2, '0')}:${data.createdAt.minute.toString().padLeft(2, '0')}';

    // Single-cell clean header (no repetitive string glitches)
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('$appName - ${labels['exportSummaryTitle'] ?? 'ملخص شهر'} ${data.monthTitle}')
      ..cellStyle = brandTitleStyle;

    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1))
      ..value = TextCellValue(
        '${labels['exportCreatedAt'] ?? 'تاريخ الإنشاء'}: $createdAtText • ${labels['exportOperationsCount'] ?? 'العمليات'}: ${data.operationsCount} • ${labels['exportTotalExpenses'] ?? 'المصاريف'}: ${data.expenses ~/ 100} ${labels['currencyEgp'] ?? 'جنيه'}',
      )
      ..cellStyle = brandSubtitleStyle;

    // KPI Cards Block (Rows 3 & 4)
    final kpiHeaders = [
      labels['exportTotalExpenses'] ?? 'إجمالي المصاريف',
      labels['exportRemainingAmount'] ?? 'المبلغ المتبقي',
      labels['exportMonthBudget'] ?? 'ميزانية الشهر',
      labels['exportTotalIncome'] ?? 'إجمالي الدخل',
      labels['exportOperationsCount'] ?? 'عدد العمليات',
    ];

    final kpiValues = [
      DoubleCellValue(data.expenses / 100.0),
      DoubleCellValue(data.remaining / 100.0),
      DoubleCellValue(data.budget / 100.0),
      DoubleCellValue(data.income / 100.0),
      IntCellValue(data.operationsCount),
    ];

    for (var i = 0; i < kpiHeaders.length; i++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 3))
        ..value = TextCellValue(kpiHeaders[i])
        ..cellStyle = kpiHeaderStyle;

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4))
        ..value = kpiValues[i]
        ..cellStyle = kpiValueStyle;
    }

    // Category Breakdown Section
    var r = 6;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue(labels['exportChartCategoryExpenses'] ?? 'توزيع المصاريف حسب التصنيف')
      ..cellStyle = sectionHeaderStyle;

    r = 7;
    final catHeaderRow = r;
    final catCols = [
      labels['exportColCategory'] ?? 'التصنيف',
      labels['exportColOperationsCount'] ?? 'عدد العمليات',
      '${labels['exportColTotal'] ?? 'الإجمالي'} (${labels['currencyEgp'] ?? 'جنيه'})',
      '${labels['exportColPercentage'] ?? 'النسبة'} (%)',
    ];

    for (var c = 0; c < catCols.length; c++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: catHeaderRow))
        ..value = TextCellValue(catCols[c])
        ..cellStyle = tableHeaderPrimary;
    }

    final catStartRow = catHeaderRow + 2; // 1-based index in Excel formula
    var catIndex = 0;
    for (final cat in data.categories) {
      r++;
      final isZebra = catIndex % 2 == 1;
      final centerStyle = isZebra ? cellZebraCenter : cellWhiteCenter;
      final rightStyle = isZebra ? cellZebraRight : cellWhiteRight;

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(cat.name)
        ..cellStyle = rightStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = IntCellValue(cat.transactionCount)
        ..cellStyle = centerStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = DoubleCellValue(cat.totalAmount / 100.0)
        ..cellStyle = centerStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r))
        ..value = DoubleCellValue(cat.percentage)
        ..cellStyle = centerStyle;

      catIndex++;
    }
    final catEndRow = r + 1; // 1-based index in Excel formula

    // Category Table Total Row
    r++;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue(labels['exportTotalLabel'] ?? 'الإجمالي العام')
      ..cellStyle = totalRowStyle;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
      ..value = IntCellValue(data.operationsCount)
      ..cellStyle = totalRowStyle;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
      ..value = DoubleCellValue(data.expenses / 100.0)
      ..cellStyle = totalRowStyle;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r))
      ..value = DoubleCellValue(100.0)
      ..cellStyle = totalRowStyle;

    // Add Column Chart right beneath the Category Table for perfect mobile visibility
    if (data.categories.isNotEmpty) {
      try {
        final columnChart = ColumnChart(
          title: labels['exportChartCategoryExpenses'] ?? 'توزيع المصاريف حسب التصنيف',
          series: [
            ChartSeries(
              name: labels['exportTotalExpenses'] ?? 'المصاريف',
              categoriesRange: "$summarySheetName!\$A\$$catStartRow:\$A\$$catEndRow",
              valuesRange: "$summarySheetName!\$C\$$catStartRow:\$C\$$catEndRow",
            ),
          ],
          anchor: ChartAnchor.at(column: 0, row: r + 2, width: 6, height: 14),
        );
        summarySheet.addChart(columnChart);
      } catch (_) {}
    }

    // Daily Expenses Section (placed after chart area or table)
    r = r + 18;
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
      ..value = TextCellValue(labels['exportChartDailyExpenses'] ?? 'المصاريف اليومية خلال الشهر')
      ..cellStyle = sectionHeaderStyle;

    r++;
    final dailyCols = [
      labels['exportColDate'] ?? 'التاريخ',
      labels['exportColDay'] ?? 'اليوم',
      '${labels['exportTotalExpenses'] ?? 'إجمالي المصاريف'} (${labels['currencyEgp'] ?? 'جنيه'})',
    ];

    for (var c = 0; c < dailyCols.length; c++) {
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
        ..value = TextCellValue(dailyCols[c])
        ..cellStyle = tableHeaderSecondary;
    }

    var dayIndex = 0;
    for (final day in data.dailyExpenses) {
      r++;
      final local = day.date.toLocal();
      final isZebra = dayIndex % 2 == 1;
      final centerStyle = isZebra ? cellZebraCenter : cellWhiteCenter;
      final dateFormatted =
          '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r))
        ..value = TextCellValue(dateFormatted)
        ..cellStyle = centerStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r))
        ..value = TextCellValue(day.dayName)
        ..cellStyle = centerStyle;
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r))
        ..value = DoubleCellValue(day.totalAmount / 100.0)
        ..cellStyle = centerStyle;

      dayIndex++;
    }

    // ==========================================
    // 3. BUILD OPERATIONS SHEET ("العمليات")
    // ==========================================
    opsSheet.setColumnWidth(0, 15.0); // Date
    opsSheet.setColumnWidth(1, 14.0); // Day
    opsSheet.setColumnWidth(2, 12.0); // Time
    opsSheet.setColumnWidth(3, 18.0); // Category
    opsSheet.setColumnWidth(4, 32.0); // Description / Note
    opsSheet.setColumnWidth(5, 14.0); // Type
    opsSheet.setColumnWidth(6, 16.0); // Amount

    // Top Title in Operations Sheet
    opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
      ..value = TextCellValue('$appName - ${labels['exportSheetOperations'] ?? 'العمليات'} (${data.monthTitle})')
      ..cellStyle = brandTitleStyle;

    // Freeze header row on operations sheet (row 1 is headers)
    opsSheet.frozenRows = 2;

    final opsHeaders = [
      labels['exportColDate'] ?? 'التاريخ',
      labels['exportColDay'] ?? 'اليوم',
      labels['exportColTime'] ?? 'الوقت',
      labels['exportColCategory'] ?? 'التصنيف',
      labels['exportColDescription'] ?? 'البيان / الملاحظة',
      labels['exportColType'] ?? 'النوع',
      '${labels['exportColAmount'] ?? 'المبلغ'} (${labels['currencyEgp'] ?? 'جنيه'})',
    ];

    for (var c = 0; c < opsHeaders.length; c++) {
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 1))
        ..value = TextCellValue(opsHeaders[c])
        ..cellStyle = tableHeaderPrimary;
    }

    var opRow = 1;
    var txIndex = 0;
    for (final tx in data.transactions) {
      opRow++;
      final local = tx.createdAt.toLocal();
      final dateFormatted =
          '${local.year}/${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')}';
      final desc = tx.note != null && tx.note!.isNotEmpty
          ? '${tx.description} (${tx.note})'
          : tx.description;

      final isZebra = txIndex % 2 == 1;
      final centerStyle = isZebra ? cellZebraCenter : cellWhiteCenter;
      final rightStyle = isZebra ? cellZebraRight : cellWhiteRight;

      // Stored as human-readable formatted date string to prevent serial numbers on mobile
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: opRow))
        ..value = TextCellValue(dateFormatted)
        ..cellStyle = centerStyle;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: opRow))
        ..value = TextCellValue(tx.dayName)
        ..cellStyle = centerStyle;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: opRow))
        ..value = TextCellValue(tx.timeText)
        ..cellStyle = centerStyle;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: opRow))
        ..value = TextCellValue(tx.categoryName)
        ..cellStyle = centerStyle;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: opRow))
        ..value = TextCellValue(desc)
        ..cellStyle = rightStyle;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: opRow))
        ..value = TextCellValue(tx.typeText)
        ..cellStyle = centerStyle;

      // Real numeric double cell value for accurate math & formulas
      final double pounds = tx.amount / 100.0;
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: opRow))
        ..value = DoubleCellValue(pounds)
        ..cellStyle = centerStyle;

      txIndex++;
    }

    // Operations Grand Total Row at bottom
    opRow++;
    for (var c = 0; c <= 5; c++) {
      opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: opRow))
        ..value = TextCellValue(c == 0 ? (labels['exportTotalLabel'] ?? 'الإجمالي العام') : '')
        ..cellStyle = totalRowStyle;
    }
    opsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: opRow))
      ..value = DoubleCellValue(data.expenses / 100.0)
      ..cellStyle = totalRowStyle;

    // Enable auto-filter on table headers
    if (opRow > 2) {
      opsSheet.setAutoFilterByString('A2:G$opRow');
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }
}
