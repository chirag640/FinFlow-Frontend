import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../expenses/domain/entities/expense.dart';
import '../../groups/domain/entities/group_expense.dart';
import '../../groups/domain/entities/group_member.dart';
import '../domain/export_options.dart';

/// Generates a formatted A4 PDF expense report and shares it via the OS
/// share sheet. Uses built-in Helvetica — no custom fonts required.
class PdfExportService {
  static Future<File> exportExpenses({
    required List<Expense> expenses,
    required String fileName,
    required String fromLabel,
    required String toLabel,
    String currencySymbol = '',
    ExportOptions options = const ExportOptions(),
    List<Expense>? previousPeriodExpenses,
    String? previousFromLabel,
    String? previousToLabel,
    String organizationName = '',
    String organizationFooter = '',
    String executiveSignatory = '',
    bool shareFile = true,
    Directory? outputDirectory,
  }) async {
    final doc = pw.Document();

    // ── Summary numbers ──────────────────────────────────────────────────────
    final totalExpense =
        expenses.where((e) => !e.isIncome).fold(0.0, (s, e) => s + e.amount);
    final totalIncome =
        expenses.where((e) => e.isIncome).fold(0.0, (s, e) => s + e.amount);
    final net = totalIncome - totalExpense;
    final prefix = currencySymbol.isEmpty ? '' : '$currencySymbol ';
    final accent = _templateAccent(options.brandTemplate);
    final tableHeader = _templateTableHeader(options.brandTemplate);

    final headers = ['Date', 'Description', 'Category', 'Amount', 'Type'];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => _buildHeader(
          fromLabel,
          toLabel,
          options.brandTemplate,
          organizationName,
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (organizationFooter.trim().isNotEmpty)
              pw.Expanded(
                child: pw.Text(
                  organizationFooter,
                  style:
                      const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          _buildSummary(
            layout: options.summaryLayout,
            prefix: prefix,
            totalExpense: totalExpense,
            totalIncome: totalIncome,
            net: net,
            accent: accent,
          ),
          pw.SizedBox(height: 16),
          ..._buildBodySections(
            expenses: expenses,
            headers: headers,
            grouping: options.grouping,
            tableHeader: tableHeader,
            prefix: prefix,
          ),
          if (previousPeriodExpenses != null)
            ..._buildComparisonSection(
              currentExpenses: expenses,
              previousExpenses: previousPeriodExpenses,
              prefix: prefix,
              previousFromLabel: previousFromLabel,
              previousToLabel: previousToLabel,
            ),
          if (options.summaryLayout == ExportSummaryLayout.executive)
            ..._buildSignatureSection(
              signatory: executiveSignatory,
              organizationName: organizationName,
            ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = outputDirectory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(bytes);
    if (shareFile) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'FinFlow — Expense Report  ($fromLabel → $toLabel)',
      );
    }
    return file;
  }

  static Future<void> exportGroupExpenses({
    required List<GroupExpense> expenses,
    required String groupName,
    required String groupEmoji,
    required List<GroupMember> members,
    required String fileName,
    String currencySymbol = '',
  }) async {
    final doc = pw.Document();
    final prefix = currencySymbol.isEmpty ? '' : '$currencySymbol ';

    // exclude settlement entries from the expense table
    final billable = expenses.where((e) => !e.isSettlement).toList();

    String memberName(String id) => members
        .firstWhere((m) => m.id == id,
            orElse: () => GroupMember(id: id, name: 'Unknown'))
        .name;

    final totalAmount = billable.fold(0.0, (s, e) => s + e.amount);
    final uniquePayers = billable.map((e) => e.paidByMemberId).toSet().length;

    final headers = ['Date', 'Description', 'Paid By', 'Amount'];
    final rows = billable.map((e) {
      return [
        '${e.date.year}-${_pad(e.date.month)}-${_pad(e.date.day)}',
        e.description,
        memberName(e.paidByMemberId),
        '$prefix${e.amount.toStringAsFixed(2)}',
      ];
    }).toList();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        header: (_) => _buildGroupHeader(groupEmoji, groupName),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
            ),
          ],
        ),
        build: (context) => [
          pw.SizedBox(height: 12),

          // ── Summary tiles ────────────────────────────────────────────────
          pw.Row(children: [
            _summaryTile(
              label: 'Total Expenses',
              value: '$prefix${totalAmount.toStringAsFixed(2)}',
              color: PdfColors.indigo100,
            ),
            pw.SizedBox(width: 8),
            _summaryTile(
              label: 'Transactions',
              value: '${billable.length}',
              color: PdfColors.teal100,
            ),
            pw.SizedBox(width: 8),
            _summaryTile(
              label: 'Active Payers',
              value: uniquePayers.toString(),
              color: PdfColors.orange100,
            ),
          ]),
          pw.SizedBox(height: 16),

          // ── Expense table ────────────────────────────────────────────────
          pw.Text(
            '${billable.length} expense${billable.length == 1 ? '' : 's'}',
            style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 9,
                color: PdfColors.white),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.indigo400),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellHeight: 20,
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            columnWidths: {
              0: const pw.FixedColumnWidth(62),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FixedColumnWidth(72),
            },
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.pdf');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'FinFlow — $groupEmoji $groupName Group Expenses',
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static pw.Widget _buildGroupHeader(String emoji, String groupName) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FinFlow',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo700)),
            pw.Text('$emoji $groupName — Group Expense Report',
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text(
                'Generated: ${DateTime.now().year}-${_pad(DateTime.now().month)}-${_pad(DateTime.now().day)}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
        ],
      ),
      pw.Divider(color: PdfColors.indigo200),
    ]);
  }

  static pw.Widget _buildHeader(
    String from,
    String to,
    ExportBrandTemplate template,
    String organizationName,
  ) {
    final accent = _templateAccent(template);
    final subtitle = switch (template) {
      ExportBrandTemplate.classic => 'Expense Report',
      ExportBrandTemplate.minimal => 'Financial Snapshot',
      ExportBrandTemplate.ledger => 'Ledger Statement',
    };

    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FinFlow',
                style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: accent)),
            pw.Text(subtitle,
                style:
                    const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            if (organizationName.trim().isNotEmpty)
              pw.Text(
                organizationName,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800),
              ),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Period: $from → $to',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.Text(
                'Generated: ${DateTime.now().year}-${_pad(DateTime.now().month)}-${_pad(DateTime.now().day)}',
                style:
                    const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
        ],
      ),
      pw.Divider(color: _templateDivider(template)),
    ]);
  }

  static List<pw.Widget> _buildBodySections({
    required List<Expense> expenses,
    required List<String> headers,
    required ExportGrouping grouping,
    required PdfColor tableHeader,
    required String prefix,
  }) {
    if (grouping == ExportGrouping.none) {
      return [
        _buildTableTitle(
            '${expenses.length} transaction${expenses.length == 1 ? '' : 's'}'),
        pw.SizedBox(height: 6),
        _expenseTable(
          headers: headers,
          rows: _rowsFor(expenses, prefix),
          headerColor: tableHeader,
        ),
      ];
    }

    final grouped = <String, List<Expense>>{};
    for (final expense in expenses) {
      final key = _groupKey(expense, grouping);
      grouped.putIfAbsent(key, () => <Expense>[]).add(expense);
    }
    final keys = grouped.keys.toList()..sort();

    final widgets = <pw.Widget>[
      _buildTableTitle(
          '${expenses.length} transaction${expenses.length == 1 ? '' : 's'} · grouped'),
      pw.SizedBox(height: 10),
    ];

    for (final key in keys) {
      final items = grouped[key]!;
      final subtotal = items.fold(0.0, (sum, e) => sum + e.amount);
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const pw.BoxDecoration(
          color: PdfColors.grey200,
          borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(key,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey900)),
            pw.Text('Subtotal: $prefix${subtotal.toStringAsFixed(2)}',
                style:
                    const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          ],
        ),
      ));
      widgets.add(pw.SizedBox(height: 6));
      widgets.add(_expenseTable(
        headers: headers,
        rows: _rowsFor(items, prefix),
        headerColor: tableHeader,
      ));
      widgets.add(pw.SizedBox(height: 10));
    }

    return widgets;
  }

  static pw.Widget _buildSummary({
    required ExportSummaryLayout layout,
    required String prefix,
    required double totalExpense,
    required double totalIncome,
    required double net,
    required PdfColor accent,
  }) {
    if (layout == ExportSummaryLayout.compact) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: accent, width: 0.6),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Expenses: $prefix${totalExpense.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text('Income: $prefix${totalIncome.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.Text(
                'Net: ${net >= 0 ? '+' : ''}$prefix${net.toStringAsFixed(2)}',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: net >= 0 ? PdfColors.green700 : PdfColors.red700)),
          ],
        ),
      );
    }

    if (layout == ExportSummaryLayout.executive) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: accent, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Executive Summary',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: accent)),
                pw.SizedBox(height: 6),
                pw.Text(
                    'Total Expenses: $prefix${totalExpense.toStringAsFixed(2)}'),
                pw.Text(
                    'Total Income: $prefix${totalIncome.toStringAsFixed(2)}'),
                pw.Text(
                    'Net Position: ${net >= 0 ? '+' : ''}$prefix${net.toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      );
    }

    return pw.Row(children: [
      _summaryTile(
        label: 'Total Expenses',
        value: '$prefix${totalExpense.toStringAsFixed(2)}',
        color: PdfColors.red200,
      ),
      pw.SizedBox(width: 8),
      _summaryTile(
        label: 'Total Income',
        value: '$prefix${totalIncome.toStringAsFixed(2)}',
        color: PdfColors.green200,
      ),
      pw.SizedBox(width: 8),
      _summaryTile(
        label: 'Net Balance',
        value: '${net >= 0 ? '+' : ''}$prefix${net.toStringAsFixed(2)}',
        color: net >= 0 ? PdfColors.blue200 : PdfColors.orange200,
      ),
    ]);
  }

  static List<pw.Widget> _buildComparisonSection({
    required List<Expense> currentExpenses,
    required List<Expense> previousExpenses,
    required String prefix,
    String? previousFromLabel,
    String? previousToLabel,
  }) {
    final currentExpenseTotal = currentExpenses
        .where((e) => !e.isIncome)
        .fold(0.0, (s, e) => s + e.amount);
    final currentIncomeTotal = currentExpenses
        .where((e) => e.isIncome)
        .fold(0.0, (s, e) => s + e.amount);
    final previousExpenseTotal = previousExpenses
        .where((e) => !e.isIncome)
        .fold(0.0, (s, e) => s + e.amount);
    final previousIncomeTotal = previousExpenses
        .where((e) => e.isIncome)
        .fold(0.0, (s, e) => s + e.amount);

    final currentNet = currentIncomeTotal - currentExpenseTotal;
    final previousNet = previousIncomeTotal - previousExpenseTotal;
    final delta = currentNet - previousNet;
    final deltaPct = previousNet == 0 ? null : (delta / previousNet) * 100;

    return [
      pw.SizedBox(height: 8),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Cross-Period Comparison',
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800)),
            if ((previousFromLabel ?? '').isNotEmpty &&
                (previousToLabel ?? '').isNotEmpty)
              pw.Text('Compared with: $previousFromLabel → $previousToLabel',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
            pw.SizedBox(height: 6),
            pw.Text(
                'Current Net: ${currentNet >= 0 ? '+' : ''}$prefix${currentNet.toStringAsFixed(2)}'),
            pw.Text(
                'Previous Net: ${previousNet >= 0 ? '+' : ''}$prefix${previousNet.toStringAsFixed(2)}'),
            pw.Text(
              'Delta: ${delta >= 0 ? '+' : ''}$prefix${delta.toStringAsFixed(2)}'
              '${deltaPct == null ? '' : ' (${deltaPct >= 0 ? '+' : ''}${deltaPct.toStringAsFixed(1)}%)'}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: delta >= 0 ? PdfColors.green700 : PdfColors.red700,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  static List<pw.Widget> _buildSignatureSection({
    required String signatory,
    required String organizationName,
  }) {
    return [
      pw.SizedBox(height: 18),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(
            width: 220,
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.grey500, width: 0.8),
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  signatory.trim().isEmpty ? 'Authorized Signatory' : signatory,
                  style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800),
                ),
                if (organizationName.trim().isNotEmpty)
                  pw.Text(organizationName,
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  static pw.Widget _buildTableTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700),
    );
  }

  static pw.Widget _expenseTable({
    required List<String> headers,
    required List<List<String>> rows,
    required PdfColor headerColor,
  }) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
          fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
      headerDecoration: pw.BoxDecoration(color: headerColor),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellHeight: 20,
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      columnWidths: {
        0: const pw.FixedColumnWidth(58),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.6),
        3: const pw.FixedColumnWidth(68),
        4: const pw.FixedColumnWidth(52),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.center,
      },
    );
  }

  static List<List<String>> _rowsFor(List<Expense> expenses, String prefix) {
    return expenses
        .map((e) => [
              '${e.date.year}-${_pad(e.date.month)}-${_pad(e.date.day)}',
              e.description,
              e.category.label,
              '$prefix${e.amount.toStringAsFixed(2)}',
              e.isIncome ? 'Income' : 'Expense',
            ])
        .toList();
  }

  static String _groupKey(Expense e, ExportGrouping grouping) {
    switch (grouping) {
      case ExportGrouping.category:
        return e.category.label;
      case ExportGrouping.type:
        return e.isIncome ? 'Income' : 'Expense';
      case ExportGrouping.day:
        return '${e.date.year}-${_pad(e.date.month)}-${_pad(e.date.day)}';
      case ExportGrouping.none:
        return 'All';
    }
  }

  static PdfColor _templateAccent(ExportBrandTemplate template) {
    switch (template) {
      case ExportBrandTemplate.classic:
        return PdfColors.indigo700;
      case ExportBrandTemplate.minimal:
        return PdfColors.blueGrey700;
      case ExportBrandTemplate.ledger:
        return PdfColors.teal700;
    }
  }

  static PdfColor _templateDivider(ExportBrandTemplate template) {
    switch (template) {
      case ExportBrandTemplate.classic:
        return PdfColors.indigo200;
      case ExportBrandTemplate.minimal:
        return PdfColors.blueGrey200;
      case ExportBrandTemplate.ledger:
        return PdfColors.teal200;
    }
  }

  static PdfColor _templateTableHeader(ExportBrandTemplate template) {
    switch (template) {
      case ExportBrandTemplate.classic:
        return PdfColors.indigo400;
      case ExportBrandTemplate.minimal:
        return PdfColors.blueGrey500;
      case ExportBrandTemplate.ledger:
        return PdfColors.teal500;
    }
  }

  static pw.Widget _summaryTile({
    required String label,
    required String value,
    required PdfColor color,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw
            .Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800)),
          pw.SizedBox(height: 2),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900)),
        ]),
      ),
    );
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
