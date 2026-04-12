import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../expenses/domain/entities/expense.dart';
import '../domain/export_options.dart';

class CsvExportService {
  static Future<File> exportExpenses({
    required List<Expense> expenses,
    required String fileName,
    ExportOptions options = const ExportOptions(),
    bool shareFile = true,
    Directory? outputDirectory,
  }) async {
    final rows = <List<dynamic>>[];
    const header = [
      'Date',
      'Description',
      'Category',
      'Amount',
      'Type',
      'Note'
    ];
    rows.add(header);

    if (options.grouping == ExportGrouping.none) {
      rows.addAll(expenses.map((e) => [
            '${e.date.year}-${_p(e.date.month)}-${_p(e.date.day)}',
            e.description,
            e.category.label,
            e.amount.toStringAsFixed(2),
            e.isIncome ? 'Income' : 'Expense',
            e.note ?? '',
          ]));
    } else {
      final grouped = <String, List<Expense>>{};
      for (final e in expenses) {
        final key = _groupKey(e, options.grouping);
        grouped.putIfAbsent(key, () => <Expense>[]).add(e);
      }

      final keys = grouped.keys.toList()..sort();
      for (final key in keys) {
        final group = grouped[key]!;
        final subtotal = group.fold(0.0, (sum, item) => sum + item.amount);
        rows.add(['Group', key, '', '', '', '']);
        rows.addAll(group.map((e) => [
              '${e.date.year}-${_p(e.date.month)}-${_p(e.date.day)}',
              e.description,
              e.category.label,
              e.amount.toStringAsFixed(2),
              e.isIncome ? 'Income' : 'Expense',
              e.note ?? '',
            ]));
        rows.add(['Subtotal', '', '', subtotal.toStringAsFixed(2), '', '']);
        rows.add(['', '', '', '', '', '']);
      }
    }

    final csv = const ListToCsvConverter().convert(rows);
    final dir = outputDirectory ?? await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName.csv');
    await file.writeAsString(csv);
    if (shareFile) {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'FinFlow — Expense Export',
      );
    }
    return file;
  }

  static String _groupKey(Expense e, ExportGrouping grouping) {
    switch (grouping) {
      case ExportGrouping.category:
        return e.category.label;
      case ExportGrouping.type:
        return e.isIncome ? 'Income' : 'Expense';
      case ExportGrouping.day:
        return '${e.date.year}-${_p(e.date.month)}-${_p(e.date.day)}';
      case ExportGrouping.none:
        return 'All';
    }
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
