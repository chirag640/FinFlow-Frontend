import '../../../core/storage/hive_service.dart';
import '../domain/export_options.dart';

class ExportPreset {
  final String id;
  final String name;
  final String format; // csv | pdf
  final ExportTransactionFilter transactionFilter;
  final ExportGrouping grouping;
  final ExportSummaryLayout summaryLayout;
  final ExportBrandTemplate brandTemplate;
  final Set<String> categories;
  final bool includeComparison;

  const ExportPreset({
    required this.id,
    required this.name,
    required this.format,
    required this.transactionFilter,
    required this.grouping,
    required this.summaryLayout,
    required this.brandTemplate,
    this.categories = const <String>{},
    this.includeComparison = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'format': format,
        'transactionFilter': transactionFilter.name,
        'grouping': grouping.name,
        'summaryLayout': summaryLayout.name,
        'brandTemplate': brandTemplate.name,
        'categories': categories.toList(),
        'includeComparison': includeComparison,
      };

  static ExportPreset fromJson(Map<String, dynamic> j) => ExportPreset(
        id: (j['id'] as String?) ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: (j['name'] as String?) ?? 'Preset',
        format: (j['format'] as String?) ?? 'csv',
        transactionFilter: ExportTransactionFilter.values.firstWhere(
          (e) => e.name == j['transactionFilter'],
          orElse: () => ExportTransactionFilter.all,
        ),
        grouping: ExportGrouping.values.firstWhere(
          (e) => e.name == j['grouping'],
          orElse: () => ExportGrouping.category,
        ),
        summaryLayout: ExportSummaryLayout.values.firstWhere(
          (e) => e.name == j['summaryLayout'],
          orElse: () => ExportSummaryLayout.standard,
        ),
        brandTemplate: ExportBrandTemplate.values.firstWhere(
          (e) => e.name == j['brandTemplate'],
          orElse: () => ExportBrandTemplate.classic,
        ),
        categories:
            (j['categories'] as List?)?.map((e) => e.toString()).toSet() ??
                <String>{},
        includeComparison: (j['includeComparison'] as bool?) ?? false,
      );
}

class ExportPresetStore {
  static const _key = 'export_presets';

  static List<ExportPreset> load() {
    final raw = HiveService.settings.get(_key, defaultValue: const <dynamic>[]);
    if (raw is! List) return const <ExportPreset>[];
    return raw
        .whereType<Map>()
        .map((m) => ExportPreset.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  static Future<void> saveAll(List<ExportPreset> presets) {
    return HiveService.settings
        .put(_key, presets.map((p) => p.toJson()).toList());
  }
}
