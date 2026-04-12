import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/notification_service.dart';
import '../../expenses/domain/entities/expense.dart';
import '../data/export_schedule_store.dart';
import '../domain/export_options.dart';
import '../domain/export_schedule.dart';
import 'csv_export_service.dart';
import 'pdf_export_service.dart';

class ScheduledExportService {
  static Future<int> runDueSchedules({
    required DateTime now,
    required List<Expense> allExpenses,
    required String currencyCode,
    required String organizationName,
    required String organizationFooter,
    required String executiveSignatory,
  }) async {
    final schedules = ExportScheduleStore.load();
    if (schedules.isEmpty) return 0;

    final outputDirectory = await _scheduledOutputDirectory();
    final updated = <ExportSchedule>[];
    var generatedCount = 0;

    for (final schedule in schedules) {
      if (!_isDue(schedule, now)) {
        updated.add(schedule);
        continue;
      }

      final period = _periodRange(schedule, now);
      final filtered = _applyFilters(
        source: allExpenses,
        from: period.$1,
        to: period.$2,
        schedule: schedule,
      );

      if (filtered.isEmpty) {
        updated.add(schedule.copyWith(lastRunAt: now));
        continue;
      }

      final namePart = schedule.name
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_|_$'), '');
      final fileName =
          'finflow_auto_${namePart.isEmpty ? 'export' : namePart}_${DateFormat('yyyyMMdd_HHmm').format(now)}';

      final options = ExportOptions(
        transactionFilter: schedule.transactionFilter,
        grouping: schedule.grouping,
        summaryLayout: schedule.summaryLayout,
        brandTemplate: schedule.brandTemplate,
      );

      if (schedule.format == ExportScheduleFormat.csv) {
        await CsvExportService.exportExpenses(
          expenses: filtered,
          fileName: fileName,
          options: options,
          shareFile: false,
          outputDirectory: outputDirectory,
        );
      } else {
        List<Expense>? previousPeriodExpenses;
        String? previousFromLabel;
        String? previousToLabel;

        if (schedule.includeComparison) {
          final previous = _previousPeriod(period.$1, period.$2);
          previousPeriodExpenses = _applyFilters(
            source: allExpenses,
            from: previous.$1,
            to: previous.$2,
            schedule: schedule,
          );
          previousFromLabel = DateFormat('d MMM yyyy').format(previous.$1);
          previousToLabel = DateFormat('d MMM yyyy').format(previous.$2);
        }

        await PdfExportService.exportExpenses(
          expenses: filtered,
          fileName: fileName,
          fromLabel: DateFormat('d MMM yyyy').format(period.$1),
          toLabel: DateFormat('d MMM yyyy').format(period.$2),
          currencySymbol: currencyCode,
          options: options,
          previousPeriodExpenses: previousPeriodExpenses,
          previousFromLabel: previousFromLabel,
          previousToLabel: previousToLabel,
          organizationName: organizationName,
          organizationFooter: organizationFooter,
          executiveSignatory: executiveSignatory,
          shareFile: false,
          outputDirectory: outputDirectory,
        );
      }

      generatedCount++;
      await NotificationService.showScheduledExportReady(
        schedule.name,
        schedule.format.name.toUpperCase(),
      );
      updated.add(schedule.copyWith(lastRunAt: now));
    }

    await ExportScheduleStore.saveAll(updated);
    return generatedCount;
  }

  static List<Expense> _applyFilters({
    required List<Expense> source,
    required DateTime from,
    required DateTime to,
    required ExportSchedule schedule,
  }) {
    return source.where((expense) {
      if (expense.date.isBefore(from) || expense.date.isAfter(to)) {
        return false;
      }

      if (schedule.transactionFilter == ExportTransactionFilter.expense &&
          expense.isIncome) {
        return false;
      }
      if (schedule.transactionFilter == ExportTransactionFilter.income &&
          !expense.isIncome) {
        return false;
      }

      if (schedule.categories.isNotEmpty &&
          !schedule.categories.contains(expense.category.name)) {
        return false;
      }

      return true;
    }).toList();
  }

  static bool _isDue(ExportSchedule schedule, DateTime now) {
    if (!schedule.enabled) return false;

    final nowAtMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      schedule.hour,
      schedule.minute,
    );
    if (nowAtMinute.isBefore(scheduledToday)) {
      return false;
    }

    if (schedule.lastRunAt != null) {
      final currentKey = _periodKey(schedule, now);
      final lastKey = _periodKey(schedule, schedule.lastRunAt!);
      if (currentKey == lastKey) {
        return false;
      }
    }

    return switch (schedule.frequency) {
      ExportScheduleFrequency.daily => true,
      ExportScheduleFrequency.weekly => now.weekday == schedule.dayOfWeek,
      ExportScheduleFrequency.monthly =>
        now.day == _effectiveMonthDay(now, schedule.dayOfMonth),
    };
  }

  static String _periodKey(ExportSchedule schedule, DateTime date) {
    return switch (schedule.frequency) {
      ExportScheduleFrequency.daily => DateFormat('yyyy-MM-dd').format(date),
      ExportScheduleFrequency.weekly =>
        '${_isoWeekYear(date)}-W${_isoWeekNumber(date).toString().padLeft(2, '0')}-${schedule.dayOfWeek}',
      ExportScheduleFrequency.monthly =>
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${_effectiveMonthDay(date, schedule.dayOfMonth).toString().padLeft(2, '0')}',
    };
  }

  static (DateTime, DateTime) _periodRange(
      ExportSchedule schedule, DateTime now) {
    return switch (schedule.frequency) {
      ExportScheduleFrequency.daily => (
          DateTime(now.year, now.month, now.day),
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        ),
      ExportScheduleFrequency.weekly => (
          DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: now.weekday - DateTime.monday)),
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        ),
      ExportScheduleFrequency.monthly => (
          DateTime(now.year, now.month, 1),
          DateTime(now.year, now.month, now.day, 23, 59, 59, 999),
        ),
    };
  }

  static (DateTime, DateTime) _previousPeriod(DateTime from, DateTime to) {
    final durationDays = to.difference(from).inDays + 1;
    final previousTo = from.subtract(const Duration(days: 1));
    final previousFrom = previousTo.subtract(Duration(days: durationDays - 1));
    return (
      previousFrom,
      DateTime(
        previousTo.year,
        previousTo.month,
        previousTo.day,
        23,
        59,
        59,
        999,
      )
    );
  }

  static int _effectiveMonthDay(DateTime date, int targetDay) {
    final maxDay = DateTime(date.year, date.month + 1, 0).day;
    return targetDay.clamp(1, maxDay);
  }

  static int _isoWeekNumber(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final day = d.weekday == DateTime.sunday ? 7 : d.weekday;
    final thursday = d.add(Duration(days: 4 - day));
    final yearStart = DateTime.utc(thursday.year, 1, 1);
    final diff = thursday.difference(yearStart).inDays;
    return ((diff + 1) / 7).ceil();
  }

  static int _isoWeekYear(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final day = d.weekday == DateTime.sunday ? 7 : d.weekday;
    final thursday = d.add(Duration(days: 4 - day));
    return thursday.year;
  }

  static Future<Directory> _scheduledOutputDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/exports/scheduled');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
