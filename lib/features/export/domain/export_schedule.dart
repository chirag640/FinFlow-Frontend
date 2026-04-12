import 'export_options.dart';

enum ExportScheduleFrequency {
  daily,
  weekly,
  monthly,
}

enum ExportScheduleFormat {
  csv,
  pdf,
}

class ExportSchedule {
  final String id;
  final String name;
  final bool enabled;
  final ExportScheduleFrequency frequency;
  final ExportScheduleFormat format;
  final int hour;
  final int minute;
  final int dayOfWeek; // 1=Mon ... 7=Sun (used for weekly)
  final int dayOfMonth; // 1..31 (used for monthly)
  final ExportTransactionFilter transactionFilter;
  final ExportGrouping grouping;
  final ExportSummaryLayout summaryLayout;
  final ExportBrandTemplate brandTemplate;
  final Set<String> categories;
  final bool includeComparison;
  final DateTime? lastRunAt;

  const ExportSchedule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.frequency = ExportScheduleFrequency.weekly,
    this.format = ExportScheduleFormat.pdf,
    this.hour = 9,
    this.minute = 0,
    this.dayOfWeek = DateTime.monday,
    this.dayOfMonth = 1,
    this.transactionFilter = ExportTransactionFilter.all,
    this.grouping = ExportGrouping.category,
    this.summaryLayout = ExportSummaryLayout.standard,
    this.brandTemplate = ExportBrandTemplate.classic,
    this.categories = const <String>{},
    this.includeComparison = false,
    this.lastRunAt,
  });

  ExportSchedule copyWith({
    String? id,
    String? name,
    bool? enabled,
    ExportScheduleFrequency? frequency,
    ExportScheduleFormat? format,
    int? hour,
    int? minute,
    int? dayOfWeek,
    int? dayOfMonth,
    ExportTransactionFilter? transactionFilter,
    ExportGrouping? grouping,
    ExportSummaryLayout? summaryLayout,
    ExportBrandTemplate? brandTemplate,
    Set<String>? categories,
    bool? includeComparison,
    Object? lastRunAt = _sentinel,
  }) {
    return ExportSchedule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      format: format ?? this.format,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      transactionFilter: transactionFilter ?? this.transactionFilter,
      grouping: grouping ?? this.grouping,
      summaryLayout: summaryLayout ?? this.summaryLayout,
      brandTemplate: brandTemplate ?? this.brandTemplate,
      categories: categories ?? this.categories,
      includeComparison: includeComparison ?? this.includeComparison,
      lastRunAt: identical(lastRunAt, _sentinel)
          ? this.lastRunAt
          : lastRunAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'frequency': frequency.name,
        'format': format.name,
        'hour': hour,
        'minute': minute,
        'dayOfWeek': dayOfWeek,
        'dayOfMonth': dayOfMonth,
        'transactionFilter': transactionFilter.name,
        'grouping': grouping.name,
        'summaryLayout': summaryLayout.name,
        'brandTemplate': brandTemplate.name,
        'categories': categories.toList(),
        'includeComparison': includeComparison,
        'lastRunAt': lastRunAt?.toIso8601String(),
      };

  static ExportSchedule fromJson(Map<String, dynamic> json) {
    final rawHour = (json['hour'] as num?)?.toInt() ?? 9;
    final rawMinute = (json['minute'] as num?)?.toInt() ?? 0;

    return ExportSchedule(
      id: (json['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (json['name'] as String?) ?? 'Scheduled Export',
      enabled: (json['enabled'] as bool?) ?? true,
      frequency: ExportScheduleFrequency.values.firstWhere(
        (value) => value.name == json['frequency'],
        orElse: () => ExportScheduleFrequency.weekly,
      ),
      format: ExportScheduleFormat.values.firstWhere(
        (value) => value.name == json['format'],
        orElse: () => ExportScheduleFormat.pdf,
      ),
      hour: rawHour.clamp(0, 23),
      minute: rawMinute.clamp(0, 59),
      dayOfWeek: ((json['dayOfWeek'] as num?)?.toInt() ?? DateTime.monday)
          .clamp(DateTime.monday, DateTime.sunday),
      dayOfMonth: ((json['dayOfMonth'] as num?)?.toInt() ?? 1).clamp(1, 31),
      transactionFilter: ExportTransactionFilter.values.firstWhere(
        (value) => value.name == json['transactionFilter'],
        orElse: () => ExportTransactionFilter.all,
      ),
      grouping: ExportGrouping.values.firstWhere(
        (value) => value.name == json['grouping'],
        orElse: () => ExportGrouping.category,
      ),
      summaryLayout: ExportSummaryLayout.values.firstWhere(
        (value) => value.name == json['summaryLayout'],
        orElse: () => ExportSummaryLayout.standard,
      ),
      brandTemplate: ExportBrandTemplate.values.firstWhere(
        (value) => value.name == json['brandTemplate'],
        orElse: () => ExportBrandTemplate.classic,
      ),
      categories: (json['categories'] as List?)
              ?.map((entry) => entry.toString())
              .toSet() ??
          <String>{},
      includeComparison: (json['includeComparison'] as bool?) ?? false,
      lastRunAt: DateTime.tryParse((json['lastRunAt'] as String?) ?? ''),
    );
  }

  String get cadenceLabel {
    final time =
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    return switch (frequency) {
      ExportScheduleFrequency.daily => 'Daily at $time',
      ExportScheduleFrequency.weekly => 'Weekly (day $dayOfWeek) at $time',
      ExportScheduleFrequency.monthly => 'Monthly (day $dayOfMonth) at $time',
    };
  }

  static const _sentinel = Object();
}
